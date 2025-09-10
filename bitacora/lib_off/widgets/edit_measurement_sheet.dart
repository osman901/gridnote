// lib/widgets/edit_measurement_sheet.dart
import 'package:flutter/material.dart';
import '../models/measurement.dart';

class EditMeasurementSheet extends StatefulWidget {
  const EditMeasurementSheet({super.key, required this.model});
  final Measurement model;

  @override
  State<EditMeasurementSheet> createState() => _EditMeasurementSheetState();
}

class _EditMeasurementSheetState extends State<EditMeasurementSheet> {
  late final TextEditingController _prog;
  late final TextEditingController _ohm1;
  late final TextEditingController _ohm3;
  late final TextEditingController _obs;
  late final TextEditingController _lat;
  late final TextEditingController _lng;

  String? _errOhm1, _errOhm3, _errLat, _errLng;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final m = widget.model;
    _prog = TextEditingController(text: m.progresiva);
    _ohm1 = TextEditingController(text: '${m.ohm1m}');
    _ohm3 = TextEditingController(text: '${m.ohm3m}');
    _obs  = TextEditingController(text: m.observations);
    _lat  = TextEditingController(text: m.latitude == null ? '' : '${m.latitude}');
    _lng  = TextEditingController(text: m.longitude == null ? '' : '${m.longitude}');
    _validate();
  }

  @override
  void dispose() {
    _prog.dispose();
    _ohm1.dispose();
    _ohm3.dispose();
    _obs.dispose();
    _lat.dispose();
    _lng.dispose();
    super.dispose();
  }

  double? _numOrNull(String t) {
    final x = t.replaceAll(',', '.').trim();
    if (x.isEmpty) return null;
    return double.tryParse(x);
  }

  bool _validate() {
    _errOhm1 = null; _errOhm3 = null; _errLat = null; _errLng = null;
    if (_ohm1.text.trim().isNotEmpty && _numOrNull(_ohm1.text) == null) _errOhm1 = 'NÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âºmero invÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡lido';
    if (_ohm3.text.trim().isNotEmpty && _numOrNull(_ohm3.text) == null) _errOhm3 = 'NÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âºmero invÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡lido';
    final lat = _numOrNull(_lat.text);
    final lng = _numOrNull(_lng.text);
    if (_lat.text.trim().isNotEmpty && (lat == null || lat < -90 || lat > 90)) _errLat = 'Lat invÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡lida';
    if (_lng.text.trim().isNotEmpty && (lng == null || lng < -180 || lng > 180)) _errLng = 'Lng invÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡lida';
    setState(() {});
    return _errOhm1 == null && _errOhm3 == null && _errLat == null && _errLng == null;
  }

  Future<void> _save() async {
    if (!_validate()) return;
    setState(() => _saving = true);
    final updated = widget.model.copyWith(
      progresiva: _prog.text.trim(),
      ohm1m: _numOrNull(_ohm1.text),
      ohm3m: _numOrNull(_ohm3.text),
      observations: _obs.text.trim(),
      latitude: _numOrNull(_lat.text),
      longitude: _numOrNull(_lng.text),
    );
    if (!mounted) return;
    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final canSave = _errOhm1 == null && _errOhm3 == null && _errLat == null && _errLng == null;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(height: 4, width: 40, margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(4))),
              Row(
                children: [
                  const Expanded(child: Text('Editar mediciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n', style: TextStyle(fontWeight: FontWeight.bold))),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              TextField(controller: _prog, decoration: const InputDecoration(labelText: 'Progresiva'), textInputAction: TextInputAction.next),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ohm1,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
                      decoration: InputDecoration(labelText: '1 m (ÃƒÆ’Ã…Â½Ãƒâ€šÃ‚Â©)', errorText: _errOhm1),
                      onChanged: (_) => _validate(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _ohm3,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
                      decoration: InputDecoration(labelText: '3 m (ÃƒÆ’Ã…Â½Ãƒâ€šÃ‚Â©)', errorText: _errOhm3),
                      onChanged: (_) => _validate(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _lat,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      decoration: InputDecoration(labelText: 'Latitud', errorText: _errLat),
                      onChanged: (_) => _validate(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _lng,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      decoration: InputDecoration(labelText: 'Longitud', errorText: _errLng),
                      onChanged: (_) => _validate(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _obs,
                maxLines: null,
                decoration: const InputDecoration(labelText: 'Observaciones'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: (_saving || !canSave) ? null : _save,
                  child: _saving
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Guardar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
