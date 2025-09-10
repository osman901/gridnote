// lib/services/photo_store.dart
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// PhotoStore con cámara IN-APP (plugin `camera`) para evitar
/// que Android mate la actividad al salir a la cámara externa.
/// Si algo falla, hace fallback a `image_picker`.
class PhotoStore {
  PhotoStore._();

  static final ImagePicker _picker = ImagePicker();
  static bool _busy = false;

  static Future<Directory> _rowDir(String sheetId, Object rowId) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'photos', sheetId, rowId.toString()));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Abre la cámara interna y guarda la foto en:
  /// /photos/<sheetId>/<rowId>/IMG_<epoch>.jpg
  ///
  /// IMPORTANTE: ahora recibe `BuildContext` para poder abrir la UI in-app.
  static Future<File?> addFromCamera(
      BuildContext ctx,
      String sheetId,
      Object rowId,
      ) async {
    if (_busy) return null;
    _busy = true;

    XFile? x;

    try {
      // 1) Intento in-app camera (no salimos de la app)
      x = await Navigator.of(ctx).push<XFile>(
        MaterialPageRoute(builder: (_) => const _InAppCameraPage()),
      );

      // 2) Si usuario canceló o falló, intento con image_picker como backup.
      if (x == null) {
        try {
          x = await _picker.pickImage(
            source: ImageSource.camera,
            preferredCameraDevice: CameraDevice.rear,
            requestFullMetadata: false,
            maxWidth: 1280,
            maxHeight: 1280,
            imageQuality: 72,
          );

          // En Android, si el proceso fue matado, recuperar última foto
          if (x == null) {
            final lost = await _picker.retrieveLostData();
            if (!lost.isEmpty && lost.file != null) {
              x = lost.file;
            }
          }
        } catch (_) {}
      }

      if (x == null) return null;

      final dir = await _rowDir(sheetId, rowId);
      final ts = DateTime.now().toUtc().millisecondsSinceEpoch;
      final target = File(p.join(dir.path, 'IMG_$ts.jpg'));

      try {
        await x.saveTo(target.path); // evita decodificar en memoria
      } catch (_) {
        await File(x.path).copy(target.path); // fallback
      }
      return await target.exists() ? target : null;
    } catch (_) {
      return null;
    } finally {
      _busy = false;
    }
  }

  static Future<List<File>> list(String sheetId, Object rowId) async {
    final dir = await _rowDir(sheetId, rowId);
    if (!await dir.exists()) return <File>[];
    final files = await dir
        .list()
        .where((e) => e is File && e.path.toLowerCase().endsWith('.jpg'))
        .cast<File>()
        .toList();
    files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    return files;
  }

  static Future<void> delete(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// 🔎 **Galería global reciente** (para Home): busca en /photos/** todas las imágenes
  /// de la app y devuelve las más recientes (orden desc). Soporta JPG/JPEG/PNG/WEBP/HEIC/HEIF.
  static Future<List<File>> listRecentGlobal({int limit = 120}) async {
    final roots = <Directory>[];

    try {
      final docs = await getApplicationDocumentsDirectory();
      roots.add(Directory(p.join(docs.path, 'photos')));
    } catch (_) {}

    // Android: además, directorio externo específico de la app (si existe)
    try {
      final ext = await getExternalStorageDirectory();
      if (ext != null) roots.add(Directory(p.join(ext.path, 'photos')));
    } catch (_) {}

    final exts = {'.jpg', '.jpeg', '.png', '.webp', '.heic', '.heif'};
    final files = <File>[];

    for (final root in roots) {
      if (!await root.exists()) continue;
      await for (final e in root.list(recursive: true, followLinks: false)) {
        if (e is! File) continue;
        final lower = e.path.toLowerCase();
        if (exts.any((x) => lower.endsWith(x))) {
          files.add(e);
        }
      }
    }

    if (files.isEmpty) return <File>[];

    files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    return files.length > limit ? files.sublist(0, limit) : files;
  }
}

/// Página de cámara interna: mantiene el control dentro de Flutter.
/// Maneja ciclo de vida para evitar pantalla negra al volver.
class _InAppCameraPage extends StatefulWidget {
  const _InAppCameraPage();

  @override
  State<_InAppCameraPage> createState() => _InAppCameraPageState();
}

class _InAppCameraPageState extends State<_InAppCameraPage>
    with WidgetsBindingObserver {
  CameraController? _controller;
  Future<void>? _initFuture;
  List<CameraDescription> _cameras = const [];
  bool _taking = false;
  FlashMode _flash = FlashMode.off;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initFuture = _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      final back = _cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );
      final ctrl = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      _controller = ctrl;
      await ctrl.initialize();
      _flash = FlashMode.off;
      await ctrl.setFlashMode(_flash);
      if (mounted) setState(() {});
    } catch (_) {
      // si falla, cerramos devolviendo null
      if (mounted) Navigator.of(context).pop<XFile?>(null);
    }
  }

  Future<void> _disposeCamera() async {
    try {
      await _controller?.dispose();
    } catch (_) {}
    _controller = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeCamera();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      // liberar cuando perdemos foco (ej. bloqueo de pantalla)
      _disposeCamera();
    } else if (state == AppLifecycleState.resumed) {
      // re-crear al volver
      _initFuture = _initCamera();
      setState(() {});
    }
  }

  Future<void> _toggleFlash() async {
    final ctrl = _controller;
    if (ctrl == null) return;
    try {
      final next = switch (_flash) {
        FlashMode.off => FlashMode.auto,
        FlashMode.auto => FlashMode.always,
        FlashMode.always => FlashMode.off,
        _ => FlashMode.off,
      };
      await ctrl.setFlashMode(next);
      setState(() => _flash = next);
    } catch (_) {}
  }

  Future<void> _take() async {
    if (_taking) return;
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;

    setState(() => _taking = true);
    try {
      final x = await ctrl.takePicture();
      if (!mounted) return;
      Navigator.of(context).pop<XFile>(x);
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop<XFile?>(null);
    } finally {
      if (mounted) setState(() => _taking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<void>(
        future: _initFuture,
        builder: (ctx, snap) {
          final ctrl = _controller;
          final ready = snap.connectionState == ConnectionState.done &&
              ctrl != null &&
              ctrl.value.isInitialized;

          return Stack(
            children: [
              Positioned.fill(
                child: ready ? CameraPreview(ctrl) : const SizedBox(),
              ),
              // Top bar
              SafeArea(
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop<XFile?>(null),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _toggleFlash,
                      icon: Icon(
                        switch (_flash) {
                          FlashMode.off => Icons.flash_off,
                          FlashMode.auto => Icons.flash_auto,
                          FlashMode.always => Icons.flash_on,
                          _ => Icons.flash_off
                        },
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                ),
              ),
              // Shutter
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  minimum: const EdgeInsets.only(bottom: 24),
                  child: FloatingActionButton.large(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    onPressed: ready && !_taking ? _take : null,
                    child: _taking
                        ? const SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    )
                        : const Icon(Icons.camera_alt),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
