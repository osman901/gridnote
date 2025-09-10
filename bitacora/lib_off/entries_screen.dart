// lib/screens/entries_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../data/app_db.dart';
import '../data/sheets_dao.dart';
import '../services/attachment_service.dart';
import '../services/export_xlsx_service.dart';
import '../widgets/title_field.dart';

// Infra
final appDbProvider = Provider<AppDb>((ref) => AppDb());

final sheetsDaoProvider = Provider<SheetsDao>((ref) {
  final db = ref.watch(appDbProvider);
  return SheetsDao(db);
});

final attachmentServiceProvider = Provider<AttachmentService>((ref) {
  final dao = ref.watch(sheetsDaoProvider);
  return AttachmentService(dao);
});

final exportXlsxServiceProvider = Provider<ExportXlsxService>((ref) {
  final dao = ref.watch(sheetsDaoProvider);
  final db = ref.watch(appDbProvider);
  return ExportXlsxService(dao, db);
});

// Data
final entriesStreamProvider =
StreamProvider.family<List<EntryRow>, int>((ref, sheetId) {
  final dao = ref.watch(sheetsDaoProvider);
  return dao.watchEntriesForSheet(sheetId);
});

final attachmentCountProvider =
FutureProvider.family<int, int>((ref, entryId) async {
  final dao = ref.watch(sheetsDaoProvider);
  return dao.countAttachmentsForEntry(entryId);
});

class EntriesScreen extends ConsumerStatefulWidget {
  final int sheetId;
  final String sheetName;
  const EntriesScreen({super.key, required this.sheetId, required this.sheetName});

  @override
  ConsumerState<EntriesScreen> createState() => _EntriesScreenState();
}

class _EntriesScreenState extends ConsumerState<EntriesScreen> {
  final _picker = ImagePicker();
  final _noteControllers = <int, TextEditingController>{};
  final _titleControllers = <int, TextEditingController>{};

  @override
  void dispose() {
    for (final c in _noteControllers.values) {
      c.dispose();
    }
    for (final c in _titleControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _titleCtlFor(EntryRow e) =>
      _titleControllers.putIfAbsent(e.id, () => TextEditingController(text: e.title ?? ''));

  TextEditingController _noteCtlFor(EntryRow e) =>
      _noteControllers.putIfAbsent(e.id, () => TextEditingController(text: e.note ?? ''));

  Future<void> _addEntry() async {
    final dao = ref.read(sheetsDaoProvider);
    await dao.createEntry(widget.sheetId);
  }

  Future<void> _deleteEntry(EntryRow e) async {
    final dao = ref.read(sheetsDaoProvider);
    await dao.deleteEntry(e.id);
  }

  Future<void> _saveTitle(EntryRow e) async {
    final dao = ref.read(sheetsDaoProvider);
    final text = _titleCtlFor(e).text.trim();
    await dao.updateEntryTitle(e.id, text.isEmpty ? null : text);
  }

  Future<void> _saveNote(EntryRow e) async {
    final dao = ref.read(sheetsDaoProvider);
    final text = _noteCtlFor(e).text.trim();
    await dao.updateEntryNote(e.id, text.isEmpty ? null : text);
  }

  Future<void> _attachPhoto(EntryRow e) async {
    final s = ref.read(attachmentServiceProvider);
    final x = await _picker.pickImage(source: ImageSource.gallery);
    if (x == null) return;
    try {
      await s.addPhotoToEntry(entryId: e.id, original: File(x.path));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto adjuntada')));
      }
    } on DuplicateAttachmentException {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Esa foto ya estaba adjunta')));
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $err')));
    }
  }

  Future<void> _setLocation(EntryRow e) async {
    final dao = ref.read(sheetsDaoProvider);

    // Permisos
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Permiso de ubicación denegado')));
      return;
    }

    // ✅ Sin 'desiredAccuracy' (deprecado): usamos LocationSettings
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    await dao.updateEntryLocation(
      e.id,
      lat: pos.latitude,
      lng: pos.longitude,
      accuracy: pos.accuracy,
      provider: 'gps',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ubicación guardada')));
  }

  Future<void> _exportXlsx() async {
    final svc = ref.read(exportXlsxServiceProvider);
    try {
      await svc.exportAndOpen(widget.sheetId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(entriesStreamProvider(widget.sheetId));

    return Scaffold(
      appBar: AppBar(
        title: Text('Planilla: ${widget.sheetName}'),
        actions: [
          IconButton(
            tooltip: 'Exportar a Excel (offline)',
            onPressed: _exportXlsx,
            icon: const Icon(Icons.table_view),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addEntry,
        icon: const Icon(Icons.add),
        label: const Text('Nueva fila'),
      ),
      body: entriesAsync.when(
        data: (entries) {
          if (entries.isEmpty) {
            return const Center(child: Text('Sin filas aún. Crea la primera.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemBuilder: (ctx, i) {
              final e = entries[i];
              final titleCtl = _titleCtlFor(e);
              final noteCtl = _noteCtlFor(e);
              final countAsync = ref.watch(attachmentCountProvider(e.id));

              return Dismissible(
                key: ValueKey('entry_${e.id}'),
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                secondaryBackground: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (_) async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Eliminar fila'),
                      content: const Text('¿Seguro que quieres eliminar esta fila?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
                      ],
                    ),
                  );
                  return ok ?? false;
                },
                onDismissed: (_) => _deleteEntry(e),
                child: Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TitleField(
                          controller: titleCtl,
                          label: 'Título (opcional)',
                          sheetId: widget.sheetId,
                          onSubmitted: (_) => _saveTitle(e),
                          onClear: () {
                            titleCtl.clear();
                            _saveTitle(e);
                          },
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: noteCtl,
                          minLines: 1,
                          maxLines: 5,
                          decoration: InputDecoration(
                            labelText: 'Nota (opcional)',
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.check),
                              tooltip: 'Guardar nota',
                              onPressed: () => _saveNote(e),
                            ),
                          ),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _saveNote(e),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (e.lat != null && e.lng != null)
                              Chip(
                                avatar: const Icon(Icons.place, size: 18),
                                label: Text(
                                  '(${e.lat!.toStringAsFixed(5)}, ${e.lng!.toStringAsFixed(5)}) • ${e.provider ?? 'gps'}',
                                ),
                              )
                            else
                              const Text('Sin ubicación', style: TextStyle(color: Colors.grey)),
                            FilledButton.icon(
                              onPressed: () => _setLocation(e),
                              icon: const Icon(Icons.my_location),
                              label: const Text('Guardar ubicación'),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        Row(
                          children: [
                            FilledButton.icon(
                              onPressed: () => _attachPhoto(e),
                              icon: const Icon(Icons.photo),
                              label: const Text('Adjuntar foto'),
                            ),
                            const SizedBox(width: 12),
                            countAsync.when(
                              data: (c) => Text('Adjuntos: $c'),
                              loading: () => const Text('Adjuntos: …'),
                              error: (_, __) => const Text('Adjuntos: error'),
                            ),
                            const Spacer(),
                            Text(
                              'ID ${e.id} • ${e.createdAt}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemCount: entries.length,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error cargando filas: $e')),
      ),
    );
  }
}
