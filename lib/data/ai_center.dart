import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/measurement_repository.dart';
import '../ai/anomaly_service.dart';
import '../ai/fill_suggester.dart';

/// Orquesta IA: escucha cambios y publica anomalías + sugerencias.
class AiCenter extends ChangeNotifier {
  AiCenter(this._repo);
  final MeasurementRepository _repo;

  final _anomalySvc = const AnomalyService();
  final _fill = FillSuggester();

  List<AnomalyFlag> _anomalies = [];
  List<FillSuggestion> _fills = [];
  List<AnomalyFlag> get anomalies => _anomalies;
  List<FillSuggestion> get fillSuggestions => _fills;

  Timer? _debounce;

  void init() {
    _repo.addListener(_scheduleRecompute);
    _scheduleRecompute();
  }

  @override
  void dispose() {
    _repo.removeListener(_scheduleRecompute);
    _debounce?.cancel();
    super.dispose();
  }

  void _scheduleRecompute() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _recompute);
  }

  void _recompute() {
    final items = _repo.items.toList(growable: false);
    _anomalies = _anomalySvc.find(items, _repo.keyFor);
    _fills = _fill.suggest(items);
    notifyListeners();
  }
}
