// lib/widgets/measurement_columns.dart
import '../models/measurement.dart';

class MeasurementColumn {
  static const String progresiva   = 'progresiva';
  static const String ohm1m        = 'ohm1m';
  static const String ohm3m        = 'ohm3m';
  static const String observations = 'observations';
  static const String date         = 'date';

  static const List<String> all = [
    progresiva, ohm1m, ohm3m, observations, date,
  ];

  static String titleOf(String column) {
    switch (column) {
      case progresiva:   return 'Progresiva';
      case ohm1m:        return 'O a 1m';
      case ohm3m:        return 'O a 3m';
      case observations: return 'Observaciones';
      case date:         return 'Fecha';
      default:           return column;
    }
  }

  static dynamic valueOf(Measurement m, String column) {
    switch (column) {
      case progresiva:   return m.progresiva;
      case ohm1m:        return m.ohm1m;
      case ohm3m:        return m.ohm3m;
      case observations: return m.observations;
      case date:         return m.date;
      default:           return null;
    }
  }

  static int compareBy(Measurement a, Measurement b, String column, {bool asc = true}) {
    int r;
    switch (column) {
      case progresiva:   r = _cmpComparable<String>(a.progresiva, b.progresiva); break;
      case observations: r = _cmpComparable<String>(a.observations, b.observations); break;
      case date:         r = _cmpComparable<DateTime>(a.date, b.date); break;
      case ohm1m:        r = _cmpComparable<num>(a.ohm1m, b.ohm1m); break;
      case ohm3m:        r = _cmpComparable<num>(a.ohm3m, b.ohm3m); break;
      default:           r = 0;
    }
    return asc ? r : -r;
  }

  static int _cmpComparable<T extends Comparable>(T? a, T? b) {
    if (a == null && b == null) return 0;
    if (a == null) return -1; // nulos primero
    if (b == null) return 1;
    return a.compareTo(b);
  }
}
