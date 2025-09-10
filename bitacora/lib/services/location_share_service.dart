import 'package:flutter/services.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:share_plus/share_plus.dart';

class LocationShareService {
  /// Enlace universal a Google Maps (web) con zoom razonable.
  static String mapsUrl(double lat, double lng, {String? label}) {
    final qLabel = (label == null || label.trim().isEmpty)
        ? '$lat,$lng'
        : '${Uri.encodeComponent(label)}@$lat,$lng';
    // q: muestra pin; ll: centra; z: zoom
    return 'https://maps.google.com/?q=$qLabel&ll=$lat,$lng&z=17';
    // Alternativa sÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âºper fiable:
    // return 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
  }

  static Future<void> share(String label, double lat, double lng) async {
    final url = mapsUrl(lat, lng, label: label);
    final text = (label.trim().isEmpty) ? url : '$label\n$url';
    await Share.share(text, subject: label.isEmpty ? 'UbicaciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n' : label);
  }

  static Future<void> email(String to, String label, double lat, double lng) async {
    final url = mapsUrl(lat, lng, label: label);
    final email = Email(
      recipients: [to],
      subject: label.isEmpty ? 'UbicaciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n' : 'UbicaciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n: $label',
      body: (label.trim().isEmpty) ? url : '$label\n\n$url',
      isHTML: false,
    );
    try {
      await FlutterEmailSender.send(email);
    } on PlatformException {
      await share(label, lat, lng);
    }
  }
}
