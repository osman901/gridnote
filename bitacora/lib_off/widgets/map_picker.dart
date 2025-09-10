import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../services/location_share_service.dart';

class MapPickerResult {
  final double lat;
  final double lng;
  final String label;
  const MapPickerResult(this.lat, this.lng, this.label);
}

Future<MapPickerResult?> showMapPicker(
    BuildContext context, {
      double? initialLat,
      double? initialLng,
      String initialLabel = '',
    }) {
  return Navigator.of(context).push<MapPickerResult>(
    MaterialPageRoute(
      builder: (_) => _MapPickerPage(
        initialLat: initialLat,
        initialLng: initialLng,
        initialLabel: initialLabel,
      ),
    ),
  );
}

class _MapPickerPage extends StatefulWidget {
  const _MapPickerPage({this.initialLat, this.initialLng, this.initialLabel = ''});
  final double? initialLat;
  final double? initialLng;
  final String initialLabel;

  @override
  State<_MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<_MapPickerPage> {
  final MapController _map = MapController();
  late final TextEditingController _labelController;

  LatLng? _pin;
  String _label = '';
  bool _locBusy = false;

  @override
  void initState() {
    super.initState();
    _label = widget.initialLabel;
    _labelController = TextEditingController(text: _label)
      ..addListener(() => _label = _labelController.text);

    if (widget.initialLat != null && widget.initialLng != null) {
      _pin = LatLng(widget.initialLat!, widget.initialLng!);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _map.move(_pin!, 16);
      });
    } else {
      _goToMyLocation();
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _goToMyLocation() async {
    if (_locBusy) return;
    setState(() => _locBusy = true);
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) throw Exception('GPS desactivado');
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        throw Exception('Sin permiso de ubicaciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n');
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final here = LatLng(pos.latitude, pos.longitude);
      _map.move(here, 16);
      setState(() => _pin ??= here);
      HapticFeedback.selectionClick();
    } catch (_) {
      _map.move(_pin ?? const LatLng(-34.6037, -58.3816), 12); // fallback
    } finally {
      if (mounted) setState(() => _locBusy = false);
    }
  }

  void _setPin(LatLng p) {
    setState(() => _pin = p);
    HapticFeedback.lightImpact();
  }

  void _copy() {
    if (_pin == null) return;
    Clipboard.setData(ClipboardData(text: '${_pin!.latitude},${_pin!.longitude}'));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coordenadas copiadas')));
  }

  void _share() {
    if (_pin == null) return;
    LocationShareService.share(_label, _pin!.latitude, _pin!.longitude);
  }

  void _use() {
    if (_pin == null) return;
    Navigator.pop(context, MapPickerResult(_pin!.latitude, _pin!.longitude, _label.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final pin = _pin;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Elegir ubicaciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n'),
        actions: [
          IconButton(onPressed: _copy, icon: const Icon(Icons.copy_all_outlined)),
          IconButton(onPressed: _share, icon: const Icon(Icons.ios_share_outlined)),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: pin ?? const LatLng(-34.6037, -58.3816),
              initialZoom: pin == null ? 12 : 16,
              onTap: (_, p) => _setPin(p),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.gridnote.app',
              ),
              if (pin != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: pin,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.location_on, size: 40, color: Colors.redAccent),
                    ),
                  ],
                ),
            ],
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _labelController,
                      decoration: const InputDecoration(
                        labelText: 'Etiqueta (opcional)',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _locBusy ? null : _goToMyLocation,
                          icon: _locBusy
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.my_location),
                          label: const Text('Mi ubicaciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n'),
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: pin == null ? null : _use,
                          icon: const Icon(Icons.check),
                          label: const Text('Usar este punto'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
