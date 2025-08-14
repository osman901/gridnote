// lib/screens/sheet_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // HapticFeedback, Clipboard
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

import '../models/measurement.dart';
import '../models/sheet_meta.dart';
import '../theme/gridnote_theme.dart';
import '../widgets/measurement_datagrid.dart';

class SheetScreen extends StatefulWidget {
  const SheetScreen({
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
  State<SheetScreen> createState() => _SheetScreenState();
}

class _SheetScreenState extends State<SheetScreen> {
  static const _kDefaultEmailKey = 'default_email';

  bool _editingTitle = false;
  late final TextEditingController _titleCtrl;

  final Future<SharedPreferences> _sp = SharedPreferences.getInstance();
  String? _defaultEmail;

  double? _lat;
  double? _lng;

  late List<Measurement> _currentMeasurements;
  late String _title;

  bool _isBusy = false;

  // IDs locales negativos
  int _nextTempId = -1;

  final _gridCtrl = MeasurementGridController();

  @override
  void initState() {
    super.initState();
    _title = widget.meta.name;
    _titleCtrl = TextEditingController(text: _title);
    _currentMeasurements = List<Measurement>.from(widget.initial);
    _ensureLocalIds();
    _loadDefaultEmail();
    _loadSavedLocation();
    _cleanupOldTempXlsx(); // limpieza silenciosa de temporales viejos
  }

  @override
  void didUpdateWidget(covariant SheetScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initial != oldWidget.initial) {
      _currentMeasurements = List<Measurement>.from(widget.initial);
      _ensureLocalIds();
      // setState() no es necesario aquí: build se ejecuta tras didUpdateWidget.
    }
    if (widget.meta.name != oldWidget.meta.name) {
      setState(() {
        _title = widget.meta.name;
        _titleCtrl.text = _title;
      });
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  //──────────────────────────────── Helpers generales
  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _logError(Object e, [StackTrace? st]) {
    debugPrint('SheetScreen error: $e');
    if (st != null) debugPrint(st.toString());
  }

  //──────────────────────────────── Prefs email
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

  //──────────────────────────────── Título
  Future<void> _saveTitle() async {
    final v = _titleCtrl.text.trim();
    var changed = false;
    if (v.isNotEmpty && v != _title) {
      widget.onTitleChanged?.call(v);
      setState(() => _title = v);
      changed = true;
    }
    if (!mounted) return;
    setState(() => _editingTitle = false);
    HapticFeedback.selectionClick();
    if (changed) _snack('Título guardado.');
  }

  //──────────────────────────────── Ubicación
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
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        _snack('Activá el GPS para guardar la ubicación.');
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
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
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _showLocationSheet() async {
    final lat = _lat, lng = _lng;
    if (lat == null || lng == null) {
      await _saveLocation();
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text('Ubicación guardada'),
                subtitle: Text('Revisá o actualizá la ubicación de la planilla'),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text('Lat: ${lat.toStringAsFixed(6)}\nLng: ${lng.toStringAsFixed(6)}'),
                  ),
                  IconButton(
                    tooltip: 'Copiar',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: '$lat,$lng'));
                      Navigator.pop(ctx);
                      _snack('Coordenadas copiadas');
                    },
                    icon: const Icon(Icons.copy_all_outlined),
                  )
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _openMapsFor(lat: lat, lng: lng);
                    },
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Ver en mapa'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _saveLocation();
                    },
                    icon: const Icon(Icons.my_location_outlined),
                    label: const Text('Actualizar ubicación'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openMapsFor({double? lat, double? lng}) async {
    if (lat == null || lng == null) return;
    final uri = Uri.parse(_mapsUrl(lat, lng));
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

  String _mapsUrl(double lat, double lng) => 'https://www.google.com/maps?q=$lat,$lng';

  //──────────────────────────────── XLSX / Share
  String _safeFileName(String name) {
    final cleaned = name.trim().isEmpty ? 'planilla' : name.trim();
    return cleaned.replaceAll(RegExp(r'[^a-zA-Z0-9 _-]'), '_').replaceAll(' ', '_');
  }

  Future<List<int>> _buildXlsx(List<Measurement> data) async {
    final book = xlsio.Workbook();
    final sheet = book.worksheets[0];
    sheet.name = 'Datos';

    sheet.getRangeByIndex(1, 1).setText('Progresiva');
    sheet.getRangeByIndex(1, 2).setText('1 m Ω');
    sheet.getRangeByIndex(1, 3).setText('3 m Ω');
    sheet.getRangeByIndex(1, 4).setText('Obs');
    sheet.getRangeByIndex(1, 5).setText('Fecha');
    sheet.getRangeByIndex(1, 6).setText('Latitud');
    sheet.getRangeByIndex(1, 7).setText('Longitud');
    sheet.getRangeByIndex(1, 8).setText('Maps');
    sheet.getRangeByIndex(1, 1, 1, 8).cellStyle.bold = true;

    final gLat = _lat, gLng = _lng;
    var r = 2;
    for (final m in data) {
      sheet.getRangeByIndex(r, 1).setText(m.progresiva);
      final v1 = m.ohm1m;
      final v3 = m.ohm3m;
      if (v1 != null) sheet.getRangeByIndex(r, 2).setNumber(v1);
      if (v3 != null) sheet.getRangeByIndex(r, 3).setNumber(v3);
      sheet.getRangeByIndex(r, 4).setText(m.observations);
      sheet.getRangeByIndex(r, 5).setDateTime(m.date);
      sheet.getRangeByIndex(r, 5).numberFormat = 'dd/mm/yyyy';

      final rowLat = m.latitude ?? gLat;
      final rowLng = m.longitude ?? gLng;
      if (rowLat != null && rowLng != null) {
        sheet.getRangeByIndex(r, 6).setNumber(rowLat);
        sheet.getRangeByIndex(r, 7).setNumber(rowLng);
        sheet.getRangeByIndex(r, 6, r, 7).numberFormat = '0.000000';
        sheet.getRangeByIndex(r, 8).setFormula('HYPERLINK("${_mapsUrl(rowLat, rowLng)}","Ver")');
      }
      r++;
    }

    sheet.getRangeByIndex(1, 4, r - 1, 4).cellStyle.wrapText = true;

    for (var c = 1; c <= 8; c++) {
      sheet.autoFitColumn(c);
    }
    for (var i = 1; i < r; i++) {
      sheet.autoFitRow(i);
    }

    final bytes = book.saveAsStream();
    book.dispose();
    return bytes;
  }

  Future<File> _writeTempXlsx(List<int> bytes) async {
    final dir = await getTemporaryDirectory();
    final base = _safeFileName(_title);
    final ts = DateTime.now().toIso8601String().replaceAll(':', '').replaceAll('.', '').replaceAll('-', '');
    final file = File('${dir.path}/gridnote_${base}_$ts.xlsx');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> _cleanupOldTempXlsx({Duration maxAge = const Duration(hours: 12)}) async {
    try {
      final dir = await getTemporaryDirectory();
      final now = DateTime.now();
      final entities = await dir.list().toList();
      for (final e in entities) {
        if (e is! File) continue;
        final p = e.path;
        if (!p.endsWith('.xlsx') || !p.contains('gridnote_')) continue;
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

  bool _isEmailValid(String e) {
    final s = e.trim();
    final re = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');
    return re.hasMatch(s);
  }

  String _buildEmailBody(List<Measurement> rows) {
    final b = StringBuffer();
    b.writeln('Adjunto XLSX generado con Gridnote para "$_title".');
    final lat = _lat, lng = _lng;
    if (lat != null && lng != null) {
      b.writeln('');
      b.writeln('Ubicación general:');
      b.writeln(_mapsUrl(lat, lng));
    }
    final withCoords = rows.where((m) => m.latitude != null && m.longitude != null).toList();
    if (withCoords.isNotEmpty) {
      b.writeln('');
      b.writeln('Enlaces por fila:');
      for (final m in withCoords.take(10)) {
        final ml = m.latitude!;
        final mg = m.longitude!;
        final url = _mapsUrl(ml, mg);
        final prog = (m.progresiva.isEmpty) ? '-' : m.progresiva;
        b.writeln('• $prog → $url');
      }
      if (withCoords.length > 10) b.writeln('• (+${withCoords.length - 10} más)');
    }
    return b.toString();
  }

  Future<void> _shareViaEmail({required List<Measurement> rows}) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
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
        subject: 'Gridnote – $_title',
        body: bodyText,
        attachmentPaths: [file.path],
        isHTML: false,
      );

      try {
        await FlutterEmailSender.send(mail);
        _snack('Se abrió tu app de correo. Tocá “Enviar”.');
      } catch (e, st) {
        _logError(e, st);
        final mailto = Uri(
          scheme: 'mailto',
          path: trimmed,
          queryParameters: <String, String>{'subject': 'Gridnote – $_title', 'body': bodyText},
        );
        try {
          if (await canLaunchUrl(mailto)) {
            final ok = await launchUrl(mailto, mode: LaunchMode.externalApplication);
            if (ok) return;
          }
        } catch (e2, st2) {
          _logError(e2, st2);
        }
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
          subject: 'Gridnote – $_title',
          text: bodyText,
        );
      }

      // No borrar aquí. Limpieza diferida: _cleanupOldTempXlsx().

    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<String?> _askForEmail({String? initial}) async {
    final ctl = TextEditingController(text: initial ?? '');
    bool saveAsDefault = false;

    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        void submit() {
          final v = ctl.text.trim();
          if (saveAsDefault && v.isNotEmpty) _saveDefaultEmail(v);
          Navigator.pop(ctx, v.isEmpty ? null : v);
        }

        final viewInsets = MediaQuery.of(ctx).viewInsets;
        return SafeArea(
          child: AnimatedPadding(
            padding: EdgeInsets.only(bottom: viewInsets.bottom),
            duration: const Duration(milliseconds: 150),
            curve: Curves.decelerate,
            child: SingleChildScrollView(
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
                          autofocus: true,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => submit(),
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
                        OverflowBar(
                          alignment: MainAxisAlignment.spaceBetween,
                          overflowAlignment: OverflowBarAlignment.end,
                          spacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx, null);
                                _saveDefaultEmail(null);
                              },
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Borrar guardado'),
                            ),
                            FilledButton.icon(
                              onPressed: submit,
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
          ),
        );
      },
    );
    return result;
  }

  //──────────────────────────────── Estilos y header
  ButtonStyle _chipStyle(Color surface) => OutlinedButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    visualDensity: VisualDensity.compact,
    shape: const StadiumBorder(),
    backgroundColor: surface,
  );

  Widget _shareMenuButton({required bool compact}) {
    final Widget child = compact
        ? const Icon(Icons.ios_share_outlined)
        : Row(
      mainAxisSize: MainAxisSize.min,
      children: const [
        Icon(Icons.ios_share_outlined),
        SizedBox(width: 8),
        Text('Compartir'),
      ],
    );

    final Widget button = IgnorePointer(
      ignoring: true,
      child: compact
          ? IconButton.filledTonal(onPressed: () {}, icon: child)
          : FilledButton.tonal(onPressed: () {}, child: child),
    );

    return PopupMenuButton<String>(
      tooltip: 'Compartir / Exportar',
      enabled: !_isBusy,
      onSelected: (v) async {
        switch (v) {
          case 'send_visible':
            await _shareViaEmail(rows: _gridCtrl.snapshot());
            break;
          case 'send_all':
            await _shareViaEmail(rows: _currentMeasurements);
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
      child: button,
    );
  }

  Widget _buildHeader(GridnoteTheme t, GridnoteTableStyle table) {
    final hasLoc = _lat != null && _lng != null;

    final locBtn = OutlinedButton.icon(
      style: _chipStyle(t.surface),
      onPressed: _isBusy ? null : (hasLoc ? _showLocationSheet : _saveLocation),
      icon: _isBusy
          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(hasLoc ? Icons.check_circle : Icons.place_outlined),
      label: Text(hasLoc ? 'Ubicación guardada' : 'Guardar ubicación'),
    );

    final titleWidget = _editingTitle
        ? TextField(
      controller: _titleCtrl,
      autofocus: true,
      textInputAction: TextInputAction.done,
      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      decoration: const InputDecoration(isCollapsed: true, border: InputBorder.none),
      onSubmitted: (_) => _saveTitle(),
      onTapOutside: (_) => _saveTitle(),
    )
        : GestureDetector(
      onTap: () => setState(() => _editingTitle = true),
      child: Text(
        _title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      ),
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
                      _shareMenuButton(compact: true),
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
                    _shareMenuButton(compact: false),
                  ],
                );
              }
            },
          ),
        ),
      ),
    );
  }

  //──────────────────────────────── Filas con UID local
  int _genTempId() => _nextTempId--;

  Measurement _withLocalId(Measurement m) {
    return (m.id != null) ? m : m.copyWith(id: _genTempId());
  }

  void _ensureLocalIds() {
    // Asigna IDs locales a los que no tienen.
    _currentMeasurements = _currentMeasurements.map(_withLocalId).toList(growable: true);
  }

  int _indexOfById(Measurement m) {
    final id = m.id;
    if (id == null) return -1;
    return _currentMeasurements.indexWhere((e) => e.id == id);
  }

  // Fallback por si llega un objeto sin id
  int _indexOfByFields(Measurement m) {
    return _currentMeasurements.indexWhere((e) =>
    e.progresiva == m.progresiva &&
        e.date == m.date &&
        (e.latitude ?? 0.0) == (m.latitude ?? 0.0) &&
        (e.longitude ?? 0.0) == (m.longitude ?? 0.0));
  }

  int _indexOfMeasurement(Measurement m) {
    final byId = _indexOfById(m);
    if (byId >= 0) return byId;
    return _indexOfByFields(m);
  }

  void _onUpdateRow(Measurement updated) {
    setState(() {
      final i = _indexOfMeasurement(updated);
      if (i >= 0) {
        // Si el editor devuelve un objeto sin ID, restauramos el ID previo
        // (local negativo o de BD) para no perder la referencia de la fila.
        final oldId = _currentMeasurements[i].id;
        final next = (updated.id != null || oldId == null)
            ? updated
            : updated.copyWith(id: oldId);
        _currentMeasurements = List.of(_currentMeasurements)..[i] = next;
      }
    });
  }

  void _onDeleteRow(Measurement m) {
    setState(() {
      final i = _indexOfMeasurement(m);
      if (i >= 0) {
        _currentMeasurements = List.of(_currentMeasurements)..removeAt(i);
      } else {
        _currentMeasurements = _currentMeasurements.where((e) => e != m).toList();
      }
    });
  }

  void _onDuplicateRow(Measurement m) {
    setState(() {
      final dup = m.copyWith(id: _genTempId());
      _currentMeasurements = List.of(_currentMeasurements)..add(dup);
    });
  }

  //──────────────────────────────── Build
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
            title: Text('Planilla: ${widget.meta.id}', overflow: TextOverflow.ellipsis),
            bottom: _isBusy
                ? const PreferredSize(
              preferredSize: Size.fromHeight(2),
              child: LinearProgressIndicator(minHeight: 2),
            )
                : null,
          ),
          body: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: Container(
              color: table.cellBg,
              child: Column(
                children: [
                  _buildHeader(t, table),
                  Expanded(
                    child: MeasurementDataGrid(
                      meta: widget.meta,
                      initial: _currentMeasurements,
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
          ),
        );
      },
    );
  }
}
