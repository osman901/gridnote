import 'package:intl/intl.dart';

class Formatters {
  static String date(DateTime date, {String pattern = 'dd/MM/yyyy'}) {
    return DateFormat(pattern).format(date);
  }

  static String? doubleValue(double? value, {int decimals = 2}) {
    if (value == null) return '';
    return value.toStringAsFixed(decimals);
  }
}
