import 'package:flutter/material.dart';
import '../repositories/sheets_repo.dart';
import '../data/local_db.dart';

class SheetDetailScreen extends StatefulWidget {
  const SheetDetailScreen({
    super.key,
    required this.repo,
    required this.sheetId,
  });
  final SheetsRepo repo;
  final int sheetId;

  @override
  State<SheetDetailScreen> createState() => _SheetDetailScreenState();
}

class _SheetDetailScreenState extends State<SheetDetailScreen> {
  late Future<List<Entry>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repo.listEntries(widget.sheetId);
  }

  Future<void> _reload() async {
    setState(() {
      _future = widget.repo.listEntries(widget.sheetId);
    });
  }

  Future<void> _addRow() async {
    await widget.repo.newEntry(widget.sheetId);
    await _reload();
  }

  String _fmtTs(dynamic ts) {
    final d = ts is int
        ? DateTime.fromMillisecondsSinceEpoch(ts)
        : (ts is DateTime ? ts : DateTime.now());
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _editText({
    required Entry e,
    required String field, // "title" | "note" | "provider"
    required String? initial,
  }) async {
    final ctrl = TextEditingController(text: initial ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Editar $field'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: field == 'note' ? 4 : 1,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Guardar')),
        ],
      ),
    );
    if (result == null) return;

    await widget.repo.updateEntry(
      e.id,
      title: field == 'title' ? (result.isEmpty ? null : result) : null,
      note: field == 'note' ? (result.isEmpty ? null : result) : null,
      provider: field == 'provider' ? (result.isEmpty ? null : result) : null,
    );
    await _reload();
  }

  Future<void> _editNumber({
    required Entry e,
    required String field, // "lat" | "lng" | "accuracy"
    required double? initial,
  }) async {
    final ctrl = TextEditingController(text: initial?.toString() ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Editar $field'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
          decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'número'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Guardar')),
        ],
      ),
    );
    if (result == null) return;

    double? v;
    if (result.isNotEmpty) {
      v = double.tryParse(result.replaceAll(',', '.'));
    }
    await widget.repo.updateEntry(
      e.id,
      lat: field == 'lat' ? v : null,
      lng: field == 'lng' ? v : null,
      accuracy: field == 'accuracy' ? v : null,
    );
    await _reload();
  }

  Future<void> _deleteRow(Entry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar fila'),
        content: const Text('¿Seguro que deseas eliminar esta fila?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok == true) {
      await widget.repo.deleteEntry(e.id);
      await _reload();
    }
  }

  DataRow _row(Entry e) {
    return DataRow(
      cells: [
        DataCell(
          Text(e.title ?? ''),
          onTap: () => _editText(e: e, field: 'title', initial: e.title),
        ),
        DataCell(
          Text(e.note ?? ''),
          onTap: () => _editText(e: e, field: 'note', initial: e.note),
        ),
        DataCell(
          Text(e.lat?.toStringAsFixed(5) ?? ''),
          onTap: () => _editNumber(e: e, field: 'lat', initial: e.lat),
        ),
        DataCell(
          Text(e.lng?.toStringAsFixed(5) ?? ''),
          onTap: () => _editNumber(e: e, field: 'lng', initial: e.lng),
        ),
        DataCell(
          Text(e.accuracy?.toStringAsFixed(1) ?? ''),
          onTap: () => _editNumber(e: e, field: 'accuracy', initial: e.accuracy),
        ),
        DataCell(
          Text(e.provider ?? ''),
          onTap: () => _editText(e: e, field: 'provider', initial: e.provider),
        ),
        DataCell(Text(_fmtTs(e.updatedAt))),
        DataCell(
          IconButton(
            tooltip: 'Eliminar',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _deleteRow(e),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<Sheet?>(
          future: widget.repo.getSheet(widget.sheetId),
          builder: (_, snap) => Text(snap.data?.name ?? 'Planilla'),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addRow,
        icon: const Icon(Icons.add),
        label: const Text('Agregar fila'),
      ),
      body: FutureBuilder<List<Entry>>(
        future: _future,
        builder: (_, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snap.data!;
          if (rows.isEmpty) {
            return const Center(child: Text('Sin filas. Agregá la primera.'));
          }

          // Tabla “tipo Excel”
          return Scrollbar(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 900),
                child: SingleChildScrollView(
                  child: DataTable(
                    headingTextStyle: Theme.of(context).textTheme.labelLarge,
                    columns: const [
                      DataColumn(label: Text('Título')),
                      DataColumn(label: Text('Nota')),
                      DataColumn(label: Text('Lat')),
                      DataColumn(label: Text('Lng')),
                      DataColumn(label: Text('Precisión')),
                      DataColumn(label: Text('Fuente')),
                      DataColumn(label: Text('Actualizado')),
                      DataColumn(label: Text('')),
                    ],
                    rows: rows.map(_row).toList(),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
