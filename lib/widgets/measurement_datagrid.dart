// lib/widgets/measurement_datagrid.dart
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

import '../models/measurement.dart';
import '../models/sheet_meta.dart';
import '../theme/gridnote_theme.dart';
import 'measurement_datasource.dart';
import 'measurement_row_editor.dart';

/// Nombres de columnas centralizados
class MeasurementColumn {
  static const String index = '_rowIndex';
  static const String progresiva = 'progresiva';
  static const String ohm1m = 'ohm1m';
  static const String ohm3m = 'ohm3m';
  static const String observations =
      'observations'; // fallback a 'obs' si la DS usa ese nombre
  static const String date = 'date';
  static const String maps = 'maps';
  static const String edit = '_edit';
  // Opcionales que puede exponer tu DataSource aunque no se muestren
  static const String id = 'id';
  static const String lat = 'lat';
  static const String lon = 'lon';
}

/// Breakpoints y alturas (evitan "números mágicos")
const double kCompactLayoutBreakpoint = 720.0;
const double kCompactRowHeight = 52.0;
const double kRegularRowHeight = 44.0;
const double kCompactHeaderHeight = 54.0;
const double kRegularHeaderHeight = 46.0;

// Paleta de headers (eliminá si ya existe en tu tema)
extension GridnoteHeaderPalette on GridnoteTableStyle {
  Color get indexHeaderBg => const Color(0xFFE7F3EC);
  Color get progressiveHeaderBg => const Color(0xFFE7F3EC);
  Color get ohm1mHeaderBg => const Color(0xFFFCE7DF);
  Color get ohm3mHeaderBg => const Color(0xFFE6F3F8);
  Color get obsHeaderBg => const Color(0xFFFCE7DF);
}

class MeasurementGridController {
  List<Measurement> Function()? _snapshotGetter;
  VoidCallback? _undoFn;
  VoidCallback? _redoFn;
  bool Function()? _canUndoGetter;
  bool Function()? _canRedoGetter;

  List<Measurement> snapshot() =>
      _snapshotGetter?.call() ?? const <Measurement>[];
  void undo() => _undoFn?.call();
  void redo() => _redoFn?.call();
  bool get canUndo => _canUndoGetter?.call() ?? false;
  bool get canRedo => _canRedoGetter?.call() ?? false;
}

class MeasurementDataGrid extends StatefulWidget {
  const MeasurementDataGrid({
    super.key,
    required this.meta,
    required this.initial,
    required this.themeController,
    required this.onUpdateRow, // ← callback requerido para aplicar cambios
    this.controller,
    this.onSelectionChanged,
    this.autoWidth = false,
    this.pullToRefresh = false,
    this.enablePager = false,
    this.rowsPerPage = 25,
    this.onOpenMaps,
    this.onDeleteRow,
    this.onDuplicateRow,
  });

  final SheetMeta meta;
  final List<Measurement> initial;
  final GridnoteThemeController themeController;
  final MeasurementGridController? controller;
  final void Function(List<DataGridRow>, List<DataGridRow>)? onSelectionChanged;
  final bool autoWidth;
  final bool pullToRefresh;
  final bool enablePager;
  final int rowsPerPage;
  final void Function(Measurement m)? onOpenMaps;

  /// Recibe el Measurement actualizado desde el editor
  final ValueChanged<Measurement> onUpdateRow;
  final ValueChanged<Measurement>? onDeleteRow;
  final ValueChanged<Measurement>? onDuplicateRow;

  @override
  State<MeasurementDataGrid> createState() => _MeasurementDataGridState();
}

class _MeasurementDataGridState extends State<MeasurementDataGrid> {
  late final DataGridController _dg;
  late MeasurementDataSource _source;

  _StyleSig? _lastStyle; // cache de estilo

  @override
  void initState() {
    super.initState();
    _dg = DataGridController();
    _source = MeasurementDataSource(
      widget.initial,
      rowsPerPage: widget.rowsPerPage,
      showIndexColumn: true,
      onTapMaps: widget.onOpenMaps,
    );
    _attachController();
  }

  @override
  void didUpdateWidget(covariant MeasurementDataGrid oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!identical(oldWidget.initial, widget.initial)) {
      _source.updateData(widget.initial);
    }
    if (oldWidget.rowsPerPage != widget.rowsPerPage) {
      _source.setRowsPerPage(widget.rowsPerPage);
    }
    if (oldWidget.controller != widget.controller) {
      _detachController(oldWidget.controller);
      _attachController();
    }
    _source.onTapMaps = widget.onOpenMaps;
  }

  void _attachController() {
    widget.controller?._snapshotGetter = _source.exportSnapshot;
    widget.controller?._undoFn = _source.undo;
    widget.controller?._redoFn = _source.redo;
    widget.controller?._canUndoGetter = () => _source.canUndo;
    widget.controller?._canRedoGetter = () => _source.canRedo;
  }

  void _detachController(MeasurementGridController? controller) {
    controller?._snapshotGetter = null;
    controller?._undoFn = null;
    controller?._redoFn = null;
    controller?._canUndoGetter = null;
    controller?._canRedoGetter = null;
  }

  @override
  void dispose() {
    _detachController(widget.controller);
    _dg.dispose();
    super.dispose();
  }

  Widget _header(String text, Color bg, GridnoteTableStyle table,
      {FontWeight fw = FontWeight.w700}) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: table.gridLine, width: 1.0)),
      ),
      child: Text(
        text,
        style: TextStyle(fontWeight: fw, color: table.headerText),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
      ),
    );
  }

  void _applyStyleIfNeeded(GridnoteTableStyle table) {
    final sig = _StyleSig(
      gridLine: table.gridLine,
      cellBg: table.cellBg,
      cellBgAlt: table.cellBgAlt,
      cellText: table.cellText,
    );
    if (sig == _lastStyle) return;
    _lastStyle = sig;

    _source.applyStyle(
      rowColor: table.cellBg,
      altRowColor: table.cellBgAlt,
      cellTextStyle: TextStyle(color: table.cellText),
      cellPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      indexTextStyle:
          TextStyle(color: table.cellText, fontWeight: FontWeight.w600),
      indexWidth: 44.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < kCompactLayoutBreakpoint;
    final double rowH = compact ? kCompactRowHeight : kRegularRowHeight;
    final double headerH =
        compact ? kCompactHeaderHeight : kRegularHeaderHeight;

    // En SfDataPager, pageCount es double en varias versiones.
    final double pageCount = (_source.itemCount == 0)
        ? 1.0
        : (((_source.itemCount + widget.rowsPerPage - 1) ~/ widget.rowsPerPage)
            .toDouble());

    return AnimatedBuilder(
      animation: widget.themeController,
      builder: (_, __) {
        final t = widget.themeController.theme;
        final table = GridnoteTableStyle.from(t);

        _applyStyleIfNeeded(table);

        final widthMode = widget.autoWidth
            ? ColumnWidthMode.fitByColumnName
            : ColumnWidthMode.none;

        return Column(
          children: [
            Expanded(
              child: Container(
                color: table.cellBg,
                child: SfDataGridTheme(
                  data: SfDataGridThemeData(
                    gridLineColor: table.gridLine,
                    headerHoverColor: table.headerBg,
                    rowHoverColor: table.cellBgAlt,
                    selectionColor: Colors.transparent,
                  ),
                  child: SfDataGrid(
                    source: _source,
                    controller: _dg,
                    frozenColumnsCount: 1,
                    footerFrozenRowsCount: 0,
                    allowEditing: true,
                    editingGestureType: EditingGestureType.tap,
                    allowSorting: true,
                    allowFiltering: true,
                    sortingGestureType: SortingGestureType.tap,
                    headerGridLinesVisibility: GridLinesVisibility.both,
                    gridLinesVisibility: GridLinesVisibility.both,
                    columnWidthMode: widthMode,
                    rowHeight: rowH,
                    headerRowHeight: headerH,
                    selectionMode: SelectionMode.single,
                    navigationMode: GridNavigationMode.cell,
                    allowPullToRefresh: widget.pullToRefresh,
                    onSelectionChanged: widget.onSelectionChanged,
                    onCellTap: (DataGridCellTapDetails details) async {
                      final rci = details.rowColumnIndex;
                      if (rci.rowIndex <= 0) return; // header
                      // En versiones recientes, column es no-nullable
                      if (details.column.columnName != MeasurementColumn.edit) {
                        return;
                      }
                      final int dataRowIndex = rci.rowIndex - 1;
                      if (dataRowIndex >= _source.effectiveRows.length) return;
                      final DataGridRow row =
                          _source.effectiveRows[dataRowIndex];
                      final m = _rowToMeasurement(row);
                      await MeasurementRowEditor.show(
                        context,
                        initial: m,
                        onSave: widget.onUpdateRow,
                        onDelete: widget.onDeleteRow,
                        onDuplicate: widget.onDuplicateRow,
                      );
                    },
                    columns: [
                      GridColumn(
                        width: 44.0,
                        columnName: MeasurementColumn.index,
                        label: _header('A', table.indexHeaderBg, table,
                            fw: FontWeight.w600),
                        allowFiltering: false,
                        allowSorting: false,
                      ),
                      GridColumn(
                        columnName: MeasurementColumn.progresiva,
                        label: _header(
                            'Progresiva', table.progressiveHeaderBg, table),
                        allowEditing: true,
                      ),
                      GridColumn(
                        columnName: MeasurementColumn.ohm1m,
                        label: _header('1 m Ω', table.ohm1mHeaderBg, table),
                        allowEditing: true,
                      ),
                      GridColumn(
                        columnName: MeasurementColumn.ohm3m,
                        label: _header('3 m Ω', table.ohm3mHeaderBg, table),
                        allowEditing: true,
                      ),
                      GridColumn(
                        columnName: MeasurementColumn.observations,
                        label: _header('Obs', table.obsHeaderBg, table),
                        allowEditing: true,
                      ),
                      GridColumn(
                        columnName: MeasurementColumn.date,
                        label: _header('Fecha', table.headerBg, table),
                        allowEditing: true,
                      ),
                      GridColumn(
                        width: 72.0,
                        columnName: MeasurementColumn.maps,
                        label: _header('Mapas', table.headerBg, table),
                        allowFiltering: false,
                        allowSorting: false,
                      ),
                      // Columna ✎ sin GridWidgetColumn para máxima compatibilidad
                      GridColumn(
                        width: 56.0,
                        columnName: MeasurementColumn.edit,
                        label: Center(
                          child: Text('✎',
                              style: TextStyle(
                                  color: table.headerText,
                                  fontWeight: FontWeight.w700)),
                        ),
                        allowFiltering: false,
                        allowSorting: false,
                        allowEditing: false,
                      ),
                    ],
                    tableSummaryRows: <GridTableSummaryRow>[
                      GridTableSummaryRow(
                        position: GridTableSummaryRowPosition.bottom,
                        showSummaryInRow: false,
                        columns: const <GridSummaryColumn>[
                          GridSummaryColumn(
                              name: 'sum1',
                              columnName: MeasurementColumn.ohm1m,
                              summaryType: GridSummaryType.sum),
                          GridSummaryColumn(
                              name: 'avg1',
                              columnName: MeasurementColumn.ohm1m,
                              summaryType: GridSummaryType.average),
                          GridSummaryColumn(
                              name: 'sum3',
                              columnName: MeasurementColumn.ohm3m,
                              summaryType: GridSummaryType.sum),
                          GridSummaryColumn(
                              name: 'avg3',
                              columnName: MeasurementColumn.ohm3m,
                              summaryType: GridSummaryType.average),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (widget.enablePager)
              SfDataPager(
                delegate: _source,
                pageCount: pageCount,
                direction: Axis.horizontal,
              ),
          ],
        );
      },
    );
  }

  // ---- Helpers ----
  T? _cell<T>(DataGridRow row, String name) {
    final cells = row.getCells();
    for (final c in cells) {
      if (c.columnName == name) return c.value as T?;
    }
    return null;
  }

  Measurement _rowToMeasurement(DataGridRow row) {
    // Soporta nombres alternativos (obs/observations) y columnas no visibles (lat/lon/id)
    final id = _cell<int?>(row, MeasurementColumn.id);
    final progresiva = _cell<String>(row, MeasurementColumn.progresiva) ?? '';
    final double ohm1 =
        (_cell<num?>(row, MeasurementColumn.ohm1m)?.toDouble()) ?? 0.0;
    final double ohm3 =
        (_cell<num?>(row, MeasurementColumn.ohm3m)?.toDouble()) ?? 0.0;
    final obs = _cell<String>(row, MeasurementColumn.observations) ??
        _cell<String>(row, 'obs') ??
        '';
    final date =
        _cell<DateTime?>(row, MeasurementColumn.date) ?? DateTime.now();
    final double lat =
        (_cell<num?>(row, MeasurementColumn.lat)?.toDouble()) ?? 0.0;
    final double lon =
        (_cell<num?>(row, MeasurementColumn.lon)?.toDouble()) ?? 0.0;

    return Measurement(
      id: id,
      progresiva: progresiva,
      ohm1m: ohm1,
      ohm3m: ohm3,
      observations: obs,
      date: date,
      latitude: lat,
      longitude: lon,
    );
  }
}

@immutable
class _StyleSig {
  const _StyleSig({
    required this.gridLine,
    required this.cellBg,
    required this.cellBgAlt,
    required this.cellText,
  });

  final Color gridLine;
  final Color cellBg;
  final Color cellBgAlt;
  final Color cellText;

  @override
  bool operator ==(Object other) {
    return other is _StyleSig &&
        other.gridLine == gridLine &&
        other.cellBg == cellBg &&
        other.cellBgAlt == cellBgAlt &&
        other.cellText == cellText;
  }

  @override
  int get hashCode => Object.hash(gridLine, cellBg, cellBgAlt, cellText);
}
