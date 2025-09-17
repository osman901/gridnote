import 'column_strategy.dart';

class ObservationStrategy extends ColumnStrategy {
  ObservationStrategy(super.assistant);

  @override
  bool canHandle(String c) => c == 'observations';

  @override
  Future<AiResult> transform(AiCellContext ctx) async {
    final raw = (ctx.rawInput ?? '').toString().trim();
    if (raw.isNotEmpty) {
      return AiResult.accept(raw, hint: assistant.mkHint(_hints(ctx)));
    }

    final r = ctx.rows[ctx.rowIndex];
    final mean1 =
    assistant.historicalMean('ohm1m', (r.ohm1m as num?)?.toDouble() ?? 0);
    final mean3 =
    assistant.historicalMean('ohm3m', (r.ohm3m as num?)?.toDouble() ?? 0);
    final ok = ((r.ohm1m ?? mean1) <= mean1 * 1.15) &&
        ((r.ohm3m ?? mean3) <= mean3 * 1.15);

    final top = assistant.topPhrases('obs.mode');
    final base = ok ? 'OK' : 'Revisar';
    final guess =
    (top.isNotEmpty && top.first != base) ? top.first : base;

    return AiResult.accept(
      guess,
      hint: assistant.mkHint([
        if (ok) 'Dentro de rango' else 'Sobre promedio',
        if (top.isNotEmpty) 'Frecuentes: ${top.join(' ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â· ')}',
      ]),
    );
  }

  List<String> _hints(AiCellContext ctx) {
    final out = <String>[];
    final r = assistant.ratio(ctx);
    if (r != null) {
      if (r > assistant.maxRatio) out.add('3m muy alto vs 1m');
      if (r < assistant.minRatio) out.add('3m muy bajo vs 1m');
    }
    return out;
  }
}
