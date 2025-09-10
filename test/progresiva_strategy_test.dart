import 'package:flutter_test/flutter_test.dart';
import 'package:gridnote/ai/elite_assistant.dart';
import 'package:gridnote/ai/strategies/progresiva_strategy.dart';
import 'package:gridnote/models/measurement.dart';

// --- Shim solo para tests (si no encontrás AiCellContext) ---
class _Ctx {
  final String columnName;
  final String rawInput;
  final int rowIndex;
  final List<Measurement> rows;
  _Ctx({
    required this.columnName,
    required this.rawInput,
    required this.rowIndex,
    required this.rows,
  });
}
// ------------------------------------------------------------

Measurement m({int? id, String prog = ''}) => Measurement(
  id: id,
  progresiva: prog,
  ohm1m: 0,
  ohm3m: 0,
  observations: '',
  date: DateTime(2024, 1, 1),
);

void main() {
  test('autocompleta progresiva con el código anterior', () async {
    final assistant = await EliteAssistant.forSheet('test');
    final strategy = ProgresivaStrategy(assistant);

    final rows = <Measurement>[ m(id: 1, prog: 'KP-001'), m(id: 2, prog: '') ];

    final ctx = _Ctx(
      columnName: 'progresiva',
      rawInput: '',
      rowIndex: 1,
      rows: rows,
    );

    // cast a dynamic para que acepte el shim en lugar del tipo real
    final r = await strategy.transform(ctx as dynamic);
    expect(r.value, 'KP-002');
  });
}