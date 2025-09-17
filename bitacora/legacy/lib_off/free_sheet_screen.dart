// lib/screens/free_sheet_screen.dart
import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/attachment.dart';
import '../models/free_sheet.dart' show FreeSheetData;
import '../services/free_sheet_service.dart' as fs;
import '../export/export_csv.dart';
import '../export/export_excel.dart';
import '../services/attachments_service.dart';
import '../services/diagnostics_service.dart';
import '../theme/gridnote_theme.dart';

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

  // Scroll vertical para que las celdas no queden ocultas por el teclado
  final _vScroll = ScrollController();

  GridnoteTheme get t => (widget.theme ?? GridnoteThemeController()).theme;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _vScroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    FreeSheetData? d;
    if (widget.id == null) {
      d = await fs.FreeSheetService.instance.create(name: 'Planilla libre');
      await DiagnosticsService.instance.log('free_sheet', 'creada ${d.id}');
    } else {
      d = await fs.FreeSheetService.instance.get(widget.id!);
      d ??= await fs.FreeSheetService.instance.create(name: 'Planilla libre');
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
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      final d = _data;
      if (d != null) await fs.FreeSheetService.instance.save(d);
    });
  }

  Future<void> _addCol() async {
    final d = _data!;
    final nd = await fs.FreeSheetService.instance.addColumn(
      d,
      title: 'Col ${d.headers.length + 1}',
    );
    setState(() => _data = nd);
  }

  Future<void> _addRow() async {
    final d = _data!;
    final nd = await fs.FreeSheetService.instance.addRow(d);
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

  // ===== Adjuntos =====

  int _ensureAttachCol() {
    final d = _data!;
    const title = 'Adjuntos';
    var i = d.headers.indexOf(title);
    if (i == -1) {
      d.headers.add(title);
      for (final r in d.rows) {
        r.add('');
      }
      i = d.headers.length - 1;
      _scheduleSave();
    }
    return i;
  }

  Future<void> _appendAttachment(
      int row,
      AttachmentType type,
      String value,
      ) async {
    final d = _data!;
    final col = _ensureAttachCol();

    final prevRaw = (d.rows[row][col] ?? '').toString();
    final items = Attachment.decodeList(prevRaw);
    items.add(Attachment(type: type, value: value, timestamp: DateTime.now()));
    d.rows[row][col] = Attachment.encodeList(items);

    setState(() {});
    _scheduleSave();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Adjunto agregado')),
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
                if (p != null && p.isNotEmpty) {
                  await _appendAttachment(row, AttachmentType.signature, p);
                }
              },
            ),
            ListTile(
              leading: const Icon(CupertinoIcons.photo_camera),
              title: const Text('Foto (cámara)'),
              subtitle: const Text('Toma una foto y adjunta'),
              onTap: () async {
                Navigator.pop(context);
                final p = await as.pickFromCamera();
                if (p != null && p.isNotEmpty) {
                  await _appendAttachment(row, AttachmentType.photo, p);
                }
              },
            ),
            ListTile(
              leading: const Icon(CupertinoIcons.location),
              title: const Text('Ubicación (actual)'),
              subtitle: const Text('Guarda coordenadas actuales'),
              onTap: () async {
                Navigator.pop(context);
                final p = await as.getCurrentLocation();
                if (p != null && p.isNotEmpty) {
                  await _appendAttachment(row, AttachmentType.location, p);
                }
              },
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  // Oculta todos los “ceros”
  bool _isZeroString(String s) => RegExp(r'^\s*0+([.,]0+)?\s*$').hasMatch(s);

  String _displayForCell(int colIndex, String raw, {required int attachCol}) {
    if (colIndex == attachCol) {
      final items = Attachment.decodeList(raw);
      return items.isEmpty ? '' : '📎 ${items.length}';
    }
    return _isZeroString(raw) ? '' : raw;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _data == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final d = _data!;
    final theme = t;
    final attachCol = d.headers.indexOf('Adjuntos');

    return Scaffold(
      backgroundColor: theme.scaffold,
      appBar: AppBar(
        title: Text(d.name, overflow: TextOverflow.ellipsis),
        backgroundColor: theme.surface,
        actions: [
          IconButton(onPressed: _addCol, icon: const Icon(Icons.view_column), tooltip: 'Agregar columna'),
          IconButton(onPressed: _addRow, icon: const Icon(Icons.view_list), tooltip: 'Agregar fila'),
          IconButton(onPressed: _exportCsv, icon: const Icon(Icons.table_chart), tooltip: 'Exportar CSV'),
          IconButton(onPressed: _exportXls, icon: const Icon(Icons.grid_on), tooltip: 'Exportar XLS'),
          const SizedBox(width: 4),
        ],
      ),
      // Empuja el contenido por encima del teclado
      body: AnimatedPadding(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Scrollbar(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
              child: SingleChildScrollView(
                controller: _vScroll,
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    // Encabezados
                    Row(
                      children: List.generate(d.headers.length, (c) {
                        return _Cell(
                          theme: theme,
                          initial: d.headers[c],
                          isHeader: true,
                          vScroll: _vScroll,
                          onChanged: (v) {
                            d.headers[c] = v;
                            _scheduleSave();
                            setState(() {});
                          },
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    // Filas
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
                              final isAttach = (c == attachCol);
                              final display = _displayForCell(c, row[c], attachCol: attachCol);
                              return _Cell(
                                theme: theme,
                                initial: display,
                                readOnly: isAttach,
                                vScroll: _vScroll,
                                onChanged: (v) {
                                  if (isAttach) return;
                                  d.rows[r][c] = v.trim().isEmpty ? '' : v;
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addRow,
        icon: const Icon(Icons.add),
        label: const Text('Agregar fila'),
      ),
    );
  }
}

class _Cell extends StatefulWidget {
  const _Cell({
    required this.theme,
    required this.initial,
    required this.onChanged,
    required this.vScroll,
    this.isHeader = false,
    this.readOnly = false,
  });

  final GridnoteTheme theme;
  final String initial;
  final ValueChanged<String> onChanged;
  final ScrollController vScroll;
  final bool isHeader;
  final bool readOnly;

  @override
  State<_Cell> createState() => _CellState();
}

class _CellState extends State<_Cell> {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;
  final _key = GlobalKey();

  bool _isZeroString(String s) => RegExp(r'^\s*0+([.,]0+)?\s*$').hasMatch(s);
  String _displayFrom(String v) => _isZeroString(v) ? '' : v;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _displayFrom(widget.initial));
    _focus = FocusNode();
    _focus.addListener(() {
      if (_focus.hasFocus && _key.currentContext != null) {
        // Lleva la celda arriba del teclado
        Scrollable.ensureVisible(
          _key.currentContext!,
          alignment: 0.2,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void didUpdateWidget(covariant _Cell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initial != widget.initial && !_focus.hasFocus) {
      _ctrl.text = _displayFrom(widget.initial);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final theme = widget.theme;
    final isHeader = widget.isHeader;

    final baseForCalc = isHeader ? 16.0 : 14.0;
    final currentFactor = mq.textScaler.scale(baseForCalc) / baseForCalc;
    final capped = currentFactor > 1.12 ? 1.12 : currentFactor;

    return Container(
      key: _key,
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
          controller: _ctrl,
          focusNode: _focus,
          readOnly: widget.readOnly,
          onChanged: (v) => widget.onChanged(_isZeroString(v) ? '' : v),
          onEditingComplete: () {
            final v = _ctrl.text;
            if (_isZeroString(v)) _ctrl.text = '';
          },
          // Agrega margen para que la celda quede visible por encima del teclado
          scrollPadding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom + 100,
          ),
          minLines: 1,
          maxLines: 1,
          textAlign: isHeader ? TextAlign.left : TextAlign.center,
          textAlignVertical: TextAlignVertical.center,
          textInputAction: TextInputAction.next,
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
            hintText: '', // limpio (sin “0” ni guiones)
          ),
        ),
      ),
    );
  }
}
