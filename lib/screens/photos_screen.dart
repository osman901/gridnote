// lib/screens/photos_screen.dart
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/photo_attachment.dart';
import '../models/sheet_meta.dart';
import '../services/photo_service.dart';
import '../theme/gridnote_theme.dart';

class PhotosScreen extends ConsumerStatefulWidget {
  const PhotosScreen({super.key, required this.themeController, required this.meta});
  final GridnoteThemeController themeController;
  final SheetMeta meta;

  @override
  ConsumerState<PhotosScreen> createState() => _PhotosScreenState();
}

class _PhotosScreenState extends ConsumerState<PhotosScreen> {
  List<PhotoAttachment> _items = [];
  bool _loading = true;

  Future<void> _refresh() async {
    final list = await PhotoService.instance.list(widget.meta.id);
    if (!mounted) return;
    setState(() {
      _items = list;
      _loading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  // Deriva el rowId a partir del path si el modelo no lo tiene
  String _rowLabelFromPath(PhotoAttachment a) {
    final segs = p.split(a.path);
    final i = segs.indexOf(widget.meta.id);
    if (i != -1 && i + 1 < segs.length) {
      final id = segs[i + 1];
      return id == '_sheet' ? '' : id;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.themeController.theme;
    final messenger = ScaffoldMessenger.of(context);

    return Scaffold(
      backgroundColor: t.scaffold,
      appBar: AppBar(title: Text('Fotos • ${widget.meta.name}')),
      floatingActionButton: _fab(t),
      body: Stack(
        children: [
          // Fondo glass
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(color: Colors.black.withValues(alpha: 0.25)),
            ),
          ),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_items.isEmpty)
            const Center(child: Text('Sin fotos aún'))
          else
            Padding(
              padding: const EdgeInsets.all(12),
              child: GridView.builder(
                physics: const BouncingScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: _items.length,
                itemBuilder: (_, i) {
                  final a = _items[i];
                  final file = File(a.path);
                  return GestureDetector(
                    onTap: () async {
                      if (await file.exists()) {
                        await OpenFilex.open(a.path);
                      } else {
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Archivo no encontrado')),
                        );
                      }
                    },
                    onLongPress: () => _showPhotoMenu(a),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(
                            file,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const ColoredBox(
                              color: Color(0x22000000),
                              child: Center(child: Icon(Icons.broken_image_outlined)),
                            ),
                          ),
                          // degradé para info
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              height: 26,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Color(0x00000000), Color(0x55000000)],
                                ),
                              ),
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                // usa a.rowId si existe; si no, lo deriva del path
                                // ignore: unnecessary_null_comparison
                                (a is dynamic && (a as dynamic).rowId != null)
                                    ? ((a as dynamic).rowId as String? ?? '')
                                    : _rowLabelFromPath(a),
                                style: const TextStyle(color: Colors.white, fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _fab(GridnoteTheme t) => PopupMenuButton<String>(
    itemBuilder: (_) => const [
      PopupMenuItem(
        value: 'cam',
        child: ListTile(leading: Icon(Icons.photo_camera), title: Text('Cámara')),
      ),
      PopupMenuItem(
        value: 'gal',
        child: ListTile(leading: Icon(Icons.photo_library), title: Text('Galería')),
      ),
    ],
    onSelected: (v) async {
      if (v == 'cam') await PhotoService.instance.addFromCamera(widget.meta.id);
      if (v == 'gal') await PhotoService.instance.addFromGallery(widget.meta.id);
      await _refresh();
    },
    child: FloatingActionButton(
      backgroundColor: t.accent,
      onPressed: () {},
      child: const Icon(Icons.add_a_photo, color: Colors.black),
    ),
  );

  Future<void> _showPhotoMenu(PhotoAttachment a) async {
    await showModalBottomSheet(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('Abrir'),
              onTap: () async {
                Navigator.pop(ctx);
                await OpenFilex.open(a.path);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Compartir'),
              onTap: () {
                Navigator.pop(ctx);
                Share.shareXFiles([XFile(a.path)]);
              },
            ),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('Guardar en Descargas'),
              onTap: () async {
                Navigator.pop(ctx);
                final ok = await _saveToDownloads(File(a.path));
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ok ? 'Guardado en Descargas' : 'No se pudo guardar')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Eliminar'),
              onTap: () async {
                Navigator.pop(ctx);
                await PhotoService.instance.delete(a);
                await _refresh();
              },
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  Future<bool> _saveToDownloads(File src) async {
    try {
      final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      final name = p.basename(src.path);
      final dst = File(p.join(dir.path, name));
      await dst.writeAsBytes(await src.readAsBytes(), flush: true);
      return true;
    } catch (_) {
      return false;
    }
  }
}
