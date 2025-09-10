// lib/screens/attachments_gallery_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../services/attachments_service.dart';

class AttachmentsGalleryScreen extends StatefulWidget {
  final dynamic measurementKey;
  const AttachmentsGalleryScreen({super.key, required this.measurementKey});

  @override
  State<AttachmentsGalleryScreen> createState() => _AttachmentsGalleryScreenState();
}

class _AttachmentsGalleryScreenState extends State<AttachmentsGalleryScreen> {
  List<File> _files = <File>[];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // Fallback local si el servicio no expone dirForKey
  Future<Directory> _fallbackDirForKey(dynamic key) async {
    final base = await getApplicationDocumentsDirectory();
    final safe = (key?.toString() ?? 'default')
        .replaceAll(RegExp(r'[^\w\-]'), '_')
        .toLowerCase();
    return Directory(p.join(base.path, 'attachments', safe));
  }

  Future<void> _load({bool silently = false}) async {
    if (!silently && mounted) setState(() => _loading = true);
    try {
      // Intentar usar AttachmentsService.dirForKey si existe, si no usar fallback
      final svc = AttachmentsService.instance;
      final Directory dir = await (((svc as dynamic).dirForKey?.call(widget.measurementKey)
      as Future<Directory>?) ??
          _fallbackDirForKey(widget.measurementKey));

      final List<File> files = <File>[];
      if (await dir.exists()) {
        await for (final e in dir.list()) {
          if (e is! File) continue;
          final path = e.path.toLowerCase();
          if (path.endsWith('.jpg') ||
              path.endsWith('.jpeg') ||
              path.endsWith('.png') ||
              path.endsWith('.webp')) {
            files.add(e);
          }
        }
      }
      if (!mounted) return;
      setState(() => _files = files);
    } catch (e, st) {
      debugPrint('Error al cargar adjuntos: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudieron cargar los adjuntos.')),
        );
      }
    } finally {
      if (mounted && !silently) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_files.isEmpty) {
      body = const Center(child: Text('Sin adjuntos'));
    } else {
      body = RefreshIndicator(
        onRefresh: () => _load(silently: true),
        child: GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: _files.length,
          itemBuilder: (_, i) {
            final f = _files[i];
            return GestureDetector(
              onTap: () async {
                final changed = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => _FullImageScreen(file: f)),
                );
                if (changed == true && mounted) _load(silently: true);
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Hero(
                  tag: f.path,
                  child: Image.file(
                    f,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.low,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey.shade300,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Adjuntos')),
      body: body,
    );
  }
}

class _FullImageScreen extends StatelessWidget {
  final File file;
  const _FullImageScreen({required this.file});

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar archivo'),
        content: const Text('¿Querés borrar este adjunto? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Borrar')),
        ],
      ),
    ) ??
        false;

    if (!confirmed) return;

    try {
      if (await file.exists()) await file.delete();
      if (context.mounted) Navigator.pop(context, true);
    } catch (e, st) {
      debugPrint('Error al borrar adjunto: $e\n$st');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo borrar el archivo.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: 'Borrar',
            onPressed: () => _delete(context),
            icon: const Icon(Icons.delete_outline, color: Colors.white),
          ),
        ],
      ),
      body: Center(
        child: Hero(
          tag: file.path,
          child: InteractiveViewer(
            child: Image.file(
              file,
              errorBuilder: (_, __, ___) =>
              const Icon(Icons.broken_image_outlined, color: Colors.white, size: 48),
            ),
          ),
        ),
      ),
    );
  }
}
