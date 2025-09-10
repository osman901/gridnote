// lib/widgets/row_actions_sheet.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../services/attachments_service.dart' as attach show AttachmentsService;
import '../screens/attachments_gallery_screen.dart' show AttachmentsGalleryScreen;

class RowActionsSheet extends StatelessWidget {
  final dynamic measurementKey;
  const RowActionsSheet({super.key, required this.measurementKey});

  // Fallback: carpeta local para adjuntos de esta "key" si el service no expone dirForKey.
  Future<Directory> _dirForKey(dynamic key) async {
    final base = await getApplicationDocumentsDirectory();
    final safe = (key?.toString() ?? 'default')
        .replaceAll(RegExp(r'[^\w\-]'), '_')
        .toLowerCase();
    return Directory(p.join(base.path, 'attachments', safe));
  }

  Future<void> _attachPhoto(BuildContext context) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final svc = attach.AttachmentsService.instance;

    try {
      // 1) Capturar foto
      final srcPath = await svc.pickFromCamera();
      if (srcPath == null || srcPath.isEmpty) {
        messenger.showSnackBar(const SnackBar(content: Text('Foto cancelada')));
        return;
      }

      // 2) Directorio de la mediciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n: usar svc.dirForKey si existe, sino fallback
      final dir = await (((svc as dynamic).dirForKey?.call(measurementKey)
      as Future<Directory>?) ??
          _dirForKey(measurementKey));
      await dir.create(recursive: true);

      // 3) Copiar al destino
      final ext = p.extension(srcPath);
      final destPath = p.join(
        dir.path,
        'photo_${DateTime.now().millisecondsSinceEpoch}'
            '${ext.isEmpty ? '.jpg' : ext}',
      );
      await File(srcPath).copy(destPath);

      messenger.showSnackBar(const SnackBar(content: Text('Foto adjuntada')));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error al adjuntar foto: $e')),
      );
    } finally {
      if (navigator.mounted) navigator.pop(); // cerrar el sheet
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('Adjuntar foto (cÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡mara)'),
            onTap: () => _attachPhoto(context),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Ver adjuntos'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AttachmentsGalleryScreen(
                    measurementKey: measurementKey,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
