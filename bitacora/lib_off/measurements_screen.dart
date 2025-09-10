// lib/screens/measurements_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';

import '../theme/gridnote_theme.dart';
import '../models/measurement.dart';
import '../models/sheet_meta.dart';
import '../services/measurements_store.dart';
import '../services/attachments_service.dart';
import '../services/xlsx_export_service.dart';

class MeasurementScreen extends StatefulWidget {
  const MeasurementScreen({
    super.key,
    required this.id,
    required this.meta,
    required this.initial,           // se usa como fallback si no hay guardado
    required this.themeController,
  });

  final String id;
  final SheetMeta meta;
  final List<Measurement> initial;
  final GridnoteThemeController themeController;

  @override
  State<MeasurementScreen> createState() => _MeasurementScreenState();
}

class _MeasurementScreenState extends State<MeasurementScreen> {
  final _store = MeasurementsStore.instance;

  late List<Measurement> _rows;
  late List<String> _headers; // tÃƒÆ’Ã‚Â­tulos editables
  String _q = '';
  String _sort = 'date'; // date | progresiva | ohm1m | ohm3m
  bool _asc = true;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _rows = List<Measurement>.from(widget.initial);
    _headers = <String>['Fecha','Progresiva','1m (ÃƒÅ½Ã‚Â©)','3m (ÃƒÅ½Ã‚Â©)','Observaciones','UbicaciÃƒÆ’Ã‚Â³n'];
    _loadPersisted();
  }

  Future<void> _loadPersisted() async {
    final snap = await _store.load(widget.id);
    setState(() {
      _headers = snap.headers.isNotEmpty ? snap.headers : _headers;
      _rows = snap.items.isNotEmpty ? snap.items : _rows;
    });
  }

  Future<void> _persistNow() async {
    await _store.save(
      widget.id,
      MeasurementsSnapshot(headers: _headers, items: _rows, updatedAt: DateTime.now()),
    );
  }

  void _schedulePersist() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _persistNow);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  // ----------------- helpers -----------------
  List<Measurement> get _filteredSorted {
    final q = _q.trim().toLowerCase();
    final list = _rows.where((m) {
      if (q.isEmpty) return true;
      bool hit(String? s) => (s ?? '').toLowerCase().contains(q);
      return hit(m.progresiva) ||
          hit(m.observations) ||
          (m.ohm1m?.toString() ?? '').contains(q) ||
          (m.ohm3m?.toString() ?? '').contains(q) ||
          m.dateString.toLowerCase().contains(q);
    }).toList();

    int cmpNum(double? a, double? b) {
      if (a == null && b == null) return 0;
      if (a == null) return -1;
      if (b == null) return 1;
      return a.compareTo(b);
    }

    list.sort((a, b) {
      int r;
      switch (_sort) {
        case 'progresiva':
          r = a.progresiva.compareTo(b.progresiva);
          break;
        case 'ohm1m':
          r = cmpNum(a.ohm1m, b.ohm1m);
          break;
        case 'ohm3m':
          r = cmpNum(a.ohm3m, b.ohm3m);
          break;
        case 'date':
        default:
          final ad = a.date, bd = b.date;
          if (ad == null && bd == null) r = 0;
          else if (ad == null) r = -1;
          else if (bd == null) r = 1;
          else r = ad.compareTo(bd);
      }
      return _asc ? r : -r;
    });
    return list;
  }

  void _addRow() {
    setState(() {
      _rows = List.of(_rows)..add(const Measurement(progresiva: '', observations: ''));
    });
    _schedulePersist();
  }

  Future<void> _editRow(int index) async {
    final current = _rows[index];
    final edited = await showModalBottomSheet<Measurement>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _MeasurementEditor(initial: current),
    );
    if (edited == null) return;
    setState(() {
      final next = List.of(_rows);
      next[index] = edited;
      _rows = next;
    });
    _schedulePersist();
  }

  void _duplicateRow(int index) {
    setState(() {
      final next = List.of(_rows)..insert(index + 1, _rows[index].copyWith());
      _rows = next;
    });
    _schedulePersist();
  }

  void _deleteRow(int index) {
    setState(() {
      final next = List.of(_rows)..removeAt(index);
      _rows = next;
    });
    _schedulePersist();
  }

  Future<void> _attachPhotoCam(Measurement m) async {
    final path = await AttachmentsService.instance.pickFromCameraForKey('${widget.id}_${m.id ?? _rows.indexOf(m)}');
    if (path == null) return;
    final idx = _rows.indexOf(m);
    if (idx < 0) return;
    final updated = m.copyWith(photos: List.of(m.photos)..add(path));
    setState(() => _rows[idx] = updated);
    _schedulePersist();
  }

  Future<void> _attachPhotoGallery(Measurement m) async {
    final path = await AttachmentsService.instance.pickFromGalleryForKey('${widget.id}_${m.id ?? _rows.indexOf(m)}');
    if (path == null) return;
    final idx = _rows.indexOf(m);
    if (idx < 0) return;
    final updated = m.copyWith(photos: List.of(m.photos)..add(path));
    setState(() => _rows[idx] = updated);
    _schedulePersist();
  }

  Future<void> _setLocation(Measurement m) async {
    final geo = await AttachmentsService.instance.getCurrentLocation();
    if (geo == null) return;
    // geo:lat,lng
    final parts = geo.substring(4).split(',');
    final lat = double.tryParse(parts[0]);
    final lng = double.tryParse(parts[1]);
    if (lat == null || lng == null) return;
    final idx = _rows.indexOf(m);
    if (idx < 0) return;
    setState(() => _rows[idx] = m.copyWith(latitude: lat, longitude: lng));
    _schedulePersist();
  }

  Future<void> _editHeaders() async {
    final controllers = List.generate(
      _headers.length,
          (i) => TextEditingController(text: _headers[i]),
    );
    final newHeaders = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar tÃƒÆ’Ã‚Â­tulos de columnas'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            _headers.length,
                (i) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                controller: controllers[i],
                decoration: InputDecoration(labelText: 'Columna ${i + 1}'),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controllers.map((c) => c.text.trim()).toList()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (newHeaders == null) return;
    setState(() => _headers = newHeaders);
    _schedulePersist();
  }

  Future<void> _toggleDefaultHeaders() async {
    final def = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('TÃƒÆ’Ã‚Â­tulos'),
        content: const Text('Ãƒâ€šÃ‚ÂUsar tÃƒÆ’Ã‚Â­tulos por defecto o dejarlos vacÃƒÆ’Ã‚Â­os para editarlos 100%?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('VacÃƒÆ’Ã‚Â­os')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Por defecto')),
        ],
      ),
    );
    if (def == null) return;
    setState(() {
      _headers = def
          ? <String>['Fecha','Progresiva','1m (ÃƒÅ½Ã‚Â©)','3m (ÃƒÅ½Ã‚Â©)','Observaciones','UbicaciÃƒÆ’Ã‚Â³n']
          : List<String>.filled(6, '');
    });
    _schedulePersist();
  }

  Future<void> _exportXlsx() async {
    final file = await XlsxExportService().buildFile(
      sheetId: widget.id,
      title: widget.meta.name.isEmpty ? 'Planilla' : widget.meta.name,
      data: _rows,
      headers: _headers, // ÃƒÂ¢Ã¢â‚¬ Ã‚Â tÃƒÆ’Ã‚Â­tulos editables
      getPhotos: (m) => m.photos,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exportado: ${file.path}')),
    );
  }

  // ----------------- UI -----------------
  @override
  Widget build(BuildContext context) {
    final t = widget.themeController.theme;
    final rows = _filteredSorted;

    return Scaffold(
      backgroundColor: t.scaffold,
      appBar: AppBar(
        backgroundColor: t.scaffold,
        elevation: 0,
        title: Text(
          widget.meta.name.isEmpty ? 'Planilla' : widget.meta.name,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Ordenar',
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'date', child: Text('Ordenar por fecha')),
              PopupMenuItem(value: 'progresiva', child: Text('Ordenar por progresiva')),
              PopupMenuItem(value: 'ohm1m', child: Text('Ordenar por 1 m (ÃƒÅ½Ã‚Â©)')),
              PopupMenuItem(value: 'ohm3m', child: Text('Ordenar por 3 m (ÃƒÅ½Ã‚Â©)')),
            ],
            icon: const Icon(Icons.sort),
          ),
          IconButton(
            tooltip: _asc ? 'Ascendente' : 'Descendente',
            onPressed: () => setState(() => _asc = !_asc),
            icon: Icon(_asc ? Icons.arrow_upward : Icons.arrow_downward),
          ),
          PopupMenuButton<String>(
            tooltip: 'MÃƒÆ’Ã‚Â¡s',
            onSelected: (v) {
              if (v == 'edit_headers') _editHeaders();
              if (v == 'toggle_headers') _toggleDefaultHeaders();
              if (v == 'export') _exportXlsx();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit_headers', child: Text('Editar tÃƒÆ’Ã‚Â­tulos')),
              PopupMenuItem(value: 'toggle_headers', child: Text('TÃƒÆ’Ã‚Â­tulos: por defecto / vacÃƒÆ’Ã‚Â­os')),
              PopupMenuItem(value: 'export', child: Text('Exportar a Excel')),
            ],
            icon: const Icon(Icons.more_vert),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            child: TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'BuscarÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦',
                border: const OutlineInputBorder(),
                isDense: true,
                filled: true,
                fillColor: t.surface,
              ),
            ),
          ),
          // Cabecera con tÃƒÆ’Ã‚Â­tulos actuales (para referencia)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: List.generate(_headers.length, (i) {
                final h = _headers[i].isEmpty ? '(sin tÃƒÆ’Ã‚Â­tulo)' : _headers[i];
                return Chip(label: Text(h));
              }),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 88),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final m = rows[i];
                final subtitleParts = <String>[];
                if (m.date != null) subtitleParts.add(m.dateString);
                if (m.ohm1m != null) subtitleParts.add('1 m: ${m.ohm1m}');
                if (m.ohm3m != null) subtitleParts.add('3 m: ${m.ohm3m}');
                if (m.latitude != null && m.longitude != null) {
                  subtitleParts.add('(${m.latitude!.toStringAsFixed(6)}, ${m.longitude!.toStringAsFixed(6)})');
                }
                if (m.observations.isNotEmpty) subtitleParts.add(m.observations);
                final subtitle = subtitleParts.join(' ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¢ ');

                return Card(
                  color: t.surface,
                  child: ListTile(
                    title: Text(
                      m.progresiva.isEmpty ? '(sin progresiva)' : m.progresiva,
                      style: TextStyle(color: t.text, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(subtitle, style: TextStyle(color: t.textFaint)),
                    onTap: () async {
                      final realIndex = _rows.indexOf(m);
                      if (realIndex >= 0) await _editRow(realIndex);
                    },
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) {
                        final realIndex = _rows.indexOf(m);
                        if (realIndex < 0) return;
                        if (v == 'edit') _editRow(realIndex);
                        if (v == 'dup') _duplicateRow(realIndex);
                        if (v == 'del') _deleteRow(realIndex);
                        if (v == 'cam') _attachPhotoCam(m);
                        if (v == 'gal') _attachPhotoGallery(m);
                        if (v == 'loc') _setLocation(m);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Editar')),
                        PopupMenuItem(value: 'dup', child: Text('Duplicar')),
                        PopupMenuItem(value: 'del', child: Text('Eliminar')),
                        PopupMenuItem(value: 'cam', child: Text('Foto (cÃƒÆ’Ã‚Â¡mara)')),
                        PopupMenuItem(value: 'gal', child: Text('Foto (galerÃƒÆ’Ã‚Â­a)')),
                        PopupMenuItem(value: 'loc', child: Text('Fijar ubicaciÃƒÆ’Ã‚Â³n')),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addRow,
        icon: const Icon(Icons.add),
        label: const Text('Agregar fila'),
      ),
    );
  }
}

// ----------------- Editor -----------------
class _MeasurementEditor extends StatefulWidget {
  const _MeasurementEditor({required this.initial});
  final Measurement initial;

  @override
  State<_MeasurementEditor> createState() => _MeasurementEditorState();
}

class _MeasurementEditorState extends State<_MeasurementEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _prog;
  late final TextEditingController _ohm1;
  late final TextEditingController _ohm3;
  late final TextEditingController _obs;
  late final TextEditingController _lat;
  late final TextEditingController _lng;
  DateTime? _date;

  @override
  void initState() {
    super.initState();
    final m = widget.initial;
    _prog = TextEditingController(text: m.progresiva);
    _ohm1 = TextEditingController(text: m.ohm1m?.toString() ?? '');
    _ohm3 = TextEditingController(text: m.ohm3m?.toString() ?? '');
    _obs  = TextEditingController(text: m.observations);
    _lat  = TextEditingController(text: m.latitude?.toString() ?? '');
    _lng  = TextEditingController(text: m.longitude?.toString() ?? '');
    _date = m.date;
  }

  @override
  void dispose() {
    _prog.dispose(); _ohm1.dispose(); _ohm3.dispose();
    _obs.dispose();  _lat.dispose();  _lng.dispose();
    super.dispose();
  }

  double? _toD(String s) {
    final t = s.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final base = _date ?? now;
    final d = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10),
    );
    if (!mounted) return;
    setState(() => _date = d ?? _date);
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final m = widget.initial.copyWith(
      progresiva: _prog.text.trim(),
      ohm1m: _toD(_ohm1.text),
      ohm3m: _toD(_ohm3.text),
      observations: _obs.text.trim(),
      latitude: _toD(_lat.text),
      longitude: _toD(_lng.text),
      date: _date,
    );
    Navigator.of(context).pop(m);
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.viewInsetsOf(context).bottom;
    final dateText = _date == null
        ? 'ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â'
        : '${_date!.day.toString().padLeft(2, '0')}/${_date!.month.toString().padLeft(2, '0')}/${_date!.year}';

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 12 + pad),
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              children: [
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Editar mediciÃƒÆ’Ã‚Â³n', style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('CompletÃƒÆ’Ã‚Â¡ los campos y guardÃƒÆ’Ã‚Â¡'),
                ),
                TextFormField(controller: _prog, decoration: const InputDecoration(labelText: 'Progresiva')),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _ohm1,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: '1 m (ÃƒÅ½Ã‚Â©)'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _ohm3,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: '3 m (ÃƒÅ½Ã‚Â©)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(controller: _obs, maxLines: 3, decoration: const InputDecoration(labelText: 'Observaciones')),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _pickDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Fecha'),
                          child: Text(dateText),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => setState(() => _date = DateTime.now()),
                      icon: const Icon(Icons.today),
                      label: const Text('Hoy'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: const Text('Guardar')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

