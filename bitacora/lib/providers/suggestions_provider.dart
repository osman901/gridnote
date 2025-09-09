// lib/providers/suggestions_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

final titleSuggestionsProvider =
FutureProvider.family<List<String>, int>((ref, sheetId) async {
  // TODO: reemplazar por tu fuente real (historial del usuario, analytics, etc.)
  return <String>[
    'InspecciÃƒÆ’Ã‚Â³n diaria',
    'Mantenimiento preventivo',
    'Visita de obra',
    'Checklist seguridad',
    'Control de materiales',
    'Relevamiento',
  ];
});
