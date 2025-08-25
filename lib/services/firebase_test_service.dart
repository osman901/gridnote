// lib/services/firebase_test_service.dart
import 'package:flutter/foundation.dart';

class FirebaseTestService {
  /// Stub: Firebase deshabilitado. Siempre devuelve false.
  static Future<bool> testConnection() async {
    if (kDebugMode) {
      debugPrint('FirebaseTestService: Firebase está deshabilitado (stub).');
    }
    return false;
  }
}
