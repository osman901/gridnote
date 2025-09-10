import 'package:geolocator/geolocator.dart';

class PermissionsService {
  PermissionsService._();
  static final PermissionsService instance = PermissionsService._();

  /// Pide o verifica permisos de ubicación.
  /// Devuelve true si están concedidos (whileInUse o always).
  Future<bool> ensureLocationPermission() async {
    // ¿Servicio de ubicación encendido?
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return false;

    // Estado actual
    var perm = await Geolocator.checkPermission();

    // Si está denegado, pedimos una vez
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }

    // Denegado para siempre -> sugerir abrir ajustes; devolvemos false
    if (perm == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      return false;
    }

    // Concedido
    return perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
  }
}
