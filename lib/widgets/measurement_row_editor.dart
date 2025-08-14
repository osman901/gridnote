// lib/widgets/measurement_row_editor.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../models/measurement.dart';

class MeasurementRowEditor extends StatefulWidget {
  const MeasurementRowEditor({
    super.key,
    required this.initial,
    required this.onSave,
    this.onDelete,
    this.onDuplicate,
  });

  final Measurement initial;
  final ValueChanged<Measurement> onSave;
  final ValueChanged<Measurement>? onDelete;
  final ValueChanged<Measurement>? onDuplicate;

  static Future<void> show(
      BuildContext context, {
        required Measurement initial,
        required ValueChanged<Measurement> onSave,
        ValueChanged<Measurement>? onDelete,
        ValueChanged<Measurement>? onDuplicate,
      }) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (_) => MeasurementRowEditor(
        initial: initial,
        onSave: onSave,
        onDelete: onDelete,
        onDuplicate: onDuplicate,
      ),
    );
  }

  @override
  State<MeasurementRowEditor> createState() => _MeasurementRowEditorState();
}

class _MeasurementRowEditorState extends State<MeasurementRowEditor> {
  static const int _kFieldCount = 6;

  late Measurement m;

  final _form = GlobalKey<FormState>();
  final _nodes = List<FocusNode>.generate(_kFieldCount, (_) => FocusNode());

  final _progCtrl = TextEditingController();
  final _ohm1Ctrl = TextEditingController();
  final _ohm3Ctrl = TextEditingController();
  final _obsCtrl  = TextEditingController();
  final _latCtrl  = TextEditingController();
  final _lonCtrl  = TextEditingController();
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    m = widget.initial; // sin copy(); evitamos error si no existe
    _progCtrl.text = m.progresiva;
    _ohm1Ctrl.text = m.ohm1m?.toString() ?? '';
    _ohm3Ctrl.text = m.ohm3m?.toString() ?? '';
    _obsCtrl.text  = m.observations;
    _latCtrl.text  = m.latitude?.toStringAsFixed(6) ?? '';
    _lonCtrl.text  = m.longitude?.toStringAsFixed(6) ?? '';
    _date = m.date;
  }

  @override
  void dispose() {
    for (final n in _nodes) { n.dispose(); }
    _progCtrl.dispose();
    _ohm1Ctrl.dispose();
    _ohm3Ctrl.dispose();
    _obsCtrl.dispose();
    _latCtrl.dispose();
    _lonCtrl.dispose();
    super.dispose();
  }

  // Utilidades
  TextInputFormatter get _numFmt =>
      FilteringTextInputFormatter.allow(RegExp(r'[0-9\-.,]')); // sin escape redundante

  double? _toDouble(String s) {
    final t = s.replaceAll(',', '.').trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  int _focusedIndex() {
    for (var i = 0; i < _nodes.length; i++) {
      if (_nodes[i].hasFocus) return i;
    }
    return -1;
  }

  void _focusPrev() {
    final i = _focusedIndex();
    if (i > 0) FocusScope.of(context).requestFocus(_nodes[i - 1]);
  }

  void _focusNext() {
    final i = _focusedIndex();
    if (i >= 0 && i < _nodes.length - 1) {
      FocusScope.of(context).requestFocus(_nodes[i + 1]);
    }
  }

  // Acciones
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _fillGPS() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Permiso de ubicación denegado.')),
            );
          }
          return;
        }
      }
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _latCtrl.text = pos.latitude.toStringAsFixed(6);
        _lonCtrl.text = pos.longitude.toStringAsFixed(6);
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo obtener la ubicación. Verifique el GPS.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _save() {
    if (!_form.currentState!.validate()) return;

    final updated = m.copyWith(
      progresiva: _progCtrl.text.trim(),
      ohm1m: _toDouble(_ohm1Ctrl.text),
      ohm3m: _toDouble(_ohm3Ctrl.text),
      observations: _obsCtrl.text.trim(),
      latitude: _toDouble(_latCtrl.text),
      longitude: _toDouble(_lonCtrl.text),
      date: _date,
    );
    widget.onSave(updated);
    Navigator.of(context).maybePop();
  }

  // UI
  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        top: false,
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            children: [
              Row(
                children: [
                  Icon(Icons.grid_on, size: 18, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  const Text('Editar fila', style: TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Duplicar',
                    onPressed: widget.onDuplicate == null
                        ? null
                        : () {
                      widget.onDuplicate!(m.copyWith(id: null));
                      Navigator.of(context).maybePop();
                    },
                    icon: const Icon(Icons.copy_all),
                  ),
                  IconButton(
                    tooltip: 'Borrar',
                    onPressed: widget.onDelete == null ? null : () {
                      widget.onDelete!(m);
                      Navigator.of(context).maybePop();
                    },
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              TextFormField(
                focusNode: _nodes[0],
                controller: _progCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Progresiva'),
                validator: (v) => null,
              ),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      focusNode: _nodes[1],
                      controller: _ohm1Ctrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [_numFmt],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: '1 m Ω'),
                      validator: (v) {
                        final t = (v ?? '').trim();
                        if (t.isEmpty) return null;
                        return _toDouble(t) == null ? 'Valor inválido' : null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      focusNode: _nodes[2],
                      controller: _ohm3Ctrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [_numFmt],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: '3 m Ω'),
                      validator: (v) {
                        final t = (v ?? '').trim();
                        if (t.isEmpty) return null;
                        return _toDouble(t) == null ? 'Valor inválido' : null;
                      },
                    ),
                  ),
                ],
              ),

              TextFormField(
                focusNode: _nodes[3],
                controller: _obsCtrl,
                textInputAction: TextInputAction.newline,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Observaciones'),
                validator: (v) => null,
              ),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      focusNode: _nodes[4],
                      controller: _latCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      inputFormatters: [_numFmt],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Latitud'),
                      validator: (v) {
                        final t = (v ?? '').trim();
                        if (t.isEmpty) return null;
                        final val = _toDouble(t);
                        if (val == null) return 'Valor inválido';
                        if (val < -90 || val > 90) return 'Debe estar entre -90 y 90';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      focusNode: _nodes[5],
                      controller: _lonCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      inputFormatters: [_numFmt],
                      textInputAction: TextInputAction.done,
                      onEditingComplete: _save, // guarda al tocar “Listo”
                      decoration: const InputDecoration(labelText: 'Longitud'),
                      validator: (v) {
                        final t = (v ?? '').trim();
                        if (t.isEmpty) return null;
                        final val = _toDouble(t);
                        if (val == null) return 'Valor inválido';
                        if (val < -180 || val > 180) return 'Debe estar entre -180 y 180';
                        return null;
                      },
                    ),
                  ),
                  IconButton(
                    tooltip: 'GPS',
                    onPressed: _fillGPS,
                    icon: const Icon(Icons.my_location),
                  ),
                ],
              ),

              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Fecha'),
                        child: Text(
                          '${_date.day.toString().padLeft(2, '0')}/'
                              '${_date.month.toString().padLeft(2, '0')}/'
                              '${_date.year}',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton.icon(
                    onPressed: () => setState(() => _date = DateTime.now()),
                    icon: const Icon(Icons.today),
                    label: const Text('Hoy'),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: const Text('Guardar cambios'),
              ),
              const SizedBox(height: 8),
              SizedBox(height: bottomInset > 0 ? 8 : 0),
            ],
          ),
        ),
      ),

      bottomNavigationBar: AnimatedPadding(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: _KeyboardBar(
          onPrev: _focusPrev,
          onNext: _focusNext,
          onDone: () => FocusScope.of(context).unfocus(),
          canPrev: _focusedIndex() > 0,
          canNext: _focusedIndex() >= 0 && _focusedIndex() < _nodes.length - 1,
        ),
      ),
    );
  }
}

class _KeyboardBar extends StatelessWidget {
  const _KeyboardBar({
    required this.onPrev,
    required this.onNext,
    required this.onDone,
    required this.canPrev,
    required this.canNext,
  });

  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onDone;
  final bool canPrev;
  final bool canNext;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              IconButton(
                tooltip: 'Anterior',
                onPressed: canPrev ? onPrev : null,
                icon: const Icon(Icons.keyboard_arrow_up),
              ),
              IconButton(
                tooltip: 'Siguiente',
                onPressed: canNext ? onNext : null,
                icon: const Icon(Icons.keyboard_arrow_down),
              ),
              const Spacer(),
              TextButton(onPressed: onDone, child: const Text('Listo')),
            ],
          ),
        ),
      ),
    );
  }
}
