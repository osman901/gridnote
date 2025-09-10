// lib/screens/free_sheet_screen.dart
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/free_sheet.dart';
import '../services/free_sheet_service.dart';
import '../export/export_csv.dart';
import '../export/export_excel.dart';
import '../services/attachments_service.dart';
import '../services/diagnostics_service.dart';
import '../theme/gridnote_theme.dart';
import 'note_sheet_pluto_screen.dart';

class FreeSheetScreen extends StatefulWidget {
  const FreeSheetScreen({super.key, this.id, this.theme});
  final String? id;
  final GridnoteThemeController? theme;

  @override
  State<FreeSheetScreen> createState() => _FreeSheetScreenState();
}

class _FreeSheetScreenState extends State<FreeSheetScreen> {
  FreeSheetData? _data;
  bool _loading = true;
  Timer? _debounce;

  GridnoteTheme get t => (widget.theme ?? GridnoteThemeController()).theme;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    FreeSheetData? d;
    if (widget.id == null) {
      d = await FreeSheetService.instance.create(name: 'Planilla libre');
      await DiagnosticsService.instance.log('free_sheet', 'creada ${d.id}');
    } else {
      d = await FreeSheetService.instance.get(widget.id!);
      d ??= await FreeSheetService.instance.create(name: 'Planilla libre');
    }
    d.ensureWidth(d.headers.length);
    d.ensureHeight(8);
    setState(() {
      _data = d;
      _loading = false;
    });
  }

  void _scheduleSave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final d = _data;
      if (d != null) await FreeSheetService.instance.save(d);
    });
  }

  Future<void> _addCol() async {
    final d = _data!;
    final nd = await FreeSheetService.instance.addColumn(
      d,
      title: 'Col ${d.headers.length + 1}',
    );
    setState(() => _data = nd);
  }

  Future<void> _addRow() async {
    final d = _data!;
    final nd = await FreeSheetService.instance.addRow(d);
    setState(() => _data = nd);
  }

  Future<void> _exportCsv() async {
    final file = await exportFreeSheetToCsv(_data!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('CSV exportado: ${file.path.split('/').last}')),
    );
  }

  Future<void> _exportXls() async {
    final file = await exportFreeSheetToXlsLike(_data!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('XLS exportado: ${file.path.split('/').last}')),
    );
  }

  Future<void> _attachMenu(int row) async {
    final as = AttachmentsService.instance;
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(CupertinoIcons.pencil),
              title: const Text('Firma'),
              subtitle: const Text('Dibuja y adjunta una firma'),
              onTap: () async {
                Navigator.pop(context);
                final p = await as.addSignature(context);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Adjuntado: $p')),
                );
              },
            ),
            ListTile(
              leading: const Icon(CupertinoIcons.photo_camera),
              title: const Text('Foto (cámara)'),
              subtitle: const Text('Toma una foto y adjunta'),
              onTap: () async {
                Navigator.pop(context);
                final p = await as.pickFromCamera();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(p == null || p.isEmpty ? 'Foto cancelada' : 'Adjuntado: $p')),
                );
              },
            ),
            ListTile(
              leading: const Icon(CupertinoIcons.location),
              title: const Text('Ubicación (actual)'),
              subtitle: const Text('Guarda coordenadas actuales'),
              onTap: () async {
                Navigator.pop(context);
                final p = await as.getCurrentLocation();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(p == null || p.isEmpty ? 'Ubicación cancelada' : 'Adjuntado: $p')),
                );
              },
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _data == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final d = _data!;
    final theme = t;

    return Scaffold(
      backgroundColor: theme.scaffold,
      appBar: AppBar(
        title: Text(d.name, overflow: TextOverflow.ellipsis),
        backgroundColor: theme.surface,
        actions: [
          IconButton(
            tooltip: 'Abrir bloc de notas (Pluto)',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => NoteSheetPlutoScreen(
                    id: d.id,
                    theme: (widget.theme ?? GridnoteThemeController()),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.view_comfy_alt),
          ),
          IconButton(
            tooltip: 'Agregar columna',
            onPressed: _addCol,
            icon: const Icon(Icons.view_column),
          ),
          IconButton(
            tooltip: 'Agregar fila',
            onPressed: _addRow,
            icon: const Icon(Icons.view_list),
          ),
          IconButton(
            tooltip: 'Exportar CSV',
            onPressed: _exportCsv,
            icon: const Icon(Icons.table_chart),
          ),
          IconButton(
            tooltip: 'Exportar XLS',
            onPressed: _exportXls,
            icon: const Icon(Icons.grid_on),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Scrollbar(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // Fila de headers editables
                  Row(
                    children: List.generate(d.headers.length, (c) {
                      return _Cell(
                        theme: theme,
                        initial: d.headers[c],
                        isHeader: true,
                        onChanged: (v) {
                          d.headers[c] = v;
                          _scheduleSave();
                          setState(() {});
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  // Filas de datos
                  for (int r = 0; r < d.rows.length; r++) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        for (int c = 0; c < d.headers.length; c++) ...[
                          Builder(builder: (_) {
                            final row = d.rows[r];
                            if (row.length < d.headers.length) {
                              row.addAll(List.filled(d.headers.length - row.length, ''));
                            }
                            return _Cell(
                              theme: theme,
                              initial: row[c],
                              onChanged: (v) {
                                d.rows[r][c] = v;
                                _scheduleSave();
                              },
                            );
                          }),
                        ],
                        IconButton(
                          tooltip: 'Adjuntar (firma/foto/ubicación)',
                          icon: const Icon(CupertinoIcons.paperclip),
                          onPressed: () => _attachMenu(r),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addRow,
        icon: const Icon(Icons.add),
        label: const Text('Agregar fila'),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.theme,
    required this.initial,
    required this.onChanged,
    this.isHeader = false,
  });

  final GridnoteTheme theme;
  final String initial;
  final ValueChanged<String> onChanged;
  final bool isHeader;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // Capamos la escala de texto de forma no lineal-safe.
    final baseForCalc = isHeader ? 16.0 : 14.0;
    final currentFactor = mq.textScaler.scale(baseForCalc) / baseForCalc;
    final capped = currentFactor > 1.12 ? 1.12 : currentFactor;

    return Container(
      width: 180,
      constraints: BoxConstraints(minHeight: isHeader ? 56 : 52),
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isHeader ? theme.surface : theme.scaffold,
        border: Border.all(color: theme.divider.withValues(alpha: 0.55), width: 0.6),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: MediaQuery(
        data: mq.copyWith(textScaler: TextScaler.linear(capped)),
        child: TextFormField(
          initialValue: initial,
          onChanged: onChanged,
          minLines: 1,
          maxLines: 1,
          textAlign: isHeader ? TextAlign.left : TextAlign.center,
          textAlignVertical: TextAlignVertical.center,
          strutStyle: StrutStyle(
            forceStrutHeight: true,
            height: 1.3,
            leading: 0,
            fontSize: isHeader ? 16 : 14,
            fontWeight: isHeader ? FontWeight.w700 : FontWeight.w400,
          ),
          style: TextStyle(
            fontSize: isHeader ? 16 : 14,
            height: 1.3,
            fontWeight: isHeader ? FontWeight.w700 : FontWeight.w400,
            overflow: TextOverflow.ellipsis,
          ),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 14),
            border: InputBorder.none,
            hintText: '—',
          ),
        ),
      ),
    );
  }
}
