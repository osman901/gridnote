import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// HUD de "Guardado" con tilde + haptic, estilo iOS.
/// Uso: await SavedHUD.show(context, text: 'Planilla guardada');
class SavedHUD {
  static DateTime? _lastShownAt;

  /// Muestra el HUD. Internamente hace throttle (2s) para no ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã¢â‚¬Å“spamearÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â.
  static Future<void> show(
      BuildContext context, {
        String text = 'Guardado',
        Duration minInterval = const Duration(seconds: 2),
        Duration visibleFor = const Duration(milliseconds: 900),
      }) async {
    // Haptic inmediato
    unawaited(HapticFeedback.lightImpact());

    // Throttle
    final now = DateTime.now();
    if (_lastShownAt != null && now.difference(_lastShownAt!) < minInterval) return;
    _lastShownAt = now;

    // Capturar overlay SIN usar context despuÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©s del await.
    final overlay = Overlay.of(context);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: IgnorePointer(
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.85, end: 1.0),
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) => Opacity(
                opacity: 0.98,
                child: Transform.scale(scale: scale, child: child),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.80),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 18)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_rounded, color: Colors.white, size: 36),
                    const SizedBox(width: 10),
                    Text(
                      text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        letterSpacing: .2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    await Future.delayed(visibleFor);
    if (entry.mounted) entry.remove();
  }
}
