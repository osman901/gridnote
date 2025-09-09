// lib/ai/ai_center.dart
import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/measurement.dart';
import '../ai/anomaly_service.dart';
import '../ai/fill_suggester.dart';

/// Orquesta IA: escucha cambios y publica anomalÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­as + sugerencias.
/// InyectÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡ una lista observable de mediciones y una funciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n `keyFor`.
class AiCenter extends ChangeNotifier {
  AiCenter(this._items, this._keyFor);

  /// Fuente reactiva de datos. Puede ser un ValueNotifier o cualquier ValueListenable.
  final ValueListenable<List<Measurement>> _items;

  /// Clave estable por mediciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n para detecciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n de duplicados u orden.
  final String Function(Measurement m) _keyFor;

  final _anomalySvc = const AnomalyService();
  final _fill = FillSuggester();

  List<AnomalyFlag> _anomalies = [];
  List<FillSuggestion> _fills = [];

  List<AnomalyFlag> get anomalies => _anomalies;
  List<FillSuggestion> get fillSuggestions => _fills;

  Timer? _debounce;

  void init() {
    // Recalcular ante cada cambio de la lista.
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
