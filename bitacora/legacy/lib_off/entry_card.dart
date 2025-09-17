// lib/widgets/entry_card.dart
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/local_db.dart';
import '../repositories/sheets_repo.dart';

class EntryCard extends StatelessWidget {
  const EntryCard({
    super.key,
    required this.entry,
    required this.repo,
    this.onChanged,
  });

  final Entry entry;
  final SheetsRepo repo;
  final VoidCallback? onChanged;

  Future<void> editEntryTap(BuildContext context) async {
    final titleController = TextEditingController(text: entry.title ?? '');
    final noteController = TextEditingController(text: entry.note ?? '');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Título',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Nota',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  // Repo con named params opcionales; si tu LocalDb aún no los soporta,
                  // esta llamada compilará (los ignora internamente) y podrás
                  // añadir el soporte luego.
                  await repo.updateEntry(
                    entry.id,
                    title: titleController.text.trim().isEmpty
                        ? null
                        : titleController.text.trim(),
                    note: noteController.text.trim().isEmpty
                        ? null
                        : noteController.text.trim(),
                  );
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  onChanged?.call();
                },
                child: const Text('Guardar'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> deleteEntryTap(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar entrada'),
        content: const Text('¿Estás seguro de eliminar esta entrada?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await repo.deleteEntry(entry.id);
      onChanged?.call();
    }
  }

  Future<void> addPhotoTap() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery);
    if (img == null) return;

    // Hash + persistencia simple
    final bytes = await img.readAsBytes();
    final hash = sha256.convert(bytes).toString();
    final appDir = await getApplicationDocumentsDirectory();
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${p.basename(img.path)}';
    final savedPath = p.join(appDir.path, fileName);
    final savedFile = await File(img.path).copy(savedPath);

    // Usamos la misma imagen como "thumb" para simplificar
    await repo.addAttachment(
      entryId: entry.id,
      path: savedFile.path,
      thumbPath: savedFile.path,
      sizeBytes: bytes.length,
      hash: hash,
    );
    onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Attachment>>(
      future: repo.listAttachments(entry.id),
      builder: (context, snap) {
        final attachments = snap.data ?? const <Attachment>[];

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      entry.title ?? '(sin título)',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Agregar foto',
                    icon: const Icon(Icons.photo_camera_outlined),
                    onPressed: addPhotoTap,
                  ),
                  IconButton(
                    tooltip: 'Editar',
                    icon: const Icon(Icons.edit),
                    onPressed: () => editEntryTap(context),
                  ),
                  IconButton(
                    tooltip: 'Eliminar',
                    icon: const Icon(Icons.delete),
                    onPressed: () => deleteEntryTap(context),
                  ),
                ]),
                const SizedBox(height: 4),
                if (entry.note != null && entry.note!.isNotEmpty)
                  Text(entry.note!, style: const TextStyle(color: Colors.grey)),
                if (entry.lat != null && entry.lng != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(children: [
                      const Icon(Icons.location_on_outlined,
                          size: 14, color: Colors.blueGrey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${entry.lat!.toStringAsFixed(5)}, ${entry.lng!.toStringAsFixed(5)}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.blueGrey),
                        ),
                      ),
                    ]),
                  ),
                if (snap.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(),
                  )
                else if (attachments.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: attachments.map((att) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(att.thumbPath),
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                          ),
                        );
                      }).toList(),
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
