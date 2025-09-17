// lib/widgets/title_field.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/suggestions_provider.dart';

class TitleField extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final int sheetId;
  final String label;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;

  const TitleField({
    super.key,
    required this.controller,
    required this.sheetId,
    this.label = 'TÃƒÆ’Ã‚Â­tulo (opcional)',
    this.onSubmitted,
    this.onClear,
  });

  @override
  ConsumerState<TitleField> createState() => _TitleFieldState();
}

class _TitleFieldState extends ConsumerState<TitleField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suggAsync = ref.watch(titleSuggestionsProvider(widget.sheetId));
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            labelText: widget.label,
            suffixIcon: widget.controller.text.isNotEmpty
                ? IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                widget.controller.clear();
                _focusNode.requestFocus();
                setState(() {});
                widget.onClear?.call();
              },
            )
                : null,
          ),
          onChanged: (_) => setState(() {}),
          textInputAction: TextInputAction.done,
          onSubmitted: widget.onSubmitted,
        ),
        const SizedBox(height: 8),
        suggAsync.when(
          data: (sugg) {
            if (sugg.isEmpty) return const SizedBox.shrink();
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: sugg.map((s) {
                return ActionChip(
                  label: Text(s, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onPressed: () {
                    widget.controller.text = s;
                    widget.controller.selection = TextSelection.fromPosition(
                      TextPosition(offset: widget.controller.text.length),
                    );
                    _focusNode.requestFocus();
                    setState(() {});
                    widget.onSubmitted?.call(s);
                  },
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                );
              }).toList(),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}
