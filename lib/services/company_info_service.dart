import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';

/// Modelo simple para info de empresa.
class CompanyInfo {
  final String nombre;
  final String direccion;
  final String email;
  final Color color;
  final String? logoPath;

  CompanyInfo({
    required this.nombre,
    required this.direccion,
    required this.email,
    required this.color,
    this.logoPath,
  });
}

/// Servicio local para cargar y guardar info/logo de empresa.
class CompanyInfoService {
  static Future<String> _infoPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/empresa_info.txt';
  }

  static Future<String> _logoPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/logo_empresa.png';
  }

  /// Lee la info local. Si no existe, retorna valores por defecto.
  static Future<CompanyInfo> load() async {
    String nombre = 'Empresa S.A.';
    String direccion = 'Dirección no cargada';
    String email = 'contacto@empresa.com';
    Color color = Colors.cyan;
    String? logoPath;

    try {
      final infoFile = File(await _infoPath());
      if (await infoFile.exists()) {
        final lines = await infoFile.readAsLines();
        if (lines.length >= 4) {
          nombre = lines[0].trim().isNotEmpty ? lines[0] : nombre;
          direccion = lines[1].trim().isNotEmpty ? lines[1] : direccion;
          email = lines[2].trim().isNotEmpty ? lines[2] : email;
          try {
            color = Color(int.parse(lines[3]));
          } catch (_) {}
        }
      }
    } catch (_) {}

    try {
      final logoFile = File(await _logoPath());
      if (await logoFile.exists()) logoPath = logoFile.path;
    } catch (_) {}

    return CompanyInfo(
      nombre: nombre,
      direccion: direccion,
      email: email,
      color: color,
      logoPath: logoPath,
    );
  }

  /// Guarda la info local de la empresa.
  static Future<void> save(CompanyInfo info) async {
    final infoFile = File(await _infoPath());
    await infoFile.writeAsString([
      info.nombre,
      info.direccion,
      info.email,
      info.color.value.toString(),
    ].join('\n'));
    // El logo se guarda aparte con [saveLogo]
  }

  /// Guarda el logo (imagen) en la carpeta local de la app.
  static Future<void> saveLogo(File image) async {
    final dest = File(await _logoPath());
    await image.copy(dest.path);
  }
}
