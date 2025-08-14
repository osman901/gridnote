// lib/screens/measurement_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;

import '../models/measurement.dart';
import '../models/sheet_meta.dart';
import '../theme/gridnote_theme.dart';
import '../widgets/measurement_datagrid.dart';

class MeasurementScreen extends StatefulWidget {
  const MeasurementScreen({
    super.key,
    required this.id,
    required this.meta,
    required this.initial,
    required this.themeController,
    this.onTitleChanged,
  });

  final String id;
  final SheetMeta meta;
  final List<Measurement> initial;
  final GridnoteThemeController themeController;
  final ValueChanged<String>? onTitleChanged;

  @override
  State<MeasurementScreen> createState() => _MeasurementScreenState();
}

class _MeasurementScreenState extends State<MeasurementScreen> {
  static const _kDefaultEmailKey = 'default_email';

  // XLSX columns
  static const int _cPro = 1;
  static const int _cOhm1 = 2;
  static const int _cOhm3 = 3;
  static const int _cObs = 4;
  static const int _cDate = 5;
  static const int _cLat = 6;
  static const int _cLng = 7;
  static const int _cMaps = 8;

  bool _editingTitle = false;
  bool _isLoading = false;

  late final TextEditingController _titleCtrl;
  final Future<SharedPreferences> _sp = SharedPreferences.getInstance();

  String? _defaultEmail;
  double? _lat;
  double? _lng;

  late List<Measurement> _rows;
  final _gridCtrl = MeasurementGridController();

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.meta.name);
    _rows = List<Measurement>.from(widget.initial);
    _loadDefaultEmail();
    _loadSavedLocation();
  }

  @override
  void didUpdateWidget(covariant MeasurementScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.initial, widget.initial)) {
      setState(() => _rows = List<Measurement>.from(widget.initial));
    }
    if (oldWidget.meta.name != widget.meta.name) {
      _titleCtrl.text = widget.meta.name;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  // ---------- helpers ----------
  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _logError(Object error, [StackTrace? st]) {
    debugPrint('MeasurementScreen error: $error');
    if (st != null) debugPrint(st.toString());
  }

  Future<void> _withBusy(Future<void> Function() op) async {
    if (!mounted) return op();
    setState(() => _isLoading = true);
    try {
      await op();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------- Prefs ----------
  Future<void> _loadDefaultEmail() async {
    final sp = await _sp;
    if (!mounted) return;
    setState(() => _defaultEmail = sp.getString(_kDefaultEmailKey));
  }

  Future<void> _saveDefaultEmail(String? email) async {
    final sp = await _sp;
    if (email == null || email.trim().isEmpty) {
      await sp.remove(_kDefaultEmailKey);
      if (!mounted) return;
      setState(() => _defaultEmail = null);
    } else {
      final v = email.trim();
      await sp.setString(_kDefaultEmailKey, v);
      if (!mounted) return;
      setState(() => _defaultEmail = v);
    }
  }

  // ---------- Title ----------
  Future<void> _saveTitle() async {
    final v = _titleCtrl.text.trim();
    if (v.isNotEmpty && v != widget.meta.name) {
      widget.onTitleChanged?.call(v);
    }
    if (!mounted) return;
    setState(() => _editingTitle = false);
    HapticFeedback.selectionClick();
  }

  // ---------- Location ----------
  String get _latKey => 'sheet_${widget.meta.id}_lat';
  String get _lngKey => 'sheet_${widget.meta.id}_lng';

  Future<void> _loadSavedLocation() async {
    final sp = await _sp;
    if (!mounted) return;
    setState(() {
      _lat = sp.getDouble(_latKey);
      _lng = sp.getDouble(_lngKey);
    });
  }

  Future<void> _saveLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _snack('Activá el GPS para guardar la ubicación.');
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _snack('Sin permisos de ubicación.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final sp = await _sp;
      await sp.setDouble(_latKey, pos.latitude);
      await sp.setDouble(_lngKey, pos.longitude);
      if (!mounted) return;
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
      _snack('Ubicación guardada.');
    } catch (e, st) {
      _logError(e, st);
      _snack('No se pudo obtener la ubicación.');
    }
  }

  Future<void> _openMapsFor({double? lat, double? lng}) async {
    final dLat = lat, dLng = lng;
    if (dLat == null || dLng == null) return;
    final uri = Uri.parse(_mapsUrl(dLat, dLng));
    try {
      if (await canLaunchUrl(uri)) {
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!ok) _snack('No se pudo abrir la app de mapas.');
      } else {
        _snack('No se pudo abrir la app de mapas.');
      }
    } catch (e, st) {
      _logError(e, st);
      _snack('No se pudo abrir la app de mapas.');
    }
  }

  String _mapsUrl(double lat, double lng) =>
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng';

  // ---------- XLSX / Share ----------
  String _safeFileName(String name) {
    final cleaned = name.trim().isEmpty ? 'planilla' : name.trim();
    return cleaned
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\- ]'), '_')
        .replaceAll(' ', '_');
  }

  Future<List<int>> _buildXlsx(List<Measurement> data) async {
    final book = xlsio.Workbook();
    final sheet = book.worksheets[0];
    sheet.name = 'Datos';

    // Headers
    sheet.getRangeByIndex(1, _cPro).setText('Progresiva');
    sheet.getRangeByIndex(1, _cOhm1).setText('1 m Ω');
    sheet.getRangeByIndex(1, _cOhm3).setText('3 m Ω');
    sheet.getRangeByIndex(1, _cObs).setText('Obs');
    sheet.getRangeByIndex(1, _cDate).setText('Fecha');
    sheet.getRangeByIndex(1, _cLat).setText('Latitud');
    sheet.getRangeByIndex(1, _cLng).setText('Longitud');
    sheet.getRangeByIndex(1, _cMaps).setText('Maps');
    sheet.getRangeByIndex(1, _cPro, 1, _cMaps).cellStyle.bold = true;

    final gLat = _lat, gLng = _lng;
    var r = 2;
    for (final m in data) {
      sheet.getRangeByIndex(r, _cPro).setText(m.progresiva);
      sheet.getRangeByIndex(r, _cOhm1).setNumber(m.ohm1m);
      sheet.getRangeByIndex(r, _cOhm3).setNumber(m.ohm3m);
      sheet.getRangeByIndex(r, _cObs).setText(m.observations);

      sheet.getRangeByIndex(r, _cDate).setDateTime(m.date);
      sheet.getRangeByIndex(r, _cDate).numberFormat = 'dd/mm/yyyy';

      final rowLat = m.latitude ?? gLat;
      final rowLng = m.longitude ?? gLng;
      if (rowLat != null && rowLng != null) {
        sheet.getRangeByIndex(r, _cLat).setNumber(rowLat);
        sheet.getRangeByIndex(r, _cLng).setNumber(rowLng);
        sheet.getRangeByIndex(r, _cLat, r, _cLng).numberFormat = '0.000000';
        sheet.getRangeByIndex(r, _cMaps).setFormula(
              'HYPERLINK("${_mapsUrl(rowLat, rowLng)}","Ver")',
            );
      }
      r++;
    }

    sheet.getRangeByIndex(1, _cObs, r - 1, _cObs).cellStyle.wrapText = true;

    for (var c = _cPro; c <= _cMaps; c++) {
      sheet.autoFitColumn(c);
    }
    for (var i = 1; i < r; i++) {
      sheet.autoFitRow(i);
    }

    final bytes = book.saveAsStream(); // List<int>
    book.dispose();
    return bytes;
  }

  Future<File> _writeTempXlsx(List<int> bytes) async {
    final dir = await getTemporaryDirectory();
    final base = _safeFileName(widget.meta.name);
    final ts = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('.', '')
        .replaceAll('-', '');
    final file = File('${dir.path}/gridnote_${base}_$ts.xlsx');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  bool _isEmailValid(String e) {
    final s = e.trim();
    final re = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');
    return re.hasMatch(s);
  }

  String _buildEmailBody(List<Measurement> rows) {
    final b = StringBuffer();
    b.writeln('Adjunto XLSX generado con Gridnote para "${widget.meta.name}".');

    final lat = _lat, lng = _lng;
    if (lat != null && lng != null) {
      b.writeln('');
      b.writeln('Ubicación general:');
      b.writeln(_mapsUrl(lat, lng));
    }

    final withCoords =
        rows.where((m) => (m.latitude != null && m.longitude != null)).toList();
    if (withCoords.isNotEmpty) {
      b.writeln('');
      b.writeln('Enlaces por fila:');
      for (final m in withCoords.take(10)) {
        final url = _mapsUrl(m.latitude!, m.longitude!);
        final prog = (m.progresiva.isEmpty) ? '-' : m.progresiva;
        b.writeln('• $prog → $url');
      }
      if (withCoords.length > 10) {
        b.writeln('• (+${withCoords.length - 10} más)');
      }
    }
    return b.toString();
  }

  Future<void> _shareViaEmail({required List<Measurement> rows}) async {
    final email = await _askForEmail(initial: _defaultEmail);
    if (email == null) return;

    final trimmed = email.trim();
    if (!_isEmailValid(trimmed)) {
      _snack('Email inválido. Revisá el destinatario.');
      return;
    }

    final bytes = await _buildXlsx(rows);
    final file = await _writeTempXlsx(bytes);
    final bodyText = _buildEmailBody(rows);

    final mail = Email(
      recipients: [trimmed],
      subject: 'Gridnote – ${widget.meta.name}',
      body: bodyText,
      attachmentPaths: [file.path],
      isHTML: false,
    );

    try {
      await FlutterEmailSender.send(mail);
      _snack('Se abrió tu app de correo. Tocá “Enviar”.');
      return;
    } catch (e, st) {
      _logError(e, st);
      final mailto = Uri(
        scheme: 'mailto',
        path: trimmed,
        queryParameters: <String, String>{
          'subject': 'Gridnote – ${widget.meta.name}',
          'body': bodyText,
        },
      );
      try {
        if (await canLaunchUrl(mailto)) {
          final ok =
              await launchUrl(mailto, mode: LaunchMode.externalApplication);
          if (ok) return;
        }
      } catch (e2, st2) {
        _logError(e2, st2);
      }
      await Share.shareXFiles(
        [
          XFile(
            file.path,
            mimeType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ),
        ],
        subject: 'Gridnote – ${widget.meta.name}',
        text: bodyText,
      );
    }
  }

  Future<String?> _askForEmail({String? initial}) async {
    final ctl = TextEditingController(text: initial ?? '');
    bool saveAsDefault = false;

    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: StatefulBuilder(
            builder: (context, setSB) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ListTile(
                    title: Text('Enviar por correo'),
                    subtitle: Text('Podés guardar el email como frecuente'),
                  ),
                  TextField(
                    controller: ctl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email destino',
                      prefixIcon: Icon(Icons.alternate_email),
                    ),
                  ),
                  const SizedBox(height: 4),
                  CheckboxListTile(
                    value: saveAsDefault,
                    onChanged: (v) => setSB(() => saveAsDefault = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('Guardar como frecuente'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx, null);
                          _saveDefaultEmail(null);
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Borrar guardado'),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: () {
                          final v = ctl.text.trim();
                          if (saveAsDefault && v.isNotEmpty) {
                            _saveDefaultEmail(v);
                          }
                          Navigator.pop(ctx, v.isEmpty ? null : v);
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('Aceptar'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    return result;
  }

  ButtonStyle _chipStyle(Color surface) => OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        visualDensity: VisualDensity.compact,
        shape: const StadiumBorder(),
        backgroundColor: surface,
      );

  Widget _buildHeader(GridnoteTheme t, GridnoteTableStyle table) {
    final hasLoc = _lat != null && _lng != null;

    final locBtn = OutlinedButton.icon(
      style: _chipStyle(t.surface),
      onPressed: hasLoc
          ? () => _openMapsFor(lat: _lat, lng: _lng)
          : () => _withBusy(_saveLocation),
      icon: Icon(hasLoc ? Icons.check_circle : Icons.place_outlined),
      label: Text(hasLoc ? 'Ubicación guardada' : 'Guardar ubicación'),
    );

    final titleWidget = _editingTitle
        ? TextField(
            controller: _titleCtrl,
            autofocus: true,
            textInputAction: TextInputAction.done,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            decoration: const InputDecoration(
                isCollapsed: true, border: InputBorder.none),
            onSubmitted: (_) => _saveTitle(),
            onTapOutside: (_) => _saveTitle(),
          )
        : GestureDetector(
            onTap: () => setState(() => _editingTitle = true),
            child: Text(
              widget.meta.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
          );

    final shareBtn = FilledButton.tonalIcon(
      onPressed: () =>
          _withBusy(() => _shareViaEmail(rows: _gridCtrl.snapshot())),
      icon: const Icon(Icons.ios_share_outlined),
      label: const Text('Compartir'),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: table.gridLine),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: LayoutBuilder(
            builder: (ctx, c) {
              final narrow = c.maxWidth < 520;
              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: titleWidget),
                      const SizedBox(width: 8),
                      shareBtn,
                    ]),
                    const SizedBox(height: 8),
                    locBtn,
                  ],
                );
              } else {
                return Row(
                  children: [
                    Expanded(child: titleWidget),
                    const SizedBox(width: 8),
                    Flexible(fit: FlexFit.loose, child: locBtn),
                    const SizedBox(width: 8),
                    shareBtn,
                  ],
                );
              }
            },
          ),
        ),
      ),
    );
  }

  // ---------- Row CRUD ----------
  void _onUpdateRow(Measurement updated) {
    setState(() {
      final next = List<Measurement>.from(_rows);
      int idx = next.indexWhere((e) => e.id != null && e.id == updated.id);
      if (idx < 0) {
        idx = next.indexWhere(
          (e) =>
              e.id == null &&
              e.progresiva == updated.progresiva &&
              e.date == updated.date,
        );
      }
      if (idx >= 0) next[idx] = updated;
      _rows = next;
    });
  }

  void _onDeleteRow(Measurement m) {
    setState(() {
      final next = List<Measurement>.from(_rows);
      next.removeWhere(
        (e) =>
            (e.id != null && e.id == m.id) ||
            (e.id == null && e.progresiva == m.progresiva && e.date == m.date),
      );
      _rows = next;
    });
    _snack('Fila eliminada.');
  }

  void _onDuplicateRow(Measurement m) {
    setState(() {
      final next = List<Measurement>.from(_rows);
      next.add(m.copyWith(id: null));
      _rows = next;
    });
    _snack('Fila duplicada.');
  }

  // ---------- Build ----------
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.themeController,
      builder: (_, __) {
        final t = widget.themeController.theme;
        final table = GridnoteTableStyle.from(t);

        return Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: t.scaffold,
          appBar: AppBar(
            title: Text('Planilla: ${widget.meta.id}',
                overflow: TextOverflow.ellipsis),
            actions: [
              PopupMenuButton<String>(
                tooltip: 'Compartir / Exportar',
                onSelected: (v) async {
                  switch (v) {
                    case 'send_visible':
                      await _withBusy(
                          () => _shareViaEmail(rows: _gridCtrl.snapshot()));
                      break;
                    case 'send_all':
                      await _withBusy(() =>
                          _shareViaEmail(rows: List<Measurement>.from(_rows)));
                      break;
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'send_visible',
                    child: ListTile(
                      leading: Icon(Icons.filter_alt_outlined),
                      title: Text('Enviar XLSX (solo visible)'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'send_all',
                    child: ListTile(
                      leading: Icon(Icons.grid_on_outlined),
                      title: Text('Enviar XLSX (todas las filas)'),
                    ),
                  ),
                ],
                icon: const Icon(Icons.ios_share_outlined),
              ),
            ],
          ),
          body: GestureDetector(
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: Stack(
              children: [
                Container(
                  color: table.cellBg,
                  child: Column(
                    children: [
                      _buildHeader(t, table),
                      Expanded(
                        child: MeasurementDataGrid(
                          meta: widget.meta,
                          initial: _rows,
                          themeController: widget.themeController,
                          controller: _gridCtrl,
                          autoWidth: true,
                          enablePager: true,
                          onOpenMaps: (m) => _openMapsFor(
                            lat: m.latitude ?? _lat,
                            lng: m.longitude ?? _lng,
                          ),
                          onUpdateRow: _onUpdateRow,
                          onDeleteRow: _onDeleteRow,
                          onDuplicateRow: _onDuplicateRow,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isLoading)
                  Positioned.fill(
                    child: AbsorbPointer(
                      child: Container(
                        color: Colors.black.withOpacity(0.25),
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
