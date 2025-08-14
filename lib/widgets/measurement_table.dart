import 'package:flutter/material.dart';
import '../models/measurement.dart';

class MeasurementTable extends StatelessWidget {
  final List<Measurement> measurements;

  /// Encabezados (pasalos desde tu screen; si vienen vacíos se muestra un espacio)
  final String col1Label; // Progresiva
  final String col2Label; // Ω (1 m)
  final String col3Label; // Ω (3 m)
  final String col4Label; // Observaciones

  const MeasurementTable({
    Key? key,
    required this.measurements,
    this.col1Label = '',
    this.col2Label = '',
    this.col3Label = '',
    this.col4Label = '',
  }) : super(key: key);

  static const _headerStyle = TextStyle(fontWeight: FontWeight.bold);
  static const _cellPadding = EdgeInsets.symmetric(vertical: 8, horizontal: 4);

  @override
  Widget build(BuildContext context) {
    String _label(String s) => (s.isEmpty) ? ' ' : s;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 24,
        columns: [
          DataColumn(label: Text(_label(col1Label), style: _headerStyle)),
          DataColumn(label: Text(_label(col2Label), style: _headerStyle)),
          DataColumn(label: Text(_label(col3Label), style: _headerStyle)),
          DataColumn(label: Text(_label(col4Label), style: _headerStyle)),
        ],
        rows: measurements.map((m) {
          return DataRow(cells: [
            DataCell(Padding(
              padding: _cellPadding,
              child: Text('${m.progresiva}'),
            )),
            DataCell(Padding(
              padding: _cellPadding,
              child: Text(_fmtNumber(m.ohm1m)),
            )),
            DataCell(Padding(
              padding: _cellPadding,
              child: Text(_fmtNumber(m.ohm3m)),
            )),
            DataCell(Padding(
              padding: _cellPadding,
              child: Text(m.observations ?? ''),
            )),
          ]);
        }).toList(),
      ),
    );
  }

  static String _fmtNumber(num? x) {
    if (x == null) return '';
    final d = x.toDouble();
    return d % 1 == 0 ? d.toStringAsFixed(0) : d.toString();
  }
}