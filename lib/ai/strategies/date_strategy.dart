// lib/ai/strategies/date_strategy.dart
import 'column_strategy.dart';

class DateStrategy extends ColumnStrategy {
  DateStrategy(super.assistant);

  @override
  bool canHandle(String c) => c == 'date';

  @override
  Future<AiResult> transform(AiCellContext ctx) async {
    final raw = (ctx.rawInput ?? '').toString().trim();
    if (raw.isEmpty) return AiResult.accept(DateTime.now(), hint: 'Hoy');

    final r = raw.replaceAll('-', '/');
    final m = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{2,4})$').firstMatch(r);
    if (m == null) return AiResult.reject('Fecha inválida (dd/mm/aaaa)');
    var y = int.parse(m.group(3)!); if (y < 100) y += 2000;
    final d = DateTime(y, int.parse(m.group(2)!), int.parse(m.group(1)!));
    return AiResult.accept(d, hint: 'OK');
  }
}
