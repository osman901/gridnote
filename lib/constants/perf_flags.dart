// lib/constants/perf_flags.dart
/// Flags de performance para dispositivos de baja especificación.
///
/// Activar en tiempo de ejecución/compilación:
///   flutter run --dart-define=LOW_SPEC=true
///   flutter build apk --dart-define=LOW_SPEC=true
///
/// Si no definís nada, queda en `false`.
const bool kLowSpec = bool.fromEnvironment('LOW_SPEC', defaultValue: false);
