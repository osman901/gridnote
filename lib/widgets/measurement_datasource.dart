// lib/widgets/measurement_datasource.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../models/measurement.dart';

class MeasurementDataSource extends DataGridSource {
  MeasurementDataSource(
    List<Measurement> data, {
    int rowsPerPage = 10,
    this.showIndexColumn = false,
    this.rowColor,
    this.altRowColor,
    this.cellTextStyle,
    this.cellPadding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.indexTextStyle,
    this.indexWidth = 44,
    this.minVisibleRows = 20,
    this.onTapMaps,
  })  : _all = List<Measurement>.from(data),
        _rowsPerPage = rowsPerPage {
    _rebuildSlice();
  }

  final List<Measurement> _all;
  late List<DataGridRow> _rows;
  int _rowsPerPage;
  int _startIndex = 0;

  final bool showIndexColumn;
  Color? rowColor;
  Color? altRowColor;
  TextStyle? cellTextStyle;
  EdgeInsets cellPadding;
  TextStyle? indexTextStyle;
  double indexWidth;
  final int minVisibleRows;

  void Function(Measurement m)? onTapMaps;

  Object? _pendingValue;

  // ===== Undo / Redo =====
  final List<_EditOp> _undo = <_EditOp>[];
  final List<_EditOp> _redo = <_EditOp>[];

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  // Total real de ítems (para el pager)
  int get itemCount => _all.length;

  void undo() {
    if (_undo.isEmpty) return;
    final op = _undo.removeLast();
    _applyEdit(op.index, op.column, op.oldValue, pushTo: _redo, asNew: false);
  }

  void redo() {
    if (_redo.isEmpty) return;
    final op = _redo.removeLast();
    _applyEdit(op.index, op.column, op.newValue, pushTo: _undo, asNew: false);
  }

  void _applyEdit(int index, String column, dynamic value,
      {List<_EditOp>? pushTo, required bool asNew}) {
    if (index < 0 || index >= _all.length) return;
    final m = _all[index];
    dynamic oldVal;

    switch (column) {
      case 'progresiva':
        oldVal = m.progresiva;
        m.progresiva = (value ?? '').toString();
        break;
      case 'ohm1m':
        oldVal = m.ohm1m;
        m.ohm1m = _toNum(value)?.toDouble() ?? m.ohm1m;
        break;
      case 'ohm3m':
        oldVal = m.ohm3m;
        m.ohm3m = _toNum(value)?.toDouble() ?? m.ohm3m;
        break;
      case 'observations':
        oldVal = m.observations;
        m.observations = (value ?? '').toString();
        break;
      case 'date':
        oldVal = m.date;
        final d = _parseDate(value);
        if (d != null) m.date = d;
        break;
    }

    if (pushTo != null) {
      if (asNew) pushTo.clear();
      pushTo.add(_EditOp(index, column, oldVal, value));
    }

    _rebuildSlice();
    notifyListeners();
  }

  // ===== Estilo =====
  void applyStyle({
    Color? rowColor,
    Color? altRowColor,
    TextStyle? cellTextStyle,
    EdgeInsets? cellPadding,
    TextStyle? indexTextStyle,
    double? indexWidth,
  }) {
    this.rowColor = rowColor ?? this.rowColor;
    this.altRowColor = altRowColor ?? this.altRowColor;
    this.cellTextStyle = cellTextStyle ?? this.cellTextStyle;
    this.cellPadding = cellPadding ?? this.cellPadding;
    this.indexTextStyle = indexTextStyle ?? this.indexTextStyle;
    this.indexWidth = indexWidth ?? this.indexWidth;
    notifyListeners();
  }

  @override
  List<DataGridRow> get rows => _rows;

  int indexOf(DataGridRow row) => _rows.indexOf(row) + _startIndex;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final visibleIndex = _rows.indexOf(row);
    final globalIndex = _startIndex + visibleIndex;
    final bg = (visibleIndex.isEven ? rowColor : altRowColor);

    final m = (globalIndex < _all.length) ? _all[globalIndex] : null;

    final cellsWidgets = <Widget>[];

    if (showIndexColumn) {
      cellsWidgets.add(
        Container(
          alignment: Alignment.center,
          width: indexWidth,
          color: bg,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('${globalIndex + 1}',
              style: indexTextStyle ?? cellTextStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
      );
    }

    for (final c in row.getCells()) {
      if (c.columnName == 'maps') {
        final hasCoords = m?.latitude != null && m?.longitude != null;
        cellsWidgets.add(
          Container(
            alignment: Alignment.center,
            color: bg,
            child: IconButton(
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              tooltip: hasCoords ? 'Abrir en Maps' : 'Sin ubicación',
              onPressed:
                  (hasCoords && m != null) ? () => onTapMaps?.call(m) : null,
            ),
          ),
        );
        continue;
      }
      if (c.columnName == '_edit') {
        cellsWidgets.add(
          Container(
            alignment: Alignment.center,
            color: bg,
            child: const Icon(Icons.edit, size: 18),
          ),
        );
        continue;
      }

      cellsWidgets.add(
        Container(
          alignment: Alignment.centerLeft,
          color: bg,
          padding: cellPadding,
          child: Text('${c.value ?? ''}',
              style: cellTextStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
      );
    }

    return DataGridRowAdapter(cells: cellsWidgets);
  }

  TextEditingController? _editingController;

  @override
  Widget? buildEditWidget(
    DataGridRow dataGridRow,
    RowColumnIndex rowColumnIndex,
    GridColumn column,
    CellSubmit submitCell,
  ) {
    if (column.columnName == 'maps' || column.columnName == '_edit') {
      return null;
    }

    final String columnName = column.columnName;
    final Object? currentValue = dataGridRow
        .getCells()
        .firstWhere((c) => c.columnName == columnName)
        .value;

    final visibleIndex = rowColumnIndex.rowIndex - 1;
    final bg = (visibleIndex.isEven ? rowColor : altRowColor);

    final isNumeric = columnName == 'ohm1m' || columnName == 'ohm3m';
    _editingController =
        TextEditingController(text: currentValue?.toString() ?? '');
    _pendingValue = _editingController!.text;

    return Container(
      alignment: Alignment.centerLeft,
      color: bg,
      padding: cellPadding,
      child: TextField(
        controller: _editingController,
        autofocus: true,
        keyboardType: isNumeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        // Regex sin escapes redundantes y con '-' seguro dentro del set
        inputFormatters: isNumeric
            ? <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'[0-9,.\-]'))
              ]
            : null,
        textInputAction: TextInputAction.done,
        style: cellTextStyle,
        autocorrect: false,
        enableSuggestions: false,
        smartDashesType: SmartDashesType.disabled,
        smartQuotesType: SmartQuotesType.disabled,
        scrollPadding: EdgeInsets.zero,
        decoration: const InputDecoration(
            isCollapsed: true, border: InputBorder.none, counterText: ''),
        onChanged: (v) => _pendingValue = v,
        onSubmitted: (_) => submitCell(),
        onTapOutside: (_) => submitCell(),
      ),
    );
  }

  // Nota: según tu versión del package, este getter puede no existir en la superclase.
  // Lo dejamos sin @override para evitar el error de “doesn't override”.
  int get rowCount => max(_all.length, minVisibleRows);

  @override
  Future<bool> handlePageChange(int oldPageIndex, int newPageIndex) async {
    _startIndex = newPageIndex * _rowsPerPage;
    _rebuildSlice();
    notifyListeners();
    return true;
  }

  @override
  Future<void> onCellSubmit(
    DataGridRow dataGridRow,
    RowColumnIndex rowColumnIndex,
    GridColumn column,
  ) async {
    final dynamic newValue = _pendingValue;
    _pendingValue = null;

    final int globalIndex = _startIndex + _rows.indexOf(dataGridRow);
    final bool isGhost = globalIndex >= _all.length;

    Measurement m;
    if (isGhost) {
      m = Measurement(
        progresiva: '',
        ohm1m: 0,
        ohm3m: 0,
        observations: '',
        date: DateTime.now(),
      );
      _all.insert(globalIndex.clamp(0, _all.length), m);
    } else {
      m = _all[globalIndex];
    }

    dynamic oldV;
    switch (column.columnName) {
      case 'progresiva':
        oldV = m.progresiva;
        break;
      case 'ohm1m':
        oldV = m.ohm1m;
        break;
      case 'ohm3m':
        oldV = m.ohm3m;
        break;
      case 'observations':
        oldV = m.observations;
        break;
      case 'date':
        oldV = m.date;
        break;
    }

    _applyEdit(globalIndex, column.columnName, newValue,
        pushTo: _undo, asNew: true);
    if (_undo.isNotEmpty) {
      _undo[_undo.length - 1] =
          _EditOp(globalIndex, column.columnName, oldV, newValue);
      _redo.clear();
    }
  }

  @override
  Future<void> sort() async {
    if (sortedColumns.isEmpty) {
      _rebuildSlice();
      notifyListeners();
      return;
    }

    int compareBy(SortColumnDetails s, Measurement a, Measurement b) {
      int r = 0;
      switch (s.name) {
        case 'progresiva':
          r = a.progresiva.compareTo(b.progresiva);
          break;
        case 'ohm1m':
          r = a.ohm1m.compareTo(b.ohm1m);
          break;
        case 'ohm3m':
          r = a.ohm3m.compareTo(b.ohm3m);
          break;
        case 'observations':
          r = a.observations.compareTo(b.observations);
          break;
        case 'date':
          r = a.date.compareTo(b.date);
          break;
      }
      return s.sortDirection == DataGridSortDirection.ascending ? r : -r;
    }

    _all.sort((a, b) {
      for (final s in sortedColumns) {
        final r = compareBy(s, a, b);
        if (r != 0) return r;
      }
      return 0;
    });

    _rebuildSlice();
    notifyListeners();
  }

  void updateData(List<Measurement> items) {
    _all
      ..clear()
      ..addAll(items);
    _startIndex =
        min(_startIndex, max(0, max(_all.length, minVisibleRows) - 1));
    _rebuildSlice();
    notifyListeners();
  }

  void setRowsPerPage(int value) {
    if (value <= 0) return;
    _rowsPerPage = value;
    _startIndex = 0;
    _rebuildSlice();
    notifyListeners();
  }

  List<Measurement> exportSnapshot() => List<Measurement>.unmodifiable(_all);

  void _rebuildSlice() {
    final total = max(_all.length, minVisibleRows);
    final end = min(_startIndex + _rowsPerPage, total);
    final list = <DataGridRow>[];
    for (int i = _startIndex; i < end; i++) {
      list.add(i < _all.length ? _rowFrom(_all[i]) : _ghostRow());
    }
    _rows = list;
  }

  DataGridRow _rowFrom(Measurement m) => DataGridRow(cells: [
        DataGridCell<String>(columnName: 'progresiva', value: m.progresiva),
        DataGridCell<double?>(columnName: 'ohm1m', value: m.ohm1m),
        DataGridCell<double?>(columnName: 'ohm3m', value: m.ohm3m),
        DataGridCell<String>(columnName: 'observations', value: m.observations),
        DataGridCell<String>(
          columnName: 'date',
          value:
              '${m.date.day.toString().padLeft(2, '0')}/${m.date.month.toString().padLeft(2, '0')}/${m.date.year}',
        ),
        const DataGridCell<String>(columnName: 'maps', value: ''),
        const DataGridCell<String>(columnName: '_edit', value: ''),
      ]);

  DataGridRow _ghostRow() => const DataGridRow(cells: [
        DataGridCell<String>(columnName: 'progresiva', value: ''),
        DataGridCell<double?>(columnName: 'ohm1m', value: null),
        DataGridCell<double?>(columnName: 'ohm3m', value: null),
        DataGridCell<String>(columnName: 'observations', value: ''),
        DataGridCell<String>(columnName: 'date', value: ''),
        DataGridCell<String>(columnName: 'maps', value: ''),
        DataGridCell<String>(columnName: '_edit', value: ''),
      ]);

  static num? _toNum(Object? v) {
    if (v == null) return null;
    if (v is num) return v;
    final s = v.toString().replaceAll(',', '.').trim();
    return num.tryParse(s);
  }

  static DateTime? _parseDate(Object? v) {
    if (v == null) return null;
    final s = v.toString().trim();
    final ddmmyyyy = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$');
    final yyyymmdd = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$');
    if (ddmmyyyy.hasMatch(s)) {
      final m = ddmmyyyy.firstMatch(s)!;
      return DateTime(int.parse(m.group(3)!), int.parse(m.group(2)!),
          int.parse(m.group(1)!));
    }
    if (yyyymmdd.hasMatch(s)) {
      final m = yyyymmdd.firstMatch(s)!;
      return DateTime(int.parse(m.group(1)!), int.parse(m.group(2)!),
          int.parse(m.group(3)!));
    }
    return DateTime.tryParse(s);
  }
}

class _EditOp {
  _EditOp(this.index, this.column, this.oldValue, this.newValue);
  final int index;
  final String column;
  final dynamic oldValue;
  final dynamic newValue;
}
