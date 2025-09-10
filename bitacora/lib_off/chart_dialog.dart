import 'package:flutter/material.dart';
// Mantiene la firma original para no romper llamadas existentes.
import '../models/measurement.dart';

/// Beta: gráficos deshabilitados. Dejamos stub para no depender de fl_chart.
/// Sustituye la UI por un diálogo simple. Más adelante se puede
/// reimplementar con CustomPainter o volver a una lib de charts.
Future<void> showChartDialog(BuildContext context, List<Measurement> rows) async {
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Gráfico'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Los gráficos están deshabilitados en la beta.'),
          const SizedBox(height: 8),
          Text('Filas disponibles: ${rows.length}'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
}
