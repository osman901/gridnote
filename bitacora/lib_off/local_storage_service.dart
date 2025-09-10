// lib/services/local_storage_service.dart

import 'package:hive_flutter/hive_flutter.dart';

class LocalStorageService {
  static const String _boxName = 'gridnote_data';

  // Guarda la lista de planillas
  static Future<void> savePlanillas(
      List<Map<String, dynamic>> planillas) async {
    final box = await Hive.openBox(_boxName);
    await box.put('planillas', planillas);
    await box.close();
  }

  // Recupera la lista de planillas (si existe)
  static Future<List<Map<String, dynamic>>> loadPlanillas() async {
    final box = await Hive.openBox(_boxName);
    final data = box.get('planillas', defaultValue: []) as List?;
    await box.close();
    return (data?.cast<Map>() ?? [])
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}
