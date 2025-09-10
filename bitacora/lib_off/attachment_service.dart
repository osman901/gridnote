// lib/services/attachment_service.dart
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/sheets_dao.dart';

/// Servicio básico para gestionar adjuntos (fotos) de una entrada.
/// - Copia el archivo a una carpeta interna
/// - Calcula hash md5 para evitar duplicados
/// - Inserta el registro en la tabla attachments vía SheetsDao
class AttachmentService {
  AttachmentService(this._dao);
  final SheetsDao _dao;

  Future<void> addPhotoToEntry({
    required int entryId,
    required File original,
  }) async {
    // Lee bytes, calcula hash
    final bytes = await original.readAsBytes();
    final hash = md5.convert(bytes).toString();

    // Carpeta de adjuntos
    final baseDir = await getApplicationDocumentsDirectory();
    final destDir = Directory(p.join(baseDir.path, 'attachments'));
    if (!await destDir.exists()) {
      await destDir.create(recursive: true);
    }

    // Nombre por hash para evitar duplicados físicos
    final ext = p.extension(original.path).toLowerCase();
    final fileName = '$hash$ext';
    final dest = File(p.join(destDir.path, fileName));

    if (!await dest.exists()) {
      await dest.writeAsBytes(bytes, flush: true);
    }

    final sizeBytes = await dest.length();

    // En esta versión usamos el mismo path como "thumbPath" (placeholder)
    await _dao.insertAttachment(
      entryId: entryId,
      path: dest.path,
      thumbPath: dest.path,
      sizeBytes: sizeBytes,
      hash: hash,
    );
  }
}
