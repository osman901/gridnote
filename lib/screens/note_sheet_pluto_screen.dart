// lib/screens/note_sheet_pluto_screen.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pluto_grid/pluto_grid.dart';

import '../models/free_sheet.dart';
import '../services/free_sheet_service.dart';
import '../services/diagnostics_service.dart';
import '../theme/gridnote_theme.dart';

// Exportar / compartir XLSX (para la grilla de datos)
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xls;

// >>> Bloc de notas con dictado
import '../widgets/voice_notes_sheet.dart' show showVoiceNotesBottomSheet;

class NoteSheetPlutoScreen extends StatefulWidget {
  const NoteSheetPlutoScreen({super.key, this.id, required this.theme});
  final String? id;
  final GridnoteThemeController theme;

  @override
  State<NoteSheetPlutoScreen> createState() => _NoteSheetPlutoScreenState();
}

class _NoteSheetPlutoScreenState extends State<NoteSheetPlutoScreen> {
  FreeSheetData? _data;
  bool _loading = true;

  // ====== Config de “planilla infinita” ======
  static const int _initialCols = 12;
  static const int _initialRows = 200;
  static const int _growChunk = 50;
  static const int _trailingBuffer = 10;

  // Auto-save
  Timer? _debounce;
  void _scheduleSave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      final d = _data;
      if (d != null) {
        await FreeSheetService.instance.save(d);
        HapticFeedback.selectionClick();
      }
    });
  }

  // Grid state
  final List<PlutoColumn> _columns = <PlutoColumn>[];
  final List<PlutoRow> _rows = <PlutoRow>[];
  PlutoGridStateManager? _sm;

  // Estilo
  static const Color _gridBorder = Color(0xFFE3E6EA);
  static const Color _cellBg = Color(0xFFF9FAFB);
  static const Color _altCellBg = Color(0xFFF2F4F7);
  static const Color _selection = Color(0xFF1D6EE3);
  static const Color _text = Color(0xFF1F2328);

  // Auto-fit
  Timer? _fitDebounce;
  void _scheduleAutoFit() {
    _fitDebounce?.cancel();
    _fitDebounce = Timer(const Duration(milliseconds: 160), _autoFitColumns);
  }

  // Títulos editables
  late List<String> _titles;
  final Map<int, TextEditingController> _titleCtrls = {};
  final Set<int> _editing = <int>{};

  // Filtros
  bool _filtersOn = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _fitDebounce?.cancel();
    for (final c in _titleCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    late FreeSheetData d;
    if (widget.id == null) {
      d = await FreeSheetService.instance.create(name: 'Hoja');
      await DiagnosticsService.instance.log('notes_pluto', 'creada ${d.id}');
    } else {
      final got = await FreeSheetService.instance.get(widget.id!);
      d = got ?? await FreeSheetService.instance.create(name: 'Hoja');
    }

    if (d.headers.isEmpty) {
      d.headers.addAll(List.filled(_initialCols, '', growable: true));
    }
    if (d.rows.isEmpty) {
      d.rows.addAll(List.generate(
        _initialRows,
            (_) => List.filled(d.headers.length, '', growable: true),
      ));
    } else {
      for (final r in d.rows) {
        if (r.length < d.headers.length) {
          r.addAll(List.filled(d.headers.length - r.length, '', growable: true));
        }
      }
      if (d.rows.length < _initialRows) {
        d.rows.addAll(List.generate(
          _initialRows - d.rows.length,
              (_) => List.filled(d.headers.length, '', growable: true),
        ));
      }
    }

    _titles = List<String>.from(d.headers);

    _buildGridFromData(d);
    setState(() {
      _data = d;
      _loading = false;
    });

    _scheduleAutoFit();
  }

  // ===== Encabezado editable =====
  Widget _editableHeader(int idx) {
    final isEditing = _editing.contains(idx);
    final title = (_titles[idx]).trim();

    if (!isEditing) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _titleCtrls[idx] ??= TextEditingController(text: _titles[idx]);
          setState(() => _editing.add(idx));
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title.isEmpty ? '' : title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: _text,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.edit_outlined, size: 14, color: _text.withOpacity(.55)),
            ],
          ),
        ),
      );
    }

    final ctrl = _titleCtrls[idx]!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: SizedBox(
        height: 34,
        child: TextField(
          controller: ctrl,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (v) => _commitHeader(idx, v),
          onTapOutside: (_) => _commitHeader(idx, ctrl.text),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            hintText: '',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
    );
  }

  void _commitHeader(int idx, String value) {
    final v = value.trim();
    setState(() {
      _titles[idx] = v;
      _editing.remove(idx);
    });
    final d = _data!;
    if (d.headers.length != _titles.length) {
      d.headers
        ..clear()
        ..addAll(List.filled(_titles.length, '', growable: true));
    }
    for (var i = 0; i < _titles.length; i++) {
      d.headers[i] = _titles[i];
    }
    _scheduleSave();
  }

  // ===== Build grid =====
  void _buildGridFromData(FreeSheetData d) {
    _columns.clear();

    for (int i = 0; i < d.headers.length; i++) {
      _columns.add(
        PlutoColumn(
          title: ' ',
          field: 'c$i',
          type: PlutoColumnType.text(),
          enableContextMenu: false,
          enableSorting: false,
          enableColumnDrag: true,
          titleSpan: TextSpan(children: [WidgetSpan(child: _editableHeader(i))]),
          renderer: (ctx) => Text(
            (ctx.cell.value ?? '').toString(),
            maxLines: 10,
            overflow: TextOverflow.visible,
            style: const TextStyle(fontSize: 14, color: _text),
          ),
          minWidth: 90,
        ),
      );
    }

    _rows
      ..clear()
      ..addAll(List.generate(d.rows.length, (r) {
        final map = <String, PlutoCell>{};
        for (int c = 0; c < d.headers.length; c++) {
          map['c$c'] = PlutoCell(value: d.rows[r][c]);
        }
        return PlutoRow(cells: map);
      }));
  }

  // ===== Helpers para crecer filas =====
  void _appendRows(int count) {
    final d = _data;
    final sm = _sm;
    if (d == null || sm == null || count <= 0) return;

    final width = _columns.length;

    d.rows.addAll(List.generate(
      count,
          (_) => List.filled(width, '', growable: true),
    ));

    final newRows = List<PlutoRow>.generate(count, (_) {
      final cells = <String, PlutoCell>{};
      for (int c = 0; c < width; c++) {
        cells['c$c'] = PlutoCell(value: '');
      }
      return PlutoRow(cells: cells);
    });
    sm.appendRows(newRows);

    _scheduleSave();
  }

  // ===== Auto fit =====
  void _autoFitColumns() {
    final sm = _sm;
    if (sm == null) return;

    const int maxScan = 50;
    const double minW = 72.0, maxW = 360.0, pad = 26.0;
    const TextStyle textStyle = TextStyle(fontSize: 14, color: _text);

    final cols = sm.columns;
    for (final col in cols) {
      double maxWidth = 18;
      final int len = sm.rows.length < maxScan ? sm.rows.length : maxScan;
      for (var r = 0; r < len; r++) {
        final v = sm.rows[r].cells[col.field]?.value?.toString() ?? '';
        final w = _textWidth(v, textStyle);
        if (w > maxWidth) maxWidth = w;
      }
      final target = maxWidth.clamp(minW, maxW) + pad;
      col.width = target;
    }
    sm.notifyListeners();
  }

  double _textWidth(String text, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(minWidth: 0, maxWidth: double.infinity);
    return tp.size.width;
  }

  // ===== Sync helpers =====
  void _syncDataFromGrid() {
    final sm = _sm;
    final d = _data;
    if (sm == null || d == null) return;

    final colCount = sm.columns.length;
    final newRows = sm.rows
        .map((r) => List<String>.generate(
      colCount,
          (i) => r.cells['c$i']?.value?.toString() ?? '',
      growable: true,
    ))
        .toList();

    d.rows
      ..clear()
      ..addAll(newRows);

    d.headers
      ..clear()
      ..addAll(List<String>.generate(colCount, (i) => _titles[i], growable: true));

    _scheduleSave();
    _scheduleAutoFit();
  }

  // ===== Acciones: filas/columnas =====
  Future<void> _addRow() async {
    _appendRows(1);
    _scheduleAutoFit();
    HapticFeedback.mediumImpact();
    setState(() {});
  }

  Future<void> _addColumn() async {
    final d = _data!;
    final idx = _columns.length;

    d.headers.add(_titles.length > idx ? _titles[idx] : '');
    for (final row in d.rows) {
      row.add('');
    }
    _titles = List<String>.from(d.headers);

    final col = PlutoColumn(
      title: ' ',
      field: 'c$idx',
      type: PlutoColumnType.text(),
      enableContextMenu: false,
      enableSorting: false,
      enableColumnDrag: true,
      titleSpan: TextSpan(children: [WidgetSpan(child: _editableHeader(idx))]),
      renderer: (ctx) => Text(
        (ctx.cell.value ?? '').toString(),
        maxLines: 10,
        overflow: TextOverflow.visible,
        style: const TextStyle(fontSize: 14, color: _text),
      ),
      minWidth: 90,
    );

    _sm?.insertColumns(_columns.length, [col]);
    for (final r in _sm?.rows ?? const []) {
      r.cells['c$idx'] = PlutoCell(value: '');
    }
    _columns.add(col);

    _scheduleSave();
    HapticFeedback.mediumImpact();
    setState(() {});
    _scheduleAutoFit();
  }

  void _addColumns(int n) {
    for (var i = 0; i < n; i++) {
      _addColumn();
    }
  }

  // ===== Export XLSX (grilla) =====
  Future<void> _exportAndShareXlsx() async {
    final d = _data;
    if (d == null) return;

    final bytes = _buildXlsxBytes(d);
    final dir = await getTemporaryDirectory();

    final fileNameSafe =
    (d.name.isEmpty ? 'hoja' : d.name).replaceAll(RegExp(r'[^\w\-]+'), '_');

    final file =
    File('${dir.path}/$fileNameSafe${DateTime.now().millisecondsSinceEpoch}.xlsx');

    await file.writeAsBytes(bytes, flush: true);

    await Share.shareXFiles(
      [
        XFile(file.path,
            mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
      ],
      text: d.name,
      subject: d.name,
    );

    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Archivo XLSX generado')));
    }
  }

  List<int> _buildXlsxBytes(FreeSheetData d) {
    final wb = xls.Workbook();
    final ws = wb.worksheets[0];
    ws.name = d.name.isEmpty ? 'Hoja' : (d.name.length > 28 ? d.name.substring(0, 28) : d.name);

    for (int r = 0; r < d.rows.length; r++) {
      final row = d.rows[r];
      for (int c = 0; c < row.length; c++) {
        ws.getRangeByIndex(r + 1, c + 1).setText((row[c]).toString());
      }
    }

    final bytes = wb.saveAsStream();
    wb.dispose();
    return bytes;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _data == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final d = _data!;
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    final config = PlutoGridConfiguration(
      enterKeyAction: PlutoGridEnterKeyAction.editingAndMoveRight,
      columnSize: const PlutoGridColumnSizeConfig(
        autoSizeMode: PlutoAutoSizeMode.none,
        resizeMode: PlutoResizeMode.normal,
      ),
      style: PlutoGridStyleConfig(
        gridBorderColor: _gridBorder,
        rowHeight: 50,
        columnHeight: 50,
        cellTextStyle: const TextStyle(fontSize: 14, color: _text),
        columnTextStyle:
        const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _text),
        cellColorInEditState: _cellBg,
        cellColorInReadOnlyState: _cellBg,
        activatedColor: _selection.withOpacity(.18),
        activatedBorderColor: _selection,
        gridBackgroundColor: _cellBg,
        oddRowColor: _altCellBg,
        evenRowColor: _cellBg,
      ),
    );

    final accent = widget.theme.theme.accent;

    return Scaffold(
      appBar: AppBar(
        title: Text(d.name.isEmpty ? 'Hoja' : d.name),
        actions: [
          // >>> BOTÓN: Bloc de notas (dictado + texto)
          IconButton(
            tooltip: 'Bloc de notas',
            onPressed: () {
              showVoiceNotesBottomSheet(context, sheetId: d.id, accent: accent);
            },
            icon: const Icon(Icons.mic_none),
          ),

          // Toggle filtros
          IconButton(
            tooltip: _filtersOn ? 'Ocultar filtros' : 'Mostrar filtros',
            onPressed: () {
              _filtersOn = !_filtersOn;
              _sm?.setShowColumnFilter(_filtersOn);
              setState(() {});
            },
            icon: Icon(_filtersOn ? Icons.filter_alt_off : Icons.filter_alt),
          ),
          IconButton(
            tooltip: 'Agregar columna',
            onPressed: _addColumn,
            icon: const Icon(Icons.view_column_outlined),
          ),
          PopupMenuButton<String>(
            onSelected: (k) async {
              if (k == 'clear') {
                final width = _columns.length;
                d.rows
                  ..clear()
                  ..addAll(List.generate(
                    _initialRows,
                        (_) => List.filled(width, '', growable: true),
                  ));

                _sm?.removeRows(List<PlutoRow>.from(_sm?.rows ?? const []));
                _rows
                  ..clear()
                  ..addAll(List.generate(d.rows.length, (r) {
                    final map = <String, PlutoCell>{};
                    for (int c = 0; c < width; c++) {
                      map['c$c'] = PlutoCell(value: d.rows[r][c]);
                    }
                    return PlutoRow(cells: map);
                  }));
                _sm?.appendRows(_rows);

                _scheduleSave();
                setState(() {});
                _scheduleAutoFit();
              } else if (k == 'add50') {
                _appendRows(50);
                setState(() {});
              } else if (k == 'add5c') {
                _addColumns(5);
              } else if (k == 'export') {
                _exportAndShareXlsx();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'clear', child: Text('Limpiar hoja')),
              PopupMenuItem(value: 'add50', child: Text('Agregar 50 filas')),
              PopupMenuItem(value: 'add5c', child: Text('Agregar 5 columnas')),
              PopupMenuItem(value: 'export', child: Text('Exportar XLSX')),
            ],
          ),
        ],
      ),
      body: Container(
        color: _cellBg,
        padding: const EdgeInsets.all(8),
        child: PlutoGrid(
          columns: _columns,
          rows: _rows,
          configuration: config,
          onLoaded: (evt) {
            _sm = evt.stateManager
              ..setSelectingMode(PlutoGridSelectingMode.cell)
              ..setKeepFocus(true)
              ..setAutoEditing(true)
              ..setShowColumnFilter(_filtersOn);
            _scheduleAutoFit();
          },
          onChanged: (evt) {
            final r = evt.rowIdx;
            final c = int.tryParse(evt.column.field.replaceFirst('c', '')) ?? -1;
            if (r < 0 || c < 0) return;

            final data = _data!;
            if (r >= data.rows.length) {
              data.rows.addAll(List.generate(
                r - data.rows.length + 1,
                    (_) => List.filled(_columns.length, '', growable: true),
              ));
            }
            if (data.rows[r].length < _columns.length) {
              data.rows[r].addAll(
                List.filled(_columns.length - data.rows[r].length, '', growable: true),
              );
            }

            data.rows[r][c] = (evt.value ?? '').toString();

            if (data.rows.length - r <= _trailingBuffer) {
              _appendRows(_growChunk);
            }

            _scheduleSave();
            _scheduleAutoFit();
          },
          onRowsMoved: (_) => _syncDataFromGrid(),
          onColumnsMoved: (_) => _syncDataFromGrid(),
        ),
      ),
      floatingActionButton: keyboardOpen
          ? null
          : FloatingActionButton.extended(
        onPressed: _addRow,
        icon: const Icon(Icons.add),
        label: const Text('Agregar fila'),
      ),
    );
  }
}
