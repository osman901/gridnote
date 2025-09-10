import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/gridnote_theme.dart';
import '../models/sheet_meta.dart';
import '../services/location_service.dart';
import '../utils/geo_utils.dart';

class LocationScreen extends ConsumerStatefulWidget {
  const LocationScreen({super.key, required this.themeController, required this.meta});
  final GridnoteThemeController themeController;
  final SheetMeta meta;

  @override
  ConsumerState<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends ConsumerState<LocationScreen> {
  double? _lat, _lng;
  late final Future<SharedPreferences> _sp = SharedPreferences.getInstance();
  String get _latKey => 'sheet_${widget.meta.id}_lat';
  String get _lngKey => 'sheet_${widget.meta.id}_lng';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sp = await _sp;
    if (!mounted) return;
    final lat = sp.getDouble(_latKey);
    final lng = sp.getDouble(_lngKey);
    final valid = GeoUtils.isValid(lat, lng);
    if (!valid) {
      await sp.remove(_latKey);
      await sp.remove(_lngKey);
    }
    setState(() {
      _lat = valid ? lat : null;
      _lng = valid ? lng : null;
    });
  }

  Future<void> _saveFromGPS() async {
    // GPS apagado → abrir ajustes
    if (!await Geolocator.isLocationServiceEnabled()) {
      await Geolocator.openLocationSettings();
      return;
    }

    // Permisos
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      return;
    }
    if (perm == LocationPermission.denied) return;

    // Obtener posición
    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    if (!GeoUtils.isValid(pos.latitude, pos.longitude)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lectura GPS inválida. Intentá de nuevo.')),
      );
      return;
    }

    final sp = await _sp;
    await sp.setDouble(_latKey, pos.latitude);
    await sp.setDouble(_lngKey, pos.longitude);

    await _load();
    HapticFeedback.mediumImpact();
  }

  Future<void> _clear() async {
    final sp = await _sp;
    await sp.remove(_latKey);
    await sp.remove(_lngKey);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.themeController.theme;
    final locSvc = LocationService.instance;
    final hasCoords = GeoUtils.isValid(_lat, _lng);
    final coordsText = hasCoords
        ? '${GeoUtils.fmt(_lat!)}, ${GeoUtils.fmt(_lng!)}'
        : 'Sin ubicación guardada';

    return Scaffold(
      backgroundColor: t.scaffold,
      appBar: AppBar(title: const Text('Ubicación general')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.meta.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: t.divider),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                Row(children: [
                  const Icon(Icons.place_outlined),
                  const SizedBox(width: 8),
                  Expanded(child: Text(coordsText)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  FilledButton.icon(
                    onPressed: _saveFromGPS,
                    icon: const Icon(Icons.my_location),
                    label: const Text('Usar GPS'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: hasCoords
                        ? () => locSvc.openInMaps(lat: _lat!, lng: _lng!)
                        : null,
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Abrir en mapas'),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: hasCoords ? _clear : null,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Borrar'),
                  ),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
