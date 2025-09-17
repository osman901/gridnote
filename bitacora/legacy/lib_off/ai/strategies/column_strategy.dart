import '../elite_assistant.dart';
import '../smart_assistant.dart';

// Re-export AiResult & AiCellContext for convenience.
export '../smart_assistant.dart' show AiResult, AiCellContext;

abstract class ColumnStrategy {
  final EliteAssistant assistant;
  ColumnStrategy(this.assistant);

  bool canHandle(String columnName);
  Future<AiResult> transform(AiCellContext ctx);
}
