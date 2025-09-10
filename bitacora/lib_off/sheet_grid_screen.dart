import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../repositories/sheets_repo.dart';
import '../data/local_db.dart';
import '../export/excel_exporter.dart';

class SheetGridScreen extends StatefulWidget {
  const SheetGridScreen({super.key, required this.repo, required this.sheetId});
  final SheetsRepo repo;
  final int sheetId;

  @override
  State<SheetGridScreen> createState() => _SheetGridScreenState();
}

class _SheetGridScreenState extends State<SheetGridScreen> {
  late Future<List<Entry>> _future;
  String _sheetName = 'Planilla';

  final _hHeader = ScrollController();
  final _hBody = ScrollController();
  final _v = ScrollController();

  @override
  void initState() {
    super.initState();
    _syncScrolls();
    _load();
  }

  void _syncScrolls() {
    _hHeader.addListener(() {
      if (_hBody.hasClients && _hBody.offset != _hHeader.offset) {
        _hBody.jumpTo(_hHeader.offset);
      }
    });
    _hBody.addListener(() {
      if (_hHeader.hasClients && _hHeader.offset != _hBody.offset) {
        _hHeader.jumpTo(_hBody.offset);
      }
    });
  }

  void _load() {
    _future = widget.repo.listEntries(widget.sheetId);
    widget.repo.getSheet(widget.sheetId).then((s) {
      if (!mounted) return;
      if (s != null) setState(() => _sheetName = s.name);
    });
    setState(() {});
  }

  Future<void> _addRow() async {
    await widget.repo.newEntry(widget.sheetId);
    _load();
  }

  String _fmtTs(dynamic ts) {
    final d = ts is int
        ? DateTime.fromMillisecondsSinceEpoch(ts)
        : (ts is DateTime ? ts : DateTime.now());
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _exportExcel() async {
    final s = await widget.repo.getSheet(widget.sheetId);
    if (s == null) return;
    final file = await ExcelExporter(widget.repo).exportSheet(s);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exportado: ${file.path}')));
  }

  Future<void> _editNote(BuildContext context, Entry e, String initial) async {
    final ctrl = TextEditingController(text: initial);
    final v = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nota'),
        content: TextField(
          controller: ctrl,
          maxLines: 6,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Guardar')),
        ],
      ),
    );
    if (v == null) return;
    await widget.repo.updateEntry(e.id, note: v.isEmpty ? null : v);
    if (!mounted) return;
    _load();
  }

  Future<void> _attachPhoto(int entryId) async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.camera);
    if (img == null) return;
    final f = File(img.path);
    await widget.repo.addAttachment(
      entryId: entryId,
      path: f.path,
      thumbPath: f.path, // MVP
      sizeBytes: await f.length(),
      hash: f.path.hashCode.toString(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto agregada')));
  }

  Widget _headerRow(Color outline) {
    Widget h(String t, {double w = 160, FontWeight fw = FontWeight.w600}) {
      return Container(
        width: w,
        height: 46,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: outline), bottom: BorderSide(color: outline)),
          color: Colors.black12.withAlpha(20),
        ),
        child: Text(t, style: TextStyle(fontWeight: fw)),
      );
    }

    return SingleChildScrollView(
      controller: _hHeader,
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        h('ID', w: 90),
        h('Título'),
        h('Nota'),
        h('Lat'),
        h('Lng'),
        h('±m', w: 90),
        h('Fuente', w: 110),
        h('Adjuntos', w: 110),
        h('Actualizado', w: 160),
        h('', w: 70, fw: FontWeight.w400),
      ]),
    );
  }

  Widget _dataRow(Color outline, Entry e) {
    InputDecoration dec = const InputDecoration(
      isDense: true,
      hintText: '',
      border: InputBorder.none,
      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    );

    Widget cell({required Widget child, double w = 160}) {
      return Container(
        width: w,
        height: 44,
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: outline), bottom: BorderSide(color: outline)),
        ),
        child: child,
      );
    }

    return SingleChildScrollView(
      controller: _hBody,
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        cell(w: 90, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('${e.id}'))),
        // Título
        cell(
          child: TextFormField(
            initialValue: e.title ?? '',
            decoration: dec,
            textInputAction: TextInputAction.next,
            onChanged: (v) => widget.repo.updateEntry(e.id, title: v.trim().isEmpty ? null : v),
          ),
        ),
        // Nota (abre dialog para multilinea)
        cell(
          child: InkWell(
            onTap: () => _editNote(context, e, e.note ?? ''),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                (e.note ?? '').isEmpty ? '' : e.note!,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ),
        ),
        // Lat
        cell(
          child: TextFormField(
            initialValue: e.lat?.toStringAsFixed(5) ?? '',
            decoration: dec,
            keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
            textInputAction: TextInputAction.next,
            onChanged: (v) => widget.repo.updateEntry(e.id, lat: v.trim().isEmpty ? null : double.tryParse(v)),
          ),
        ),
        // Lng
        cell(
          child: TextFormField(
            initialValue: e.lng?.toStringAsFixed(5) ?? '',
            decoration: dec,
            keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
            textInputAction: TextInputAction.next,
            onChanged: (v) => widget.repo.updateEntry(e.id, lng: v.trim().isEmpty ? null : double.tryParse(v)),
          ),
        ),
        // ±m
        cell(
          w: 90,
          child: TextFormField(
            initialValue: e.accuracy?.toStringAsFixed(1) ?? '',
            decoration: dec,
            keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: true),
            textInputAction: TextInputAction.next,
            onChanged: (v) => widget.repo.updateEntry(e.id, accuracy: v.trim().isEmpty ? null : double.tryParse(v)),
          ),
        ),
        // Fuente
        cell(
          w: 110,
          child: TextFormField(
            initialValue: e.provider ?? '',
            decoration: dec,
            textInputAction: TextInputAction.next,
            onChanged: (v) => widget.repo.updateEntry(e.id, provider: v.trim().isEmpty ? null : v),
          ),
        ),
        // Adjuntos
        cell(
          w: 110,
          child: IconButton(
            tooltip: 'Agregar foto',
            icon: const Icon(Icons.photo_camera_outlined),
            onPressed: () => _attachPhoto(e.id),
          ),
        ),
        // Actualizado
        cell(w: 160, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text(_fmtTs(e.updatedAt)))),
        // Acciones
        cell(
          w: 70,
          child: IconButton(
            tooltip: 'Eliminar fila',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Eliminar fila'),
                  content: const Text('¿Seguro?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                    FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
                  ],
                ),
              );
              if (ok == true) {
                await widget.repo.deleteEntry(e.id);
                if (!mounted) return;
                _load();
              }
            },
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outlineVariant;
    final insets = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      appBar: AppBar(
        title: Text(_sheetName),
        actions: [
          IconButton(
            tooltip: 'Exportar Excel',
            onPressed: _exportExcel,
            icon: const Icon(Icons.table_view_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addRow,
        icon: const Icon(Icons.add),
        label: const Text('Agregar fila'),
      ),
      body: Padding(
        padding: EdgeInsets.only(bottom: insets),
        child: FutureBuilder<List<Entry>>(
          future: _future,
          builder: (_, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final entries = snap.data ?? const <Entry>[];
            return Column(
              children: [
                _headerRow(outline),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: _v,
                    itemCount: entries.length,
                    itemBuilder: (_, i) => _dataRow(outline, entries[i]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
