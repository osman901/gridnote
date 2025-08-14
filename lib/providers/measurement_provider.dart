import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/measurement.dart';

class MeasurementNotifier extends StateNotifier<List<Measurement>> {
  MeasurementNotifier() : super(const []);

  void setAll(List<Measurement> list) => state = List.unmodifiable(list);
  void add(Measurement m) => state = [...state, m];

  void removeAt(int index) {
    final list = [...state]..removeAt(index);
    state = List.unmodifiable(list);
  }

  void updateAt(int index, Measurement updated) {
    final list = [...state];
    list[index] = updated;
    state = List.unmodifiable(list);
  }

  void clear() => state = const [];
}

final measurementProvider =
StateNotifierProvider<MeasurementNotifier, List<Measurement>>(
      (ref) => MeasurementNotifier(),
);
