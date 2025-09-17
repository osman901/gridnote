import 'column_strategy.dart';

class ProgresivaStrategy extends ColumnStrategy {
  ProgresivaStrategy(super.assistant);

  @override
  bool canHandle(String c) => c == 'progresiva';

  @override
  Future<AiResult> transform(AiCellContext ctx) async {
    final raw = (ctx.rawInput ?? '').toString().trim();
    if (raw.isEmpty) {
      final prev = (ctx.rowIndex > 0 && ctx.rows.length > ctx.rowIndex)
          ? ctx.rows[ctx.rowIndex - 1].progresiva
          : '';
      if (prev.isNotEmpty) {
        final nextCode = assistant.incCode(prev);
        final modes = assistant.topPhrases('progresiva.mode');
        return AiResult.accept(
          nextCode,
          hint: assistant.mkHint([
            'Autocompletado: $nextCode',
            if (modes.isNotEmpty) 'Frecuentes: ${modes.join(' ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â· ')}',
          ]),
        );
      }
      final modes = assistant.topPhrases('progresiva.mode');
      return AiResult.accept(
        '',
        hint: assistant.mkHint([
          if (modes.isNotEmpty) 'Usadas: ${modes.join(' ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â· ')}',
          'Tip: KP-001 ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ KP-002',
        ]),
      );
    }
    final fixed = raw.replaceAll(RegExp(r'\s+'), '').replaceAll('--', '-');
    if (fixed != raw) assistant.rememberCorrection('progresiva', raw, fixed);
    return AiResult.accept(fixed, hint: 'OK');
  }
}
