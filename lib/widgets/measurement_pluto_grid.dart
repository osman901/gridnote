// lib/widgets/measurement_pluto_grid.dart
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../models/measurement.dart';
import '../models/sheet_meta.dart';
import '../services/photo_store.dart';
import '../services/location_service.dart';
import '../theme/gridnote_theme.dart';

// IA / Analytics
import '../services/smart_assistant.dart';
import '../services/elite_assistant.dart';
import '../services/usage_analytics.dart';

// Columns base (progresiva, ohm1m, ohm3m, observations, date)
import 'measurement_columns.dart';

typedef RowsChanged = void Function(List<Measurement> rows);
typedef OpenMaps = void Function(Measurement m);

// columnas internas sólo para UI
const String _kMapsCol = 'maps';
const String _kPhotosCol = 'photos';

class MeasurementGridController extends ChangeNotifier {
  _MeasurementPlutoGridState? _s;
  void _attach(_MeasurementPlutoGridState s) => _s = s;
  void _detach(_MeasurementPlutoGridState s) {
    if (_s == s) _s = null;
  }

  List<Measurement> snapshot() =>
      List<Measurement>.from(_s?._rows ?? const <Measurement>[]);

  void replaceRows(List<Measurement> rows) => _s?._replaceRows(rows);
  Future<void> setLocationOnSelection(double lat, double lng) async =>
      _s?._setLocationSelected(lat, lng);
  Future<void> addPhotoOnSelection() async => _s?._addPhotoSelected();
  Future<void> colorCellSelected(Color color) async =>
      _s?._colorCellSelected(color);
  void setFontFamily(String font) => _s?._setFont(font);

  // IA / helpers
  Future<void> fillTodayOnSelection() async => _s?._fillTodayOnSelection();
  Future<void> autoNumberProgresiva({String prefix = '', int startAt = 1}) async =>
      _s?._autoNumberProgresiva(prefix: prefix, startAt: startAt);
  Future<void> summarizeSelectionToObs() async =>
      _s?._summarizeSelectionToObs();
  Future<void> highlightOhmOutliers({String field = MeasurementColumn.ohm1m}) async =>
      _s?._highlightOhmOutliers(field: field);
}

class MeasurementDataGrid extends StatefulWidget {
  const MeasurementDataGrid({
    super.key,
    required this.meta,
    required this.initial,
    required this.themeController,
    required this.controller,
    required this.onChanged,
    required this.headerTitles,
    required this.onEditHeader,
    this.onOpenMaps,
    this.autoWidth = true,
    this.filterQuery,
    this.aiEnabled = true,
    this.showPhotoRail = true,
  });

  final SheetMeta meta;
  final List<Measurement> initial;
  final GridnoteThemeController themeController;
  final MeasurementGridController controller;
  final RowsChanged onChanged;
  final Map<String, String> headerTitles;
  final void Function(String columnName) onEditHeader;
  final OpenMaps? onOpenMaps;
  final bool autoWidth;
  final String? filterQuery;
  final bool aiEnabled;
  final bool showPhotoRail;

  @override
  State<MeasurementDataGrid> createState() => _MeasurementPlutoGridState();
}

class _MeasurementPlutoGridState extends State<MeasurementDataGrid> {
  // ==== Estado base ====
  late List<Measurement> _rows;
  late List<PlutoColumn> _columns;
  late List<PlutoRow> _plutoRows;
  PlutoGridStateManager? _sm;
  String _fontFamily = 'SF Pro Text'; // look iOS

  // Debounce/throttle
  Timer? _emitDebounce;
  void _emitChangedDebounced() {
    _emitDebounce?.cancel();
    _emitDebounce = Timer(const Duration(milliseconds: 60), () {
      if (!mounted) return;
      widget.onChanged(List<Measurement>.from(_rows));
    });
  }

  Timer? _railDebounce;
  void _scheduleRefreshRail() {
    _railDebounce?.cancel();
    _railDebounce = Timer(const Duration(milliseconds: 80), () {
      if (mounted) _refreshRail();
    });
  }

  // colores por celda
  final Map<int, Map<String, Color>> _cellBg = {};

  // fotos por fila
  final Map<int, int> _photoCount = {};
  final Map<int, File?> _photoThumb = {};
  final Set<int> _photoPending = {};
  Timer? _photoDebounce;

  // Photo Rail
  int _railRowIndex = -1;
  List<File> _railFiles = const [];
  bool _railLoading = false;
  bool _railGeoTag = true;

  // IA
  GridnoteAssistant? _assistant;
  bool _applyingSuggestion = false;

  // ==== Helpers UI ====
  ScaffoldMessengerState get _messenger => ScaffoldMessenger.of(context);

  // Imagen con cache liviano (thumbs)
  Widget _imgThumb(File f, {BoxFit fit = BoxFit.cover}) => Image.file(
    f,
    fit: fit,
    cacheWidth: 384,
    cacheHeight: 384,
    filterQuality: FilterQuality.low,
    errorBuilder: (_, __, ___) => const ColoredBox(
      color: Color(0x22000000),
      child: Center(child: Icon(Icons.broken_image_outlined, size: 18)),
    ),
  );

  @override
  void initState() {
    super.initState();
    _rows = List<Measurement>.from(widget.initial);
    _columns = _buildColumns();
    _plutoRows = _buildPlutoRows(_rows);
    widget.controller._attach(this);
    unawaited(_initAssistant());
  }

  Future<void> _initAssistant() async {
    try {
      _assistant = await EliteAssistant.forSheet(widget.meta.id);
    } catch (_) {
      _assistant = null;
    }
  }

  @override
  void didUpdateWidget(covariant MeasurementDataGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initial != oldWidget.initial) {
      _replaceRows(widget.initial, notify: false);
    }
    if (widget.filterQuery != oldWidget.filterQuery) {
      _applyFilter(widget.filterQuery ?? '');
    }
  }

  @override
  void dispose() {
    _photoDebounce?.cancel();
    _emitDebounce?.cancel();
    _railDebounce?.cancel();
    widget.controller._detach(this);
    super.dispose();
  }

  // ===================== Columnas =====================
  List<PlutoColumn> _buildColumns() {
    TextStyle headerStyle() => TextStyle(
      fontFamily: _fontFamily,
      fontWeight: FontWeight.w700,
      fontSize: 13,
      color: widget.themeController.theme.text,
    );

    // encabezado editable
    Widget header(String field, String fallback) {
      final title = widget.headerTitles[field] ?? fallback;
      return GestureDetector(
        onLongPress: () => widget.onEditHeader(field),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: headerStyle(),
          ),
        ),
      );
    }

    // renderizador genérico con color por celda
    Widget Function(PlutoColumnRendererContext ctx) textCellRenderer(
        [TextAlign align = TextAlign.left]) {
      return (ctx) {
        final idx = ctx.rowIdx;
        final field = ctx.column.field;
        final bg = _cellBg[idx]?[field];
        final String txt = '${ctx.cell.value ?? ''}';
        return Container(
          color: bg,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          alignment:
          align == TextAlign.right ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            txt.isEmpty ? '—' : txt,
            maxLines: 10,
            overflow: TextOverflow.visible,
            style: TextStyle(
              fontFamily: _fontFamily,
              fontSize: 14,
              color: widget.themeController.theme.text,
            ),
          ),
        );
      };
    }

    return <PlutoColumn>[
      PlutoColumn(
        title: 'Progresiva',
        field: MeasurementColumn.progresiva,
        type: PlutoColumnType.text(),
        enableEditingMode: true,
        renderer: textCellRenderer(),
        titleSpan: TextSpan(
          children: [
            WidgetSpan(child: header(MeasurementColumn.progresiva, 'Progresiva'))
          ],
        ),
        minWidth: 140,
        frozen: PlutoColumnFrozen.start,
      ),
      PlutoColumn(
        title: '1m (Ω)',
        field: MeasurementColumn.ohm1m,
        type: PlutoColumnType.number(allowFirstDot: false, format: '#.########'),
        enableEditingMode: true,
        renderer: textCellRenderer(TextAlign.right),
        titleSpan:
        TextSpan(children: [WidgetSpan(child: header(MeasurementColumn.ohm1m, '1m (Ω)'))]),
        width: 110,
      ),
      PlutoColumn(
        title: '3m (Ω)',
        field: MeasurementColumn.ohm3m,
        type: PlutoColumnType.number(allowFirstDot: false, format: '#.########'),
        enableEditingMode: true,
        renderer: textCellRenderer(TextAlign.right),
        titleSpan:
        TextSpan(children: [WidgetSpan(child: header(MeasurementColumn.ohm3m, '3m (Ω)'))]),
        width: 110,
      ),
      PlutoColumn(
        title: 'Obs',
        field: MeasurementColumn.observations,
        type: PlutoColumnType.text(),
        enableEditingMode: true,
        renderer: textCellRenderer(),
        titleSpan:
        TextSpan(children: [WidgetSpan(child: header(MeasurementColumn.observations, 'Obs'))]),
        minWidth: 220,
      ),
      PlutoColumn(
        title: 'Fecha',
        field: MeasurementColumn.date,
        type: PlutoColumnType.date(),
        enableEditingMode: true,
        renderer: (ctx) {
          final idx = ctx.rowIdx;
          final field = ctx.column.field;
          final bg = _cellBg[idx]?[field];
          final DateTime? dt = ctx.cell.value is DateTime ? ctx.cell.value : null;
          final txt = (dt == null || dt == DateTime(0))
              ? '—'
              : '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
          return Container(
            color: bg,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            alignment: Alignment.centerLeft,
            child: Text(
              txt,
              style: TextStyle(
                fontFamily: _fontFamily,
                fontSize: 14,
                color: widget.themeController.theme.text,
              ),
            ),
          );
        },
        titleSpan: TextSpan(children: [WidgetSpan(child: header(MeasurementColumn.date, 'Fecha'))]),
        width: 130,
      ),
      // Maps
      PlutoColumn(
        title: 'Maps',
        field: _kMapsCol,
        type: PlutoColumnType.text(),
        enableEditingMode: false,
        renderer: (ctx) {
          final i = ctx.rowIdx;
          final m = (i >= 0 && i < _rows.length) ? _rows[i] : null;
          final has = m?.latitude != null && m?.longitude != null;
          return Center(
            child: Tooltip(
              message: has ? 'Abrir en Maps' : 'Sin ubicación',
              child: Semantics(
                label: 'Abrir ubicación',
                button: true,
                child: IconButton(
                  icon: const Icon(Icons.map_outlined, size: 20),
                  onPressed: has && widget.onOpenMaps != null
                      ? () => widget.onOpenMaps!(m!)
                      : null,
                  onLongPress: () async {
                    if (m?.latitude != null && m?.longitude != null) {
                      final url = Uri.parse(
                          'https://maps.google.com/?q=${m!.latitude},${m.longitude}');
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
                ),
              ),
            ),
          );
        },
        titleSpan: const TextSpan(text: ' '),
        width: 70,
      ),
      // Fotos
      PlutoColumn(
        title: 'Fotos',
        field: _kPhotosCol,
        type: PlutoColumnType.text(),
        enableEditingMode: false,
        renderer: (ctx) {
          final i = ctx.rowIdx;
          final n = _photoCount[i] ?? 0;
          final thumb = _photoThumb[i];

          Widget thumbView() => ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (thumb != null)
                  _imgThumb(thumb)
                else
                  const Center(child: Icon(Icons.photo_camera_outlined, size: 18)),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: 22,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x00000000), Color(0x33000000)],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .65),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.photo_camera_outlined,
                            size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                        Text('$n',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            )),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );

          return Center(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () async {
                if (i < 0 || i >= _rows.length) return;
                if ((_photoCount[i] ?? 0) > 0) {
                  await _openRowGallery(i);
                } else {
                  final rid = _rows[i].id ?? i;
                  final f =
                  await PhotoStore.addFromCamera(widget.meta.id, rid);
                  if (f != null) {
                    _refreshPhotoCountBatched(i);
                    if (i == _railRowIndex) await _refreshRail(forced: true);
                  }
                }
              },
              onLongPress: () async {
                if (i < 0 || i >= _rows.length) return;
                await _showPhotoCellMenu(i);
              },
              child: SizedBox(width: 84, height: 48, child: thumbView()),
            ),
          );
        },
        titleSpan: const TextSpan(text: ' '),
        width: 96,
      ),
    ];
  }

  // ===================== Filas =====================
  List<PlutoRow> _buildPlutoRows(List<Measurement> rows) {
    return List<PlutoRow>.generate(rows.length, (i) {
      final m = rows[i];
      return PlutoRow(cells: {
        MeasurementColumn.progresiva: PlutoCell(value: m.progresiva),
        MeasurementColumn.ohm1m: PlutoCell(value: m.ohm1m),
        MeasurementColumn.ohm3m: PlutoCell(value: m.ohm3m),
        MeasurementColumn.observations: PlutoCell(value: m.observations),
        MeasurementColumn.date: PlutoCell(value: m.date),
        _kMapsCol: PlutoCell(value: ''),
        _kPhotosCol: PlutoCell(value: ''),
      });
    });
  }

  void _emitChanged() {
    final out = <Measurement>[];
    for (var i = 0; i < (_sm?.rows.length ?? 0); i++) {
      final r = _sm!.rows[i];
      final orig = (i < _rows.length) ? _rows[i] : Measurement.empty();
      out.add(orig.copyWith(
        progresiva:
        (r.cells[MeasurementColumn.progresiva]?.value ?? '').toString(),
        ohm1m: (r.cells[MeasurementColumn.ohm1m]?.value as num?)?.toDouble(),
        ohm3m: (r.cells[MeasurementColumn.ohm3m]?.value as num?)?.toDouble(),
        observations:
        (r.cells[MeasurementColumn.observations]?.value ?? '').toString(),
        date: (r.cells[MeasurementColumn.date]?.value is DateTime)
            ? r.cells[MeasurementColumn.date]!.value
            : orig.date,
      ));
    }
    _rows = out;
    widget.onChanged(List<Measurement>.from(_rows));

    if (_assistant != null) {
      for (final m in _rows) {
        _assistant!.learn(m);
      }
    }
  }

  void _patchRowFromEvent(PlutoGridOnChangedEvent evt) {
    final rowIdx = _sm?.rows.indexOf(evt.row) ?? -1;
    if (rowIdx < 0 || rowIdx >= _rows.length) return;

    final old = _rows[rowIdx];
    Measurement next = old;

    switch (evt.column.field) {
      case MeasurementColumn.progresiva:
        next = old.copyWith(progresiva: (evt.value ?? '').toString());
        break;
      case MeasurementColumn.ohm1m:
        next = old.copyWith(ohm1m: (evt.value as num?)?.toDouble());
        break;
      case MeasurementColumn.ohm3m:
        next = old.copyWith(ohm3m: (evt.value as num?)?.toDouble());
        break;
      case MeasurementColumn.observations:
        next = old.copyWith(observations: (evt.value ?? '').toString());
        break;
      case MeasurementColumn.date:
        if (evt.value is DateTime) next = old.copyWith(date: evt.value as DateTime);
        break;
    }

    _rows[rowIdx] = next;
    if (_assistant != null) _assistant!.learn(next);
    _emitChangedDebounced();
  }

  void _syncRowFromCells(int rowIdx) {
    if (_sm == null || rowIdx < 0 || rowIdx >= _rows.length) return;
    final r = _sm!.rows[rowIdx];
    final orig = _rows[rowIdx];
    _rows[rowIdx] = orig.copyWith(
      progresiva: (r.cells[MeasurementColumn.progresiva]?.value ?? '').toString(),
      ohm1m: (r.cells[MeasurementColumn.ohm1m]?.value as num?)?.toDouble(),
      ohm3m: (r.cells[MeasurementColumn.ohm3m]?.value as num?)?.toDouble(),
      observations: (r.cells[MeasurementColumn.observations]?.value ?? '').toString(),
      date: (r.cells[MeasurementColumn.date]?.value is DateTime)
          ? r.cells[MeasurementColumn.date]!.value
          : orig.date,
    );
    _emitChangedDebounced();
  }

  void _applyFilter(String q) {
    if (_sm == null) return;
    final query = q.trim().toLowerCase();
    if (query.isEmpty) {
      _sm!.setFilter(null);
      return;
    }
    _sm!.setFilter((row) {
      bool match(dynamic v) => (v?.toString().toLowerCase() ?? '').contains(query);
      return match(row.cells[MeasurementColumn.progresiva]?.value) ||
          match(row.cells[MeasurementColumn.observations]?.value) ||
          match(row.cells[MeasurementColumn.ohm1m]?.value) ||
          match(row.cells[MeasurementColumn.ohm3m]?.value);
    });
  }

  // ===================== Fotos por fila =====================
  Future<void> _ensurePhotoCount(int i) async {
    if (i < 0 || i >= _rows.length) return;
    if (_photoCount.containsKey(i) || _photoPending.contains(i)) return;
    _photoPending.add(i);
    try {
      final rid = _rows[i].id ?? i;
      final list = await PhotoStore.list(widget.meta.id, rid);
      final files = list.cast<File>();
      _photoCount[i] = files.length;
      _photoThumb[i] = files.isNotEmpty ? files.first : null;
    } catch (_) {
      // ignore
    } finally {
      _photoPending.remove(i);
      if (mounted) setState(() {});
    }
  }

  void _refreshPhotoCountBatched(int i) {
    _photoCount.remove(i);
    _photoThumb.remove(i);
    _photoDebounce?.cancel();
    _photoDebounce = Timer(const Duration(milliseconds: 120), () async {
      await _ensurePhotoCount(i);
    });
  }

  Future<void> _refreshPhotoCount(int i) async {
    _photoCount.remove(i);
    _photoThumb.remove(i);
    await _ensurePhotoCount(i);
  }

  // ===================== Mutaciones básicas =====================
  void _replaceRows(List<Measurement> rows, {bool notify = true}) {
    _rows = List<Measurement>.from(rows);
    _plutoRows = _buildPlutoRows(_rows);
    if (_sm != null) {
      _sm!.removeRows(_sm!.rows.toList());
      _sm!.appendRows(_plutoRows);
    }
    setState(() {});
    if (notify) _emitChanged();
  }

  Future<void> _setLocationSelected(double lat, double lng) async {
    final messenger = _messenger;
    final cell = _sm?.currentCell;
    final row = _sm?.currentRow;
    if (cell == null || row == null) return;
    final idx = _sm!.rows.indexOf(row);
    if (idx < 0 || idx >= _rows.length) return;
    final cur = _rows[idx];
    final next = cur.copyWith(latitude: lat, longitude: lng);
    _rows[idx] = next;
    _emitChangedDebounced();
    if (!mounted) return;
    messenger.showSnackBar(const SnackBar(content: Text('Ubicación aplicada a la fila.')));
    UsageAnalytics.instance.bump('set_location_row');
  }

  Future<void> _addPhotoSelected() async {
    final idx = _sm?.rows.indexOf(_sm?.currentRow ?? PlutoRow(cells: {})) ?? -1;
    if (idx < 0 || idx >= _rows.length) return;
    final rid = _rows[idx].id ?? idx;
    try {
      final f = await PhotoStore.addFromCamera(widget.meta.id, rid);
      if (f != null) {
        _refreshPhotoCountBatched(idx);
        if (idx == _railRowIndex) await _refreshRail(forced: true);
      }
      UsageAnalytics.instance.bump('add_photo_row');
    } catch (_) {}
  }

  Future<void> _colorCellSelected(Color color) async {
    final cell = _sm?.currentCell;
    final row = _sm?.currentRow;
    if (cell == null || row == null) return;
    final idx = _sm!.rows.indexOf(row);
    if (idx < 0) return;
    _cellBg.putIfAbsent(idx, () => <String, Color>{})[cell.column.field] = color;
    if (mounted) setState(() {});
    UsageAnalytics.instance.bump('highlight_cell');
  }

  void _setFont(String font) {
    if (_fontFamily == font) return;
    setState(() => _fontFamily = font);
  }

  // selección múltiple
  List<int> _selectedRowIndexes() {
    if (_sm == null) return const [];
    final selected = _sm!.currentSelectingRows;
    if (selected.isNotEmpty) {
      return selected.map((r) => _sm!.rows.indexOf(r)).where((i) => i >= 0).toList();
    }
    final current = _sm!.currentRow;
    if (current == null) return const [];
    final idx = _sm!.rows.indexOf(current);
    return idx >= 0 ? [idx] : const [];
  }

  // ==== Acciones rápidas ====
  Future<void> _fillTodayOnSelection() async {
    final idxs = _selectedRowIndexes();
    if (idxs.isEmpty) return;
    final now = DateTime.now();
    for (final i in idxs) {
      final r = _sm!.rows[i];
      r.cells[MeasurementColumn.date]?.value =
          DateTime(now.year, now.month, now.day);
    }
    _syncRowFromCells(idxs.first);
  }

  Future<void> _autoNumberProgresiva({String prefix = '', int startAt = 1}) async {
    final idxs = _selectedRowIndexes();
    if (idxs.isEmpty) return;
    var n = startAt;
    for (final i in idxs) {
      final r = _sm!.rows[i];
      r.cells[MeasurementColumn.progresiva]?.value = '$prefix$n';
      n++;
    }
    _syncRowFromCells(idxs.first);
  }

  Future<void> _summarizeSelectionToObs() async {
    final idxs = _selectedRowIndexes();
    if (idxs.isEmpty) return;

    double sum1 = 0, sum3 = 0;
    int c1 = 0, c3 = 0;
    for (final i in idxs) {
      final r = _sm!.rows[i];
      final v1 = (r.cells[MeasurementColumn.ohm1m]?.value as num?)?.toDouble();
      final v3 = (r.cells[MeasurementColumn.ohm3m]?.value as num?)?.toDouble();
      if (v1 != null) {
        sum1 += v1;
        c1++;
      }
      if (v3 != null) {
        sum3 += v3;
        c3++;
      }
    }
    final avg1 = c1 > 0 ? (sum1 / c1) : null;
    final avg3 = c3 > 0 ? (sum3 / c3) : null;
    final txt = [
      if (avg1 != null) 'avg 1m=${avg1.toStringAsFixed(3)}Ω',
      if (avg3 != null) 'avg 3m=${avg3.toStringAsFixed(3)}Ω',
      'n=${idxs.length}'
    ].join(' · ');

    final first = _sm!.rows[idxs.first];
    final curObs = (first.cells[MeasurementColumn.observations]?.value ?? '').toString();
    first.cells[MeasurementColumn.observations]?.value =
    curObs.isEmpty ? txt : '$curObs | $txt';

    _syncRowFromCells(idxs.first);
  }

  Future<void> _highlightOhmOutliers({String field = MeasurementColumn.ohm1m}) async {
    final idxs = _selectedRowIndexes();
    if (idxs.isEmpty) return;

    final values = <double>[];
    for (final i in idxs) {
      final v = (_sm!.rows[i].cells[field]?.value as num?)?.toDouble();
      if (v != null) values.add(v);
    }
    if (values.length < 2) return;

    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance =
        values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / (values.length - 1);
    final std = variance <= 0 ? 0 : math.sqrt(variance);
    final hi = mean + 2 * std;

    for (final i in idxs) {
      final v = (_sm!.rows[i].cells[field]?.value as num?)?.toDouble();
      if (v != null && v > hi) {
        _cellBg.putIfAbsent(i, () => <String, Color>{})[field] =
            const Color(0xFFFFC107).withValues(alpha: 0.35);
      }
    }
    if (mounted) setState(() {});
  }

  // ===================== Photo Rail =====================
  Future<void> _refreshRail({bool forced = false}) async {
    if (!widget.showPhotoRail) return;
    final row = _sm?.currentRow;
    final idx = (row == null) ? -1 : _sm!.rows.indexOf(row);
    if (!forced && idx == _railRowIndex) return;

    _railRowIndex = idx;
    if (idx < 0 || idx >= _rows.length) {
      if (mounted) setState(() => _railFiles = const []);
      return;
    }

    setState(() => _railLoading = true);
    try {
      final rid = _rows[idx].id ?? idx;
      final list = await PhotoStore.list(widget.meta.id, rid);
      _railFiles = list.cast<File>();
    } catch (_) {
      _railFiles = const [];
    } finally {
      if (mounted) setState(() => _railLoading = false);
    }
  }

  Future<void> _railAddPhoto() async {
    if (_railRowIndex < 0 || _railRowIndex >= _rows.length) return;
    final rid = _rows[_railRowIndex].id ?? _railRowIndex;

    final Future<LocationFix?> locFuture = _railGeoTag
        ? LocationService.instance
        .getPreciseFix(samples: 4)
        .then<LocationFix?>((v) => v, onError: (_) => null)
        : Future<LocationFix?>.value(null);

    final photo = await PhotoStore.addFromCamera(widget.meta.id, rid);
    final fix = await locFuture;

    if (photo != null && fix != null) {
      final cur = _rows[_railRowIndex];
      _rows[_railRowIndex] =
          cur.copyWith(latitude: fix.latitude, longitude: fix.longitude);
      _emitChangedDebounced();
    }
    if (photo != null) {
      await _refreshPhotoCount(_railRowIndex);
      await _refreshRail(forced: true);
      if (mounted) {
        _messenger.showSnackBar(const SnackBar(content: Text('Foto agregada')));
      }
    }
  }

  // ===================== Galería por fila =====================
  Future<void> _openRowGallery(int rowIndex) async {
    final rid = _rows[rowIndex].id ?? rowIndex;
    final files = (await PhotoStore.list(widget.meta.id, rid)).cast<File>();

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: Stack(
            children: [
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(color: Colors.black.withValues(alpha: .25)),
                ),
              ),
              Container(
                color: widget.themeController.theme.surface.withValues(alpha: .80),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: files.isEmpty
                      ? const SizedBox(
                      height: 160, child: Center(child: Text('Sin fotos aún')))
                      : GridView.builder(
                    physics: const BouncingScrollPhysics(),
                    gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemCount: files.length,
                    itemBuilder: (_, i) {
                      final f = files[i];
                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => OpenFilex.open(f.path),
                        onLongPress: () async {
                          await showModalBottomSheet(
                            context: ctx,
                            builder: (bctx) => SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: const Icon(Icons.open_in_new),
                                    title: const Text('Abrir'),
                                    onTap: () async {
                                      Navigator.pop(bctx);
                                      await OpenFilex.open(f.path);
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.share),
                                    title: const Text('Compartir'),
                                    onTap: () {
                                      Navigator.pop(bctx);
                                      Share.shareXFiles([XFile(f.path)]);
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.delete_outline,
                                        color: Colors.red),
                                    title: const Text('Eliminar'),
                                    onTap: () async {
                                      Navigator.pop(bctx);
                                      try {
                                        if (await f.exists()) {
                                          await f.delete();
                                        }
                                        await _refreshPhotoCount(rowIndex);
                                        await _refreshRail(forced: true);
                                        if (mounted) setState(() {});
                                      } catch (_) {}
                                    },
                                  ),
                                  const SizedBox(height: 6),
                                ],
                              ),
                            ),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _imgThumb(f),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Menú rápido desde la celda de “Fotos”
  Future<void> _showPhotoCellMenu(int rowIndex) async {
    final rid = _rows[rowIndex].id ?? rowIndex;
    final files = (await PhotoStore.list(widget.meta.id, rid)).cast<File>();
    final last = files.isEmpty ? null : files.first;

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Ver galería de la fila'),
              onTap: () {
                Navigator.pop(ctx);
                _openRowGallery(rowIndex);
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_a_photo_outlined),
              title: const Text('Agregar foto'),
              onTap: () async {
                Navigator.pop(ctx);
                final f = await PhotoStore.addFromCamera(widget.meta.id, rid);
                if (f != null) {
                  await _refreshPhotoCount(rowIndex);
                  if (rowIndex == _railRowIndex) {
                    await _refreshRail(forced: true);
                  }
                }
              },
            ),
            ListTile(
              enabled: last != null,
              leading: const Icon(Icons.share),
              title: const Text('Compartir última'),
              onTap: last == null
                  ? null
                  : () {
                Navigator.pop(ctx);
                Share.shareXFiles([XFile(last.path)]);
              },
            ),
            ListTile(
              enabled: last != null,
              leading:
              const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Eliminar última'),
              onTap: last == null
                  ? null
                  : () async {
                Navigator.pop(ctx);
                try {
                  if (await last.exists()) await last.delete();
                  await _refreshPhotoCount(rowIndex);
                  if (rowIndex == _railRowIndex) {
                    await _refreshRail(forced: true);
                  }
                } catch (_) {}
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ===================== Build =====================
  @override
  Widget build(BuildContext context) {
    final t = widget.themeController.theme;
    final table = GridnoteTableStyle.from(t);

    final config = PlutoGridConfiguration(
      enterKeyAction: PlutoGridEnterKeyAction.editingAndMoveRight,
      style: PlutoGridStyleConfig(
        gridBorderColor: table.gridLine,
        rowHeight: 50,
        columnHeight: 50,
        cellTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 14,
          color: t.text,
        ),
        columnTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: t.text,
        ),
        cellColorInEditState: table.cellBg,
        cellColorInReadOnlyState: table.cellBg,
        activatedColor: table.selection.withValues(alpha: 0.22),
        activatedBorderColor: table.selection,
        gridBackgroundColor: table.cellBg,
        oddRowColor: table.altCellBg,
        evenRowColor: table.cellBg,
      ),
    );

    final grid = RepaintBoundary(
      child: PlutoGrid(
        columns: _columns,
        rows: _plutoRows,
        configuration: config,
        onLoaded: (evt) {
          _sm = evt.stateManager;
          _sm!
            ..setSelectingMode(PlutoGridSelectingMode.cell)
            ..setKeepFocus(true)
            ..setAutoEditing(true);
          _sm!.addListener(_scheduleRefreshRail);

          for (var i = 0; i < _rows.length && i < 30; i++) {
            unawaited(_ensurePhotoCount(i));
          }
          if ((widget.filterQuery ?? '').isNotEmpty) {
            _applyFilter(widget.filterQuery!);
          }
          _refreshRail(forced: true);
        },
        onChanged: (evt) async {
          _patchRowFromEvent(evt);
          UsageAnalytics.instance.bump('edit_${evt.column.field}');
          await _maybeRunAiSuggestion(evt);
        },
      ),
    );

    if (!widget.showPhotoRail) return grid;

    return LayoutBuilder(
      builder: (_, c) {
        final showRail = c.maxWidth >= 540;
        if (!showRail) return grid;

        return Row(
          children: [
            Expanded(child: grid),
            RepaintBoundary(
              child: Container(
                width: 128,
                margin: const EdgeInsets.fromLTRB(6, 6, 6, 6),
                decoration: BoxDecoration(
                  border: Border.all(color: table.gridLine),
                  borderRadius: BorderRadius.circular(14),
                  color: t.surface.withValues(alpha: .70),
                  boxShadow: const [
                    BoxShadow(
                        blurRadius: 10,
                        color: Color(0x22000000),
                        offset: Offset(0, 4))
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: const SizedBox(),
                      ),
                    ),
                    Column(
                      children: [
                        Container(
                          height: 42,
                          padding:
                          const EdgeInsets.symmetric(horizontal: 10),
                          alignment: Alignment.centerLeft,
                          decoration: BoxDecoration(
                            border:
                            Border(bottom: BorderSide(color: table.gridLine)),
                            color: t.surface.withValues(alpha: .75),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.photo_outlined, size: 18),
                              const SizedBox(width: 6),
                              Text('Fotos',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: t.text)),
                              const Spacer(),
                              Switch.adaptive(
                                value: _railGeoTag,
                                onChanged: (v) =>
                                    setState(() => _railGeoTag = v),
                                activeColor: t.accent,
                                materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: _railLoading
                              ? const Center(
                              child: CircularProgressIndicator(
                                  strokeWidth: 2))
                              : _railFiles.isEmpty
                              ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                'Sin fotos',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: t.text
                                        .withValues(alpha: .7)),
                              ),
                            ),
                          )
                              : ScrollConfiguration(
                            behavior: const _BounceBehavior(),
                            child: GridView.builder(
                              padding: const EdgeInsets.all(6),
                              physics:
                              const BouncingScrollPhysics(),
                              gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 6,
                                crossAxisSpacing: 6,
                              ),
                              itemCount: _railFiles.length,
                              itemBuilder: (_, i) {
                                final f = _railFiles[i];
                                return InkWell(
                                  onTap: () =>
                                      OpenFilex.open(f.path),
                                  borderRadius:
                                  BorderRadius.circular(10),
                                  child: ClipRRect(
                                    borderRadius:
                                    BorderRadius.circular(10),
                                    child: _imgThumb(f),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        Padding(
                          padding:
                          const EdgeInsets.fromLTRB(8, 0, 8, 8),
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: t.accent,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10),
                              ),
                              onPressed: _railAddPhoto,
                              icon: const Icon(Icons.add_a_photo_outlined),
                              label: const Text('Agregar'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _maybeRunAiSuggestion(PlutoGridOnChangedEvent evt) async {
    if (!widget.aiEnabled) return;
    if (_assistant == null) return;
    if (_applyingSuggestion) return;

    final rowIdx = _sm?.rows.indexOf(evt.row) ?? -1;
    if (rowIdx < 0) return;

    final ctx = AiCellContext(
      sheetId: widget.meta.id,
      rowIndex: rowIdx,
      columnName: evt.column.field,
      rawInput: evt.value,
      rows: List<Measurement>.from(_rows),
    );

    final res = await _assistant!.transform(ctx);
    if (!mounted) return;

    if (!res.ok) {
      evt.row.cells[evt.column.field]?.value = evt.oldValue;
      _syncRowFromCells(rowIdx);
      _messenger.showSnackBar(SnackBar(content: Text('IA: ${res.error}')));
      UsageAnalytics.instance.bump('ai_reject');
      return;
    }

    final suggested = res.value;
    final same = (suggested is num && evt.value is num && suggested == evt.value) ||
        (suggested?.toString() == evt.value?.toString());
    final hint = res.hint;

    if (!same || (hint != null && hint.isNotEmpty)) {
      final msg =
      !same ? "Quizás quisiste decir: $suggested" : (hint ?? 'Sugerencia disponible');

      _messenger.hideCurrentSnackBar();
      _messenger.showSnackBar(
        SnackBar(
          content: Text(hint != null ? '$msg  ·  $hint' : msg),
          action: !same
              ? SnackBarAction(
            label: 'APLICAR',
            onPressed: () {
              _applyingSuggestion = true;
              evt.row.cells[evt.column.field]?.value = suggested;
              final idx = _sm?.rows.indexOf(evt.row) ?? -1;
              _syncRowFromCells(idx);
              _applyingSuggestion = false;
              UsageAnalytics.instance.bump('ai_apply');
            },
          )
              : null,
          duration: const Duration(seconds: 4),
        ),
      );
      UsageAnalytics.instance.bump('ai_suggest');
    }
  }
}

class _BounceBehavior extends ScrollBehavior {
  const _BounceBehavior();
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) =>
      StretchingOverscrollIndicator(axisDirection: details.direction, child: child);
}
