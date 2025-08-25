import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path/path.dart' as p;

import 'send_report_service.dart';

enum OutboxKind { excel, pdf }

class OutboxItem {
  OutboxItem({
    required this.kind,
    required this.path,
    required this.filename,
    this.to,
    this.subject,
    this.text,
    this.attempts = 0,
    this.lastTryAt,
  });

  final OutboxKind kind;
  final String path;
  final String filename;
  String? to;
  String? subject;
  String? text;
  int attempts;
  DateTime? lastTryAt;

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'path': path,
    'filename': filename,
    'to': to,
    'subject': subject,
    'text': text,
    'attempts': attempts,
    'lastTryAt': lastTryAt?.millisecondsSinceEpoch,
  };

  static OutboxItem fromJson(Map data) => OutboxItem(
    kind: (data['kind'] == 'pdf') ? OutboxKind.pdf : OutboxKind.excel,
    path: (data['path'] as String?) ?? '',
    filename: (data['filename'] as String?) ??
        p.basename((data['path'] as String?) ?? 'file'),
    to: data['to'] as String?,
    subject: data['subject'] as String?,
    text: data['text'] as String?,
    attempts: (data['attempts'] as int?) ?? 0,
    lastTryAt: (data['lastTryAt'] != null)
        ? DateTime.fromMillisecondsSinceEpoch(data['lastTryAt'] as int)
        : null,
  );
}

class OutboxService {
  OutboxService(this._box);

  static const _boxName = 'outbox';
  static const int _maxAttempts = 8;
  static const Duration _baseBackoff = Duration(seconds: 15);
  static const Duration _maxBackoff = Duration(minutes: 15);

  /// Singleton accesible desde toda la app (se setea en open()).
  static late OutboxService instance;

  final Box _box;
  final ValueNotifier<bool> isSyncing = ValueNotifier<bool>(false);

  StreamSubscription<List<ConnectivityResult>>? _connSub;

  /// Abrir/crear la box y comenzar a observar conectividad
  static Future<OutboxService> open({bool autoFlushOnConnectivity = true}) async {
    final box = await Hive.openBox(_boxName);
    final svc = OutboxService(box);
    instance = svc; // <-- singleton
    if (autoFlushOnConnectivity) {
      svc._watchConnectivity(); // no hace falta await
    }
    return svc;
  }

  Future<void> dispose() async {
    await _connSub?.cancel();
    isSyncing.dispose();
  }

  void _watchConnectivity() {
    _connSub?.cancel();
    _connSub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.isNotEmpty && !results.contains(ConnectivityResult.none);
      if (online) {
        unawaited(flush());
      }
    });
  }

  // ---------- API ----------

  Future<void> enqueueExcel({
    required String path,
    String? filename,
    String? to,
    String? subject,
    String? text,
  }) async {
    final item = OutboxItem(
      kind: OutboxKind.excel,
      path: path,
      filename: filename ?? p.basename(path),
      to: to,
      subject: subject,
      text: text,
    );
    await _box.add(item.toJson());
  }

  Future<void> enqueuePdf({
    required String path,
    String? filename,
    String? to,
    String? subject,
    String? text,
  }) async {
    final item = OutboxItem(
      kind: OutboxKind.pdf,
      path: path,
      filename: filename ?? p.basename(path),
      to: to,
      subject: subject,
      text: text,
    );
    await _box.add(item.toJson());
  }

  /// Procesa la cola. Devuelve cantidad de items enviados.
  Future<int> flush() async {
    if (isSyncing.value) return 0;
    isSyncing.value = true;

    var sent = 0;
    try {
      final keys = List.of(_box.keys);
      final now = DateTime.now();

      for (final key in keys) {
        final raw = _box.get(key);
        if (raw is! Map) continue;

        final item = OutboxItem.fromJson(Map<String, dynamic>.from(raw));

        if (item.attempts >= _maxAttempts) {
          continue; // tope de reintentos
        }

        final wait = _backoffFor(item.attempts);
        if (item.lastTryAt != null && now.difference(item.lastTryAt!) < wait) {
          continue;
        }

        var ok = false;
        try {
          switch (item.kind) {
            case OutboxKind.excel:
              ok = await SendReportService.instance.trySendExcelFromPath(
                path: item.path,
                filename: item.filename,
                to: item.to,
                subject: item.subject,
                text: item.text,
              );
              break;
            case OutboxKind.pdf:
              ok = await SendReportService.instance.trySendPdfFromPath(
                path: item.path,
                filename: item.filename,
                to: item.to,
                subject: item.subject,
                text: item.text,
              );
              break;
          }
        } catch (_) {
          ok = false;
        }

        if (ok) {
          await _box.delete(key);
          sent++;
        } else {
          item.attempts += 1;
          item.lastTryAt = now;
          await _box.put(key, item.toJson());
        }
      }
    } finally {
      isSyncing.value = false;
    }
    return sent;
  }

  Duration _backoffFor(int attempts) {
    var seconds = _baseBackoff.inSeconds * (1 << attempts);
    final cap = _maxBackoff.inSeconds;
    if (seconds > cap) seconds = cap;
    return Duration(seconds: seconds);
  }
}
