import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/gridnote_theme.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key, required this.theme});
  final GridnoteThemeController theme;

  @override
  Widget build(BuildContext context) {
    final t = theme.theme;
    return Scaffold(
      backgroundColor: t.scaffold,
      body: Center(
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
              backgroundColor: t.accent, foregroundColor: Colors.black),
          onPressed: () async {
            try {
              await AuthService.signInWithGoogle();
            } catch (e) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text('Error: $e')));
            }
          },
          icon: const Icon(Icons.login),
          label: const Text('Ingresar con Google'),
        ),
      ),
    );
  }
}
