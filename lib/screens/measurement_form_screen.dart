// lib/screens/measurement_form_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/measurement.dart';

class MeasurementFormScreen extends StatefulWidget {
  /// Si viene null, se crea una nueva medición.
  final Measurement? initial;

  const MeasurementFormScreen({super.key, this.initial});

  @override
  State<MeasurementFormScreen> createState() => _MeasurementFormScreenState();
}

class _MeasurementFormScreenState extends State<MeasurementFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _progCtrl;
  late final TextEditingController _ohm1Ctrl;
  late final TextEditingController _ohm3Ctrl;
  late final TextEditingController _obsCtrl;
  late final TextEditingController _latCtrl;
  late final TextEditingController _lonCtrl;

  late DateTime _selectedDate;

  // Parseo segun locale (resuelve "1.234,56" vs "1,234.56")
  final NumberFormat _nf = NumberFormat.decimalPattern();

  // Permite solo un "-" inicial y un separador decimal opcional
  final _coordFormatter = FilteringTextInputFormatter.allow(
    RegExp(r'^-?[0-9]*([.,][0-9]*)?$'),
  );
  final _posDecimalFormatter = FilteringTextInputFormatter.allow(
    RegExp(r'^[0-9]*([.,][0-9]*)?$'),
  );

  @override
  void initState() {
    super.initState();
    final m = widget.initial ?? Measurement.empty();

    _progCtrl = TextEditingController(text: m.progresiva);
    _ohm1Ctrl = TextEditingController(text: m.ohm1m?.toString() ?? '');
    _ohm3Ctrl = TextEditingController(text: m.ohm3m?.toString() ?? '');
    _obsCtrl = TextEditingController(text: m.observations);
    _latCtrl = TextEditingController(text: m.latitude?.toString() ?? '');
    _lonCtrl = TextEditingController(text: m.longitude?.toString() ?? '');
    _selectedDate = m.date;
  }

  @override
  void dispose() {
    _progCtrl.dispose();
    _ohm1Ctrl.dispose();
    _ohm3Ctrl.dispose();
    _obsCtrl.dispose();
    _latCtrl.dispose();
    _lonCtrl.dispose();
    super.dispose();
  }

  double? _toDoubleOrNull(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    try {
      return _nf.parse(t).toDouble();
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: _selectedDate,
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final base = widget.initial ?? Measurement.empty();

    final updated = base.copyWith(
      progresiva: _progCtrl.text.trim(),
      // ohms opcionales: quedan en null si el campo está vacío o inválido
      ohm1m: _toDoubleOrNull(_ohm1Ctrl.text),
      ohm3m: _toDoubleOrNull(_ohm3Ctrl.text),
      observations: _obsCtrl.text.trim(),
      latitude: _toDoubleOrNull(_latCtrl.text),
      longitude: _toDoubleOrNull(_lonCtrl.text),
      date: _selectedDate,
    );

    Navigator.of(context).pop<Measurement>(updated);
  }

  String _formattedDate() => DateFormat('dd/MM/yyyy').format(_selectedDate);

  @override
  Widget build(BuildContext context) {
    final editing = widget.initial != null;

    String? _numValidator(String? v, {bool allowEmpty = true}) {
      final s = (v ?? '').trim();
      if (s.isEmpty) return allowEmpty ? null : 'Requerido';
      try {
        _nf.parse(s);
        return null;
      } catch (_) {
        return 'Número inválido';
      }
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(editing ? 'Editar medición' : 'Nueva medición'),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _progCtrl,
                decoration: const InputDecoration(labelText: 'Progresiva'),
                validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ohm1Ctrl,
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [_posDecimalFormatter],
                decoration: const InputDecoration(labelText: 'Ohm 1m'),
                validator: (v) => _numValidator(v, allowEmpty: true),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ohm3Ctrl,
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [_posDecimalFormatter],
                decoration: const InputDecoration(labelText: 'Ohm 3m'),
                validator: (v) => _numValidator(v, allowEmpty: true),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _obsCtrl,
                decoration: const InputDecoration(labelText: 'Observaciones'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      inputFormatters: [_coordFormatter],
                      decoration: const InputDecoration(labelText: 'Latitud'),
                      validator: (v) => _numValidator(v, allowEmpty: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lonCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      inputFormatters: [_coordFormatter],
                      decoration: const InputDecoration(labelText: 'Longitud'),
                      validator: (v) => _numValidator(v, allowEmpty: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Fecha'),
                subtitle: Text(_formattedDate()),
                trailing: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: _pickDate,
                  tooltip: 'Seleccionar fecha',
                ),
                onTap: _pickDate,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: const Text('Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
