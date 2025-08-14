import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class LogoService {
  /// Elige una imagen de la galería y la guarda como logo.png en el directorio de la app.
  static Future<bool> elegirLogoEmpresa() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final dir = await getApplicationDocumentsDirectory();
      final logoPath = '${dir.path}/logo.png';
      await File(picked.path).copy(logoPath);
      return true;
    }
    return false;
  }

  /// Devuelve la ruta del logo guardado o null si no existe.
  static Future<String?> obtenerLogoPath() async {
    final dir = await getApplicationDocumentsDirectory();
    final logoPath = '${dir.path}/logo.png';
    return await File(logoPath).exists() ? logoPath : null;
  }

  /// Borra el logo de la empresa.
  static Future<void> borrarLogo() async {
    final dir = await getApplicationDocumentsDirectory();
    final logoPath = '${dir.path}/logo.png';
    final file = File(logoPath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
