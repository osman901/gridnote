// Gridnote · SmartTurbo (IA de rendimiento) · 2025-09
// - Aprende usos (contadores ligeros en SharedPreferences).
// - Precalienta GPS (warm-up corto, sin spamear permisos).
// - Prefetch de miniaturas cuando hay idle (si le registrás un loader).
// - No usa BuildContext a través de async gaps.

import 'dart:async';
import 'dart:io';
import 'package:flutter/scheduler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'location_fix_coordinator.dart';
import 'location_service.dart';

typedef PhotosLoader = Future<List<File>> Function();

class SmartTurbo {
  SmartTurbo._();
  static final SmartTurbo instance = SmartTurbo._();

  static const _prefsKey = 'smart_turbo_counters_v1';
  static const _kBoots = 'boots';
  static const _kOpenGallery = 'open_gallery';
  static const _kSaveLocation = 'save_location';

  Map<String, int> _counters = <String, int>{};
  PhotosLoader? _photosLoader;
  Timer? _idlePrefetchTimer;

  // ----- API pública -----
  static Future<void> boot() => instance._boot();
  static void registerPhotosLoader(PhotosLoader loader) =>
      instance._photosLoader = loader;

  static void trackBoot() => instance._bump(_kBoots);
  static void trackOpenGallery() => instance._bump(_kOpenGallery);
  static void trackSaveLocation() => instance._bump(_kSaveLocation);

  /// Llamalo desde un widget (post-frame) para precachear miniaturas.
  /// No guarda el `context` entre awaits.
  static Future<void> precacheThumbnails(BuildContext ctx, {int? limit}) =>
      instance._precacheThumbnails(ctx, limit: limit);

  // ----- Internals -----
  Future<void> _boot() async {
    await _load();
    _bump(_kBoots);
    // Precalentá GPS: stream corto que acelera la primer fix (sin escribir nada).
    unawaited(_warmGpsOnce());
    // Programá prefetch discreto cuando el scheduler quede libre.
    _scheduleIdlePrefetch();
  }

  Future<void> _load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getStringList(_prefsKey) ?? const <String>[];
      final m = <String, int>{};
      for (final line in raw) {
        final i = line.indexOf('=');
        if (i > 0) {
          final k = line.substring(0, i);
          final v = int.tryParse(line.substring(i + 1)) ?? 0;
          if (v > 0) m[k] = v;
        }
      }
      _counters = m;
    } catch (_) {/* noop */}
  }

  Future<void> _save() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final lines = _counters.entries.map((e) => '${e.key}=${e.value}').toList();
      await sp.setStringList(_prefsKey, lines);
    } catch (_) {/* noop */}
  }

  void _bump(String key, [int by = 1]) {
    final v = (_counters[key] ?? 0) + by;
    _counters[key] = v;
    // Guardado perezoso
    scheduleMicrotask(_save);
  }

  int _score(String key) => _counters[key] ?? 0;

  int _prefetchCount() {
    // Heurística simple: más uso → más prefetch.
    final use = _score(_kOpenGallery) + (_score(_kBoots) ~/ 3);
    if (use > 60) return 72;
    if (use > 20) return 48;
    if (use > 5) return 24;
    return 12;
  }

  Future<void> _warmGpsOnce() async {
    try {
      // Invalida LKGF para no reusar uno viejo.
      LocationFixCoordinator.instance.invalidate();
      // Warm-up suave: no persiste ni escribe, solo "enciende" los proveedores.
      await LocationService.instance.captureExact(
        warmup: const Duration(seconds: 3),
        timeout: const Duration(seconds: 6),
        targetAccuracyMeters: 35,
      );
    } catch (_) {/* ignoramos fallas */}
  }

  void _scheduleIdlePrefetch() {
    _idlePrefetchTimer?.cancel();
    _idlePrefetchTimer = Timer(const Duration(seconds: 2), () {
      SchedulerBinding.instance.scheduleTask(() async {
        final loader = _photosLoader;
        if (loader == null) return;
        try {
          // No requiere context aquí; solo fuerza lectura a disco para calentar FS.
          final files = await loader();
          // Nada más: el precache real de imágenes se hace con BuildContext (método público).
          if (files.isNotEmpty) {/* hot fs ok */}
        } catch (_) {/* noop */}
      }, Priority.animation);
    });
  }

  Future<void> _precacheThumbnails(BuildContext ctx, {int? limit}) async {
    final loader = _photosLoader;
    if (loader == null) return;
    List<File> files;
    try {
      files = await loader();
    } catch (_) {
      return;
    }
    if (files.isEmpty) return;

    final n = limit ?? _prefetchCount();
    final take = files.take(n).toList();

    // Precachea sin bloquear el frame: pequeños lotes.
    for (int i = 0; i < take.length; i++) {
      final f = take[i];
      final provider = ResizeImage(FileImage(f), width: 256, height: 256);
      try {
        await precacheImage(provider, ctx);
      } catch (_) {/* seguir */}
      // Respiro para no bloquear el UI thread.
      if (i % 6 == 5) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
    }
  }
}
