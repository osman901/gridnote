// lib/screens/import_screen.dart
import 'dart:io';
import 'package:excel/excel.dart' as ex;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:csv/csv.dart';

import '../theme/gridnote_theme.dart';
import '../models/sheet_meta.dart';
import '../models/measurement.dart';
import '../state/measurement_async_provider.dart';

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key, required this.themeController, required this.meta});
  final GridnoteThemeController themeController;
  final SheetMeta meta;

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  List<Measurement> _preview = [];

  Future<void> _pick() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx'],
    );
    if (res == null || res.files.single.path == null) return;

    final file = File(res.files.single.path!);
    final ext = file.path.split('.').last.toLowerCase();
    if (ext == 'csv') {
      await _importCsv(file);
    } else {
      await _importXlsx(file);
    }
  }

  Future<void> _importCsv(File file) async {
    final raw = await file.readAsString();
    final rows = const CsvToListConverter(eol: '\n').convert(raw);
    if (rows.isEmpty) return;
    await _parseRows(rows.map((r) => r.map((e) => e?.toString()).toList()).toList());
  }

  Future<void> _importXlsx(File file) async {
    final bytes = await file.readAsBytes();
    final book = ex.Excel.decodeBytes(bytes);
    final name = book.tables.keys.isNotEmpty ? book.tables.keys.first : null;
    final sheet = (name != null) ? book.tables[name] : null;
    if (sheet == null || sheet.rows.isEmpty) return;
    final rows = sheet.rows.map((row) => row.map((c) => c?.value?.toString()).toList()).toList();
    await _parseRows(rows);
  }

  Future<void> _parseRows(List<List<String?>> rows) async {
    final headers = rows.first.map((e) => (e ?? '').toLowerCase().trim()).toList();

    int idxOf(String name, {List<String> alias = const []}) {
      final all = [name.toLowerCase(), ...alias.map((a) => a.toLowerCase())];
      for (final n in all) {
        final i = headers.indexOf(n);
        if (i >= 0) return i;
      }
      return -1;
    }

    final iProg = idxOf('progresiva', alias: ['kp', 'pk']);
    final iOhm1 = idxOf('ohm1m', alias: ['ohm_1m', 'res1m', 'r1m']);
    final iOhm3 = idxOf('ohm3m', alias: ['ohm_3m', 'res3m', 'r3m']);
    final iObs  = idxOf('observaciones', alias: ['observacion', 'obs', 'descripcion', 'comentarios']);
    final iLat  = idxOf('lat', alias: ['latitude', 'latitud']);
    final iLng  = idxOf('lng', alias: ['lon', 'long', 'longitud']);
    final iDate = idxOf('fecha', alias: ['date', 'datetime']);

    double toDouble(String? v, {double def = 0.0}) {
      if (v == null) return def;
      return double.tryParse(v.replaceAll(',', '.')) ?? def;
    }

    DateTime toDate(String? v) {
      if (v == null || v.trim().isEmpty) return DateTime.now();
      final iso = DateTime.tryParse(v);
      if (iso != null) return iso;
      final parts = v.split(RegExp(r'[\/\-]'));
      if (parts.length >= 3) {
        final d = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final y = int.tryParse(parts[2]);
        if (d != null && m != null && y != null) return DateTime(y, m, d);
      }
      return DateTime.now();
    }

    final list = <Measurement>[];
    for (var r = 1; r < rows.length; r++) {
      final row = rows[r];

      String pick(int i) => (i >= 0 && i < row.length) ? (row[i] ?? '').trim() : '';

      final progresiva = pick(iProg);
      final ohm1m = toDouble(pick(iOhm1));
      final ohm3m = toDouble(pick(iOhm3));
      final observations = pick(iObs);
      final lat = toDouble(pick(iLat), def: double.nan);
      final lng = toDouble(pick(iLng), def: double.nan);
      final date = toDate(pick(iDate));

      list.add(Measurement(
        id: r,
        progresiva: progresiva,
        ohm1m: ohm1m,
        ohm3m: ohm3m,
        observations: observations,
        date: date,
        latitude: lat.isNaN ? null : lat,
        longitude: lng.isNaN ? null : lng,
      ));
    }

    if (!mounted) return;
    setState(() => _preview = list);
  }

  Future<void> _commit() async {
    if (_preview.isEmpty) return;
    // ✅ usar el provider *family* con el id de la planilla para acceder al notifier
    ref.read(measurementAsyncProvider(widget.meta.id).notifier).setAll(_preview);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Importación completa')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.themeController.theme;
    return Scaffold(
      backgroundColor: t.scaffold,
      appBar: AppBar(title: const Text('Importar')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(children: [
              FilledButton.icon(
                onPressed: _pick,
                icon: const Icon(Icons.file_open),
                label: const Text('Elegir CSV/XLSX'),
              ),
              const SizedBox(width: 12),
              if (_preview.isNotEmpty)
                FilledButton.icon(
                  onPressed: _commit,
                  icon: const Icon(Icons.check),
                  label: const Text('Importar'),
                ),
            ]),
            const SizedBox(height: 12),
            Expanded(
              child: _preview.isEmpty
                  ? const Center(child: Text('Encabezados: progresiva, ohm1m, ohm3m, observaciones, lat, lng, fecha'))
                  : ListView.separated(
                itemCount: _preview.length,
                separatorBuilder: (_, __) => const Divider(height: 0),
                itemBuilder: (_, i) {
                  final m = _preview[i];
                  final loc = (m.latitude == null || m.longitude == null)
                      ? ''
                      : '${m.latitude}, ${m.longitude}';
                  return ListTile(
                    title: Text(m.progresiva.isEmpty ? '(sin progresiva)' : m.progresiva),
                    subtitle: Text(m.observations),
                    trailing: Text(loc, style: TextStyle(color: t.text.withValues(alpha: 0.7))),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
