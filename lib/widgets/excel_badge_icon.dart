import 'package:flutter/material.dart';

/// Pequeño “badge” para el formato Excel (XLSX), escalable por `size`.
class ExcelBadgeIcon extends StatelessWidget {
  const ExcelBadgeIcon({
    super.key,
    this.size = 20,
    this.backgroundColor,
    this.textColor = Colors.white,
    this.semanticsLabel = 'Ícono de formato Excel XLSX',
    this.isButton = false,
    this.tooltip,
  });

  /// Alto base del badge. El ancho se calcula con [_kAspectRatio].
  final double size;

  /// Color de fondo. Por defecto, verde Excel.
  final Color? backgroundColor;

  /// Color del texto “XLSX”.
  final Color textColor;

  /// Etiqueta para lectores de pantalla. Si querés que sea decorativo, pasá `null`.
  final String? semanticsLabel;

  /// Si el badge se usa dentro de un botón, marcá `true` para mejor accesibilidad.
  final bool isButton;

  /// Tooltip opcional (se muestra al dejar pulsado / hover).
  final String? tooltip;

  // ── “Números mágicos” documentados ──────────────────────────────────────────
  // Proporción ancho/alto del rectángulo (suaviza el aspecto del badge).
  static const double _kAspectRatio = 1.35;
  // Radio de esquinas relativo al alto ⇒ look consistente a cualquier escala.
  static const double _kCornerRadiusFactor = .2;
  // Tamaño de fuente relativo al alto ⇒ legible a cualquier escala.
  static const double _kFontSizeFactor = .36;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? const Color(0xFF1F8C3A);

    Widget badge = Container(
      height: size,
      width: size * _kAspectRatio, // relación de aspecto documentada arriba
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(size * _kCornerRadiusFactor),
      ),
      alignment: Alignment.center,
      child: Text(
        'XLSX',
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w800,
          fontSize: size * _kFontSizeFactor,
          letterSpacing: .5,
        ),
      ),
    );

    if (tooltip != null) {
      badge = Tooltip(message: tooltip!, child: badge);
    }

    // Accesibilidad: etiqueta descriptiva y rol de botón opcional.
    return semanticsLabel == null
        ? ExcludeSemantics(child: badge)
        : Semantics(label: semanticsLabel, button: isButton, child: badge);
  }
}
