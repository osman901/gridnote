// lib/widgets/note_card.dart
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/note_model.dart';

class NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback? onTap; // acción al tocar

  const NoteCard({
    super.key,
    required this.note,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: theme.dividerColor),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: (note.imagePath != null && note.imagePath!.isNotEmpty)
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(note.imagePath!),
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.image_not_supported_outlined,
                    size: 36,
                    color: theme.colorScheme.secondary,
                  ),
                ),
              )
            : Icon(
                Icons.note_alt_outlined,
                size: 36,
                color: theme.colorScheme.secondary,
              ),
        title: Text(
          note.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          note.content,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ),
    );
  }
}
