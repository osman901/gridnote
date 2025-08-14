// lib/widgets/editable_table.dart
import 'package:flutter/material.dart';
import '../models/measurement.dart';

/// Tabla editable tipo “hoja de cálculo ligera”.
class EditableTable extends StatefulWidget {
  final List<Measurement> data;
  final void Function(List<Measurement>)? onChanged;

  const EditableTable({
    Key? key,
    required this.data,
    this.onChanged,
  }) : super(key: key);

  @override
  State<EditableTable> createState() => _EditableTableState();
}

class _EditableTableState extends State<EditableTable> {
  final List<Map<String, TextEditingController>> _controllers = [];

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  @override
  void didUpdateWidget(covariant EditableTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si cambia la instancia o el largo, reconstruimos controladores
    if (widget.data != oldWidget.data ||
        widget.data.length != oldWidget.data.length) {
      _disposeControllers();
      _initControllers();
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    for (final m in _controllers) {
      for (final c in m.values) {
        c.dispose();
      }
    }
    _controllers.clear();
  }

  void _initControllers() {
    for (final m in widget.data) {
      _controllers.add({
        'progresiva': TextEditingController(text: m.progresiva),
        'ohm1m': TextEditingController(text: m.ohm1m.toString()),
        'ohm3m': TextEditingController(text: m.ohm3m.toString()),
        'observations': TextEditingController(text: m.observations),
        'latitude': TextEditingController(text: m.latitude?.toString() ?? ''),
        'longitude': TextEditingController(text: m.longitude?.toString() ?? ''),
      });
    }
  }

  void _saveRow(int i) {
    if (i < 0 || i >= widget.data.length || i >= _controllers.length) return;
    final ctrl = _controllers[i];

    // Copia inmutable para notificar al padre
    final updated = List<Measurement>.from(widget.data);

    updated[i] = updated[i].copyWith(
      progresiva: ctrl['progresiva']!.text,
      ohm1m: double.tryParse(ctrl['ohm1m']!.text.replaceAll(',', '.')) ??
          updated[i].ohm1m,
      ohm3m: double.tryParse(ctrl['ohm3m']!.text.replaceAll(',', '.')) ??
          updated[i].ohm3m,
      observations: ctrl['observations']!.text,
      latitude: double.tryParse(ctrl['latitude']!.text.replaceAll(',', '.')),
      longitude: double.tryParse(ctrl['longitude']!.text.replaceAll(',', '.')),
    );

    // No setState aquí: el padre debe reconstruir con la nueva lista
    widget.onChanged?.call(updated);
  }

  TableRow _buildHeaderRow() {
    const headers = <String>[
      'Progresiva', 'Ohm 1m', 'Ohm 3m', 'Observaciones', 'Latitud', 'Longitud', 'Fecha'
    ];
    return TableRow(
      decoration: BoxDecoration(color: Colors.grey.shade900),
      children: headers
          .map((h) => Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          h,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ))
          .toList(),
    );
  }

  TableRow _buildEditableRow(int i, Measurement m) {
    final c = _controllers[i];
    return TableRow(
      children: [
        _cell(c['progresiva']!, onSaved: () => _saveRow(i)),
        _cell(c['ohm1m']!, numeric: true, onSaved: () => _saveRow(i)),
        _cell(c['ohm3m']!, numeric: true, onSaved: () => _saveRow(i)),
        _cell(c['observations']!, onSaved: () => _saveRow(i)),
        _cell(c['latitude']!, numeric: true, onSaved: () => _saveRow(i)),
        _cell(c['longitude']!, numeric: true, onSaved: () => _saveRow(i)),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(m.dateString, style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _cell(
      TextEditingController controller, {
        bool numeric = false,
        required VoidCallback onSaved,
      }) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Focus(
        onFocusChange: (has) {
          if (!has) onSaved();
        },
        child: TextField(
          controller: controller,
          keyboardType:
          numeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => onSaved(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        border: TableBorder.all(color: Colors.grey),
        defaultColumnWidth: const IntrinsicColumnWidth(),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          _buildHeaderRow(),
          for (var i = 0; i < widget.data.length; i++) _buildEditableRow(i, widget.data[i]),
        ],
      ),
    );
  }
}
