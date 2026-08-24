import 'package:flutter/material.dart';

import '../data/sticker_packs.dart';
import '../l10n/app_strings.dart';
import '../services/gif_service.dart';

Future<void> showEmojiPicker(
  BuildContext context, {
  required ValueChanged<String> onPick,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: Column(
                children: [
                  Text(
                    context.strings.emojiPickerTitle,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: GridView.count(
                      controller: scrollController,
                      crossAxisCount: 8,
                      children: [
                        for (final emoji in kEmojiPalette)
                          InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              onPick(emoji);
                            },
                            child: Center(
                              child: Text(emoji, style: const TextStyle(fontSize: 28)),
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
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        builder: (context, scrollController) {
          return DefaultTabController(
            length: kStickerPacks.length,
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 6),
                    child: Text(
                      strings.stickerPickerTitle,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  TabBar(
                    isScrollable: true,
                    tabs: [
                      for (final pack in kStickerPacks)
                        Tab(text: pack.title(strings.isRu)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: TabBarView(
                      children: [
                        for (final pack in kStickerPacks)
                          GridView.count(
                            controller: scrollController,
                            crossAxisCount: 4,
                            padding: const EdgeInsets.all(14),
                            mainAxisSpacing: 6,
                            crossAxisSpacing: 6,
                            childAspectRatio: 1.05,
                            children: [
                              for (final sticker in pack.stickers)
                                InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: () {
                                    Navigator.pop(context);
                                    onPick(sticker);
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest
                                          .withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: Center(
                                      child: Text(
                                        sticker.glyph,
                                        style: const TextStyle(fontSize: 48),
                                      ),
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
          );
        },
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
      final hits = await searchGifs(_query.text);
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
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return SafeArea(
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
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _query,
                        decoration: InputDecoration(
                          hintText: strings.gifSearchHint,
                          prefixIcon: const Icon(Icons.search),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onSubmitted: (_) => _search(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonal(
                      onPressed: _search,
                      child: const Icon(Icons.search, size: 20),
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
                          : _hits.isEmpty
                              ? Center(child: Text(strings.gifLoadFailed))
                              : GridView.builder(
                                  controller: scrollController,
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 8,
                                    crossAxisSpacing: 8,
                                    childAspectRatio: 1.15,
                                  ),
                                  itemCount: _hits.length,
                                  itemBuilder: (context, index) {
                                    final hit = _hits[index];
                                    return InkWell(
                                      onTap: () {
                                        Navigator.pop(context);
                                        widget.onPick(hit);
                                      },
                                      borderRadius: BorderRadius.circular(12),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          hit.previewUrl,
                                          fit: BoxFit.cover,
                                          gaplessPlayback: true,
                                          errorBuilder: (_, __, ___) => ColoredBox(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .surfaceContainerHighest,
                                            child: Center(
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  const Icon(Icons.gif_box_outlined, size: 28),
                                                  const SizedBox(height: 4),
                                                  Text(hit.name,
                                                      style: Theme.of(context).textTheme.labelSmall,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
