import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

enum AuthStatus { licensed, unlicensed, error }

class AuthService {
  static Stream<User?> get userChanges => FirebaseAuth.instance.userChanges();

  /// Verifica si el email actual estÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡ en la lista de permitidos.
  static bool _isLicensed(User? user, List<String> allowed) {
    final e = user?.email?.toLowerCase();
    return e != null && allowed.contains(e);
  }

  /// Login + verificaciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n de licencia (Google)
  static Future<AuthStatus> signInWithGoogle(List<String> allowedEmails) async {
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return AuthStatus.error;
      final gAuth = await googleUser.authentication;
      final cred = GoogleAuthProvider.credential(
        accessToken: gAuth.accessToken,
        idToken: gAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(cred);
      final ok = _isLicensed(FirebaseAuth.instance.currentUser, allowedEmails);
      if (!ok) {
        await FirebaseAuth.instance.signOut();
        return AuthStatus.unlicensed;
      }
      return AuthStatus.licensed;
    } catch (_) {
      return AuthStatus.error;
    }
  }

  static Future<void> signOut() => FirebaseAuth.instance.signOut();
}
