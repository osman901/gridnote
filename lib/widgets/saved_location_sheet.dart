import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Hoja modal para mostrar y administrar una ubicación general guardada.
/// Permite abrirla en Google Maps, compartirla o copiarla, o guardar la actual.
Future<void> showSavedLocationSheet({
  required BuildContext context,
  required double? latitude,
  required double? longitude,
  required Future<void> Function() onSaveLocation,
}) {
  return showCupertinoModalBottomSheet(
    context: context,
    expand: false,
    barrierColor: Colors.black54,
    builder: (_) {
      return SavedLocationSheet(
        latitude: latitude,
        longitude: longitude,
        onSaveLocation: onSaveLocation,
      );
    },
  );
}

class SavedLocationSheet extends StatelessWidget {
  const SavedLocationSheet({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.onSaveLocation,
  });

  final double? latitude;
  final double? longitude;
  final Future<void> Function() onSaveLocation;

  bool get _hasLocation => latitude != null && longitude != null;

  @override
  Widget build(BuildContext context) {
    final lat = latitude;
    final lng = longitude;
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 4,
                width: 38,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.place_outlined),
                  const SizedBox(width: 8),
                  Text(
                    _hasLocation ? 'Ubicación general' : 'Ubicación no guardada',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_hasLocation) ...[
                SelectableText(
                  'Lat: ${lat!.toStringAsFixed(6)}, Lon: ${lng!.toStringAsFixed(6)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    final uri = Uri.parse('https://maps.google.com/?q=$lat,$lng');
                    launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Abrir en Google Maps'),
                ),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  onPressed: () {
                    final url = 'https://maps.google.com/?q=$lat,$lng';
                    Share.share(url, subject: 'Ubicación');
                  },
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Compartir enlace'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    final text = '$lat,$lng';
                    Clipboard.setData(ClipboardData(text: text));
                    Navigator.of(context).maybePop();
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copiar coordenadas'),
                ),
              ] else ...[
                const Text('No hay coordenadas guardadas.'),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () async {
                    await onSaveLocation();
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
                  icon: const Icon(Icons.place_outlined),
                  label: const Text('Guardar ubicación actual'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
