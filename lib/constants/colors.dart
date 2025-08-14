import 'package:flutter/material.dart';

/// Paleta de colores profesional, compatible con modo claro y oscuro.
class AppColors {
  // PRINCIPALES
  static const Color primary         = Color(0xFF00BCD4); // Cyan PRO
  static const Color accent          = Color(0xFF003344); // Azul oscuro
  static const Color bg              = Color(0xFFF6F8FB); // Gris muy claro
  static const Color backgroundLight = Color(0xFFF6F8FB); // igual a bg
  static const Color backgroundDark  = Color(0xFF171A1D); // negro grisáceo oscuro

  // SUPERFICIES
  static const Color surface         = Color(0xFFFFFFFF); // blanco para tarjetas/barras
  static const Color surfaceDark     = Color(0xFF23272A); // gris oscuro para dark

  // TEXTO Y BORDES
  static const Color black           = Color(0xFF171A1D);
  static const Color white           = Color(0xFFFFFFFF);
  static const Color grey            = Color(0xFFB0BEC5);
  static const Color rowAlt          = Color(0xFFF0F0F0);
  static const Color header          = Color(0xFF006064);

  // ESTADOS
  static const Color danger          = Color(0xFFD32F2F); // Rojo para errores
  static const Color success         = Color(0xFF43A047); // Verde éxito
  static const Color warning         = Color(0xFFFFA000); // Amarillo advertencia

  // ACCESIBILIDAD
  static const Color error           = danger;
  static const Color text            = black;
  static const Color textLight       = white;
}