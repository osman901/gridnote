// Gridnote · Measurement Pluto Grid · 2025-09
// Requiere: pluto_grid, open_filex, share_plus, intl, path_provider,
// shared_preferences, syncfusion_flutter_xlsio, flutter/services.dart.

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter, FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;

import '../constants/perf_flags.dart';
import '../models/measurement.dart';
import '../models/sheet_meta.dart';
import '../services/elite_assistant.dart';
import '../services/location_service.dart';
import '../services/photo_store.dart';
import '../services/smart_assistant.dart';
import '../services/usage_analytics.dart';
import '../theme/gridnote_theme.dart';
import 'measurement_columns.dart';

// 🔌 IA de UX (toasts inteligentes) + bridge de edición/tipeo para PlutoGrid
import '../services/ux/smart_notifier.dart';
import 'pluto_edit_activity_bridge.dart';

typedef RowsChanged = void Function(List<Measurement> rows);
typedef OpenMaps = void Function(Measurement m);

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

  // AI helpers
  Future<void> fillTodayOnSelection() async => _s?._fillTodayOnSelection();
  Future<void> autoNumberProgresiva({String prefix = '', int startAt = 1}) async =>
      _s?._autoNumberProgresiva(prefix: prefix, startAt: startAt);
  Future<void> summarizeSelectionToObs() async =>
      _s?._summarizeSelectionToObs();
  Future<void> highlightOhmOutliers(
      {String field = MeasurementColumn.ohm1m}) async =>
      _s?._highlightOhmOutliers(field: field);

  // HUD de guardado
  void notifySaved() => _s?._showSavedHud();

  // Export selección
  Future<File?> exportSelectionToXlsx({String? fileName}) =>
      _s?._exportSelectionToXlsx(fileName: fileName) ?? Future<File?>.value(null);
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
    this.onHeaderTitleChanged,
    this.onOpenMaps,
    this.autoWidth = true,
    this.filterQuery,
    this.aiEnabled = true,
    this.showPhotoRail = true,
    this.showMetricsFooter = false,
  });

  final SheetMeta meta;
  final List<Measurement> initial;
  final GridnoteThemeController themeController;
  final MeasurementGridController controller;
  final RowsChanged onChanged;

  final Map<String, String> headerTitles;
  final void Function(String columnName) onEditHeader;
  final void Function(String columnName, String newTitle)? onHeaderTitleChanged;

  final OpenMaps? onOpenMaps;
  final bool autoWidth;
  final String? filterQuery;
  final bool aiEnabled;
  final bool showPhotoRail;
  final bool showMetricsFooter;

  @override
  State<MeasurementDataGrid> createState() => _MeasurementPlutoGridState();
}

class _MeasurementPlutoGridState extends State<MeasurementDataGrid>
    with SingleTickerProviderStateMixin {
  // ==== Base ====
  late List<Measurement> _rows;
  late List<PlutoColumn> _columns;
  late List<PlutoRow> _plutoRows;
  PlutoGridStateManager? _sm;
  PlutoEditActivityBridge? _bridge; // 👈 Bridge para ActivityTracker
  String _fontFamily = 'SF Pro Text';

  // Accesibilidad: números tabulares
  List<FontFeature> get _fontFeatures => const [FontFeature.tabularFigures()];

  // Debounces
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

  // Fondo/error por celda
  final Map<int, Map<String, Color>> _cellBg = {};
  final Map<int, Map<String, String>> _cellError = {};

  // Fotos
  final Map<int, int> _photoCount = {};
  final Map<int, File?> _photoThumb = {};
  final Set<int> _photoPending = {};
  Timer? _photoDebounce;

  // Rail
  int _railRowIndex = -1;
  List<File> _railFiles = const [];
  bool _railLoading = false;
  bool _railGeoTag = true;

  // Asistente
  GridnoteAssistant? _assistant;
  bool _applyingSuggestion = false;

  // Focus/Atajos
  final FocusNode _kbdFocus = FocusNode(debugLabel: 'grid_kbd');

  // Undo/Redo
  final List<_EditOp> _undo = <_EditOp>[];
  final List<_EditOp> _redo = <_EditOp>[];
  static const int _maxHistory = 200;

  // Vistas guardadas (filtros)
  static const String _prefsKey = 'grid_views_v1';
  Map<String, _SavedView> _views = {};
  String get _viewId => widget.meta.id;

  // Footer métricas
  _SelectionStats _stats = const _SelectionStats.empty();

  ScaffoldMessengerState get _messenger => ScaffoldMessenger.of(context);

  // ===== Guardado: HUD con tilde + haptic =====
  late final AnimationController _saveCtrl;
  OverlayEntry? _saveHud;

  void _showSavedHud() {
    if (!mounted) return;
    HapticFeedback.lightImpact();

    _saveHud?.remove();
    final t = widget.themeController.theme;

    final curved = CurvedAnimation(parent: _saveCtrl, curve: Curves.easeOutBack);
    _saveHud = OverlayEntry(
      builder: (_) => IgnorePointer(
        child: Center(
          child: FadeTransition(
            opacity: _saveCtrl.drive(Tween(begin: 0.0, end: 1.0)),
            child: ScaleTransition(
              scale: curved,
              child: _SavedTick(theme: t),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context, rootOverlay: true).insert(_saveHud!);
    _saveCtrl.forward(from: 0).whenComplete(() async {
      await Future.delayed(const Duration(milliseconds: 450));
      _saveHud?.remove();
      _saveHud = null;
    });
  }

  bool _takingPhoto = false;
  Future<File?> _takePhotoForRow(int rowIndex) async {
    if (_takingPhoto || rowIndex < 0 || rowIndex >= _rows.length) return null;
    _takingPhoto = true;
    try {
      final rid = _rows[rowIndex].id ?? rowIndex;
      // No usamos context luego de await dentro de este método
      return await PhotoStore.addFromCamera(context, widget.meta.id, rid);
    } finally {
      _takingPhoto = false;
    }
  }

  Widget _imgThumb(File f, {BoxFit fit = BoxFit.cover}) => Image.file(
    f,
    fit: fit,
    cacheWidth: kLowSpec ? 192 : 256,
    cacheHeight: kLowSpec ? 192 : 256,
    filterQuality: kLowSpec ? FilterQuality.none : FilterQuality.low,
    errorBuilder: (_, __, ___) => const ColoredBox(
      color: Color(0x22000000),
      child: Center(child: Icon(Icons.broken_image_outlined, size: 18)),
    ),
  );

  // ===== Fecha =====
  final DateFormat _dateUiFmt = DateFormat('dd MMM yyyy', 'es');
  String _formatUiDate(DateTime? dt) =>
      (dt == null) ? '—' : _dateUiFmt.format(dt.toLocal());
  DateTime _utcFromLocalDate(DateTime local) =>
      DateTime(local.year, local.month, local.day).toUtc();

  Future<DateTime?> _pickLocalDate(BuildContext ctx, DateTime? current) async {
    final now = DateTime.now();
    final init = (current ?? now).toLocal();
    final picked = await showDatePicker(
      context: ctx,
      initialDate: init,
      firstDate: DateTime(now.year - 5, 1, 1),
      lastDate: DateTime(now.year + 5, 12, 31),
      helpText: 'Elegí la fecha',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
      locale: const Locale('es'),
    );
    if (picked == null) return null;
    return DateTime(picked.year, picked.month, picked.day);
  }

  // ===== Encabezados editables =====
  final Map<String, String> _titleOverrides = <String, String>{};
  final Set<String> _editingHeaders = <String>{};
  final Map<String, TextEditingController> _headerCtrls =
  <String, TextEditingController>{};
  final Map<String, FocusNode> _headerFocus = <String, FocusNode>{};

  String _titleFor(String field, String fallback) =>
      _titleOverrides[field] ?? widget.headerTitles[field] ?? fallback;

  void _commitHeader(String field, String value) {
    final v = value.trim();
    if (v.isEmpty) return;
    setState(() {
      _titleOverrides[field] = v;
      _editingHeaders.remove(field);
    });
    widget.onHeaderTitleChanged?.call(field, v);
  }

  Widget _editableHeader(String field, String fallback,
      {TextAlign align = TextAlign.left}) {
    final t = widget.themeController.theme;
    final isEditing = _editingHeaders.contains(field);
    final title = _titleFor(field, fallback);

    if (!isEditing) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _headerCtrls[field] ??= TextEditingController();
          _headerCtrls[field]!.text = title;
          _headerFocus[field] ??= FocusNode();
          setState(() => _editingHeaders.add(field));
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _headerFocus[field]!.requestFocus();
          });
        },
        onLongPress: () => widget.onEditHeader(field),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: align,
                  style: TextStyle(
                    fontFamily: _fontFamily,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: t.text,
                    fontFeatures: _fontFeatures,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.edit_outlined, size: 14, color: t.text.withValues(alpha: .7)),
            ],
          ),
        ),
      );
    }

    final ctrl = _headerCtrls[field]!;
    final fn = _headerFocus[field] ??= FocusNode();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: SizedBox(
        height: 34,
        child: TextField(
          controller: ctrl,
          focusNode: fn,
          autofocus: true,
          textInputAction: TextInputAction.done,
          textAlign: align,
          onSubmitted: (v) => _commitHeader(field, v),
          onTapOutside: (_) => _commitHeader(field, ctrl.text),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            hintText: 'Título…',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
    );
  }

  // ===== Init/Dispose =====
  @override
  void initState() {
    super.initState();
    _saveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _rows = List<Measurement>.from(widget.initial);
    _columns = _buildColumns();
    _plutoRows = _buildPlutoRows(_rows);
    widget.controller._attach(this);
    unawaited(_initAssistant());
    unawaited(_loadViews());
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
    _bridge?.dispose(); // 👈 liberar bridge
    _saveHud?.remove();
    _saveCtrl.dispose();
    _photoDebounce?.cancel();
    _emitDebounce?.cancel();
    _railDebounce?.cancel();
    for (final c in _headerCtrls.values) {
      c.dispose();
    }
    for (final f in _headerFocus.values) {
      f.dispose();
    }
    _kbdFocus.dispose();
    widget.controller._detach(this);
    super.dispose();
  }

  // ==== Columnas ====
  List<PlutoColumn> _buildColumns() {
    Widget Function(PlutoColumnRendererContext ctx) textCellRenderer(
        [TextAlign align = TextAlign.left]) {
      return (ctx) {
        final idx = ctx.rowIdx;
        final field = ctx.column.field;
        final bgCustom = _cellBg[idx]?[field];
        final err = _cellError[idx]?[field];

        final isCurrent = ctx.cell == ctx.stateManager.currentCell;
        final isEditing = isCurrent && ctx.stateManager.isEditing;

        final theme = widget.themeController.theme;
        final Color base = err != null
            ? const Color(0xFFFFCDD2)
            : (bgCustom ?? Colors.transparent);
        final Color animColor = isEditing
            ? theme.accent.withValues(alpha: .12)
            : (isCurrent ? theme.selection.withValues(alpha: .10) : base);

        final String txt = '${ctx.cell.value ?? ''}';

        return AnimatedScale(
          scale: isCurrent ? 1.0 : 0.995,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            color: animColor,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            alignment: align == TextAlign.right ? Alignment.centerRight : Alignment.centerLeft,
            child: Tooltip(
              message: err ?? '',
              triggerMode: err == null ? TooltipTriggerMode.manual : TooltipTriggerMode.tap,
              child: Text(
                txt.isEmpty ? '—' : txt,
                maxLines: 10,
                overflow: TextOverflow.visible,
                style: TextStyle(
                    fontFamily: _fontFamily, fontSize: 14, color: theme.text, fontFeatures: _fontFeatures),
              ),
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
        enableSorting: false,
        titleSpan: TextSpan(children: [
          WidgetSpan(child: _editableHeader(MeasurementColumn.progresiva, 'Progresiva'))
        ]),
        renderer: textCellRenderer(),
        minWidth: 140,
        frozen: PlutoColumnFrozen.start,
      ),
      PlutoColumn(
        title: '1m (Ω)',
        field: MeasurementColumn.ohm1m,
        type: PlutoColumnType.number(allowFirstDot: false, format: '#.########'),
        enableEditingMode: true,
        enableSorting: false,
        titleSpan: TextSpan(children: [
          WidgetSpan(child: _editableHeader(MeasurementColumn.ohm1m, '1m (Ω)', align: TextAlign.right))
        ]),
        renderer: textCellRenderer(TextAlign.right),
        width: 110,
      ),
      PlutoColumn(
        title: '3m (Ω)',
        field: MeasurementColumn.ohm3m,
        type: PlutoColumnType.number(allowFirstDot: false, format: '#.########'),
        enableEditingMode: true,
        enableSorting: false,
        titleSpan: TextSpan(children: [
          WidgetSpan(child: _editableHeader(MeasurementColumn.ohm3m, '3m (Ω)', align: TextAlign.right))
        ]),
        renderer: textCellRenderer(TextAlign.right),
        width: 110,
      ),
      PlutoColumn(
        title: 'Obs',
        field: MeasurementColumn.observations,
        type: PlutoColumnType.text(),
        enableEditingMode: true,
        enableSorting: false,
        titleSpan: TextSpan(children: [
          WidgetSpan(child: _editableHeader(MeasurementColumn.observations, 'Obs'))
        ]),
        renderer: textCellRenderer(),
        minWidth: 220,
      ),
      PlutoColumn(
        title: 'Fecha',
        field: MeasurementColumn.date,
        type: PlutoColumnType.date(format: 'dd/MM/yyyy'),
        enableEditingMode: false,
        enableSorting: false,
        titleSpan: TextSpan(children: [
          WidgetSpan(child: _editableHeader(MeasurementColumn.date, 'Fecha'))
        ]),
        renderer: (ctx) {
          final idx = ctx.rowIdx;
          final field = ctx.column.field;
          final bg = _cellBg[idx]?[field];
          final DateTime? dt = ctx.cell.value is DateTime ? ctx.cell.value : null;
          return InkWell(
            onTap: () async {
              final pickedLocal = await _pickLocalDate(context, dt);
              if (pickedLocal == null) return;
              ctx.row.cells[field]?.value = pickedLocal;
              _syncRowFromCells(idx);
            },
            child: Container(
              color: bg,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              alignment: Alignment.centerLeft,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(_formatUiDate(dt),
                    style: TextStyle(
                        fontFamily: _fontFamily, fontSize: 14, color: widget.themeController.theme.text)),
                const SizedBox(width: 6),
                Icon(Icons.edit_calendar_outlined,
                    size: 16, color: widget.themeController.theme.text.withValues(alpha: .6)),
              ]),
            ),
          );
        },
        width: 170,
      ),
      PlutoColumn(
        title: ' ',
        field: _kMapsCol,
        type: PlutoColumnType.text(),
        enableEditingMode: false,
        enableSorting: false,
        renderer: (ctx) {
          final i = ctx.rowIdx;
          final m = (i >= 0 && i < _rows.length) ? _rows[i] : null;
          final has = m?.latitude != null && m?.longitude != null;
          return Center(
            child: Tooltip(
              message: has ? 'Abrir en Maps (mantener: re-tomar)' : 'Tomar ubicación',
              child: IconButton(
                icon: Icon(has ? Icons.location_on : Icons.my_location, size: 20),
                onPressed: () async {
                  if (i < 0 || i >= _rows.length) return;
                  if (!has) {
                    await _captureLocationForRow(i);
                  } else {
                    if (widget.onOpenMaps != null) {
                      widget.onOpenMaps!(m!);
                    }
                  }
                },
                onLongPress: () async {
                  if (i >= 0 && i < _rows.length) {
                    await _captureLocationForRow(i);
                  }
                },
              ),
            ),
          );
        },
        width: 80,
      ),
      PlutoColumn(
        title: ' ',
        field: _kPhotosCol,
        type: PlutoColumnType.text(),
        enableEditingMode: false,
        enableSorting: false,
        renderer: (ctx) {
          final i = ctx.rowIdx;
          final n = _photoCount[i] ?? 0;
          final thumb = _photoThumb[i];
          Widget thumbView() => ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(fit: StackFit.expand, children: [
              if (thumb != null)
                _imgThumb(thumb)
              else
                const Center(child: Icon(Icons.photo_camera_outlined, size: 18)),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                    height: 22,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [
                        Color(0x00000000),
                        Color(0x33000000)
                      ]),
                    )),
              ),
              Positioned(
                right: 4,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .65), borderRadius: BorderRadius.circular(10)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.photo_camera_outlined, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text('$n',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ]),
          );

          return Center(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () async {
                if (i < 0 || i >= _rows.length) return;
                if ((_photoCount[i] ?? 0) > 0) {
                  await _openRowGallery(i);
                } else {
                  final f = await _takePhotoForRow(i);
                  if (f != null) {
                    _refreshPhotoCountBatched(i);
                    if (i == _railRowIndex) {
                      await _refreshRail(forced: true);
                    }
                  }
                }
              },
              onLongPress: () async {
                if (i >= 0 && i < _rows.length) {
                  await _showPhotoCellMenu(i);
                }
              },
              child: SizedBox(width: 84, height: 48, child: thumbView()),
            ),
          );
        },
        width: 96,
      ),
    ];
  }

  List<PlutoRow> _buildPlutoRows(List<Measurement> rows) {
    return List<PlutoRow>.generate(rows.length, (i) {
      final m = rows[i];
      return PlutoRow(cells: {
        MeasurementColumn.progresiva: PlutoCell(value: m.progresiva),
        MeasurementColumn.ohm1m: PlutoCell(value: m.ohm1m),
        MeasurementColumn.ohm3m: PlutoCell(value: m.ohm3m),
        MeasurementColumn.observations: PlutoCell(value: m.observations),
        MeasurementColumn.date: PlutoCell(value: m.date.toLocal()),
        _kMapsCol: PlutoCell(value: ''),
        _kPhotosCol: PlutoCell(value: ''),
      });
    });
  }

  // ==== Model sync ====
  void _emitChanged() {
    final out = <Measurement>[];
    final sm = _sm;
    if (sm == null) return;
    for (var i = 0; i < sm.rows.length; i++) {
      final r = sm.rows[i];
      final orig = (i < _rows.length) ? _rows[i] : Measurement.empty();
      out.add(orig.copyWith(
        progresiva: (r.cells[MeasurementColumn.progresiva]?.value ?? '').toString(),
        ohm1m: (r.cells[MeasurementColumn.ohm1m]?.value as num?)?.toDouble(),
        ohm3m: (r.cells[MeasurementColumn.ohm3m]?.value as num?)?.toDouble(),
        observations: (r.cells[MeasurementColumn.observations]?.value ?? '').toString(),
        date: (r.cells[MeasurementColumn.date]?.value is DateTime)
            ? _utcFromLocalDate((r.cells[MeasurementColumn.date]!.value as DateTime).toLocal())
            : orig.date,
      ));
    }
    _rows = out;
    widget.onChanged(List<Measurement>.from(_rows));
  }

  void _patchRowFromEvent(PlutoGridOnChangedEvent evt) {
    final sm = _sm;
    if (sm == null) return;
    final rowIdx = sm.rows.indexOf(evt.row);
    if (rowIdx < 0 || rowIdx >= _rows.length) return;
    final old = _rows[rowIdx];
    final prev = evt.oldValue;
    dynamic nextVal = evt.value;

    // Validaciones mínimas
    String? err;
    if (evt.column.field == MeasurementColumn.ohm1m ||
        evt.column.field == MeasurementColumn.ohm3m) {
      final v = (nextVal is num)
          ? nextVal.toDouble()
          : double.tryParse(nextVal?.toString() ?? '');
      if (v != null && v < 0) {
        err = 'Valor negativo no válido';
      }
    }
    _setCellError(rowIdx, evt.column.field, err);

    Measurement next = old;
    switch (evt.column.field) {
      case MeasurementColumn.progresiva:
        next = old.copyWith(progresiva: (nextVal ?? '').toString());
        break;
      case MeasurementColumn.ohm1m:
        next = old.copyWith(ohm1m: (nextVal as num?)?.toDouble());
        break;
      case MeasurementColumn.ohm3m:
        next = old.copyWith(ohm3m: (nextVal as num?)?.toDouble());
        break;
      case MeasurementColumn.observations:
        next = old.copyWith(observations: (nextVal ?? '').toString());
        break;
      case MeasurementColumn.date:
        if (nextVal is DateTime) {
          final local = (nextVal).toLocal();
          next = old.copyWith(date: _utcFromLocalDate(local));
        }
        break;
    }

    _rows[rowIdx] = next;
    _pushHistory(_EditOp(rowIdx: rowIdx, field: evt.column.field, oldValue: prev, newValue: nextVal));
    final a = _assistant;
    if (a != null) a.learn(next);
    _emitChangedDebounced();
  }

  void _syncRowFromCells(int rowIdx) {
    final sm = _sm;
    if (sm == null || rowIdx < 0 || rowIdx >= _rows.length) return;
    final r = sm.rows[rowIdx];
    final orig = _rows[rowIdx];
    _rows[rowIdx] = orig.copyWith(
      progresiva: (r.cells[MeasurementColumn.progresiva]?.value ?? '').toString(),
      ohm1m: (r.cells[MeasurementColumn.ohm1m]?.value as num?)?.toDouble(),
      ohm3m: (r.cells[MeasurementColumn.ohm3m]?.value as num?)?.toDouble(),
      observations: (r.cells[MeasurementColumn.observations]?.value ?? '').toString(),
      date: (r.cells[MeasurementColumn.date]?.value is DateTime)
          ? _utcFromLocalDate((r.cells[MeasurementColumn.date]!.value as DateTime).toLocal())
          : orig.date,
    );
    _emitChangedDebounced();
  }

  // ==== Filtro ====
  void _applyFilter(String q) {
    final sm = _sm;
    if (sm == null) return;
    final query = q.trim().toLowerCase();
    if (query.isEmpty) {
      sm.setFilter(null);
      return;
    }
    sm.setFilter((row) {
      bool match(dynamic v) => (v?.toString().toLowerCase() ?? '').contains(query);
      return match(row.cells[MeasurementColumn.progresiva]?.value) ||
          match(row.cells[MeasurementColumn.observations]?.value) ||
          match(row.cells[MeasurementColumn.ohm1m]?.value) ||
          match(row.cells[MeasurementColumn.ohm3m]?.value);
    });
  }

  // ==== Fotos/rail ====
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

  // ==== Reemplazo de filas ====
  void _replaceRows(List<Measurement> rows, {bool notify = true}) {
    _rows = List<Measurement>.from(rows);
    _plutoRows = _buildPlutoRows(_rows);
    final sm = _sm;
    if (sm != null) {
      sm.removeRows(sm.rows.toList());
      sm.appendRows(_plutoRows);
    }
    setState(() {});
    if (notify) _emitChanged();
  }

  // ==== Ubicación ====
  Future<void> _setLocationSelected(double lat, double lng) async {
    final sm = _sm;
    final cell = sm?.currentCell;
    final row = sm?.currentRow;
    if (cell == null || row == null) return;
    final idx = sm!.rows.indexOf(row);
    if (idx < 0 || idx >= _rows.length) return;
    final cur = _rows[idx];
    final next = cur.copyWith(latitude: lat, longitude: lng);
    _rows[idx] = next;
    _emitChangedDebounced();
    SmartNotifier.instance.success('Ubicación aplicada a la fila.');
    UsageAnalytics.instance.bump('set_location_row');
  }

  Future<void> _addPhotoSelected() async {
    final sm = _sm;
    final idx = sm?.rows.indexOf(sm?.currentRow ?? PlutoRow(cells: {})) ?? -1;
    if (idx < 0 || idx >= _rows.length) return;
    try {
      final f = await _takePhotoForRow(idx);
      if (f != null) {
        _refreshPhotoCountBatched(idx);
        if (idx == _railRowIndex) await _refreshRail(forced: true);
      }
      UsageAnalytics.instance.bump('add_photo_row');
    } catch (_) {}
  }

  Future<void> _colorCellSelected(Color color) async {
    final sm = _sm;
    final cell = sm?.currentCell;
    final row = sm?.currentRow;
    if (cell == null || row == null) return;
    final idx = sm!.rows.indexOf(row);
    if (idx < 0) return;
    _cellBg.putIfAbsent(idx, () => <String, Color>{})[cell.column.field] = color;
    if (mounted) setState(() {});
    UsageAnalytics.instance.bump('highlight_cell');
  }

  void _setFont(String font) {
    if (_fontFamily == font) return;
    setState(() => _fontFamily = font);
  }

  List<int> _selectedRowIndexes() {
    final sm = _sm;
    if (sm == null) return const [];
    final selected = sm.currentSelectingRows;
    if (selected.isNotEmpty) {
      return selected.map((r) => sm.rows.indexOf(r)).where((i) => i >= 0).toList();
    }
    final current = sm.currentRow;
    if (current == null) return const [];
    final idx = sm.rows.indexOf(current);
    return idx >= 0 ? [idx] : const [];
  }

  Future<void> _fillTodayOnSelection() async {
    final sm = _sm;
    if (sm == null) return;
    final idxs = _selectedRowIndexes();
    if (idxs.isEmpty) return;
    final now = DateTime.now();
    for (final i in idxs) {
      final r = sm.rows[i];
      r.cells[MeasurementColumn.date]?.value = DateTime(now.year, now.month, now.day);
    }
    _syncRowFromCells(idxs.first);
  }

  Future<void> _autoNumberProgresiva({String prefix = '', int startAt = 1}) async {
    final sm = _sm;
    if (sm == null) return;
    final idxs = _selectedRowIndexes();
    if (idxs.isEmpty) return;
    var n = startAt;
    for (final i in idxs) {
      final r = sm.rows[i];
      r.cells[MeasurementColumn.progresiva]?.value = '$prefix$n';
      n++;
    }
    _syncRowFromCells(idxs.first);
  }

  Future<void> _summarizeSelectionToObs() async {
    final sm = _sm;
    if (sm == null) return;
    final idxs = _selectedRowIndexes();
    if (idxs.isEmpty) return;

    double sum1 = 0, sum3 = 0;
    int c1 = 0, c3 = 0;
    for (final i in idxs) {
      final r = sm.rows[i];
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

    final first = sm.rows[idxs.first];
    final curObs = (first.cells[MeasurementColumn.observations]?.value ?? '').toString();
    first.cells[MeasurementColumn.observations]?.value = curObs.isEmpty ? txt : '$curObs | $txt';
    _syncRowFromCells(idxs.first);
  }

  Future<void> _highlightOhmOutliers({String field = MeasurementColumn.ohm1m}) async {
    final sm = _sm;
    if (sm == null) return;
    final idxs = _selectedRowIndexes();
    if (idxs.isEmpty) return;
    final values = <double>[];
    for (final i in idxs) {
      final v = (sm.rows[i].cells[field]?.value as num?)?.toDouble();
      if (v != null) values.add(v);
    }
    if (values.length < 2) return;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance = values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / (values.length - 1);
    final std = variance <= 0 ? 0 : math.sqrt(variance);
    final hi = mean + 2 * std;
    for (final i in idxs) {
      final v = (sm.rows[i].cells[field]?.value as num?)?.toDouble();
      if (v != null && v > hi) {
        _cellBg.putIfAbsent(i, () => <String, Color>{})[field] =
            const Color(0xFFFFC107).withValues(alpha: 0.35);
      }
    }
    if (mounted) setState(() {});
  }

  // ==== Métricas de selección ====
  void _recalcSelectionStats() {
    final sm = _sm;
    if (sm == null) return;
    final rows = _selectedRowIndexes();
    if (rows.isEmpty) {
      _stats = const _SelectionStats.empty();
      return;
    }
    final vals = <double>[];
    for (final r in rows) {
      final v1 = (sm.rows[r].cells[MeasurementColumn.ohm1m]?.value as num?)?.toDouble();
      final v3 = (sm.rows[r].cells[MeasurementColumn.ohm3m]?.value as num?)?.toDouble();
      if (v1 != null) vals.add(v1);
      if (v3 != null) vals.add(v3);
    }
    if (vals.isEmpty) {
      _stats = _SelectionStats(count: rows.length, min: null, max: null, avg: null);
      return;
    }
    vals.sort();
    final min = vals.first;
    final max = vals.last;
    final avg = vals.reduce((a, b) => a + b) / vals.length;
    _stats = _SelectionStats(count: rows.length, min: min, max: max, avg: avg);
  }

  // ==== Rail de fotos ====
  Future<void> _refreshRail({bool forced = false}) async {
    if (!widget.showPhotoRail) return;
    final sm = _sm;
    final row = sm?.currentRow;
    final idx = (row == null) ? -1 : sm!.rows.indexOf(row);
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
    } finally {
      if (mounted) setState(() => _railLoading = false);
    }
  }

  Future<void> _railAddPhoto() async {
    if (_railRowIndex < 0 || _railRowIndex >= _rows.length) return;
    final Future<LocationFix?> locFuture = _railGeoTag
        ? LocationService.instance
        .getPreciseFix(samples: 4)
        .then<LocationFix?>((v) => v, onError: (_) => null)
        : Future<LocationFix?>.value(null);
    final photo = await _takePhotoForRow(_railRowIndex);
    final fix = await locFuture;
    if (photo != null && fix != null) {
      final cur = _rows[_railRowIndex];
      _rows[_railRowIndex] = cur.copyWith(latitude: fix.latitude, longitude: fix.longitude);
      _emitChangedDebounced();
    }
    if (photo != null) {
      await _refreshPhotoCount(_railRowIndex);
      await _refreshRail(forced: true);
      SmartNotifier.instance.success('Foto agregada');
    }
  }

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
                child: kLowSpec
                    ? Container(color: Colors.black.withValues(alpha: .25))
                    : BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(color: Colors.black.withValues(alpha: .25))),
              ),
              Container(
                color: widget.themeController.theme.surface.withValues(alpha: .80),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: files.isEmpty
                      ? const SizedBox(height: 160, child: Center(child: Text('Sin fotos aún')))
                      : GridView.builder(
                    physics: const BouncingScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                              child: Column(mainAxisSize: MainAxisSize.min, children: [
                                ListTile(
                                    leading: const Icon(Icons.open_in_new),
                                    title: const Text('Abrir'),
                                    onTap: () async {
                                      Navigator.pop(bctx);
                                      await OpenFilex.open(f.path);
                                    }),
                                ListTile(
                                    leading: const Icon(Icons.share),
                                    title: const Text('Compartir'),
                                    onTap: () {
                                      Navigator.pop(bctx);
                                      Share.shareXFiles([XFile(f.path)]);
                                    }),
                                ListTile(
                                    leading: const Icon(Icons.delete_outline, color: Colors.red),
                                    title: const Text('Eliminar'),
                                    onTap: () async {
                                      Navigator.pop(bctx);
                                      try {
                                        if (await f.exists()) {
                                          await f.delete();
                                        }
                                        await _refreshPhotoCount(rowIndex);
                                        await _refreshRail(forced: true);
                                        if (mounted) {
                                          setState(() {});
                                        }
                                      } catch (_) {}
                                    }),
                                const SizedBox(height: 6),
                              ]),
                            ),
                          );
                        },
                        child: ClipRRect(borderRadius: BorderRadius.circular(12), child: _imgThumb(f)),
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

  Future<void> _showPhotoCellMenu(int rowIndex) async {
    final rid = _rows[rowIndex].id ?? rowIndex;
    final files = (await PhotoStore.list(widget.meta.id, rid)).cast<File>();
    final last = files.isEmpty ? null : files.first;
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Ver galería de la fila'),
              onTap: () {
                Navigator.pop(ctx);
                _openRowGallery(rowIndex);
              }),
          ListTile(
              leading: const Icon(Icons.add_a_photo_outlined),
              title: const Text('Agregar foto'),
              onTap: () async {
                Navigator.pop(ctx);
                final f = await _takePhotoForRow(rowIndex);
                if (f != null) {
                  await _refreshPhotoCount(rowIndex);
                  if (rowIndex == _railRowIndex) {
                    await _refreshRail(forced: true);
                  }
                }
              }),
          ListTile(
              enabled: last != null,
              leading: const Icon(Icons.share),
              title: const Text('Compartir última'),
              onTap: last == null
                  ? null
                  : () {
                Navigator.pop(ctx);
                Share.shareXFiles([XFile(last.path)]);
              }),
          ListTile(
              enabled: last != null,
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Eliminar última'),
              onTap: last == null
                  ? null
                  : () async {
                Navigator.pop(ctx);
                try {
                  if (await last.exists()) {
                    await last.delete();
                  }
                  await _refreshPhotoCount(rowIndex);
                  if (rowIndex == _railRowIndex) {
                    await _refreshRail(forced: true);
                  }
                } catch (_) {}
              }),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<void> _captureLocationForRow(int i) async {
    if (!mounted || i < 0 || i >= _rows.length) return;
    try {
      final fix = await LocationService.instance.getPreciseFix(
        samples: 6,
        perSampleTimeout: const Duration(seconds: 4),
        keepBestFraction: 0.6,
      );
      final cur = _rows[i];
      _rows[i] = cur.copyWith(latitude: fix.latitude, longitude: fix.longitude);
      _emitChangedDebounced();
      final label = cur.progresiva.isEmpty ? (cur.id ?? i).toString() : cur.progresiva;
      SmartNotifier.instance.success('Ubicación guardada en fila $label');
      if (mounted) setState(() {});
      UsageAnalytics.instance.bump('set_location_row');
    } catch (_) {
      SmartNotifier.instance.error('No se pudo obtener la ubicación.');
    }
  }

  // ==== Vistas guardadas (sin APIs rotas de Pluto 8) ====
  Future<void> _loadViews() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_prefsKey) ?? const <String>[];
      _views = {for (final s in raw.map(_SavedView.decode)) s.id: s};
      if ((widget.filterQuery ?? '').isNotEmpty) {
        _applyFilter(widget.filterQuery!);
      }
    } catch (_) {/* no-op */}
  }

  Future<void> _saveView() async {
    final sm = _sm;
    if (sm == null) return;
    final s = _SavedView.capture(_viewId, sm);
    _views[_viewId] = s;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, _views.values.map((v) => v.encode()).toList());
    SmartNotifier.instance.success('Vista guardada');
  }

  // ==== Undo/Redo ====
  void _pushHistory(_EditOp op) {
    _undo.add(op);
    if (_undo.length > _maxHistory) _undo.removeAt(0);
    _redo.clear();
  }

  void _applyEditOp(_EditOp op, {required bool reverse}) {
    final sm = _sm;
    if (sm == null) return;
    final row = sm.rows[op.rowIdx];
    final field = op.field;
    final newVal = reverse ? op.oldValue : op.newValue;
    final prevVal = row.cells[field]?.value;
    row.cells[field]?.value = newVal;
    _syncRowFromCells(op.rowIdx);
    _setCellError(op.rowIdx, field, null);
    final inv = _EditOp(rowIdx: op.rowIdx, field: field, oldValue: prevVal, newValue: newVal);
    if (reverse) {
      _redo.add(inv);
      if (_redo.length > _maxHistory) _redo.removeAt(0);
    } else {
      _undo.add(inv);
      if (_undo.length > _maxHistory) _undo.removeAt(0);
    }
  }

  void _undoOnce() {
    if (_undo.isEmpty) return;
    final op = _undo.removeLast();
    _applyEditOp(op, reverse: true);
  }

  void _redoOnce() {
    if (_redo.isEmpty) return;
    final op = _redo.removeLast();
    _applyEditOp(op, reverse: false);
  }

  // ==== Pegado multi-celda ====
  Future<void> _handlePaste() async {
    final sm = _sm;
    if (sm == null) return;
    final data = await Clipboard.getData('text/plain');
    final text = data?.text ?? '';
    if (text.trim().isEmpty) return;

    final lines = text.replaceAll('\r\n', '\n').split('\n').where((l) => l.isNotEmpty).toList();
    final matrix = lines.map((l) => l.split('\t')).toList();

    final startCell = sm.currentCell;
    final startRow = sm.currentRow;
    if (startCell == null || startRow == null) return;

    final startR = sm.rows.indexOf(startRow);
    final startC =
    sm.columns.indexOf(sm.columns.firstWhere((c) => c.field == startCell.column.field));
    final fields = sm.columns.map((c) => c.field).toList();

    final timer = Stopwatch()..start();
    for (int r = 0; r < matrix.length; r++) {
      final rr = startR + r;
      if (rr >= sm.rows.length) break;
      for (int c = 0; c < matrix[r].length; c++) {
        final cc = startC + c;
        if (cc >= fields.length) break;
        final field = fields[cc];
        if (field == _kPhotosCol || field == _kMapsCol) continue;
        final val = matrix[r][c];
        sm.rows[rr].cells[field]?.value = _coerceValue(field, val);
        _setCellError(rr, field, null);
      }
      if (r % 64 == 0) await Future<void>.delayed(Duration.zero);
    }
    _syncRowFromCells(startR);
    UsageAnalytics.instance.bump('paste_block');
    // log
    // ignore: avoid_print
    print('Paste block in ${timer.elapsedMilliseconds}ms');
  }

  dynamic _coerceValue(String field, String val) {
    if (field == MeasurementColumn.ohm1m || field == MeasurementColumn.ohm3m) {
      return double.tryParse(val.replaceAll(',', '.'));
    }
    if (field == MeasurementColumn.date) {
      try {
        if (val.contains('/')) {
          final p = val.split('/');
          if (p.length == 3) {
            final d = int.parse(p[0]);
            final m = int.parse(p[1]);
            final y = int.parse(p[2]);
            return DateTime(y, m, d);
          }
        } else {
          final dt = DateTime.tryParse(val);
          if (dt != null) return dt;
        }
      } catch (_) {}
      return null;
    }
    return val;
  }

  // ==== Autorrelleno simple ====
  Future<void> _autoFillPattern() async {
    final sm = _sm;
    if (sm == null) return;
    final rows = _selectedRowIndexes();
    if (rows.length < 2) return;

    String field = MeasurementColumn.progresiva;
    if (sm.currentCell?.column.field == MeasurementColumn.ohm1m ||
        sm.currentCell?.column.field == MeasurementColumn.ohm3m) {
      field = sm.currentCell!.column.field;
    }

    final values = rows.map((r) => sm.rows[r].cells[field]?.value).toList();
    if (field == MeasurementColumn.progresiva) {
      final prefix = _extractPrefix(values.first?.toString() ?? '');
      final nums = values.map((v) => _extractNumber(v?.toString() ?? '')).toList();
      if (nums.length >= 2 && nums[0] != null && nums[1] != null) {
        final delta = (nums[1]! - nums[0]!).toInt();
        var cur = nums[0]!;
        for (int i = 0; i < rows.length; i++) {
          sm.rows[rows[i]].cells[field]?.value = '$prefix${cur.toInt()}';
          cur += delta;
        }
      }
    } else {
      final n0 = (values.first as num?)?.toDouble();
      final n1 = (values[1] as num?)?.toDouble();
      if (n0 != null && n1 != null) {
        final delta = (rows.length <= 1) ? 0 : (n1 - n0);
        var cur = n0;
        for (int i = 0; i < rows.length; i++) {
          sm.rows[rows[i]].cells[field]?.value = cur;
          cur += delta;
        }
      }
    }
    _syncRowFromCells(rows.first);
  }

  String _extractPrefix(String s) {
    final m = RegExp(r'^([^\d]*)').firstMatch(s);
    return m?.group(1) ?? '';
  }

  double? _extractNumber(String s) {
    final m = RegExp(r'(\d+(\.\d+)?)').firstMatch(s);
    return m != null ? double.tryParse(m.group(1)!) : null;
  }

  // ==== Export selección a XLSX ====
  Future<File?> _exportSelectionToXlsx({String? fileName}) async {
    final rows = _selectedRowIndexes();
    if (rows.isEmpty) return null;

    final doc = xlsio.Workbook();
    final sheet = doc.worksheets[0];

    final headers = <String, String>{
      MeasurementColumn.progresiva: _titleFor(MeasurementColumn.progresiva, 'Progresiva'),
      MeasurementColumn.ohm1m: _titleFor(MeasurementColumn.ohm1m, '1m (Ω)'),
      MeasurementColumn.ohm3m: _titleFor(MeasurementColumn.ohm3m, '3m (Ω)'),
      MeasurementColumn.observations: _titleFor(MeasurementColumn.observations, 'Obs'),
      MeasurementColumn.date: _titleFor(MeasurementColumn.date, 'Fecha'),
    };
    final fields = headers.keys.toList();

    for (int c = 0; c < fields.length; c++) {
      sheet.getRangeByIndex(1, c + 1).setText(headers[fields[c]]!);
      sheet.getRangeByIndex(1, c + 1).cellStyle.bold = true;
    }

    final sm = _sm;
    if (sm == null) return null;

    for (int r = 0; r < rows.length; r++) {
      final rr = rows[r];
      for (int c = 0; c < fields.length; c++) {
        final field = fields[c];
        final cell = sm.rows[rr].cells[field];
        final v = cell?.value;
        final range = sheet.getRangeByIndex(r + 2, c + 1);
        if (v is num) {
          range.setNumber(v.toDouble());
        } else if (v is DateTime) {
          range.setDateTime(v);
          range.numberFormat = 'dd/mm/yyyy';
        } else {
          range.setText(v?.toString() ?? '');
        }
      }
    }

    for (int c = 1; c <= fields.length; c++) {
      sheet.autoFitColumn(c);
    }

    final bytes = doc.saveAsStream();
    doc.dispose();

    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/${fileName ?? 'gridnote_export'}.xlsx');
    await f.writeAsBytes(bytes, flush: true);

    UsageAnalytics.instance.bump('export_xlsx_selection');
    SmartNotifier.instance.info('Exportado ${rows.length} filas → ${f.path.split('/').last}');
    return f;
  }

  // ==== OCR/QR rápidos (portapapeles) ====
  Future<void> _quickOcrFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      SmartNotifier.instance.warn('Portapapeles vacío');
      return;
    }
    final parts = text.split(RegExp(r'[\s,;|]+')).where((s) => s.isNotEmpty).toList();
    final sm = _sm;
    final row = sm?.currentRow;
    if (row == null || sm == null) return;
    final idx = sm.rows.indexOf(row);
    if (idx < 0) return;

    if (parts.isNotEmpty) {
      row.cells[MeasurementColumn.progresiva]?.value = parts[0];
    }
    if (parts.length > 1) {
      row.cells[MeasurementColumn.ohm1m]?.value = double.tryParse(parts[1].replaceAll(',', '.'));
    }
    if (parts.length > 2) {
      row.cells[MeasurementColumn.ohm3m]?.value = double.tryParse(parts[2].replaceAll(',', '.'));
    }
    if (parts.length > 3) {
      row.cells[MeasurementColumn.observations]?.value = parts.sublist(3).join(' ');
    }
    _syncRowFromCells(idx);
    SmartNotifier.instance.success('Texto pegado en fila');
    UsageAnalytics.instance.bump('ocr_clipboard_apply');
  }

  Future<void> _quickQrFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      SmartNotifier.instance.warn('Portapapeles vacío');
      return;
    }
    final sm = _sm;
    final row = sm?.currentRow;
    if (row == null || sm == null) return;
    final idx = sm.rows.indexOf(row);
    if (idx < 0) return;
    row.cells[MeasurementColumn.progresiva]?.value = text;
    _syncRowFromCells(idx);
    SmartNotifier.instance.success('Código aplicado a Progresiva');
    UsageAnalytics.instance.bump('qr_clipboard_apply');
  }

  // ==== Validación UI helpers ====
  void _setCellError(int rowIdx, String field, String? msg) {
    final m = _cellError.putIfAbsent(rowIdx, () => <String, String>{});
    if (msg == null) {
      m.remove(field);
    } else {
      m[field] = msg;
    }
    if (mounted) setState(() {});
  }

  // ==== Build ====
  @override
  Widget build(BuildContext context) {
    final t = widget.themeController.theme;
    final table = GridnoteTableStyle.from(t);

    final config = PlutoGridConfiguration(
      enterKeyAction: PlutoGridEnterKeyAction.editingAndMoveRight,
      style: PlutoGridStyleConfig(
        gridBorderColor: table.gridLine,
        rowHeight: kLowSpec ? 44 : 50,
        columnHeight: kLowSpec ? 44 : 50,
        cellTextStyle: TextStyle(
            fontFamily: _fontFamily, fontSize: 14, color: t.text, fontFeatures: _fontFeatures),
        columnTextStyle: TextStyle(
            fontFamily: _fontFamily, fontSize: 13, fontWeight: FontWeight.w700, color: t.text, fontFeatures: _fontFeatures),
        cellColorInEditState: table.cellBg,
        cellColorInReadOnlyState: table.cellBg,
        activatedColor: table.selection.withValues(alpha: 0.22),
        activatedBorderColor: table.selection,
        gridBackgroundColor: table.cellBg,
        oddRowColor: kLowSpec ? null : table.altCellBg,
        evenRowColor: table.cellBg,
      ),
    );

    final grid = RepaintBoundary(
      child: KeyboardListener(
        focusNode: _kbdFocus,
        onKeyEvent: (KeyEvent evt) {
          if (evt is! KeyDownEvent) return;
          final ctrlOrCmd =
              HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;
          if (ctrlOrCmd && evt.logicalKey == LogicalKeyboardKey.keyV) {
            unawaited(_handlePaste());
          } else if (ctrlOrCmd && evt.logicalKey == LogicalKeyboardKey.keyZ) {
            _undoOnce();
          } else if (ctrlOrCmd &&
              (evt.logicalKey == LogicalKeyboardKey.keyY ||
                  (HardwareKeyboard.instance.isShiftPressed &&
                      evt.logicalKey == LogicalKeyboardKey.keyZ))) {
            _redoOnce();
          }
        },
        child: PlutoGrid(
          columns: _columns,
          rows: _plutoRows,
          configuration: config,
          onLoaded: (evt) {
            _sm = evt.stateManager;
            final sm = _sm!;
            sm
              ..setSelectingMode(PlutoGridSelectingMode.cell)
              ..setKeepFocus(true)
              ..setAutoEditing(true);
            sm.addListener(() {
              _scheduleRefreshRail();
              if (widget.showMetricsFooter) _recalcSelectionStats();
            });

            // 👇 Bridge para actividad de edición/teclado
            _bridge = PlutoEditActivityBridge(sm);

            final preload = math.min(_rows.length, kLowSpec ? 6 : 12);
            for (var i = 0; i < preload; i++) {
              unawaited(_ensurePhotoCount(i));
            }
            if ((widget.filterQuery ?? '').isNotEmpty) {
              _applyFilter(widget.filterQuery!);
            }
            _refreshRail(forced: true);
            Future.delayed(const Duration(milliseconds: 50), () {
              if (mounted) FocusScope.of(context).requestFocus(_kbdFocus);
            });
          },
          onChanged: (evt) async {
            HapticFeedback.selectionClick();
            _patchRowFromEvent(evt);
            UsageAnalytics.instance.bump('edit_${evt.column.field}');

            // 🔊 Marca de tipeo para la IA de UX
            _bridge?.handleOnChanged(evt);

            await _maybeRunAiSuggestion(evt);
          },
        ),
      ),
    );

    final content = widget.showPhotoRail
        ? LayoutBuilder(
      builder: (_, c) {
        final showRail = c.maxWidth >= 540;
        if (!showRail) return grid;

        final railShell = _buildRailShell(t, table);

        return Row(children: [
          Expanded(child: grid),
          RepaintBoundary(
            child: kLowSpec
                ? railShell
                : Stack(children: [
              Positioned.fill(
                  child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: const SizedBox())),
              railShell,
            ]),
          ),
        ]);
      },
    )
        : grid;

    if (!widget.showMetricsFooter) return content;

    final footer = _buildFooterBar(t);
    return Column(children: [Expanded(child: content), footer]);
  }

  Widget _buildRailShell(GridnoteTheme t, GridnoteTableStyle table) {
    return Container(
      width: 128,
      margin: const EdgeInsets.fromLTRB(6, 6, 6, 6),
      decoration: BoxDecoration(
        border: Border.all(color: table.gridLine),
        borderRadius: BorderRadius.circular(14),
        color: t.surface.withValues(alpha: .70),
        boxShadow: kLowSpec
            ? const []
            : const [BoxShadow(blurRadius: 10, color: Color(0x22000000), offset: Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: table.gridLine)),
              color: t.surface.withValues(alpha: .75),
            ),
            child: Row(
              children: [
                const Icon(Icons.photo_outlined, size: 18),
                const SizedBox(width: 6),
                Text('Fotos', style: TextStyle(fontWeight: FontWeight.w700, color: t.text)),
                const Spacer(),
                Switch.adaptive(
                  value: _railGeoTag,
                  onChanged: (v) => setState(() => _railGeoTag = v),
                  thumbColor: WidgetStatePropertyAll(t.accent),
                  trackColor: WidgetStatePropertyAll(t.accent.withValues(alpha: .35)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),
          Expanded(
            child: _railLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _railFiles.isEmpty
                ? Center(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text('Sin fotos',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: t.text.withValues(alpha: .7))),
              ),
            )
                : ScrollConfiguration(
              behavior: const _BounceBehavior(),
              child: GridView.builder(
                padding: const EdgeInsets.all(6),
                physics: const BouncingScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                ),
                itemCount: _railFiles.length,
                itemBuilder: (_, i) {
                  final f = _railFiles[i];
                  return InkWell(
                    onTap: () => OpenFilex.open(f.path),
                    borderRadius: BorderRadius.circular(10),
                    child: ClipRRect(borderRadius: BorderRadius.circular(10), child: _imgThumb(f)),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: t.accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onPressed: _railAddPhoto,
                icon: const Icon(Icons.add_a_photo_outlined),
                label: const Text('Agregar'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterBar(GridnoteTheme t) {
    final hasSel = _selectedRowIndexes().isNotEmpty;
    final buttons = <Widget>[
      _ToolBtn(icon: Icons.calculate_outlined, label: 'Prom/Min/Max', onTap: () {
        _recalcSelectionStats();
        final msg = _stats.describe();
        SmartNotifier.instance.info(msg);
      }),
      _ToolBtn(icon: Icons.today_outlined, label: 'Hoy', onTap: _fillTodayOnSelection),
      _ToolBtn(icon: Icons.format_list_numbered, label: 'Autonum', onTap: () => _autoNumberProgresiva(prefix: '', startAt: 1)),
      _ToolBtn(icon: Icons.auto_fix_high_outlined, label: 'Autorrellenar', onTap: _autoFillPattern),
      _ToolBtn(icon: Icons.place_outlined, label: 'GPS', onTap: () async {
        final idxs = _selectedRowIndexes();
        if (idxs.isEmpty) return;
        await _captureLocationForRow(idxs.first);
      }),
      _ToolBtn(icon: Icons.add_a_photo_outlined, label: 'Foto', onTap: _addPhotoSelected),
      _ToolBtn(icon: Icons.content_paste, label: 'Pegar', onTap: _handlePaste),
      _ToolBtn(icon: Icons.document_scanner_outlined, label: 'OCR (pegar)', onTap: _quickOcrFromClipboard),
      _ToolBtn(icon: Icons.qr_code_scanner, label: 'QR (pegar)', onTap: _quickQrFromClipboard),
      _ToolBtn(icon: Icons.save_outlined, label: 'Vista', onTap: _saveView),
      _ToolBtn(
          icon: Icons.ios_share_outlined,
          label: 'XLSX sel.',
          onTap: () async {
            final file = await _exportSelectionToXlsx();
            if (file != null) Share.shareXFiles([XFile(file.path)]);
          }),
      _ToolBtn(icon: Icons.undo, label: 'Undo', onTap: _undoOnce),
      _ToolBtn(icon: Icons.redo, label: 'Redo', onTap: _redoOnce),
    ];

    final metrics = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(_stats.short(),
          style: TextStyle(fontWeight: FontWeight.w700, color: t.text.withValues(alpha: .9))),
    );

    return Material(
      color: t.surface.withValues(alpha: .78),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              metrics,
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: buttons
                        .map((b) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: hasSel ? b : _ToolBtn.disabled(),
                    ))
                        .toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==== AI sugerencias ====
  Future<void> _maybeRunAiSuggestion(PlutoGridOnChangedEvent evt) async {
    if (!widget.aiEnabled) return;
    final a = _assistant;
    if (a == null) return;
    if (_applyingSuggestion) return;

    final sm = _sm;
    if (sm == null) return;
    final rowIdx = sm.rows.indexOf(evt.row);
    if (rowIdx < 0) return;

    final ctx = AiCellContext(
      sheetId: widget.meta.id,
      rowIndex: rowIdx,
      columnName: evt.column.field,
      rawInput: evt.value,
      rows: List<Measurement>.from(_rows),
    );

    final res = await a.transform(ctx);
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
      final msg = !same ? "Quizás quisiste decir: $suggested" : (hint ?? 'Sugerencia disponible');
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

// ==== Scaffolding menor ====
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

class _SavedTick extends StatelessWidget {
  const _SavedTick({required this.theme});
  final GridnoteTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.surface.withValues(alpha: .90),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(blurRadius: 28, color: Color(0x33000000))],
        border: Border.all(color: theme.accent.withValues(alpha: .35)),
      ),
      child: Icon(Icons.check_circle_rounded, size: 74, color: theme.accent),
    );
  }
}

class _SelectionStats {
  final int count;
  final double? min;
  final double? max;
  final double? avg;
  const _SelectionStats({required this.count, this.min, this.max, this.avg});
  const _SelectionStats.empty() : this(count: 0);

  String short() {
    if (count == 0) return '0 sel.';
    final b = StringBuffer()..write('Sel: $count');
    if (avg != null) b.write(' · Prom ${avg!.toStringAsFixed(3)}Ω');
    if (min != null && max != null) b.write(' · Min ${min!.toStringAsFixed(3)} · Max ${max!.toStringAsFixed(3)}');
    return b.toString();
  }

  String describe() {
    if (count == 0) return 'Sin selección';
    final lines = <String>['Filas: $count'];
    if (avg != null) lines.add('Promedio: ${avg!.toStringAsFixed(3)} Ω');
    if (min != null) lines.add('Mínimo: ${min!.toStringAsFixed(3)} Ω');
    if (max != null) lines.add('Máximo: ${max!.toStringAsFixed(3)} Ω');
    return lines.join(' · ');
  }
}

class _EditOp {
  final int rowIdx;
  final String field;
  final dynamic oldValue;
  final dynamic newValue;
  _EditOp({required this.rowIdx, required this.field, required this.oldValue, required this.newValue});
}

class _SavedView {
  final String id; // meta.id
  final Map<String, double> colWidths;
  final List<String> order;

  _SavedView({required this.id, required this.colWidths, required this.order});

  static _SavedView capture(String id, PlutoGridStateManager sm) {
    final widths = <String, double>{};
    for (final c in sm.refColumns) {
      widths[c.field] = c.width;
    }
    final order = sm.refColumns.originalList.map((c) => c.field).toList();
    return _SavedView(id: id, colWidths: widths, order: order);
  }

  String encode() {
    final parts = <String>[];
    parts.add(id);
    parts.add(colWidths.entries.map((e) => '${e.key}:${e.value.toStringAsFixed(2)}').join(','));
    parts.add(order.join(','));
    return parts.join('|');
  }

  static _SavedView decode(String s) {
    final p = s.split('|');
    final id = p[0];
    final widths = <String, double>{};
    if (p.length > 1 && p[1].isNotEmpty) {
      for (final kv in p[1].split(',')) {
        final i = kv.indexOf(':');
        if (i > 0) {
          widths[kv.substring(0, i)] = double.tryParse(kv.substring(i + 1)) ?? 120.0;
        }
      }
    }
    final order = (p.length > 2 && p[2].isNotEmpty) ? p[2].split(',') : <String>[];
    return _SavedView(id: id, colWidths: widths, order: order);
  }
}

class _ToolBtn extends StatelessWidget {
  const _ToolBtn({this.icon, this.label, this.onTap});
  final IconData? icon;
  final String? label;
  final VoidCallback? onTap;

  static Widget disabled() => const Opacity(opacity: .35, child: _ToolBtn(icon: Icons.block, label: '—'));

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: SizedBox(
        height: 44,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Icon(icon, size: 18),
                  const SizedBox(width: 6),
                  Text(label ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
