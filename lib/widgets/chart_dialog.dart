import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../models/measurement.dart';

Future<void> showChartDialog(BuildContext context, List<Measurement> rows) async {
  String x = 'date'; // date | progresiva
  String y = 'ohm1m'; // ohm1m | ohm3m
  String type = 'line'; // line | bar

  List<DropdownMenuItem<String>> items(List<String> v) =>
      v.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList();

  List<FlSpot> spots() {
    final sorted = List<Measurement>.from(rows)
      ..sort((a, b) => a.date.compareTo(b.date));
    double idx = 0;
    return sorted.map((m) {
      idx += 1;
      final xv = (x == 'date') ? idx : idx; // para simplificar
      final yv = (y == 'ohm1m') ? m.ohm1m : m.ohm3m;
      return FlSpot(xv, yv);
    }).toList();
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: StatefulBuilder(
            builder: (context, setSB) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ListTile(
                    title: Text('Gráfico rápido'),
                    subtitle: Text('Seleccioná ejes y tipo'),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: x,
                          items: items(['date','progresiva']),
                          onChanged: (v) => setSB(() => x = v ?? x),
                          decoration: const InputDecoration(labelText: 'Eje X'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: y,
                          items: items(['ohm1m','ohm3m']),
                          onChanged: (v) => setSB(() => y = v ?? y),
                          decoration: const InputDecoration(labelText: 'Eje Y'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: type,
                          items: items(['line','bar']),
                          onChanged: (v) => setSB(() => type = v ?? type),
                          decoration: const InputDecoration(labelText: 'Tipo'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AspectRatio(
                    aspectRatio: 1.6,
                    child: (type == 'line')
                        ? LineChart(LineChartData(
                      gridData: const FlGridData(show: true),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: true),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots(),
                          isCurved: false,
                          dotData: const FlDotData(show: false),
                        ),
                      ],
                    ))
                        : BarChart(BarChartData(
                      titlesData: const FlTitlesData(show: false),
                      barGroups: spots()
                          .map((s) => BarChartGroupData(x: s.x.toInt(), barRods: [
                        BarChartRodData(toY: s.y),
                      ]))
                          .toList(),
                    )),
                  ),
                ],
              );
            },
          ),
        ),
      );
    },
  );
}
