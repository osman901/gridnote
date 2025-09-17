// lib/services/smart_turbo.dart
// Gridnote ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â· SmartTurbo (IA de rendimiento) ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â· 2025-09
// - Contadores ligeros en SharedPreferences.
// - Warm-up de GPS sin pedir permisos extra.
// - Prefetch discreto de miniaturas cuando hay idle.
// - No usa BuildContext a travÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©s de async gaps.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // ---------- API pÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âºblica ----------
  static Future<void> boot() => instance._boot();
  static void registerPhotosLoader(PhotosLoader loader) =>
      instance._photosLoader = loader;

  static void trackBoot() => instance._bump(_kBoots);
  static void trackOpenGallery() => instance._bump(_kOpenGallery);
  static void trackSaveLocation() => instance._bump(_kSaveLocation);

  /// Precarga miniaturas. Usa `BuildContext` solo para derivar una
  /// `ImageConfiguration` al inicio y luego **no lo vuelve a usar**.
  static Future<void> precacheThumbnails(BuildContext ctx, {int? limit}) =>
      instance._precacheThumbnails(ctx, limit: limit);

  // ---------- Internals ----------
  Future<void> _boot() async {
    await _load();
    _bump(_kBoots);
    // Warm-up de GPS no bloqueante.
    unawaited(_warmGpsOnce(
      warmup: const Duration(seconds: 3),
      timeout: const Duration(seconds: 6),
      desiredAccuracy: LocationAccuracy.low,
    ));
    // Prefetch discreto cuando el scheduler quede libre.
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
      final lines =
      _counters.entries.map((e) => '${e.key}=${e.value}').toList();
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
    // HeurÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­stica simple: mÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡s uso ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ mÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡s prefetch.
    final use = _score(_kOpenGallery) + (_score(_kBoots) ~/ 3);
    if (use > 60) return 72;
    if (use > 20) return 48;
    if (use > 5) return 24;
    return 12;
  }

  /// Warm-up de GPS: activa proveedores por poco tiempo.
  /// No persiste nada. No muestra diÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡logos.
  Future<void> _warmGpsOnce({
    required Duration warmup,
    required Duration timeout,
    required LocationAccuracy desiredAccuracy,
  }) async {
    try {
      // Si no hay permisos, no forzamos. Solo calentamos si ya estÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡n.
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return; // sin permisos, no molestamos
      }

      // Stream corto para encender hardware y cache.
      final stream = Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: desiredAccuracy,
          distanceFilter: 0,
        ),
      );

      final sub = stream.listen((_) {}, onError: (_) {});
      // DejÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡ correr un toque para calentar providers.
      await Future<void>.delayed(warmup);

      // Intento de una fix rÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡pida con timeout. Ignoramos resultado.
      await Geolocator.getCurrentPosition(
        desiredAccuracy: desiredAccuracy,
        timeLimit: timeout,
      ).catchError((_) {});

      await sub.cancel();
    } catch (_) {/* ignoramos fallas */}
  }

  void _scheduleIdlePrefetch() {
    _idlePrefetchTimer?.cancel();
    _idlePrefetchTimer = Timer(const Duration(seconds: 2), () {
      SchedulerBinding.instance.scheduleTask(() async {
        final loader = _photosLoader;
        if (loader == null) return;
        try {
          // Solo lectura para calentar FS y metadata.
          final files = await loader();
          if (files.isNotEmpty) {/* hot fs ok */}
        } catch (_) {/* noop */}
      }, Priority.animation);
    });
  }

  Future<void> _precacheThumbnails(BuildContext ctx, {int? limit}) async {
    final loader = _photosLoader;
    if (loader == null) return;

    // Derivamos configuraciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n de imagen **antes** de cualquier await.
    // Luego NO volvemos a usar `ctx`.
    final ImageConfiguration cfg = createLocalImageConfiguration(ctx);

    List<File> files;
    try {
      files = await loader();
    } catch (_) {
      return;
    }
    if (files.isEmpty) return;

    final n = limit ?? _prefetchCount();
    final take = files.take(n).toList();

    // Precache sin bloquear frame: resolver con ImageConfiguration directo.
    for (int i = 0; i < take.length; i++) {
      final f = take[i];
      final provider = ResizeImage(FileImage(f), width: 256, height: 256);
      try {
        await _precacheProvider(provider, cfg);
      } catch (_) {/* continuar */}
      if (i % 6 == 5) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
    }
  }

  /// Precacha un ImageProvider sin requerir `BuildContext` tras awaits.
  Future<void> _precacheProvider(
      ImageProvider provider, ImageConfiguration cfg) {
    final completer = Completer<void>();
    final ImageStream stream = provider.resolve(cfg);
    late final ImageStreamListener listener;
    listener = ImageStreamListener((ImageInfo _, bool __) {
      try {
        stream.removeListener(listener);
      } catch (_) {}
      if (!completer.isCompleted) completer.complete();
    }, onError: (Object _, StackTrace? __) {
      try {
        stream.removeListener(listener);
      } catch (_) {}
      if (!completer.isCompleted) completer.complete(); // seguimos igual
    });
    stream.addListener(listener);
    return completer.future;
  }

  // Llamalo al cerrar la app si querÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©s cancelar timers.
  void dispose() {
    _idlePrefetchTimer?.cancel();
    _idlePrefetchTimer = null;
  }
}
