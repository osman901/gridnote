// lib/screens/login_google_page.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// ✅ Reemplazo de get_it / service_locator:
/// Pasá la lista de correos permitidos por constructor (o dejá vacío para permitir todos).
class LoginGooglePage extends StatefulWidget {
  const LoginGooglePage({
    super.key,
    this.allowedEmails = const <String>[], // si está vacío => no se restringe
  });

  final List<String> allowedEmails;

  @override
  State<LoginGooglePage> createState() => _LoginGooglePageState();
}

class _LoginGooglePageState extends State<LoginGooglePage> {
  bool _loading = false;
  String? _error;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }

      final gAuth = await googleUser.authentication;
      final cred = GoogleAuthProvider.credential(
        accessToken: gAuth.accessToken,
        idToken: gAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(cred);

      // ✅ Filtro por lista blanca (si provista)
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && widget.allowedEmails.isNotEmpty) {
        final email = (user.email ?? '').toLowerCase().trim();
        final allow = widget.allowedEmails.map((e) => e.toLowerCase().trim()).toSet();
        if (!allow.contains(email)) {
          await FirebaseAuth.instance.signOut();
          if (!mounted) return;
          setState(() {
            _loading = false;
            _error =
            'Este correo no está autorizado para usar la aplicación.';
          });
          return;
        }
      }

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            FilledButton.icon(
              onPressed: _signInWithGoogle,
              icon: const Icon(Icons.login),
              label: const Text('Continuar con Google'),
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.secondary,
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
