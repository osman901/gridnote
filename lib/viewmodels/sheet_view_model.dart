// lib/viewmodels/sheet_view_model.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show ValueNotifier, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/measurement.dart';
import '../services/audit_log_service.dart';
import '../services/errors.dart';
import '../services/ocr_table_import_service.dart';
import '../services/suggest_service.dart';
import '../services/xlsx_export_service.dart';
import '../services/csv_export_service.dart';
import '../services/pdf_export_service.dart';
import '../services/service_locator.dart';

enum PermResult { ok, disabled, denied, deniedForever }

class SheetViewModel {
  SheetViewModel({
    required this.sheetId,
    required String initialTitle,          // <- parámetro simple, no "this."
    required List<Measurement> initialRows,
    required this.audit,
    required this.onSnack,
    required this.onTitleChanged,
  }) {
    measurements.value = _ensureLocalIds(List<Measurement>.from(initialRows));
    title.value = initialTitle;
  }

  // --- Inyectadas / dependencias ---
  final String sheetId;
  final AuditLogService audit;
  final void Function(String) onSnack;
  final void Function(String) onTitleChanged;

  final SuggestService _suggest = getIt<SuggestService>();
  final XlsxExportService _xlsx = getIt<XlsxExportService>();
  final OcrTableImportService _ocr = getIt<OcrTableImportService>();
  final SharedPreferences _sp = getIt<SharedPreferences>();

  // --- Estado reactivo ---
  final ValueNotifier<bool> isBusy = ValueNotifier(false);
  final ValueNotifier<bool> formView = ValueNotifier(false);
  final ValueNotifier<bool> canUndo = ValueNotifier(false);
  final ValueNotifier<String> title = ValueNotifier('');
  final ValueNotifier<Map<String, String>> headers = ValueNotifier(<String, String>{});
  final ValueNotifier<List<Measurement>> measurements = ValueNotifier(<Measurement>[]);
  final ValueNotifier<String?> defaultEmail = ValueNotifier<String?>(null);
  final ValueNotifier<double?> lat = ValueNotifier<double?>(null);
  final ValueNotifier<double?> lng = ValueNotifier<double?>(null);
  final ValueNotifier<String> searchQuery = ValueNotifier('');

  // --- Keys SP ---
  String get _headersKey => 'sheet_${sheetId}_headers_v2';
  String get _latKey => 'sheet_${sheetId}_lat';
  String get _lngKey => 'sheet_${sheetId}_lng';
  static const _kDefaultEmailKey = 'default_email';

  // --- Undo ---
  final List<List<Measurement>> _undo = <List<Measurement>>[];

  // --- Helpers internos ---
  int _nextTempId = -1;
  Timer? _searchDebounce;

  // --- Ciclo de vida ---
  Future<void> init() async {
    isBusy.value = true;
    try {
      await _loadHeaders();
      await _loadDefaultEmail();
      await _loadSavedLocation();
      await _cleanupOldTempFiles();
      await _suggest.load();
    } catch (e, st) {
      _logError(e, st);
    } finally {
      isBusy.value = false;
    }
  }

  void dispose() {
    isBusy.dispose();
    formView.dispose();
    canUndo.dispose();
    title.dispose();
    headers.dispose();
    measurements.dispose();
    defaultEmail.dispose();
    lat.dispose();
    lng.dispose();
    searchQuery.dispose();
    _searchDebounce?.cancel();
  }

  // --- Headers ---
  Future<void> _loadHeaders() async {
    final raw = _sp.getString(_headersKey);
    final map = (raw == null || raw.isEmpty) ? <String, String>{} : Map<String, String>.from(Uri.splitQueryString(raw));
    headers.value = map;
  }

  Future<void> setHeaderTitle(String column, String newTitle) async {
    final current = Map<String, String>.from(headers.value);
    current[column] = newTitle;
    headers.value = current;
    await _sp.setString(_headersKey, Uri(queryParameters: current).query);
  }

  // --- Título ---
  Future<void> saveTitle(String next) async {
    final v = next.trim();
    if (v == title.value) return;
    title.value = v;
    onTitleChanged(v);
    audit.log('title_changed', {'title': v});
    HapticFeedback.selectionClick();
    onSnack('Título guardado.');
  }

  // --- Email frecuente ---
  Future<void> _loadDefaultEmail() async {
    defaultEmail.value = _sp.getString(_kDefaultEmailKey);
  }

  Future<void> saveDefaultEmail(String? email) async {
    if (email == null || email.trim().isEmpty) {
      await _sp.remove(_kDefaultEmailKey);
      defaultEmail.value = null;
    } else {
      final v = email.trim();
      await _sp.setString(_kDefaultEmailKey, v);
      defaultEmail.value = v;
    }
  }

  bool isEmailValid(String e) {
    final s = e.trim();
    final re = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');
    return re.hasMatch(s);
  }

  // --- Ubicación ---
  Future<void> _loadSavedLocation() async {
    lat.value = _sp.getDouble(_latKey);
    lng.value = _sp.getDouble(_lngKey);
  }

  Future<PermResult> _ensureLocationPermissions() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return PermResult.disabled;

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied) return PermResult.denied;
    if (perm == LocationPermission.deniedForever) return PermResult.deniedForever;
    return PermResult.ok;
  }

  Future<void> saveLocation() async {
    if (isBusy.value) return;
    isBusy.value = true;
    try {
      final perm = await _ensureLocationPermissions();
      switch (perm) {
        case PermResult.disabled:
          onSnack('Activá el GPS para guardar la ubicación.');
          return;
        case PermResult.denied:
          onSnack('Permiso de ubicación denegado.');
          return;
        case PermResult.deniedForever:
          await Geolocator.openAppSettings();
          return;
        case PermResult.ok:
          break;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      await _sp.setDouble(_latKey, pos.latitude);
      await _sp.setDouble(_lngKey, pos.longitude);
      lat.value = pos.latitude;
      lng.value = pos.longitude;
      HapticFeedback.lightImpact();
      onSnack('Ubicación guardada.');
      audit.log('location_saved', {'lat': lat.value, 'lng': lng.value});
    } catch (e, st) {
      _logError(e, st);
      onSnack('No se pudo obtener la ubicación.');
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> openMapsFor({double? latParam, double? lngParam}) async {
    final la = latParam ?? lat.value;
    final lo = lngParam ?? lng.value;
    if (la == null || lo == null) return;

    final bool isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final Uri uriApp = isIOS ? Uri.parse('maps://?q=$la,$lo') : Uri.parse('geo:$la,$lo?q=$la,$lo');
    final Uri uriWeb = isIOS
        ? Uri.parse('https://maps.apple.com/?q=$la,$lo')
        : Uri.parse('https://www.google.com/maps/search/?api=1&query=$la,$lo');

    try {
      if (await canLaunchUrl(uriApp)) {
        final ok = await launchUrl(uriApp, mode: LaunchMode.externalApplication);
        if (ok) return;
      }
      if (await canLaunchUrl(uriWeb)) {
        final ok = await launchUrl(uriWeb, mode: LaunchMode.externalApplication);
        if (ok) return;
      }
      onSnack('No se pudo abrir la app de mapas.');
    } catch (e, st) {
      _logError(e, st);
      onSnack('No se pudo abrir la app de mapas.');
    }
  }

  String mapsUrl(double la, double lo) {
    final bool isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    return isIOS
        ? 'https://maps.apple.com/?q=$la,$lo'
        : 'https://www.google.com/maps/search/?api=1&query=$la,$lo';
  }

  // --- Export / Share ---
  Future<File> _makeXlsxFile(List<Measurement> rows) {
    return _xlsx.buildFile(
      sheetId: sheetId,
      title: title.value,
      data: rows,
      defaultLat: lat.value,
      defaultLng: lng.value,
    );
  }

  Future<File> _makeCsvFile(List<Measurement> rows) async {
    final base = _safeFileName(title.value);
    final ts = DateTime.now().toIso8601String().replaceAll(':', '').replaceAll('.', '').replaceAll('-', '');
    final name = 'gridnote_${base}_$ts.csv';
    // <- método estático
    return CsvExportService.exportMeasurements(rows, fileName: name);
  }

  Future<File> _makePdfFile(List<Measurement> rows) async {
    final base = _safeFileName(title.value);
    final ts = DateTime.now().toIso8601String().replaceAll(':', '').replaceAll('.', '').replaceAll('-', '');
    final name = 'gridnote_${base}_$ts.pdf';
    // <- método estático
    return PdfExportService.export(title: title.value, rows: rows, fileName: name);
  }

  String _safeFileName(String name) {
    final base = name.trim().isEmpty ? 'planilla' : name.trim();
    var sanitized = base.replaceAll(RegExp(r'[^\w\s.-]'), '_').replaceAll(RegExp(r'\s+'), '_');
    if (sanitized.length > 80) sanitized = sanitized.substring(0, 80);
    return sanitized;
  }

  String buildEmailBody(List<Measurement> rows) {
    final b = StringBuffer();
    b.writeln('Adjunto archivo generado con Gridnote para "${title.value}".');
    final la = lat.value, lo = lng.value;
    if (la != null && lo != null) {
      b.writeln('');
      b.writeln('Ubicación general:');
      b.writeln(mapsUrl(la, lo));
    }
    final withCoords = rows.where((m) => m.latitude != null && m.longitude != null).toList();
    if (withCoords.isNotEmpty) {
      b.writeln('');
      b.writeln('Enlaces por fila:');
      for (final m in withCoords.take(10)) {
        final url = mapsUrl(m.latitude!, m.longitude!);
        final prog = (m.progresiva.isEmpty) ? '-' : m.progresiva;
        b.writeln('• $prog → $url');
      }
      if (withCoords.length > 10) b.writeln('• (+${withCoords.length - 10} más)');
    }
    return b.toString();
  }

  Future<void> shareViaEmailXlsx({
    required List<Measurement> rows,
    required String? email,
  }) async {
    if (isBusy.value) return;
    isBusy.value = true;
    try {
      final trimmed = (email ?? '').trim();
      if (!isEmailValid(trimmed)) {
        onSnack('Email inválido. Revisá el destinatario.');
        return;
      }

      File file;
      try {
        file = await _makeXlsxFile(rows);
      } on ExcelExportException catch (e) {
        onSnack(e.message);
        return;
      } on FileSystemException {
        onSnack('No se pudo guardar el archivo. Verificá el espacio disponible.');
        return;
      }

      final bodyText = buildEmailBody(rows);
      final mail = Email(
        recipients: [trimmed],
        subject: 'Gridnote – ${title.value}',
        body: bodyText,
        attachmentPaths: [file.path],
        isHTML: false,
      );

      try {
        await FlutterEmailSender.send(mail);
        onSnack('Se abrió tu app de correo. Tocá “Enviar”.');
      } catch (_) {
        final mailto = Uri(
          scheme: 'mailto',
          path: trimmed,
          queryParameters: <String, String>{'subject': 'Gridnote – ${title.value}', 'body': bodyText},
        );
        try {
          if (await canLaunchUrl(mailto)) {
            final ok = await launchUrl(mailto, mode: LaunchMode.externalApplication);
            if (ok) return;
          }
        } catch (_) {}
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
          subject: 'Gridnote – ${title.value}',
          text: bodyText,
        );
      }
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> shareCsv({required List<Measurement> rows}) async {
    if (isBusy.value) return;
    isBusy.value = true;
    try {
      File file;
      try {
        file = await _makeCsvFile(rows);
      } on FileSystemException {
        onSnack('No se pudo guardar el archivo. Verificá el espacio disponible.');
        return;
      }
      await Share.shareXFiles([XFile(file.path, mimeType: 'text/csv')],
          subject: 'Gridnote – ${title.value}', text: buildEmailBody(rows));
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> exportPdf({required List<Measurement> rows}) async {
    if (isBusy.value) return;
    isBusy.value = true;
    try {
      final file = await _makePdfFile(rows);
      await Share.shareXFiles([XFile(file.path, mimeType: 'application/pdf')],
          subject: 'Gridnote – ${title.value}', text: buildEmailBody(rows));
    } catch (_) {
      onSnack('No se pudo generar el PDF.');
    } finally {
      isBusy.value = false;
    }
  }

  // --- OCR ---
  Future<List<Measurement>> importOcrFromCamera() async {
    final rows = await _ocr.fromCamera();
    return _importedRows(rows);
  }

  Future<List<Measurement>> importOcrFromGallery() async {
    final rows = await _ocr.fromGallery();
    return _importedRows(rows);
  }

  List<Measurement> _importedRows(List<Measurement> rows) {
    if (rows.isEmpty) {
      onSnack('No se detectaron filas.');
      return measurements.value;
    }
    _pushUndo();
    final next = List<Measurement>.from(measurements.value)..addAll(rows.map(_withLocalId));
    measurements.value = next;
    audit.log('ocr_import', {'rows': rows.length});
    onSnack('Importadas ${rows.length} filas.');
    HapticFeedback.selectionClick();
    return next;
  }

  // --- Datos / edición ---
  void addRow() {
    _pushUndo();
    final next = List<Measurement>.from(measurements.value)..add(_withLocalId(Measurement.empty()));
    measurements.value = next;
    HapticFeedback.selectionClick();
    audit.log('row_add', {});
  }

  void replaceRows(List<Measurement> rows) {
    _pushUndo();
    measurements.value = _ensureLocalIds(rows);
    audit.log('rows_changed', {'count': measurements.value.length});
  }

  void _pushUndo() {
    _undo.add(List<Measurement>.from(measurements.value));
    canUndo.value = _undo.isNotEmpty;
  }

  void undoLast() {
    if (_undo.isEmpty) return;
    final prev = _undo.removeLast();
    measurements.value = _ensureLocalIds(prev);
    canUndo.value = _undo.isNotEmpty;
    HapticFeedback.selectionClick();
    onSnack('Deshacer');
  }

  // --- Búsqueda (debounce) ---
  void setQueryDebounced(String q, {Duration delay = const Duration(milliseconds: 300)}) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(delay, () {
      searchQuery.value = q;
    });
  }

  // --- Limpieza temporales ---
  Future<void> _cleanupOldTempFiles({Duration maxAge = const Duration(hours: 12)}) async {
    try {
      final dir = await getTemporaryDirectory();
      final now = DateTime.now();
      final entities = await dir.list().toList();
      for (final e in entities) {
        if (e is! File) continue;
        final p = e.path;
        if ((!p.endsWith('.xlsx') && !p.endsWith('.csv') && !p.endsWith('.pdf')) || !p.contains('gridnote_')) continue;
        final stat = await e.stat();
        if (now.difference(stat.modified) > maxAge) {
          try {
            await e.delete();
          } catch (err, st) {
            _logError(err, st);
          }
        }
      }
    } catch (e, st) {
      _logError(e, st);
    }
  }

  // --- Utils ---
  int _genTempId() => _nextTempId--;
  Measurement _withLocalId(Measurement m) => (m.id != null) ? m : m.copyWith(id: _genTempId());
  List<Measurement> _ensureLocalIds(List<Measurement> list) => list.map(_withLocalId).toList(growable: true);

  void _logError(Object e, [StackTrace? st]) {
    // TODO: Integra Crashlytics/Sentry si querés.
    // ignore: avoid_print
    print('SheetViewModel error: $e\n$st');
  }
}
