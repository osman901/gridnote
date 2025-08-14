// lib/widgets/measurement_table_dialog.dart
import 'package:flutter/material.dart';

class MeasurementTableDialog extends StatelessWidget {
  /// Usa tipos estrictos para evitar crashes en tiempo de ejecución.
  final List<Map<String, dynamic>> mediciones;

  const MeasurementTableDialog({super.key, required this.mediciones});

  List<String> _collectHeaders() {
    // Reúne todas las claves preservando el orden de aparición.
    final headers = <String>{};
    for (final m in mediciones) {
      for (final k in m.keys) {
        if (k != 'id') headers.add(k);
      }
    }
    return headers.toList();
  }

  @override
  Widget build(BuildContext context) {
    // Caso lista vacía: devolver SIEMPRE un diálogo completo.
    if (mediciones.isEmpty) {
      return AlertDialog(
        title: const Text('Mediciones'),
        content: const Text('No hay mediciones para mostrar.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      );
    }

    final headers = _collectHeaders();

    return AlertDialog(
      title: const Text('Tabla de Mediciones'),
      contentPadding: const EdgeInsets.all(16),
      content: SizedBox(
        // Altura fija con scroll vertical + horizontal para tablas grandes
        height: 360,
        child: Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: headers
                    .map((h) => DataColumn(label: Text(h.toUpperCase())))
                    .toList(),
                rows: mediciones.map((m) {
                  return DataRow(
                    cells: headers
                        .map((h) => DataCell(Text('${m[h] ?? ''}')))
                        .toList(),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}
