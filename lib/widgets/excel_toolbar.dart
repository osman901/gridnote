// lib/widgets/excel_toolbar.dart
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:geolocator/geolocator.dart';

import '../theme/gridnote_theme.dart';
import '../services/location_service.dart';
import '../widgets/measurement_pluto_grid.dart';

class ExcelToolbar extends StatefulWidget {
  const ExcelToolbar({
    super.key,
    required this.themeController,
    required this.gridController,
    required this.onFontFamilyChanged,
    this.sheetTitle = '',
  });

  final GridnoteThemeController themeController;
  final MeasurementGridController gridController;
  final ValueChanged<String> onFontFamilyChanged;
  final String sheetTitle;

  @override
  State<ExcelToolbar> createState() => _ExcelToolbarState();
}

class _ExcelToolbarState extends State<ExcelToolbar> {
  String _font = 'Arimo';

  Future<void> _pickColor() async {
    Color picked = Colors.amber;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pintar celda'),
        content: BlockPicker(
          pickerColor: picked,
          onColorChanged: (c) => picked = c,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Aplicar')),
        ],
      ),
    );
    await widget.gridController.colorCellSelected(picked.withValues(alpha: 0.45));
  }

  Future<void> _setMyLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Activá el GPS')));
      return;
    }

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sin permiso de ubicación')));
      return;
    }

    final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    await widget.gridController.setLocationOnSelection(pos.latitude, pos.longitude);

    final url = LocationService.instance.mapsUrl(pos.latitude, pos.longitude);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Ubicación guardada · $url')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.themeController.theme;
    return Material(
      color: t.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _setMyLocation,
              icon: const Icon(Icons.my_location_outlined),
              label: const Text('Ubicación'),
            ),
            FilledButton.icon(
              onPressed: () => widget.gridController.addPhotoOnSelection(),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Foto'),
            ),
            OutlinedButton.icon(
              onPressed: _pickColor,
              icon: const Icon(Icons.format_color_fill),
              label: const Text('Pintar celda'),
            ),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _font,
              onChanged: (v) {
                if (v == null) return;
                setState(() => _font = v);
                widget.onFontFamilyChanged(v);
              },
              items: const [
                DropdownMenuItem(value: 'Arimo', child: Text('Arimo (Arial-like)')),
                DropdownMenuItem(value: 'Roboto', child: Text('Roboto')),
                DropdownMenuItem(value: 'NotoSans', child: Text('Noto Sans')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
