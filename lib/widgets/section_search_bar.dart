import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';

class SectionSearchBar extends StatefulWidget {
  const SectionSearchBar({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  State<SectionSearchBar> createState() => _SectionSearchBarState();
}

class _SectionSearchBarState extends State<SectionSearchBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: widget.controller,
        onChanged: widget.onChanged,
        decoration: InputDecoration(
          hintText: widget.hint,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: widget.controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    widget.controller.clear();
                    widget.onChanged('');
                  },
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
      ),
    );
  }
}

String searchHintForSection(AppStrings strings, int sectionIndex) {
  return switch (sectionIndex) {
    0 => strings.searchChats,
    1 => strings.searchGroups,
    2 => strings.searchChannels,
    _ => strings.search,
  };
}

String createLabelForSection(AppStrings strings, int sectionIndex) {
  return switch (sectionIndex) {
    0 => strings.createChat,
    1 => strings.createGroup,
    2 => strings.createChannel,
    _ => '',
  };
}

String createDialogTitleForSection(AppStrings strings, int sectionIndex) {
  return switch (sectionIndex) {
    0 => strings.newChatTitle,
    1 => strings.newGroupTitle,
    2 => strings.newChannelTitle,
    _ => '',
  };
}

String createDialogHintForSection(AppStrings strings, int sectionIndex) {
  return switch (sectionIndex) {
    0 => strings.newChatHint,
    1 => strings.newGroupHint,
    2 => strings.newChannelHint,
    _ => '',
  };
}
