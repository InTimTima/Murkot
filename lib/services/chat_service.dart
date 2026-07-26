import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/conversation.dart';
import '../models/message.dart';
import '../utils/helpers.dart';

class ChatService extends ChangeNotifier {
  ChatService(this._prefs, this._userLogin) {
    _load();
    if (_conversations.isEmpty) {
      _seedDemoData();
    } else {
      _syncAllConversationPreviews();
    }
  }

  static const _conversationsKey = 'conversations';
  static const _messagesKey = 'messages';
  static const _commentsKey = 'comments';
  static const _pinnedMeKey = 'pinned_me';
  static const _dataVersionKey = 'chat_data_version';
  static const _currentDataVersion = 2;

  final SharedPreferences _prefs;
  final String _userLogin;

  List<Conversation> _conversations = [];
  Map<String, List<Message>> _messages = {};
  Map<String, List<Message>> _comments = {};
  Map<String, List<String>> _pinnedForMe = {};

  List<Conversation> getConversations(ConversationType type) {
    return _conversations.where((c) => c.type == type).toList()
      ..sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
  }

  List<Conversation> searchConversations(ConversationType type, String query) {
    final q = query.trim();
    if (q.isEmpty) return getConversations(type);
    return getConversations(type).where((c) {
      return matchesSearch(c.name, q) ||
          matchesSearch(c.lastMessage, q) ||
          (c.lastMessageSender != null && matchesSearch(c.lastMessageSender!, q));
    }).toList();
  }

  Conversation? getConversation(String id) {
    try {
      return _conversations.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  List<Message> getMessages(String conversationId) {
    return (_messages[conversationId] ?? [])
        .where((m) => !m.deletedForMe)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  List<Message> getMediaMessages(String conversationId, MessageType type) {
    return getMessages(conversationId).where((m) => m.type == type).toList();
  }

  List<Message> getPinnedMessages(String conversationId) {
    final conv = getConversation(conversationId);
    if (conv == null) return [];

    final allIds = {
      ...conv.pinnedForAllIds,
      ...(_pinnedForMe[conversationId] ?? []),
    };
    final messages = getMessages(conversationId);
    return allIds
        .map((id) => messages.where((m) => m.id == id).firstOrNull)
        .whereType<Message>()
        .toList();
  }

  List<Message> getComments(String messageId) {
    return (_comments[messageId] ?? [])
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  bool canSendMessages(Conversation conversation) {
    if (conversation.type != ConversationType.channel) return true;
    return conversation.isAdmin;
  }

  Future<void> setTyping(String conversationId, bool isTyping) async {
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index == -1) return;

    var typing = List<String>.from(_conversations[index].typingUsers);
    if (isTyping) {
      if (!typing.contains(_userLogin)) typing.add(_userLogin);
    } else {
      typing.remove(_userLogin);
    }

    _conversations[index] =
        _conversations[index].copyWith(typingUsers: typing);
    notifyListeners();
  }

  Future<Conversation> createConversation({
    required ConversationType type,
    required String name,
  }) async {
    final id = '${type.name}_${DateTime.now().millisecondsSinceEpoch}';
    final conversation = Conversation(
      id: id,
      type: type,
      name: name,
      avatarEmoji: pickRandomEmoji(),
      lastActivity: DateTime.now(),
      isAdmin: type != ConversationType.direct,
      memberIds: [_userLogin],
      onlineCount: type == ConversationType.group ? 1 : 0,
      subscriberCount: type == ConversationType.channel ? 1 : 0,
    );
    _conversations.add(conversation);
    _messages[id] = [];
    await _save();
    notifyListeners();
    return conversation;
  }

  Future<void> deleteConversation(String id) async {
    _conversations.removeWhere((c) => c.id == id);
    _messages.remove(id);
    _pinnedForMe.remove(id);
    await _save();
    notifyListeners();
  }

  Future<void> leaveConversation(String id) async {
    await deleteConversation(id);
  }

  Future<void> updateConversation(Conversation updated) async {
    final index = _conversations.indexWhere((c) => c.id == updated.id);
    if (index == -1) return;
    _conversations[index] = updated;
    await _save();
    notifyListeners();
  }

  Future<void> sendMessage({
    required String conversationId,
    required MessageType type,
    required String content,
    String? senderEmoji,
  }) async {
    final parts = type == MessageType.text ? splitMessageText(content) : [content];

    for (var i = 0; i < parts.length; i++) {
      final part = parts[i];
      final message = Message(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}_$i',
        conversationId: conversationId,
        senderId: _userLogin,
        senderName: _userLogin,
        type: type,
        content: part,
        timestamp: DateTime.now().add(Duration(milliseconds: i * 10)),
        isRead: false,
        viewCount: 0,
        senderEmoji: senderEmoji,
      );

      _messages.putIfAbsent(conversationId, () => []).add(message);
      _updateConversationPreview(conversationId, message);
    }

    await _save();
    notifyListeners();
  }

  Future<void> addComment({
    required String postMessageId,
    required String conversationId,
    required String content,
  }) async {
    final comment = Message(
      id: 'cmt_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: conversationId,
      senderId: _userLogin,
      senderName: _userLogin,
      type: MessageType.text,
      content: content,
      timestamp: DateTime.now(),
    );
    _comments.putIfAbsent(postMessageId, () => []).add(comment);
    await _save();
    notifyListeners();
  }

  Future<void> markMessagesRead(String conversationId) async {
    final list = _messages[conversationId];
    if (list == null) return;
    var changed = false;
    for (var i = 0; i < list.length; i++) {
      if (list[i].senderId != _userLogin && !list[i].isRead) {
        list[i] = list[i].copyWith(isRead: true);
        changed = true;
      }
    }
    if (changed) {
      await _save();
      notifyListeners();
    }
  }

  Future<void> incrementViews(String conversationId, String messageId) async {
    final list = _messages[conversationId];
    if (list == null) return;
    final index = list.indexWhere((m) => m.id == messageId);
    if (index == -1) return;
    list[index] = list[index].copyWith(viewCount: list[index].viewCount + 1);
    await _save();
    notifyListeners();
  }

  Future<void> editMessage(
    String conversationId,
    String messageId,
    String newContent,
  ) async {
    final list = _messages[conversationId];
    if (list == null) return;
    final index = list.indexWhere((m) => m.id == messageId);
    if (index == -1 || list[index].senderId != _userLogin) return;

    list[index] = list[index].copyWith(content: newContent, isEdited: true);
    _syncConversationPreview(conversationId);
    await _save();
    notifyListeners();
  }

  Future<void> deleteMessage(
    String conversationId,
    String messageId, {
    required bool forEveryone,
  }) async {
    final list = _messages[conversationId];
    if (list == null) return;
    final index = list.indexWhere((m) => m.id == messageId);
    if (index == -1 || list[index].senderId != _userLogin) return;

    if (forEveryone) {
      list[index] = list[index].copyWith(isDeletedForAll: true, content: '');
    } else {
      list[index] = list[index].copyWith(deletedForMe: true);
    }
    _unpinMessage(conversationId, messageId);
    _syncConversationPreview(conversationId);
    await _save();
    notifyListeners();
  }

  Future<void> pinMessage(
    String conversationId,
    String messageId, {
    required bool forEveryone,
  }) async {
    if (forEveryone) {
      final conv = getConversation(conversationId);
      if (conv == null) return;
      final pinned = List<String>.from(conv.pinnedForAllIds);
      if (!pinned.contains(messageId)) pinned.add(messageId);
      await updateConversation(conv.copyWith(pinnedForAllIds: pinned));
    } else {
      _pinnedForMe.putIfAbsent(conversationId, () => []);
      if (!_pinnedForMe[conversationId]!.contains(messageId)) {
        _pinnedForMe[conversationId]!.add(messageId);
        await _savePinnedForMe();
        notifyListeners();
      }
    }
  }

  Future<void> unpinMessage(
    String conversationId,
    String messageId, {
    required bool forEveryone,
  }) async {
    if (forEveryone) {
      final conv = getConversation(conversationId);
      if (conv == null) return;
      final pinned =
          conv.pinnedForAllIds.where((id) => id != messageId).toList();
      await updateConversation(conv.copyWith(pinnedForAllIds: pinned));
    } else {
      _pinnedForMe[conversationId]?.remove(messageId);
      await _savePinnedForMe();
      notifyListeners();
    }
  }

  void _unpinMessage(String conversationId, String messageId) {
    _pinnedForMe[conversationId]?.remove(messageId);
    final convIndex = _conversations.indexWhere((c) => c.id == conversationId);
    if (convIndex != -1) {
      final conv = _conversations[convIndex];
      _conversations[convIndex] = conv.copyWith(
        pinnedForAllIds:
            conv.pinnedForAllIds.where((id) => id != messageId).toList(),
      );
    }
  }

  Future<void> toggleReaction(
    String conversationId,
    String messageId,
    String emoji,
  ) async {
    final list = _messages[conversationId];
    if (list == null) return;
    final index = list.indexWhere((m) => m.id == messageId);
    if (index == -1) return;

    final reactions = Map<String, String>.from(list[index].reactions);
    if (reactions[_userLogin] == emoji) {
      reactions.remove(_userLogin);
    } else {
      reactions[_userLogin] = emoji;
    }
    list[index] = list[index].copyWith(reactions: reactions);
    await _save();
    notifyListeners();
  }

  void _updateConversationPreview(String conversationId, Message message) {
    final preview = message.type == MessageType.text
        ? message.content
        : messageTypeLabel(message.type);

    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index != -1) {
      _conversations[index] = _conversations[index].copyWith(
        lastMessage: preview,
        lastMessageSender: _userLogin,
        lastActivity: message.timestamp,
      );
    }
  }

  void _syncConversationPreview(String conversationId) {
    final visible = getMessages(conversationId);
    final index = _conversations.indexWhere((c) => c.id == conversationId);

    if (index == -1) return;

    if (visible.isEmpty) {
      _conversations[index] = _conversations[index].copyWith(
        lastMessage: '',
        lastMessageSender: null,
      );
      return;
    }

    final last = visible.last;
    _conversations[index] = _conversations[index].copyWith(
      lastMessage: last.type == MessageType.text
          ? last.content
          : messageTypeLabel(last.type),
      lastMessageSender: last.senderId == _userLogin ? _userLogin : last.senderName,
      lastActivity: last.timestamp,
    );
  }

  void _syncAllConversationPreviews() {
    for (final conv in _conversations) {
      _syncConversationPreview(conv.id);
    }
  }

  void _load() {
    final version = _prefs.getInt('${_dataVersionKey}_$_userLogin') ?? 0;
    if (version < _currentDataVersion) {
      _prefs.remove('${_conversationsKey}_$_userLogin');
      _prefs.remove('${_messagesKey}_$_userLogin');
      _prefs.remove('${_commentsKey}_$_userLogin');
      _prefs.setInt('${_dataVersionKey}_$_userLogin', _currentDataVersion);
      return;
    }

    final convRaw = _prefs.getString('${_conversationsKey}_$_userLogin');
    if (convRaw != null) {
      final list = jsonDecode(convRaw) as List<dynamic>;
      _conversations = list
          .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    final msgRaw = _prefs.getString('${_messagesKey}_$_userLogin');
    if (msgRaw != null) {
      final map = jsonDecode(msgRaw) as Map<String, dynamic>;
      _messages = map.map(
        (key, value) => MapEntry(
          key,
          (value as List<dynamic>)
              .map((e) => Message.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
    }

    final cmtRaw = _prefs.getString('${_commentsKey}_$_userLogin');
    if (cmtRaw != null) {
      final map = jsonDecode(cmtRaw) as Map<String, dynamic>;
      _comments = map.map(
        (key, value) => MapEntry(
          key,
          (value as List<dynamic>)
              .map((e) => Message.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
    }

    final pinnedRaw = _prefs.getString('${_pinnedMeKey}_$_userLogin');
    if (pinnedRaw != null) {
      final map = jsonDecode(pinnedRaw) as Map<String, dynamic>;
      _pinnedForMe = map.map(
        (key, value) => MapEntry(key, (value as List<dynamic>).cast<String>()),
      );
    }
  }

  Future<void> _save() async {
    await _prefs.setString(
      '${_conversationsKey}_$_userLogin',
      jsonEncode(_conversations.map((c) => c.toJson()).toList()),
    );
    await _prefs.setString(
      '${_messagesKey}_$_userLogin',
      jsonEncode(
        _messages.map(
          (key, value) => MapEntry(key, value.map((m) => m.toJson()).toList()),
        ),
      ),
    );
    await _prefs.setString(
      '${_commentsKey}_$_userLogin',
      jsonEncode(
        _comments.map(
          (key, value) => MapEntry(key, value.map((m) => m.toJson()).toList()),
        ),
      ),
    );
    await _prefs.setInt('${_dataVersionKey}_$_userLogin', _currentDataVersion);
  }

  Future<void> _savePinnedForMe() async {
    await _prefs.setString(
      '${_pinnedMeKey}_$_userLogin',
      jsonEncode(_pinnedForMe),
    );
  }

  void _seedDemoData() {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    _conversations = [
      Conversation(
        id: 'direct_alice',
        type: ConversationType.direct,
        name: 'Алиса',
        avatarEmoji: '🦊',
        lastActivity: now.subtract(const Duration(minutes: 2)),
        isOnline: true,
        memberIds: ['Алиса'],
        contactStatus: 'Учусь в универе',
        contactBirthday: DateTime(2003, 5, 14),
      ),
      Conversation(
        id: 'direct_bob',
        type: ConversationType.direct,
        name: 'Боб',
        avatarEmoji: '🎮',
        lastActivity: now.subtract(const Duration(hours: 1)),
        isOnline: false,
        memberIds: ['Боб'],
        contactStatus: 'На работе',
        contactBirthday: DateTime(1999, 11, 3),
      ),
      Conversation(
        id: 'direct_kate',
        type: ConversationType.direct,
        name: 'Катя',
        avatarEmoji: '🌟',
        lastActivity: now.subtract(const Duration(minutes: 45)),
        isOnline: true,
        memberIds: ['Катя'],
        contactStatus: 'В пути',
        contactBirthday: DateTime(2001, 2, 28),
      ),
      Conversation(
        id: 'group_friends',
        type: ConversationType.group,
        name: 'Друзья',
        avatarEmoji: '🎉',
        lastActivity: now.subtract(const Duration(minutes: 8)),
        onlineCount: 4,
        memberIds: ['Катя', 'Дима', 'Алиса', 'Боб'],
        isAdmin: true,
      ),
      Conversation(
        id: 'group_work',
        type: ConversationType.group,
        name: 'Работа',
        avatarEmoji: '💼',
        lastActivity: now.subtract(const Duration(hours: 3)),
        onlineCount: 2,
        memberIds: ['Иван', 'Мария', 'Олег'],
        isAdmin: false,
      ),
      Conversation(
        id: 'group_gaming',
        type: ConversationType.group,
        name: 'Геймеры',
        avatarEmoji: '🕹️',
        lastActivity: yesterday,
        onlineCount: 6,
        memberIds: ['Боб', 'Дима', 'Саша'],
        isAdmin: true,
      ),
      Conversation(
        id: 'channel_news',
        type: ConversationType.channel,
        name: 'Новости Tujh',
        avatarEmoji: '📢',
        lastActivity: now.subtract(const Duration(hours: 5)),
        subscriberCount: 1280,
        isAdmin: true,
      ),
      Conversation(
        id: 'channel_memes',
        type: ConversationType.channel,
        name: 'Мемы дня',
        avatarEmoji: '😂',
        lastActivity: now.subtract(const Duration(minutes: 20)),
        subscriberCount: 5420,
        isAdmin: false,
      ),
    ];

    _messages = {
      'direct_alice': _genDirectChat('direct_alice', 'Алиса', '🦊', now, 25),
      'direct_bob': _genDirectChat('direct_bob', 'Боб', '🎮', now, 18),
      'direct_kate': _genDirectChat('direct_kate', 'Катя', '🌟', now, 12),
      'group_friends': _genGroupChat('group_friends', now, ['Катя', 'Дима', 'Алиса', 'Боб'], 30),
      'group_work': _genGroupChat('group_work', now, ['Иван', 'Мария', 'Олег'], 15),
      'group_gaming': _genGroupChat('group_gaming', yesterday, ['Боб', 'Дима', 'Саша'], 22),
      'channel_news': _genChannelPosts('channel_news', now, 8),
      'channel_memes': _genChannelPosts('channel_memes', now, 6),
    };

    _syncAllConversationPreviews();

    // Seed comments for first channel post
    final newsPosts = _messages['channel_news']!;
    if (newsPosts.isNotEmpty) {
      _comments[newsPosts.first.id] = [
        _msg('channel_news', 'User1', 'Круто!', now.subtract(const Duration(hours: 4)), emoji: '👤'),
        _msg('channel_news', 'User2', 'Ждём обновление', now.subtract(const Duration(hours: 3)), emoji: '🎭'),
        ...List.generate(12, (i) => _msg(
          'channel_news', 'User$i', 'Коммент $i', now.subtract(Duration(minutes: 120 - i)),
        )),
      ];
    }

    _save();
  }

  List<Message> _genDirectChat(
    String convId,
    String name,
    String emoji,
    DateTime now,
    int count,
  ) {
    final texts = [
      'Привет!', 'Как дела?', 'Что делаешь?', 'Пойдём гулять?',
      'Отправил файл', 'Посмотри это', 'ахахах', 'ок', 'понял', 'спасибо!',
      'До встречи', 'Пока!', '👋', 'Хорошо', 'Завтра созвонимся?',
    ];
    return List.generate(count, (i) {
      final isMe = i % 2 == 1;
      final time = now.subtract(Duration(minutes: (count - i) * 7));
      return _msg(
        convId,
        isMe ? _userLogin : name,
        texts[i % texts.length],
        time,
        emoji: isMe ? null : emoji,
        isRead: isMe || i < count - 2,
      );
    });
  }

  List<Message> _genGroupChat(
    String convId,
    DateTime now,
    List<String> members,
    int count,
  ) {
    final texts = [
      'Всем привет!', 'Встречаемся в 18:00', 'Я опаздываю',
      'Кто идёт?', 'Я!', 'Ок', 'Не смогу', 'Перенесём?',
      'Фото с прошлого раза', 'ахах', '🔥', 'го',
    ];
    return List.generate(count, (i) {
      final sender = members[i % members.length];
      return _msg(
        convId,
        sender,
        texts[i % texts.length],
        now.subtract(Duration(minutes: (count - i) * 5)),
        emoji: pickRandomEmoji(i),
        isRead: i < count - 3,
      );
    });
  }

  List<Message> _genChannelPosts(String convId, DateTime now, int count) {
    final posts = [
      'Обновление v2.0 уже здесь!',
      'Новые стикеры в магазине',
      'Техработы завтра с 3:00 до 5:00',
      'Конкурс: лучший мем месяца',
      'Интервью с разработчиками',
      'Планируем голосовые комнаты',
      'Спасибо за 1000 подписчиков!',
      'Beta-тест новых реакций',
    ];
    return List.generate(count, (i) {
      return Message(
        id: 'post_${convId}_$i',
        conversationId: convId,
        senderId: 'Admin',
        senderName: 'Admin',
        type: MessageType.text,
        content: posts[i % posts.length],
        timestamp: now.subtract(Duration(hours: count - i)),
        viewCount: 100 + i * 47,
        senderEmoji: '📢',
      );
    });
  }

  Message _msg(
    String convId,
    String sender,
    String text,
    DateTime time, {
    String? emoji,
    bool isRead = false,
  }) {
    return Message(
      id: 'msg_${convId}_${time.millisecondsSinceEpoch}_$sender',
      conversationId: convId,
      senderId: sender,
      senderName: sender,
      type: MessageType.text,
      content: text,
      timestamp: time,
      isRead: isRead,
      senderEmoji: emoji,
    );
  }
}

String generateVerificationCode() {
  final random = Random();
  return List.generate(5, (_) => random.nextInt(10)).join();
}
