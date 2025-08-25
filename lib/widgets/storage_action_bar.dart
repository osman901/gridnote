// lib/widgets/storage_action_bar.dart
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/measurement.dart';
import '../services/storage_manager.dart';
import '../services/xlsx_export_service.dart';

/// Barra simple: guarda local y exporta a XLSX para compartir.
class StorageActionBar extends StatefulWidget {
  const StorageActionBar({
    super.key,
    required this.sheetId,
    required this.sheetTitle,
    required this.itemsProvider,
    this.defaultLat,
    this.defaultLng,
  });

  final String sheetId; // ID único de la planilla
  final String sheetTitle; // Título a mostrar / usar en el XLSX
  final List<Measurement> Function() itemsProvider; // Datos actuales
  final double? defaultLat;
  final double? defaultLng;

  @override
  State<StorageActionBar> createState() => _StorageActionBarState();
}

class _StorageActionBarState extends State<StorageActionBar> {
  bool _busy = false;

  Future<void> _saveAndExport() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      // 1) Guardar en almacenamiento LOCAL, por planilla
      final items = widget.itemsProvider();
      await StorageManager.instance.saveAll(widget.sheetId, items);

      // 2) Exportar XLSX (siempre local) y compartir/abrir con otras apps
      final file = await XlsxExportService().buildFile(
        sheetId: widget.sheetId,
        title: widget.sheetTitle.isEmpty
            ? 'Planilla ${widget.sheetId}'
            : widget.sheetTitle,
        data: items,
        defaultLat: widget.defaultLat,
        defaultLng: widget.defaultLng,
      );

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Planilla ${widget.sheetTitle}',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Guardado y exportado.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: _busy ? null : _saveAndExport,
      icon: _busy
          ? const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      )
          : const Icon(Icons.save_outlined),
      label: const Text('Guardar y exportar'),
    );
  }
}
