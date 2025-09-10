import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginGooglePage extends StatefulWidget {
  const LoginGooglePage({super.key});
  @override
  State<LoginGooglePage> createState() => _LoginGooglePageState();
}

class _LoginGooglePageState extends State<LoginGooglePage> {
  bool _loading = false;
  String? _error;

  Future<void> _signInWithGoogle() async {
    setState(() { _loading = true; _error = null; });
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) { setState(() => _loading = false); return; }
      final gAuth = await googleUser.authentication;
      final cred = GoogleAuthProvider.credential(
        accessToken: gAuth.accessToken, idToken: gAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(cred);
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const FlutterLogo(size: 72),
                  const SizedBox(height: 16),
                  const Text('Gridnote', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 24),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_error!, style: const TextStyle(color: Colors.red)),
                    ),
                  FilledButton.icon(
                    onPressed: _loading ? null : _signInWithGoogle,
                    icon: const Icon(Icons.login),
                    label: Text(_loading ? 'Ingresando…' : 'Entrar con Google'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
