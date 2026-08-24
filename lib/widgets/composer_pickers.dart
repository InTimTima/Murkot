import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/gif_config.dart';
import '../data/sticker_packs.dart';
import '../l10n/app_strings.dart';

class GifHit {
  const GifHit({required this.previewUrl, required this.url, required this.name});

  final String previewUrl;
  final String url;
  final String name;
}

Future<void> showEmojiPicker(
  BuildContext context, {
  required ValueChanged<String> onPick,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.strings.emojiPickerTitle,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 280,
                child: GridView.count(
                  crossAxisCount: 8,
                  children: [
                    for (final emoji in kEmojiPalette)
                      InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          onPick(emoji);
                        },
                        child: Center(
                          child: Text(emoji, style: const TextStyle(fontSize: 26)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> showStickerPicker(
  BuildContext context, {
  required void Function(StickerItem sticker) onPick,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      final strings = context.strings;
      return DefaultTabController(
        length: kStickerPacks.length,
        child: SafeArea(
          child: SizedBox(
            height: 420,
            child: Column(
              children: [
                Text(
                  strings.stickerPickerTitle,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                TabBar(
                  isScrollable: true,
                  tabs: [
                    for (final pack in kStickerPacks)
                      Tab(text: pack.title(strings.isRu)),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      for (final pack in kStickerPacks)
                        GridView.count(
                          crossAxisCount: 4,
                          padding: const EdgeInsets.all(12),
                          children: [
                            for (final sticker in pack.stickers)
                              InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  Navigator.pop(context);
                                  onPick(sticker);
                                },
                                child: Center(
                                  child: Text(
                                    sticker.glyph,
                                    style: const TextStyle(fontSize: 42),
                                  ),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Future<void> showGifPicker(
  BuildContext context, {
  required void Function(GifHit gif) onPick,
  required Future<void> Function() onUploadOwn,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _GifPickerSheet(
      onPick: onPick,
      onUploadOwn: onUploadOwn,
    ),
  );
}

class _GifPickerSheet extends StatefulWidget {
  const _GifPickerSheet({
    required this.onPick,
    required this.onUploadOwn,
  });

  final void Function(GifHit gif) onPick;
  final Future<void> Function() onUploadOwn;

  @override
  State<_GifPickerSheet> createState() => _GifPickerSheetState();
}

class _GifPickerSheetState extends State<_GifPickerSheet> {
  final _query = TextEditingController(text: 'cat');
  List<GifHit> _hits = const [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uri = Uri.parse(GifConfig.searchUrl).replace(queryParameters: {
        'q': _query.text.trim().isEmpty ? 'cat' : _query.text.trim(),
        'key': GifConfig.tenorKey,
        'limit': '24',
        'media_filter': 'minimal',
      });
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw StateError('Tenor ${response.statusCode}');
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final results = (json['results'] as List?) ?? const [];
      final hits = <GifHit>[];
      for (final raw in results) {
        final map = Map<String, dynamic>.from(raw as Map);
        final media = map['media'] as List?;
        if (media == null || media.isEmpty) continue;
        final first = Map<String, dynamic>.from(media.first as Map);
        final gif = first['gif'] as Map<String, dynamic>?;
        final tiny = first['tinygif'] as Map<String, dynamic>?;
        final url = gif?['url'] as String?;
        final preview = tiny?['url'] as String? ?? url;
        if (url == null) continue;
        hits.add(GifHit(
          previewUrl: preview ?? url,
          url: url,
          name: (map['content_description'] as String?) ?? 'gif',
        ));
      }
      if (!mounted) return;
      setState(() {
        _hits = hits;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return SafeArea(
      child: SizedBox(
        height: 480,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            children: [
              Text(
                strings.gifPickerTitle,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                strings.gifPickerHint,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _query,
                      decoration: InputDecoration(
                        hintText: strings.gifSearchHint,
                        prefixIcon: const Icon(Icons.search),
                      ),
                      onSubmitted: (_) => _search(),
                    ),
                  ),
                  IconButton(
                    onPressed: _search,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await widget.onUploadOwn();
                  },
                  icon: const Icon(Icons.upload_file_outlined),
                  label: Text(strings.gifUploadOwn),
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(child: Text(strings.gifLoadFailed))
                        : GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 6,
                              crossAxisSpacing: 6,
                            ),
                            itemCount: _hits.length,
                            itemBuilder: (context, index) {
                              final hit = _hits[index];
                              return InkWell(
                                onTap: () {
                                  Navigator.pop(context);
                                  widget.onPick(hit);
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(
                                    hit.previewUrl,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
