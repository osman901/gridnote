import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  static final _db = FirebaseFirestore.instance;

  static Future<void> savePlanilla(Map<String, dynamic> planilla) async {
    await _db.collection('planillas').add(planilla);
  }

  static Future<List<Map<String, dynamic>>> obtenerPlanillas() async {
    final snapshot = await _db.collection('planillas').get();
    return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
  }
}