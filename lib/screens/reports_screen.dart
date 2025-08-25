// lib/screens/reports_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../theme/gridnote_theme.dart';
import '../models/sheet_meta.dart';
import '../models/measurement.dart';
import '../state/measurement_async_provider.dart';
import '../services/xlsx_export_service.dart';
import '../services/pdf_export_service.dart';

final xlsxServiceProvider = Provider<XlsxExportService>((_) => XlsxExportService());

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key, required this.themeController, required this.meta});
  final GridnoteThemeController themeController;
  final SheetMeta meta;

  List<Measurement> _all(WidgetRef ref) {
    final asyncAll = ref.read(measurementAsyncProvider(meta.id));
    return asyncAll.hasValue ? (asyncAll.value ?? const <Measurement>[]) : const <Measurement>[];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = themeController.theme;

    Future<void> shareXlsx(List<Measurement> rows) async {
      final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = await ref.read(xlsxServiceProvider).buildFile(
        sheetId: meta.id,
        title: 'gridnote_${meta.name}_$ts',
        data: rows,
      );
      await Share.shareXFiles([XFile(file.path)], text: 'Reporte XLSX – ${meta.name}');
    }

    Future<void> sharePdf(List<Measurement> rows) async {
      final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = await PdfExportService.exportMeasurementsPdf(
        data: rows,
        fileName: 'gridnote_${meta.name}_$ts.pdf',
        title: meta.name,
      );
      await Share.shareXFiles([XFile(file.path)], text: 'Reporte PDF – ${meta.name}');
    }

    final visible = ref
        .watch(measurementFilteredAsyncProvider(meta.id))
        .maybeWhen(data: (r) => r, orElse: () => const <Measurement>[]);
    final all = _all(ref);

    return Scaffold(
      backgroundColor: t.scaffold,
      appBar: AppBar(title: const Text('Reportes')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          _CardRow(
            title: 'Solo visible',
            subtitle: '${visible.length} filas',
            onXlsx: () => shareXlsx(visible),
            onPdf: () => sharePdf(visible),
          ),
          const SizedBox(height: 12),
          _CardRow(
            title: 'Todas las filas',
            subtitle: '${all.length} filas',
            onXlsx: () => shareXlsx(all),
            onPdf: () => sharePdf(all),
          ),
        ]),
      ),
    );
  }
}

class _CardRow extends StatelessWidget {
  const _CardRow({required this.title, required this.subtitle, required this.onXlsx, required this.onPdf});
  final String title, subtitle;
  final VoidCallback onXlsx, onPdf;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Expanded(child: ListTile(title: Text(title), subtitle: Text(subtitle))),
          FilledButton.icon(onPressed: onPdf, icon: const Icon(Icons.picture_as_pdf), label: const Text('PDF')),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(onPressed: onXlsx, icon: const Icon(Icons.table_view), label: const Text('XLSX')),
        ]),
      ),
    );
  }
}
