import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/widgets.dart' as pw; // paquete: pdf
import 'package:pdf/pdf.dart';
import '../services/daily_note_service.dart';

/// Abre un bottom sheet con editor de texto plano + exportar PDF.
/// Uso: showDailyNoteSheet(context, sheetId: 'id', accent: Colors.blue);
Future<void> showDailyNoteSheet(
    BuildContext context, {
      required String sheetId,
      Color? accent,
    }) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _DailyNoteSheet(sheetId: sheetId, accent: accent),
  );
}

class _DailyNoteSheet extends StatefulWidget {
  const _DailyNoteSheet({required this.sheetId, this.accent});
  final String sheetId;
  final Color? accent;

  @override
  State<_DailyNoteSheet> createState() => _DailyNoteSheetState();
}

class _DailyNoteSheetState extends State<_DailyNoteSheet> {
  final _ctrl = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final text = await DailyNoteService.instance.load(widget.sheetId);
    if (!mounted) return;
    _ctrl.text = text;
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _exportPdfAndShare() async {
    final doc = pw.Document();
    final text = _ctrl.text.trim().isEmpty ? '(sin contenido)' : _ctrl.text;

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context _) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Parte diario', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Text(
              DateTime.now().toString(),
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.Divider(),
            pw.Text(text, style: const pw.TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );

    final bytes = await doc.save();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/parte_diario_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(bytes, flush: true);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      text: 'Parte diario',
      subject: 'Parte diario',
    );
  }

  @override
  Widget build(BuildContext context) {
    final nav = Navigator.of(context); // evita usar context tras awaits
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Barra superior
            Row(
              children: [
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Bloc de notas (parte diario)',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                ),
                IconButton(
                  tooltip: 'Exportar PDF',
                  onPressed: _exportPdfAndShare,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilledButton(
                    style: ButtonStyle(
                      backgroundColor: widget.accent != null
                          ? WidgetStatePropertyAll(widget.accent)
                          : null,
                    ),
                    onPressed: () async {
                      await DailyNoteService.instance.save(widget.sheetId, _ctrl.text);
                      if (mounted) nav.pop();
                    },
                    child: const Text('Guardar'),
                  ),
                ),
              ],
            ),

            // Editor
            SizedBox(
              height: 360,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _ctrl,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'EscribÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­ el parte diario aquÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¦',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
