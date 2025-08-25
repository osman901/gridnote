import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/measurement.dart';
import '../services/suggest_service.dart';
import '../services/validation_rules.dart';

typedef RowsChanged = void Function(List<Measurement> rows);

class FormView extends StatefulWidget {
  const FormView({
    super.key,
    required this.rows,
    required this.onChanged,
    required this.suggest,
    required this.rules,
  });

  final List<Measurement> rows;
  final RowsChanged onChanged;
  final SuggestService suggest;
  final RuleSet rules;

  @override
  State<FormView> createState() => _FormViewState();
}

class _FormViewState extends State<FormView> {
  late List<Measurement> _rows;

  @override
  void initState() {
    super.initState();
    _rows = List<Measurement>.from(widget.rows);
  }

  void _apply(int index, Measurement next) {
    setState(() => _rows[index] = next);
    widget.onChanged(_rows);
  }

  Widget _textField({
    required String label,
    required String columnKey,
    required String initial,
    required ValueChanged<String> onChanged,
    int maxLines = 1,
  }) {
    final ctl = TextEditingController(text: initial);
    return RawAutocomplete<String>(
      optionsBuilder: (txt) {
        widget.suggest.learn(columnKey, txt.text);
        if (txt.text.trim().isEmpty) return const Iterable<String>.empty();
        return widget.suggest.suggest(columnKey, txt.text);
      },
      fieldViewBuilder: (ctx, controller, focus, onFieldSubmitted) {
        controller.text = initial;
        controller.selection = TextSelection.collapsed(offset: controller.text.length);
        return TextField(
          controller: controller,
          focusNode: focus,
          maxLines: maxLines,
          decoration: InputDecoration(labelText: label),
          onChanged: (v) {
            widget.suggest.learn(columnKey, v);
            onChanged(v);
          },
        );
      },
      optionsViewBuilder: (ctx, onSelected, options) {
        return Material(
          elevation: 4,
          child: ListView(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            children: options.map((o) {
              return ListTile(
                title: Text(o),
                onTap: () => onSelected(o),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_rows.isEmpty) {
      return const Center(child: Text('No hay filas.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final m = _rows[i];
        final errs = widget.rules.validateRow(m);
        final hasErr = errs.isNotEmpty;

        return Card(
          elevation: 0.5,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _textField(
                  label: 'Progresiva',
                  columnKey: 'progresiva',
                  initial: m.progresiva,
                  onChanged: (v) => _apply(i, m.copyWith(progresiva: v)),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: m.ohm1m.toString(),
                        decoration: const InputDecoration(labelText: '1 m (Ω)'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9\.,-]'))],
                        onChanged: (v) => _apply(i, m.copyWith(ohm1m: double.tryParse(v.replaceAll(',', '.')) ?? 0)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        initialValue: m.ohm3m.toString(),
                        decoration: const InputDecoration(labelText: '3 m (Ω)'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9\.,-]'))],
                        onChanged: (v) => _apply(i, m.copyWith(ohm3m: double.tryParse(v.replaceAll(',', '.')) ?? 0)),
                      ),
                    ),
                  ],
                ),
                _textField(
                  label: 'Observaciones',
                  columnKey: 'obs',
                  initial: m.observations,
                  onChanged: (v) => _apply(i, m.copyWith(observations: v)),
                  maxLines: 3,
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: m.latitude?.toStringAsFixed(6) ?? '',
                        decoration: const InputDecoration(labelText: 'Lat'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        onChanged: (v) => _apply(i, m.copyWith(latitude: double.tryParse(v.replaceAll(',', '.')))),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        initialValue: m.longitude?.toStringAsFixed(6) ?? '',
                        decoration: const InputDecoration(labelText: 'Lng'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        onChanged: (v) => _apply(i, m.copyWith(longitude: double.tryParse(v.replaceAll(',', '.')))),
                      ),
                    ),
                  ],
                ),
                if (hasErr)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        errs.join(' · '),
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
