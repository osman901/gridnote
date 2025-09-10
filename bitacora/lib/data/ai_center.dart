// lib/ai/ai_center.dart
import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/measurement.dart';
import '../ai/anomaly_service.dart';
import '../ai/fill_suggester.dart';

/// Orquesta IA: escucha cambios y publica anomalÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­as + sugerencias.
/// Elimina la dependencia a MeasurementRepository.
/// InyectÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡:
///  - una fuente reactiva de items (ValueListenable<List<Measurement>>)
///  - una funciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n keyFor para identificar filas de forma estable.
class AiCenter extends ChangeNotifier {
  AiCenter({
    required ValueListenable<List<Measurement>> items,
    required String Function(Measurement m) keyFor,
  })  : _items = items,
        _keyFor = keyFor;

  final ValueListenable<List<Measurement>> _items;
  final String Function(Measurement m) _keyFor;

  final _anomalySvc = const AnomalyService();
  final _fill = FillSuggester();

  List<AnomalyFlag> _anomalies = <AnomalyFlag>[];
  List<FillSuggestion> _fills = <FillSuggestion>[];

  List<AnomalyFlag> get anomalies => _anomalies;
  List<FillSuggestion> get fillSuggestions => _fills;

  Timer? _debounce;

  void init() {
    _items.addListener(_scheduleRecompute);
    _scheduleRecompute();
  }

  @override
  void dispose() {
    _items.removeListener(_scheduleRecompute);
    _debounce?.cancel();
    super.dispose();
  }

  void _scheduleRecompute() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _recompute);
  }

  void _recompute() {
    final items = _items.value.toList(growable: false);
    _anomalies = _anomalySvc.find(items, _keyFor);
    _fills = _fill.suggest(items);
    notifyListeners();
  }
}
