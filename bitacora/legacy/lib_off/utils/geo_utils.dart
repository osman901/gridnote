// lib/utils/geo_utils.dart
/// Utilidades de coordenadas y URLs de mapas.
class GeoUtils {
  GeoUtils._();

  /// Valida rango y evita (0,0) ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã¢â‚¬Å“Null IslandÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â.
  static bool isValid(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    if (!lat.isFinite || !lng.isFinite) return false;
    if (lat == 0.0 && lng == 0.0) return false;
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  static String fmt(double v, {int decimals = 6}) =>
      v.toStringAsFixed(decimals);

  static Uri geoUri(double lat, double lng, {String? label}) {
    final fLat = fmt(lat), fLng = fmt(lng);
    final q = label == null
        ? '$fLat,$fLng'
        : '$fLat,$fLng(${Uri.encodeComponent(label)})';
    return Uri.parse('geo:$fLat,$fLng?q=$q');
  }

  static Uri mapsUri(double lat, double lng) {
    final fLat = fmt(lat), fLng = fmt(lng);
    return Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$fLat,$fLng');
  }
}
