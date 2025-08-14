import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../services/excel_template_service.dart';

class ExcelDataSource extends DataGridSource {
  final ExcelTemplateService svc;
  final String sheetName;
  final bool allowEditing;
  final List<GridColumn> columns;

  ExcelDataSource({
    required this.svc,
    required this.sheetName,
    required this.columns,
    this.allowEditing = true,
  }) {
    _reload();
  }

  final List<DataGridRow> _rows = [];

  void _reload() {
    final matrix = svc.matrix(sheetName);
    _rows
      ..clear()
      ..addAll(List.generate(matrix.length, (r) {
        final cells = <DataGridCell>[];
        for (var c = 0; c < matrix[r].length; c++) {
          cells.add(DataGridCell<String>(
            // Debe coincidir con GridColumn.columnName
            columnName: 'C$c',
            value: matrix[r][c],
          ));
        }
        return DataGridRow(cells: cells);
      }));
    notifyListeners();
  }

  @override
  List<DataGridRow> get rows => _rows;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().map((cell) {
        return Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(cell.value?.toString() ?? ''),
        );
      }).toList(),
    );
  }

  // ----------------- Edición -----------------

  @override
  Future<bool> canSubmitCell(
      DataGridRow dataGridRow,
      RowColumnIndex rowColumnIndex,
      GridColumn column,
      ) async {
    // Devolver false si querés bloquear el commit.
    return true;
  }

  @override
  Future<void> onCellSubmit(
      DataGridRow dataGridRow,
      RowColumnIndex rowColumnIndex,
      GridColumn column,
      ) async {
    final r = _rows.indexOf(dataGridRow);
    final c = rowColumnIndex.columnIndex;
    final newValue = dataGridRow.getCells()[c].value?.toString() ?? '';

    // 1) Persistir en workbook
    svc.setValue(sheetName, r, c, newValue);

    // 2) Reflejar en datasource usando el MISMO columnName
    _rows[r].getCells()[c] = DataGridCell<String>(
      columnName: column.columnName,
      value: newValue,
    );

    // 3) Refrescar sólo esa celda
    notifyDataSourceListeners(rowColumnIndex: RowColumnIndex(r, c));
  }

  /// Columnas por defecto C0..C{count-1}
  static List<GridColumn> defaultColumns(int count) {
    return List.generate(count, (i) {
      final name = 'C$i';
      return GridColumn(
        columnName: name,
        label: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(8),
          child: Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      );
    });
  }
}