import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseTestService {
  // Intenta escribir y leer un documento de prueba
  static Future<bool> testConnection() async {
    try {
      final docRef =
          FirebaseFirestore.instance.collection('test_connection').doc('ping');
      await docRef.set({'timestamp': DateTime.now().toIso8601String()});
      final snapshot = await docRef.get();
      return snapshot.exists;
    } catch (e) {
      print('Error test firebase: $e');
      return false;
    }
  }
}
