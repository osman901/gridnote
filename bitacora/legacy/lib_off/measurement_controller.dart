// lib/controllers/measurement_controller.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';

import 'package:bitacora/models/measurement.dart';

class MeasurementController extends ChangeNotifier {
  final Box<Measurement> box;

  late List<Measurement> _all;
  String _filter = '';

  Timer? _debounce;

  MeasurementController(this.box) {
    _all = box.values.toList();
    if (_all.isEmpty) _all.add(Measurement.empty);
    box.watch().listen((_) => _reloadFromBox());
  }

  List<Measurement> get filtered {
    if (_filter.isEmpty) return List.unmodifiable(_all);
    final q = _filter.toLowerCase();
    return _all
        .where((m) =>
    m.progresiva.toLowerCase().contains(q) ||
        m.observations.toLowerCase().contains(q) ||
        m.dateString.toLowerCase().contains(q))
        .toList();
  }

  void setFilter(String query) {
    _filter = query;
    notifyListeners();
  }

  Future<void> addRow({Position? pos}) async {
    _all.add(
      Measurement(
        progresiva: '',
        ohm1m: 0,
        ohm3m: 0,
        observations: '',
        latitude: pos?.latitude,
        longitude: pos?.longitude,
        date: DateTime.now(),
      ),
    );
    _persist();
    notifyListeners();
  }

  void removeRowAt(int filteredIndex) {
    final filteredList = filtered;
    if (filteredIndex < 0 || filteredIndex >= filteredList.length) return;
    final m = filteredList[filteredIndex];
    _all.remove(m);
    _persist();
    notifyListeners();
  }

  void updateMeasurement(Measurement oldM, Measurement newM) {
    final idx = _all.indexOf(oldM);
    if (idx != -1) {
      _all[idx] = newM;
      _persist();
      notifyListeners();
    }
  }

  void _reloadFromBox() {
    _all = box.values.toList();
    notifyListeners();
  }

  void _persist() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      await box.clear();
      await box.addAll(_all);
    });
  }
}

