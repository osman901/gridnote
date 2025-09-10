import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Reemplazá este widget por tu lista real.
/// Mantiene el parámetro [filterDate] para filtrar por fecha.
class SheetsListView extends StatelessWidget {
  final DateTime? filterDate;
  const SheetsListView({super.key, this.filterDate});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy', 'es');
    final hint = filterDate == null
        ? 'Sin filtro de fecha'
        : 'Filtrando: ${fmt.format(filterDate!)}';

    // Muestra una lista dummy para compilar.
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: 6,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        return ListTile(
          leading: const Icon(Icons.description_outlined),
          title: const Text('Planilla nueva'),
          subtitle: Text(i == 0 ? hint : '20:${24 - i}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Abrir planilla $i')),
            );
          },
        );
      },
    );
  }
}
