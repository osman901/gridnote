// lib/screens/beta_sheet_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path/path.dart' as p;

import '../services/export_xlsx_service.dart';
import '../services/email_fallback_service.dart';

// ---- Constantes de UI (nivel archivo) ----
const double kRowHeight = 56;
const double kHeaderHeight = 54;
const double kCellHPad = 10;

class BetaSheetScreen extends StatefulWidget {
  const BetaSheetScreen({
    super.key,
    this.sheetId,                 // <- ID opcional para persistencia futura
    this.columns = 5,
    this.initialRows = 60,
    this.title = 'Bitácora',
  });

  final String? sheetId;          // <- disponible para integrarte con Drift/Riverpod después
  final int columns;
  final int initialRows;
  final String title;

  @override
  State<BetaSheetScreen> createState() => _BetaSheetScreenState();
}

class _BetaSheetScreenState extends State<BetaSheetScreen> {
  // --------- Modelo ----------
  late final List<String> _headers =
  List<String>.generate(widget.columns, (_) => '');
  late final List<_RowModel> _rows = List<_RowModel>.generate(
    widget.initialRows,
        (_) => _RowModel.empty(widget.columns),
  );

  // --------- Controladores ----------
  final _listCtrl = ScrollController();
  final _picker = ImagePicker();

  // --------- Acciones ----------
  void _addRow() => setState(() => _rows.add(_RowModel.empty(_headers.length)));
  void _deleteRow(int i) => setState(() => _rows.removeAt(i));

  Future<void> _pickPhotos(int rowIndex) async {
    final picks = await _picker.pickMultiImage(imageQuality: 92);
    if (!mounted || picks.isEmpty) return;
    setState(() => _rows[rowIndex].photos.addAll(picks.map((e) => e.path)));
  }

  Future<bool> _ensureLocationPermitted() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      _toast('Activá la ubicación del dispositivo.');
      return false;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      _toast('Permiso de ubicación denegado.');
      return false;
    }
    return true;
  }

  Future<void> _markLocation(int rowIndex) async {
    if (!await _ensureLocationPermitted()) return;
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    setState(() {
      _rows[rowIndex].lat = pos.latitude;
      _rows[rowIndex].lng = pos.longitude;
    });
  }

  Future<void> _exportXlsx({required bool autoOpen}) async {
    final headers = [..._headers, 'Fotos', 'Lat', 'Lng'];
    final rows = _rows.map((r) {
      final cells = [...r.cells];
      cells.add(r.photos.map((e) => p.basename(e)).join(' | '));
      cells.add(r.lat?.toStringAsFixed(6) ?? '');
      cells.add(r.lng?.toStringAsFixed(6) ?? '');
      return cells;
    }).toList();

    final imagesByRow = <int, List<String>>{};
    for (var i = 0; i < _rows.length; i++) {
      final pics = _rows[i].photos;
      if (pics.isNotEmpty) imagesByRow[i] = List<String>.from(pics);
    }

    final file = await const ExportXlsxService().exportToXlsx(
      headers: headers,
      rows: rows,
      imagesByRow: imagesByRow,
      imageColumnIndex: _headers.length + 1,
      sheetName: widget.title,
      autoOpen: autoOpen,
    );
    if (!mounted) return;
    _toast('Exportado: ${file.path}');
    if (!autoOpen) {
      await const EmailFallbackService().sendXlsx(
        file: file,
        subject: '${widget.title} · XLSX',
        body: 'Adjunto XLSX generado.',
      );
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // --------- Edición (bottom sheet, iOS-like) ----------
  Future<void> _editHeader(int col) async {
    final value = await _showEditor(
      title: 'Encabezado',
      initial: _headers[col],
      placeholder: 'ABC',
    );
    if (value == null) return;
    setState(() => _headers[col] = value);
  }

  Future<void> _editCell(int row, int col) async {
    final value = await _showEditor(
      title: 'Celda (${row + 1}, ${col + 1})',
      initial: _rows[row].cells[col],
      placeholder: '',
    );
    if (value == null) return;
    setState(() => _rows[row].cells[col] = value);
  }

  Future<String?> _showEditor({
    required String title,
    required String initial,
    String placeholder = '',
  }) async {
    final ctrl = TextEditingController(text: initial);
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 10),
              CupertinoTextField(
                controller: ctrl,
                autofocus: true,
                placeholder: placeholder,
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                      child: const Text('Guardar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // --------- UI ----------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final divider = cs.outlineVariant.withValues(alpha: .40);
    final headerBg = cs.surfaceContainerHighest;
    final rowBg = cs.surface;

    return Scaffold(
      resizeToAvoidBottomInset: false, // el editor evita relayout del grid
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Exportar XLSX (abrir)',
            onPressed: () => _exportXlsx(autoOpen: true),
            icon: const Icon(Icons.grid_on),
          ),
          IconButton(
            tooltip: 'Enviar XLSX',
            onPressed: () => _exportXlsx(autoOpen: false),
            icon: const Icon(Icons.send_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addRow,
        child: const Icon(Icons.add),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final totalCols = _headers.length + 4; // fotos + lat + lng + acciones
          final cellWidth =
          (constraints.maxWidth / totalCols).clamp(104.0, 260.0);

          // Encabezado fijo
          final header = RepaintBoundary(
            child: Container(
              height: kHeaderHeight,
              color: headerBg,
              child: Row(
                children: [
                  for (var c = 0; c < _headers.length; c++)
                    _HeaderCell(
                      width: cellWidth,
                      text: _headers[c].isEmpty ? 'ABC' : _headers[c],
                      onTap: () => _editHeader(c),
                      divider: divider,
                    ),
                  _HeaderCell(width: cellWidth, text: 'Fotos', divider: divider),
                  _HeaderCell(width: cellWidth, text: 'Lat', divider: divider),
                  _HeaderCell(width: cellWidth, text: 'Lng', divider: divider),
                  _HeaderCell(width: cellWidth, text: '', divider: divider),
                ],
              ),
            ),
          );

          // Lista virtualizada
          return Column(
            children: [
              header,
              Divider(height: 1, color: divider),
              Expanded(
                child: ListView.builder(
                  controller: _listCtrl,
                  itemExtent: kRowHeight + 1, // +1 por el divider
                  itemCount: _rows.length,
                  cacheExtent: 800, // pre-cache para scroll suave
                  itemBuilder: (_, index) {
                    final r = _rows[index];
                    return RepaintBoundary(
                      child: Container(
                        color: rowBg,
                        child: Column(
                          children: [
                            Row(
                              children: [
                                for (var c = 0; c < _headers.length; c++)
                                  _Cell(
                                    width: cellWidth,
                                    divider: divider,
                                    child: _CellText(
                                      text: r.cells[c],
                                      onTap: () => _editCell(index, c),
                                    ),
                                  ),
                                _Cell(
                                  width: cellWidth,
                                  divider: divider,
                                  child: _PhotosButton(
                                    count: r.photos.length,
                                    onTap: () => _pickPhotos(index),
                                  ),
                                ),
                                _Cell(
                                  width: cellWidth,
                                  divider: divider,
                                  child: Text(
                                    r.lat?.toStringAsFixed(6) ?? '',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                _Cell(
                                  width: cellWidth,
                                  divider: divider,
                                  child: Text(
                                    r.lng?.toStringAsFixed(6) ?? '',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                _Cell(
                                  width: cellWidth,
                                  divider: divider,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        tooltip: 'Marcar ubicación',
                                        onPressed: () => _markLocation(index),
                                        icon: const Icon(
                                            Icons.my_location_outlined),
                                      ),
                                      IconButton(
                                        tooltip: 'Eliminar fila',
                                        onPressed: () => _deleteRow(index),
                                        icon:
                                        const Icon(Icons.delete_outline),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            Divider(height: 1, color: divider),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------- Widgets “atómicos” ----------

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({
    required this.width,
    required this.text,
    required this.divider,
    this.onTap,
  });

  final double width;
  final String text;
  final Color divider;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium!.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: .2,
    );
    return _Cell(
      width: width,
      divider: divider,
      isHeader: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: kCellHPad),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.width,
    required this.child,
    required this.divider,
    this.isHeader = false,
  });

  final double width;
  final Widget child;
  final Color divider;
  final bool isHeader;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: isHeader ? kHeaderHeight : kRowHeight,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: divider),
          bottom: BorderSide(color: divider),
        ),
      ),
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: kCellHPad),
        child: child,
      ),
    );
  }
}

class _CellText extends StatelessWidget {
  const _CellText({required this.text, required this.onTap});
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text.isEmpty ? ' ' : text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _PhotosButton extends StatelessWidget {
  const _PhotosButton({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final divider =
    Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .40);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: divider),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.photo_library_outlined, size: 18),
          const SizedBox(width: 6),
          Text(count == 0 ? 'Adjuntar' : '$count'),
        ]),
      ),
    );
  }
}

// ---------- Modelo ----------
class _RowModel {
  final List<String> cells;
  final List<String> photos;
  double? lat;
  double? lng;

  _RowModel({required this.cells, required this.photos, this.lat, this.lng});

  factory _RowModel.empty(int cols) => _RowModel(
    cells: List<String>.generate(cols, (_) => ''),
    photos: <String>[],
  );
}

