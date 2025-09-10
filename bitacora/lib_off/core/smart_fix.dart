import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart' as intl;

typedef ErrorMatcher = bool Function(Object error, StackTrace stack);
typedef FixApplier = Future<void> Function(Object error, StackTrace stack);
typedef ErrorWidgetBuilder = Widget Function(FlutterErrorDetails details);

class SmartFix {
  SmartFix._();
  static final SmartFix instance = SmartFix._();

  final List<_Rule> _rules = <_Rule>[];
  bool _installed = false;

  /// Instala ganchos globales y reglas por defecto.
  static void install({List<_Rule>? extraRules, ErrorWidgetBuilder? errorWidget}) {
    if (instance._installed) return;
    instance._installed = true;

    // Reglas base
    instance._rules.addAll(_defaultRules);
    if (extraRules != null) instance._rules.addAll(extraRules);

    // Captura errores de Flutter
    final prevOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      prevOnError?.call(details);
      FlutterError.presentError(details);
      instance._handle(details.exception, details.stack ?? StackTrace.current);
    };

    // Captura errores de plataforma
    final prevPlatformOnError = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      instance._handle(error, stack);
      return prevPlatformOnError?.call(error, stack) ?? true;
    };

    // Zona para async
    runZonedGuarded(() {}, (error, stack) => instance._handle(error, stack));

    // Widget de error (fallback visual)
    if (errorWidget != null) {
      ErrorWidget.builder = (Object e) {
        final details = FlutterErrorDetails(exception: e, stack: StackTrace.current);
        return errorWidget(details);
      };
    }
  }

  void addRule({required String name, required ErrorMatcher match, required FixApplier apply}) {
    _rules.add(_Rule(name, match, apply));
  }

  Future<void> _handle(Object error, StackTrace stack) async {
    for (final r in _rules) {
      try {
        if (r.match(error, stack)) {
          await r.apply(error, stack);
          break; // aplicamos la primera que matchee
        }
      } catch (_) {/* no-op */}
    }
  }

  // Helpers reutilizables
  static T? tryOrNull<T>(T Function() fn) { try { return fn(); } catch (_) { return null; } }
  static Future<T?> tryAsync<T>(Future<T> Function() fn) async { try { return await fn(); } catch (_) { return null; } }
}

/// ExtensiÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n segura para evitar "setState() called after dispose()"
extension SafeState on State {
  void safeSetState(VoidCallback fn) { if (mounted) setState(fn); }
}

/// Regla (matcher + fix)
class _Rule {
  final String name;
  final ErrorMatcher match;
  final FixApplier apply;
  const _Rule(this.name, this.match, this.apply);
}

/// Reglas por defecto (no invasivas)
final List<_Rule> _defaultRules = <_Rule>[
  // 1) Desborde de layout (RenderFlex overflow): no se puede ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã¢â‚¬Å“arreglarÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â aquÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­,
  //    pero al menos evitamos crash y dejamos un fallback visual en ErrorWidget.
  _Rule(
    'Render overflow notice',
        (e, _) => e.toString().contains('A RenderFlex overflowed'),
        (e, _) async {
      debugPrint('[SmartFix] Render overflow detectado: $e');
    },
  ),

  // 2) setState() despuÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©s de dispose: sÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³lo avisamos, usar safeSetState en cÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³digo.
  _Rule(
    'setState after dispose',
        (e, _) => e.toString().contains('setState() called after dispose()'),
        (e, _) async => debugPrint('[SmartFix] Ignorado: $e (usa safeSetState)'),
  ),

  // 3) Problemas de formateo de fechas/regiones -> inicializamos Intl por defecto.
  _Rule(
    'Intl fallback',
        (e, s) => e is FormatException && s.toString().contains('DateFormat'),
        (e, _) async {
      debugPrint('[SmartFix] Re-inicializando Intl (es)ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¦');
      try { await intl.initializeDateFormatting('es'); } catch (_) {}
    },
  ),

  // 4) Archivos inexistentes (p. ej. foto eliminada): lo tratamos como no fatal.
  _Rule(
    'File not found soft-fail',
        (e, _) => e.toString().contains('FileSystemException') &&
        (e.toString().contains('No such file') || e.toString().contains('no such file')),
        (e, _) async => debugPrint('[SmartFix] Archivo faltante ignorado: $e'),
  ),
];
