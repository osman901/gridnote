// lib/services_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stub de Remote Config para correr sin Firebase.
/// Si luego agregÃƒÆ’Ã‚Â¡s Firebase, podÃƒÆ’Ã‚Â©s reemplazar por la versiÃƒÆ’Ã‚Â³n real.
final remoteConfigProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return <String, dynamic>{}; // valores por defecto vacÃƒÆ’Ã‚Â­os
});
