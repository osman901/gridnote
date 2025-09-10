import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;
  static final _google = GoogleSignIn();

  static Stream<User?> get userChanges => _auth.authStateChanges();

  static Future<UserCredential> signInWithGoogle() async {
    final acc = await _google.signIn();
    if (acc == null) throw Exception('Cancelado');
    final tokens = await acc.authentication;
    final cred = GoogleAuthProvider.credential(
      idToken: tokens.idToken,
      accessToken: tokens.accessToken,
    );
    return _auth.signInWithCredential(cred);
  }

  static Future<void> signOut() async {
    await _auth.signOut();
    await _google.signOut();
  }
}
