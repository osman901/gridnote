import 'package:flutter/material.dart';
import '../services/attachment_service.dart';
import '../screens/attachments_gallery_screen.dart';

class RowActionsSheet extends StatelessWidget {
  final dynamic measurementKey;
  const RowActionsSheet({super.key, required this.measurementKey});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('Adjuntar foto (cámara)'),
            onTap: () async {
              await AttachmentService.takePhotoToKey(measurementKey);
              if (context.mounted) Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Ver adjuntos'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => AttachmentsGalleryScreen(measurementKey: measurementKey),
              ));
            },
          ),
        ],
      ),
    );
  }
}