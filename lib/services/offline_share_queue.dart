// lib/services/offline_share_queue.dart
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';

class OfflineShareQueue {
  OfflineShareQueue._();
  static final instance = OfflineShareQueue._();

  static const _box = 'share_outbox';

  StreamSubscription<List<ConnectivityResult>>? _sub;

  Future<void> init() async {
    if (!Hive.isBoxOpen(_box)) {
      await Hive.openBox<Map>(_box);
    }
    // Listener de conectividad
    _sub ??= Connectivity().onConnectivityChanged.listen((_) {
      processQueue();
    });
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }

  /// Encola un archivo para compartir
  Future<void> enqueue({
    required String path,
    String? subject,
    String? text,
  }) async {
    final box = Hive.box<Map>(_box);
    await box.add({
      'path': path,
      'subject': subject,
      'text': text,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Intenta compartir todo si hay red
  Future<void> processQueue() async {
    final conn = await Connectivity().checkConnectivity();
    final hasNet = conn.any((c) => c != ConnectivityResult.none);
    if (!hasNet) return;

    final box = Hive.box<Map>(_box);
    final keys = box.keys.toList(); // en orden de inserción
    for (final k in keys) {
      final item = Map<String, dynamic>.from(box.get(k) as Map);
      try {
        final x = XFile(item['path'] as String,
            mimeType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        await Share.shareXFiles([x],
            subject: item['subject'] as String?, text: item['text'] as String?);
        await box.delete(k); // solo si se invocó el share sin excepciones
      } catch (_) {
        // si falla, dejamos en la cola
        break;
      }
    }
  }
}
