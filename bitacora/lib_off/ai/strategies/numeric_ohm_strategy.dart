import 'column_strategy.dart';

class NumericOhmStrategy extends ColumnStrategy {
  NumericOhmStrategy(super.assistant);

  @override
  bool canHandle(String c) => c == 'ohm1m' || c == 'ohm3m';

  @override
  Future<AiResult> transform(AiCellContext ctx) async {
    final col = ctx.columnName;
    final raw = (ctx.rawInput ?? '').toString().trim();

    final norm = assistant.normalizeNumber(raw);
    final v = double.tryParse(norm);
    if (v == null) {
      final cands = assistant.numericCandidates(raw);
      final msg = [
        'NÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âºmero invÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡lido',
        if (cands.isNotEmpty) 'QuizÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡s: ${cands.join(' ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â· ')}',
      ].join(' ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â· ');
      return AiResult.reject(msg);
    }

    final x = v.clamp(0.0, 999999.0).toDouble();
    final histMean = assistant.historicalMean(col, x);

    final mu = assistant.sessionMean(col);
    final sd = assistant.sessionStdDev(col);
    double z = double.nan;
    if (mu != null && sd != null && sd > 0) z = (x - mu) / sd;

    final extras = <String>[
      'Promedio histÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³rico: ${histMean.toStringAsFixed(2)}',
      if (!z.isNaN && z.abs() >= assistant.zThreshold)
        'Muy fuera de rango (ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â°Ãƒâ€šÃ‚Â¥${assistant.zThreshold.toStringAsFixed(1)}ÃƒÆ’Ã‚ÂÃƒâ€ Ã¢â‚¬â„¢)'
      else if (!z.isNaN && z.abs() >= assistant.zThreshold * 2 / 3)
        'AtenciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n: outlier (z=${z.toStringAsFixed(2)})',
    ];

    final r = assistant.ratio(ctx);
    if (r != null) {
      if (r > assistant.maxRatio || r < assistant.minRatio) {
        extras.add('RelaciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n 3m/1m fuera de lÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­mites');
      } else {
        extras.add('RelaciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n 3m/1mÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â°Ãƒâ€¹Ã¢â‚¬ ${r.toStringAsFixed(2)}');
      }
    }

    if (norm != raw) assistant.rememberCorrection(col, raw, norm);
    assistant.teachRunning(col, x);

    return AiResult.accept(x, hint: assistant.mkHint(extras));
  }
}
