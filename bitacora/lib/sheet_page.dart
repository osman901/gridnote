import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'models.dart';
import 'data/local_db.dart';
import 'repositories/sheets_repository.dart';
import 'glass.dart';

class SheetPage extends StatefulWidget {
  final Sheet sheet;
  const SheetPage({super.key, required this.sheet});

  @override
  State<SheetPage> createState() => _SheetPageState();
}

class _SheetPageState extends State<SheetPage> {
  final sheetsRepo = SheetsRepository(LocalDB());
  final _picker = ImagePicker();
  List<Entry> _entries = [];
  bool _loading = true;

  // Eliminar una entrada (con manejo de errores)
  Future<void> _deleteEntry(int id) async {
    try {
      await sheetsRepo.db.deleteEntry(id);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar entrada: $error')));
      return;
    }
    if (!mounted) return;
    setState(() => _entries.removeWhere((x) => x.id == id));
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await sheetsRepo.rows(widget.sheet.id!);
    if (!mounted) return;
    setState(() {
      _entries = list;
      _loading = false;
    });
  }

  Future<void> _addRow() async {
    final e = await sheetsRepo.addRow(widget.sheet.id!);
    if (!mounted) return;
    setState(() => _entries.insert(0, e));
    _savedSnack();
  }

  void _savedSnack() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Guardado en el dispositivo ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã¢â‚¬Å“ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦'), duration: Duration(milliseconds: 900)),
    );
  }

  Future<void> _pickPhoto(Entry e) async {
    // Tomar foto con resoluciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n adaptada a la capacidad del dispositivo
    // (Menor resoluciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n en dispositivos de gama media para mejorar rendimiento)
    final x = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      requestFullMetadata: false,
      maxWidth: Platform.numberOfProcessors >= 8 ? 1920 : 1280,
      maxHeight: Platform.numberOfProcessors >= 8 ? 1920 : 1280,
      imageQuality: Platform.numberOfProcessors >= 8 ? 90 : 72,
    );
    if (x == null) return;
    final file = File(x.path);
    late String path;
    try {
      path = await sheetsRepo.persistImage(file, sheetId: e.sheetId, entryId: e.id!);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar foto: $error')));
      return;
    }
    final updated = e.copyWith(photoPath: path);
    await sheetsRepo.saveRow(updated);
    final idx = _entries.indexWhere((r) => r.id == e.id);
    if (!mounted) return;
    setState(() => _entries[idx] = updated);
    _savedSnack();
  }

  Future<void> _pickLocation(Entry e) async {
    // Obtener ubicaciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n GPS con precisiÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n adaptada segÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âºn dispositivo
    // (Menor precisiÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n en dispositivos de gama media para ahorrar recursos)
    late Position pos;
    try {
      pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: Platform.numberOfProcessors >= 8 ? LocationAccuracy.best : LocationAccuracy.high);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo obtener ubicaciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n: $error')));
      return;
    }
    final updated = e.copyWith(lat: pos.latitude, lon: pos.longitude);
    await sheetsRepo.saveRow(updated);
    final idx = _entries.indexWhere((r) => r.id == e.id);
    if (!mounted) return;
    setState(() => _entries[idx] = updated);
    _savedSnack();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.sheet.name),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
        physics: const BouncingScrollPhysics(),  // rebote tipo red social
        itemCount: _entries.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, index) {
          final entry = _entries[index];
          return ListTile(
            title: Text(entry.note ?? '(Sin nota)'),
            subtitle: Text(
              '${entry.lat != null ? 'ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œÃƒâ€šÃ‚Â ${entry.lat}, ${entry.lon} ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œ ' : ''}'
                  '${DateFormat('dd/MM/yy HH:mm').format(entry.updatedAt)}',
            ),
            leading: const Icon(CupertinoIcons.camera),
            trailing: const Icon(CupertinoIcons.exclamationmark_triangle, color: Colors.orange),
            onTap: () {}, // abrir detalle/ediciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n (si aplica)
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addRow,
        child: const Icon(CupertinoIcons.plus),
      ),
    );
  }
}

