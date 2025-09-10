// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Servicio mínimo de autenticación con Google + lista blanca.
/// Si [allowedEmails] está vacío, no se restringe.
class AuthService {
  static Future<void> signInWithGoogle(List<String> allowedEmails) async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return;

    final gAuth = await googleUser.authentication;
    final cred = GoogleAuthProvider.credential(
      accessToken: gAuth.accessToken,
      idToken: gAuth.idToken,
    );

    await FirebaseAuth.instance.signInWithCredential(cred);

    if (allowedEmails.isNotEmpty) {
      final email = (FirebaseAuth.instance.currentUser?.email ?? '')
          .toLowerCase()
          .trim();
      final allow = allowedEmails.map((e) => e.toLowerCase().trim()).toSet();
      if (!allow.contains(email)) {
        await FirebaseAuth.instance.signOut();
        throw Exception('Este correo no está autorizado para usar la aplicación.');
      }
    }
  }
}
