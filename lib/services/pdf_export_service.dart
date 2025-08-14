// lib/services/pdf_export_service.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:barcode/barcode.dart';

import '../models/measurement.dart';
import 'signature_service.dart';

class PdfExportService {
  static Future<File> exportMeasurementsPdf({
    required List<Measurement> data,
    String title = 'Mediciones',
    String? companyName,
    String? logoPath,
    String fileName = 'mediciones.pdf',
    bool compartir = false,
    bool abrirDespues = false,
  }) async {
    final doc = pw.Document();

    // Payload + firma para QR
    final payload = _payloadFrom(data);
    final hmac = await SignatureService.hmacOf(payload);
    final qrText = 'gridnote:v1|$payload|$hmac';

    // Logo opcional (lectura síncrona, el logo suele ser pequeño)
    pw.ImageProvider? logoImage;
    if (logoPath != null && logoPath.isNotEmpty) {
      final f = File(logoPath);
      if (await f.exists()) {
        logoImage = pw.MemoryImage(f.readAsBytesSync());
      }
    }

    final pageTheme = pw.PageTheme(
      margin: const pw.EdgeInsets.all(24),
      textDirection: pw.TextDirection.ltr,
      pageFormat: pdf.PdfPageFormat.a4,
    );

    doc.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        header: (_) => _buildHeader(title: title, companyName: companyName, logo: logoImage),
        footer: (ctx) => _buildFooter(ctx),
        build: (ctx) => [
          _buildQr(qrText),
          pw.SizedBox(height: 12),
          _buildTable(data),
        ],
      ),
    );

    // Guardar SIEMPRE en Documents/reports
    final docs = await getApplicationDocumentsDirectory();
    final reports = Directory('${docs.path}/reports');
    if (!await reports.exists()) await reports.create(recursive: true);

    // ✅ FIX Path Traversal: usar solo el nombre base del archivo
    var safeName = p.basename(fileName).trim();
    if (safeName.isEmpty) safeName = 'mediciones.pdf';

    final outFile = File('${reports.path}/$safeName');
    await outFile.writeAsBytes(await doc.save(), flush: true);

    // ✅ FIX lógica: permitir ambas acciones si se solicitan
    if (compartir) {
      await Share.shareXFiles(
        [XFile(outFile.path)],
        text: '$title generado en GridNote',
        subject: title,
      );
    }
    if (abrirDespues) {
      await OpenFile.open(outFile.path);
    }

    return outFile;
  }

  // --- Utilidades ---

  static String _payloadFrom(List<Measurement> data) {
    final parts = <String>[];
    for (final m in data) {
      parts.add('${m.progresiva}|${m.ohm1m}|${m.ohm3m}|${m.observations}|${m.date.toIso8601String()}');
    }
    return parts.join('~');
  }

  static String _formatDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    return '$d/$m/$y';
  }

  static String _formatDateTime(DateTime dt) {
    final date = _formatDate(dt);
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$date $hh:$mm';
  }

  static pw.Widget _buildQr(String text) {
    final bc = Barcode.qrCode();
    final svg = bc.toSvg(text, width: 120, height: 120);
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: pdf.PdfColors.grey300, width: 0.6),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.SvgImage(svg: svg),
      ),
    );
  }

  static pw.Widget _buildHeader({
    required String title,
    String? companyName,
    pw.ImageProvider? logo,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (logo != null)
            pw.Container(
              height: 36,
              width: 36,
              margin: const pw.EdgeInsets.only(right: 12),
              child: pw.Image(logo, fit: pw.BoxFit.contain),
            ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: pdf.PdfColors.blueGrey900,
                  ),
                ),
                if (companyName != null && companyName.trim().isNotEmpty)
                  pw.Text(
                    companyName,
                    style: pw.TextStyle(fontSize: 11, color: pdf.PdfColors.blueGrey600),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Context ctx) {
    final now = DateTime.now();
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generado: ${_formatDateTime(now)}',
            style: const pw.TextStyle(fontSize: 9, color: pdf.PdfColors.grey700),
          ),
          pw.Text(
            'Página ${ctx.pageNumber} de ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: pdf.PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTable(List<Measurement> data) {
    const headers = <String>['#', 'Progresiva', '1 m Ω', '3 m Ω', 'Obs.', 'Fecha'];

    final rows = List<List<String>>.generate(data.length, (i) {
      final m = data[i];
      return [
        '${i + 1}',
        m.progresiva,
        m.ohm1m.toString(),
        m.ohm3m.toString(),
        m.observations,
        _formatDate(m.date),
      ];
    });

    final columnWidths = <int, pw.TableColumnWidth>{
      0: const pw.FlexColumnWidth(0.6),
      1: const pw.FlexColumnWidth(1.2),
      2: const pw.FlexColumnWidth(0.9),
      3: const pw.FlexColumnWidth(0.9),
      4: const pw.FlexColumnWidth(2.2),
      5: const pw.FlexColumnWidth(1.1),
    };

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      headerDecoration: const pw.BoxDecoration(color: pdf.PdfColors.blueGrey800),
      headerStyle: pw.TextStyle(
        color: pdf.PdfColors.white,
        fontWeight: pw.FontWeight.bold,
        fontSize: 10,
      ),
      cellStyle: const pw.TextStyle(fontSize: 9),
      headerAlignment: pw.Alignment.centerLeft,
      cellAlignment: pw.Alignment.centerLeft,
      border: null,
      headerPadding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      cellPadding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
      columnWidths: columnWidths,
      rowDecoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: pdf.PdfColors.grey300, width: 0.5),
        ),
      ),
      oddRowDecoration: const pw.BoxDecoration(
        color: pdf.PdfColor.fromInt(0xFFF7F8FA),
      ),
    );
  }
}
