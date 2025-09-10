// lib/services/pdf_export_service.dart
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/measurement.dart';

class PdfExportService {
  static Future<File> exportMeasurementsPdf({
    required List<Measurement> data,
    required String fileName,
    String title = 'Mediciones',
    String? logoPath,
    List<String>? headers,
  }) {
    return export(
      title: title,
      rows: data,
      logoPath: logoPath,
      headers: headers,
      fileName: fileName,
    );
  }

  static Future<File> export({
    required String title,
    required List<Measurement> rows,
    String? logoPath,
    List<String>? headers,
    String fileName = 'gridnote_report.pdf',
  }) async {
    final doc = pw.Document();

    final tableHeaders = headers ??
        const <String>['Fecha', 'Progresiva', '1m (ÃƒÆ’Ã…Â½Ãƒâ€šÃ‚Â©)', '3m (ÃƒÆ’Ã…Â½Ãƒâ€šÃ‚Â©)', 'Observaciones', 'Lat', 'Lng'];

    pw.ImageProvider? logo;
    if (logoPath != null && logoPath.isNotEmpty) {
      final f = File(logoPath);
      if (await f.exists()) {
        logo = pw.MemoryImage(await f.readAsBytes());
      }
    }

    final nowFmt = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final data = rows
        .map((m) => <dynamic>[
      m.dateString,
      m.progresiva,
      m.ohm1m.toString(),
      m.ohm3m.toString(),
      m.observations,
      m.latitude?.toStringAsFixed(6) ?? '',
      m.longitude?.toStringAsFixed(6) ?? '',
    ])
        .toList();

    final headerAlignments = <int, pw.Alignment>{
      for (var i = 0; i < tableHeaders.length; i++) i: pw.Alignment.centerLeft,
    };
    final cellAlignments = <int, pw.Alignment>{
      0: pw.Alignment.centerLeft,
      1: pw.Alignment.centerLeft,
      2: pw.Alignment.centerRight,
      3: pw.Alignment.centerRight,
      4: pw.Alignment.centerLeft,
      5: pw.Alignment.centerRight,
      6: pw.Alignment.centerRight,
    };
    final columnWidths = <int, pw.TableColumnWidth>{
      0: const pw.FlexColumnWidth(1.2),
      1: const pw.FlexColumnWidth(1.4),
      2: const pw.FlexColumnWidth(1.0),
      3: const pw.FlexColumnWidth(1.0),
      4: const pw.FlexColumnWidth(2.5),
      5: const pw.FlexColumnWidth(1.2),
      6: const pw.FlexColumnWidth(1.2),
    };

    doc.addPage(
      pw.MultiPage(
        pageTheme: const pw.PageTheme(margin: pw.EdgeInsets.all(24)),
        build: (ctx) => <pw.Widget>[
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logo != null)
                pw.Container(
                  width: 60,
                  height: 60,
                  margin: const pw.EdgeInsets.only(right: 16),
                  child: pw.Image(logo),
                ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Reporte de Gridnote',
                      style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700),
                    ),
                    pw.Text(
                      title,
                      style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text('Generado: $nowFmt', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: tableHeaders,
            data: data,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.black),
            rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerAlignments: headerAlignments,
            cellAlignments: cellAlignments,
            columnWidths: columnWidths,
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          ),
        ],
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/${_safe(fileName)}');
    await file.writeAsBytes(await doc.save(), flush: true);
    return file;
  }

  static String _safe(String name) {
    var n = name.trim().isEmpty ? 'gridnote_report' : name.trim();
    n = n.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    if (!n.toLowerCase().endsWith('.pdf')) n = '$n.pdf';
    return n;
  }
}
