// lib/screens/sign_in_screen.dart
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/gridnote_theme.dart';

/// Editá esta lista con los correos habilitados para usar la app.
const List<String> kAllowedEmails = <String>[
  // 'empleado1@tuempresa.com',
  // 'empleado2@tuempresa.com',
];

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key, this.controller});
  final GridnoteThemeController? controller;

  @override
  Widget build(BuildContext context) {
    final t = (controller ?? GridnoteThemeController()).theme;

    return Scaffold(
      backgroundColor: t.scaffold,
      body: Center(
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: t.accent,
            foregroundColor: Colors.black,
          ),
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            try {
              await AuthService.signInWithGoogle(kAllowedEmails);
              // Éxito: seguí tu flujo de navegación aquí si querés
            } catch (e) {
              messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
            }
          },
          icon: const Icon(Icons.login),
          label: const Text('Ingresar con Google'),
        ),
      ),
    );
  }
}
