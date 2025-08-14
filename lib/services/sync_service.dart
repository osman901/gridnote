import 'dart:async';
import 'outbox_service.dart';

/// Disparador periódico simple para asegurar que la bandeja salga.
class SyncService {
  SyncService(this.outbox);

  final OutboxService outbox;
  Timer? _timer;

  void start() {
    _timer?.cancel();
    // cada 90s es un buen balance
    _timer = Timer.periodic(const Duration(seconds: 90), (_) {
      outbox.flush();
    });
  }

  void onResume() {
    // Llamá esto desde AppLifecycleState.resumed
    outbox.flush();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}