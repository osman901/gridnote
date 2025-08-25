import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/measurement_repository.dart';
import '../models/measurement.dart';
import '../services/excel_import_service.dart';

class ImportExcelButton extends StatelessWidget {
  const ImportExcelButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Importar Excel (.xlsx)',
      icon: const Icon(Icons.upload_file),
      onPressed: () async {
        // Capturamos dependencias derivadas de context ANTES de los await
        final messenger = ScaffoldMessenger.of(context);
        final repo = context.read<MeasurementRepository>();

        final picked = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['xlsx'],
          withData: false,
        );
        if (picked == null || picked.files.isEmpty) return;

        final path = picked.files.single.path;
        if (path == null) {
          messenger.showSnackBar(
            const SnackBar(content: Text('No se pudo abrir el archivo')),
          );
          return;
        }

        final file = File(path);
        final List<Measurement> parsed;
        try {
          parsed = await ExcelImportService.readXlsx(file);
        } catch (e) {
          messenger.showSnackBar(
            SnackBar(content: Text('Error leyendo Excel: $e')),
          );
          return;
        }

        if (parsed.isEmpty) {
          messenger.showSnackBar(
            const SnackBar(content: Text('No se encontraron filas válidas')),
          );
          return;
        }

        if (!context.mounted) return;
        final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Importar Excel'),
            content: Text('Se detectaron ${parsed.length} mediciones. ¿Importar ahora?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Importar'),
              ),
            ],
          ),
        ) ?? false;
        if (!ok) return;

        var added = 0;
        for (final m in parsed) {
          await repo.add(m);
          added++;
        }

        messenger.showSnackBar(
          SnackBar(content: Text('Importadas $added mediciones')),
        );
      },
    );
  }
}
