// Gridnote · SmartNotifier (cola + IA de política) · sin BuildContext tras async
import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'activity_tracker.dart';

enum SmartKind { info, success, warning, error }

class SmartToast {
  final String id;
  final String message;
  final SmartKind kind;
  final Duration duration;
  int count;
  final DateTime createdAt;
  SmartToast({
    required this.id,
    required this.message,
    required this.kind,
    required this.duration,
    this.count = 1,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

class SmartNotifier {
  SmartNotifier._();
  static final SmartNotifier instance = SmartNotifier._();

  final Queue<SmartToast> _q = Queue<SmartToast>();
  final ValueNotifier<SmartToast?> visibleToast = ValueNotifier<SmartToast?>(null);

  Timer? _pump;
  bool _showing = false;

  void info(String msg, {Duration duration = const Duration(seconds: 2)}) =>
      _enqueue(msg, SmartKind.info, duration);
  void success(String msg, {Duration duration = const Duration(seconds: 2)}) =>
      _enqueue(msg, SmartKind.success, duration);
  void warn(String msg, {Duration duration = const Duration(seconds: 3)}) =>
      _enqueue(msg, SmartKind.warning, duration);
  void error(String msg, {Duration duration = const Duration(seconds: 4)}) =>
      _enqueue(msg, SmartKind.error, duration);

  void _enqueue(String msg, SmartKind k, Duration d) {
    // Dedup: si el último en cola tiene mismo texto y <2s, agrupar
    if (_q.isNotEmpty) {
      final last = _q.last;
      final diff = DateTime.now().difference(last.createdAt).inMilliseconds;
      if (last.message == msg && diff < 2000) {
        last.count += 1;
        _kick();
        return;
      }
    }
    _q.add(SmartToast(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      message: msg,
      kind: k,
      duration: d,
    ));
    _kick();
  }

  void _kick() {
    _pump ??= Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
  }

  void _tick() {
    // Ya mostrando: esperar a que el host lo cierre
    if (_showing || visibleToast.value != null) return;

    // Nada: apagar bomba
    if (_q.isEmpty) {
      _pump?.cancel();
      _pump = null;
      return;
    }

    // Política: ¿es buen momento?
    final policy = ActivityTracker.instance;
    if (!policy.allowToastNow) {
      return; // seguimos esperando periodo siguiente
    }

    // Mostrar siguiente
    final next = _q.removeFirst();
    _showing = true;
    // Adjuntar contador "xN" si corresponde
    final msg = next.count > 1 ? '${next.message} (x${next.count})' : next.message;
    visibleToast.value = SmartToast(
      id: next.id,
      message: msg,
      kind: next.kind,
      duration: next.duration,
      createdAt: next.createdAt,
      count: next.count,
    );
  }

  /// Llamado por el host visual cuando termina de mostrarlo
  void hideCurrent() {
    visibleToast.value = null;
    _showing = false;
    _kick();
  }

  /// Limpia todo
  void clear() {
    _q.clear();
    visibleToast.value = null;
    _showing = false;
    _pump?.cancel();
    _pump = null;
  }
}
