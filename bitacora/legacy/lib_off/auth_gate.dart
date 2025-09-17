// lib/auth_gate.dart
import 'package:flutter/widgets.dart';

/// Puerta de autenticaciÃƒÆ’Ã‚Â³n en modo local: deja pasar directo.
/// MÃƒÆ’Ã‚Â¡s adelante podÃƒÆ’Ã‚Â©s reactivar Firebase sin tocar el resto de la app.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
