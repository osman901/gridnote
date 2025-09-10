/// Flags de performance para dispositivos de baja especificaciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n.
///
/// Activar en tiempo de ejecuciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n/compilaciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n:
///   flutter run --dart-define=LOW_SPEC=true
///   flutter build apk --dart-define=LOW_SPEC=true
///
/// Si no definÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­s nada, queda en `false`.
const bool kLowSpec = bool.fromEnvironment('LOW_SPEC', defaultValue: false);

/// Bandera global para habilitar/deshabilitar funciones de IA en la app.
/// Dejamos la IA desactivada por ahora.
const bool kAiEnabled = false;
