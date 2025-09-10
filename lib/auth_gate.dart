import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'theme/gridnote_theme.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.userChanges,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.data != null) {
          return child; // ✅ Logueado: HomeScreen
        }
        // ❌ No logueado: botón de Google simple
        final t = GridnoteThemeController().theme; // o pasá tu controller si querés
        return Scaffold(
          backgroundColor: t.scaffold,
          body: Center(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: t.accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              onPressed: () async {
                try {
                  await AuthService.signInWithGoogle();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              icon: const Icon(Icons.login),
              label: const Text('Ingresar con Google'),
            ),
          ),
        );
      },
    );
  }
}
