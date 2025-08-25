// Solicita permisos claves (Android 13/14+): notifs y fotos seleccionadas.
import 'dart:io' show Platform;
import 'package:permission_handler/permission_handler.dart';

enum PhotosAccess { grantedAll, grantedLimited, denied, permanentlyDenied }

class PermissionsService {
  PermissionsService._();
  static final instance = PermissionsService._();

  /// Llamá esto una vez al inicio de la app.
  Future<void> requestStartupPermissions() async {
    await _ensureNotificationPermission();
    await _ensurePhotosPermission();
  }

  Future<bool> _ensureNotificationPermission() async {
    if (!Platform.isAndroid) return true;
    final st = await Permission.notification.status;
    if (st.isGranted) return true;
    final r = await Permission.notification.request();
    return r.isGranted;
  }

  /// Android 13+: READ_MEDIA_IMAGES; Android 14+: “fotos seleccionadas”.
  /// Devuelve el estado para que ajustes UX si hay acceso limitado.
  Future<PhotosAccess> _ensurePhotosPermission() async {
    if (!Platform.isAndroid) return PhotosAccess.grantedAll;

    // En Android <=32, 'photos' cae en READ_EXTERNAL_STORAGE internamente.
    var st = await Permission.photos.status;
    if (st.isGranted) return PhotosAccess.grantedAll;
    if (st.isPermanentlyDenied) return PhotosAccess.permanentlyDenied;

    st = await Permission.photos.request();
    if (st.isGranted) return PhotosAccess.grantedAll;

    // Algunos plugins exponen 'limited' (Android 14+) similar a iOS.
    if (st.name.toLowerCase().contains('limited')) return PhotosAccess.grantedLimited;

    if (st.isPermanentlyDenied) {
      // Opcional: abrir settings si querés guiar al usuario
      // await openAppSettings();
      return PhotosAccess.permanentlyDenied;
    }
    return PhotosAccess.denied;
  }
}
