// lib/widgets/editable_measurement_table.dart
import 'package:flutter/material.dart';
import '../models/measurement.dart';

class EditableMeasurementTable extends StatefulWidget {
  final List<Measurement> measurements;
  final void Function(List<Measurement>)? onChanged;

  const EditableMeasurementTable({
    super.key,
    required this.measurements,
    this.onChanged,
  });

  @override
  State<EditableMeasurementTable> createState() =>
      _EditableMeasurementTableState();
}

class _EditableMeasurementTableState extends State<EditableMeasurementTable> {
  final List<Map<String, TextEditingController>> _controllers = [];

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  @override
  void didUpdateWidget(EditableMeasurementTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si cambia la instancia de la lista (o su largo), refrescamos controladores
    if (widget.measurements != oldWidget.measurements ||
        widget.measurements.length != oldWidget.measurements.length) {
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
    for (final map in _controllers) {
      for (final c in map.values) {
        c.dispose();
      }
    }
    _controllers.clear();
  }

  void _initControllers() {
    for (final m in widget.measurements) {
      _controllers.add({
        'progresiva': TextEditingController(text: m.progresiva),
        // m.ohm1m y m.ohm3m son no-nulos en el modelo ? no uses ?? ''
        'ohm1m': TextEditingController(text: m.ohm1m.toString()),
        'ohm3m': TextEditingController(text: m.ohm3m.toString()),
        'observations': TextEditingController(text: m.observations),
        'latitude': TextEditingController(text: m.latitude?.toString() ?? ''),
        'longitude': TextEditingController(text: m.longitude?.toString() ?? ''),
      });
    }
  }

  void _saveRow(int i) {
    if (i < 0 || i >= _controllers.length || i >= widget.measurements.length) {
      return;
    }
    final ctrl = _controllers[i];

    // 1) Copia de la lista para no mutar al padre
    final updated = List<Measurement>.from(widget.measurements);

    // 2) Nueva mediciÃƒÆ’Ã‚Â³n
    final newM = updated[i].copyWith(
      progresiva: ctrl['progresiva']!.text,
      ohm1m: double.tryParse(ctrl['ohm1m']!.text.replaceAll(',', '.')),
      ohm3m: double.tryParse(ctrl['ohm3m']!.text.replaceAll(',', '.')),
      observations: ctrl['observations']!.text,
      latitude: double.tryParse(ctrl['latitude']!.text.replaceAll(',', '.')),
      longitude: double.tryParse(ctrl['longitude']!.text.replaceAll(',', '.')),
    );

    // 3) Reemplazo en la COPIA
    updated[i] = newM;

    // 4) Notificar al padre (sin setState acÃƒÆ’Ã‚Â¡)
    widget.onChanged?.call(updated);
  }

  TableRow _buildHeaderRow() {
    const headers = <String>[
      'Progresiva',
      'Ohm 1m',
      'Ohm 3m',
      'Observaciones',
      'Latitud',
      'Longitud',
      'Fecha'
    ];
    return TableRow(
      decoration: BoxDecoration(
        color: Colors.cyan[900],
        border: const Border(
          bottom: BorderSide(color: Colors.cyanAccent, width: 2.5),
        ),
      ),
      children: headers
          .map(
            (h) => Padding(
          padding: const EdgeInsets.all(10),
          child: Text(
            h,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 15,
              letterSpacing: 0.5,
            ),
          ),
        ),
      )
          .toList(),
    );
  }

  // Formatea DateTime local a DD/MM/YYYY. Si no es DateTime, muestra '-'.
  String _fmtDate(dynamic date) {
    if (date is! DateTime) return '-';
    final d = date.toLocal();
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  }

  TableRow _buildEditableRow(int i, Measurement m) {
    final ctrl = _controllers[i];
    return TableRow(
      decoration:
      BoxDecoration(color: i % 2 == 0 ? Colors.grey[850] : Colors.black),
      children: [
        _cell(ctrl['progresiva']!, onSaved: () => _saveRow(i)),
        _cell(ctrl['ohm1m']!, onSaved: () => _saveRow(i), numeric: true),
        _cell(ctrl['ohm3m']!, onSaved: () => _saveRow(i), numeric: true),
        _cell(ctrl['observations']!, onSaved: () => _saveRow(i)),
        _cell(ctrl['latitude']!, onSaved: () => _saveRow(i), numeric: true),
        _cell(ctrl['longitude']!, onSaved: () => _saveRow(i), numeric: true),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            _fmtDate(m.date),
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
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
        onFocusChange: (hasFocus) {
          if (!hasFocus) onSaved();
        },
        child: TextField(
          controller: controller,
          keyboardType: numeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
            const EdgeInsets.symmetric(vertical: 9, horizontal: 9),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
              const BorderSide(color: Colors.cyanAccent, width: 1),
            ),
            filled: true,
            fillColor: Colors.grey[900],
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.cyan, width: 2),
            ),
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
        border: TableBorder.all(color: Colors.cyan[900]!),
        defaultColumnWidth: const IntrinsicColumnWidth(),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          _buildHeaderRow(),
          for (var i = 0; i < widget.measurements.length; i++)
            _buildEditableRow(i, widget.measurements[i]),
        ],
      ),
    );
  }
}
