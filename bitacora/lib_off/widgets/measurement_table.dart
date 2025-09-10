import 'package:flutter/material.dart';
import '../models/measurement.dart';

class MeasurementTable extends StatelessWidget {
  final List<Measurement> measurements;

  /// Encabezados (si vienen vacÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­os se muestra un espacio)
  final String col1Label; // Progresiva
  final String col2Label; // ÃƒÆ’Ã…Â½Ãƒâ€šÃ‚Â© (1 m)
  final String col3Label; // ÃƒÆ’Ã…Â½Ãƒâ€šÃ‚Â© (3 m)
  final String col4Label; // Observaciones

  /// Si lo pasÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡s, habilita pull-to-refresh (estilo Instagram).
  final Future<void> Function()? onRefresh;

  const MeasurementTable({
    super.key,
    required this.measurements,
    this.col1Label = '',
    this.col2Label = '',
    this.col3Label = '',
    this.col4Label = '',
    this.onRefresh,
  });

  static const _headerStyle = TextStyle(fontWeight: FontWeight.bold);
  static const _cellPadding = EdgeInsets.symmetric(vertical: 8, horizontal: 4);

  @override
  Widget build(BuildContext context) {
    String label(String s) => (s.isEmpty) ? ' ' : s;

    final verticalCtrl = ScrollController();
    final horizontalCtrl = ScrollController();

    Widget table = DataTable(
      columnSpacing: 24,
      columns: [
        DataColumn(label: Text(label(col1Label), style: _headerStyle)),
        DataColumn(label: Text(label(col2Label), style: _headerStyle)),
        DataColumn(label: Text(label(col3Label), style: _headerStyle)),
        DataColumn(label: Text(label(col4Label), style: _headerStyle)),
      ],
      rows: measurements.map((m) {
        return DataRow(cells: [
          DataCell(Padding(
            padding: _cellPadding,
            child: Text(m.progresiva),
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
            child: Text(m.observations),
          )),
        ]);
      }).toList(),
    );

    // Scroll horizontal + vertical con rebote iOS
    Widget scrollable = ScrollConfiguration(
      behavior: const _BounceBehavior(),
      child: Scrollbar(
        controller: horizontalCtrl,
        notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
        child: SingleChildScrollView(
          controller: horizontalCtrl,
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 720), // ancho mÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­nimo cÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³modo
            child: Scrollbar(
              controller: verticalCtrl,
              child: SingleChildScrollView(
                controller: verticalCtrl,
                scrollDirection: Axis.vertical,
                child: table,
              ),
            ),
          ),
        ),
      ),
    );

    // Pull-to-refresh (opcional)
    if (onRefresh != null) {
      scrollable = RefreshIndicator.adaptive(
        onRefresh: onRefresh!,
        child: scrollable,
      );
    }

    return scrollable;
  }

  static String _fmtNumber(num? x) {
    if (x == null) return '';
    final d = x.toDouble();
    return d % 1 == 0 ? d.toStringAsFixed(0) : d.toString();
  }
}

class _BounceBehavior extends ScrollBehavior {
  const _BounceBehavior();
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
}
