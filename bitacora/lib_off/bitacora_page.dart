import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xls;

class NoteItem {
  final String title;
  final String subtitle;
  final String thumbUrl;   // usa tus assets si querÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©s
  final String body;

  NoteItem({
    required this.title,
    required this.subtitle,
    required this.thumbUrl,
    required this.body,
  });
}

class BitacoraPage extends StatefulWidget {
  const BitacoraPage({super.key});

  @override
  State<BitacoraPage> createState() => _BitacoraPageState();
}

class _BitacoraPageState extends State<BitacoraPage> {
  final notes = <NoteItem>[
    NoteItem(
      title: 'Bitakora',
      subtitle: 'Active Notes',
      thumbUrl: 'https://picsum.photos/seed/1/200/120',
      body:
      'Texto de ejemplo. Reemplaza por el contenido de tu nota / planilla.',
    ),
    NoteItem(
      title: 'San Francisco',
      subtitle: 'Hoy 10:24',
      thumbUrl: 'https://picsum.photos/seed/2/200/120',
      body: 'Otra nota de muestra con descripciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n corta.',
    ),
  ];

  int selected = 0;

  bool get _isWide => _cachedWidth >= 900;
  double _cachedWidth = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bitakora'),
        actions: [
          IconButton(
            tooltip: 'Compartir XLSX',
            icon: const Icon(Icons.ios_share),
            onPressed: () => _exportAndShare(notes[selected]),
          ),
          IconButton(
            tooltip: 'Nueva nota',
            icon: const Icon(Icons.add),
            onPressed: () {/* TODO: crear nueva */},
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          _cachedWidth = c.maxWidth;
          if (_isWide) {
            // Tablet / escritorio: lista + detalle
            return Row(
              children: [
                SizedBox(
                  width: 360,
                  child: _SidebarList(
                    notes: notes,
                    selected: selected,
                    onTap: (i) => setState(() => selected = i),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: _DetailCard(note: notes[selected])),
              ],
            );
          }
          // TelÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©fono: lista; navega a detalle
          return _SidebarList(
            notes: notes,
            selected: selected,
            onTap: (i) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(
                      title: Text(notes[i].title),
                      actions: [
                        IconButton(
                          tooltip: 'Compartir XLSX',
                          icon: const Icon(Icons.ios_share),
                          onPressed: () => _exportAndShare(notes[i]),
                        )
                      ],
                    ),
                    body: _DetailCard(note: notes[i]),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _exportAndShare(NoteItem n) async {
    // Genera XLSX con Syncfusion
    final wb = xls.Workbook();
    final sheet = wb.worksheets[0];
    sheet.name = 'Bitacora';
    sheet.getRangeByName('A1').setText('TÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­tulo');
    sheet.getRangeByName('B1').setText('Detalle');
    sheet.getRangeByName('A2').setText(n.title);
    sheet.getRangeByName('B2').setText(n.body);

    // (ejemplo de estilo simple)
    final headerStyle = wb.styles.add('hdr');
    headerStyle.bold = true;
    sheet.getRangeByName('A1:B1').cellStyle = headerStyle;
    sheet.autoFitColumn(1);
    sheet.autoFitColumn(2);

    final bytes = wb.saveAsStream();
    wb.dispose();

    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/bitacora_${DateTime.now().millisecondsSinceEpoch}.xlsx',
    );
    await file.writeAsBytes(bytes, flush: true);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
      text: 'BitÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡cora ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œ ${n.title}',
      subject: 'BitÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡cora ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œ ${n.title}',
    );
  }
}

class _SidebarList extends StatelessWidget {
  final List<NoteItem> notes;
  final int selected;
  final ValueChanged<int> onTap;

  const _SidebarList({
    required this.notes,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemBuilder: (_, i) {
          final n = notes[i];
          final isSel = i == selected;
          return ListTile(
            selected: isSel,
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(n.thumbUrl, width: 44, height: 44, fit: BoxFit.cover),
            ),
            title: Text(n.title),
            subtitle: Text(n.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: const Icon(Icons.place_outlined),
            onTap: () => onTap(i),
          );
        },
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemCount: notes.length,
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final NoteItem note;
  const _DetailCard({required this.note});

  @override
  Widget build(BuildContext context) {
    final cardRadius = BorderRadius.circular(16);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Card(
        elevation: 1.5,
        shape: RoundedRectangleBorder(borderRadius: cardRadius),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              ClipRRect(
                borderRadius: cardRadius,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(note.thumbUrl, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 16),
              Text(note.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                note.body,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
