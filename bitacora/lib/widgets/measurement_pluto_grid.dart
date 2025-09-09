// lib/widgets/measurement_pluto_grid.dart
//
// Grilla de mediciones usando DataTable + ListView.
// Mantiene controlador externo y funciones clave (fotos por fila, ubicaciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n).

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

import 'package:bitacora/models/measurement.dart';
import 'package:bitacora/models/sheet_meta.dart';
import 'package:bitacora/theme/gridnote_theme.dart';

typedef RowsChanged = void Function(List<Measurement> rows);
typedef EditHeader = void Function(String field);
typedef HeaderTitleChanged = void Function(String field, String value);
typedef OpenMaps = void Function(Measurement m);

class MeasurementColumn {
  static const progresiva = 'progresiva';
  static const ohm1m = 'ohm1m';
  static const ohm3m = 'ohm3m';
  static const observations = 'observations';
  static const date = 'date';
  static const maps = '_maps';
  static const photos = '_photos';
}

class MeasurementGridController {
  void Function(Color)? _colorRow;
  void Function(double, double)? _setLoc;
  VoidCallback? _addPhoto;
  void Function(int)? _setSelectedRowExternal;
  int Function()? _getSelectedRowExternal;

  void _bind({
    required void Function(Color) colorRow,
    required void Function(double, double) setLoc,
    required VoidCallback addPhoto,
    required void Function(int) setSelected,
    required int Function() getSelected,
  }) {
    _colorRow = colorRow;
    _setLoc = setLoc;
    _addPhoto = addPhoto;
    _setSelectedRowExternal = setSelected;
    _getSelectedRowExternal = getSelected;
  }

  Future<void> colorCellSelected(Color c) async => _colorRow?.call(c);
  Future<void> setLocationOnSelection(double lat, double lng) async =>
      _setLoc?.call(lat, lng);
  Future<void> addPhotoOnSelection() async => _addPhoto?.call();
  void setSelectedRow(int index) => _setSelectedRowExternal?.call(index);
  int? get selectedRow => _getSelectedRowExternal?.call();
}

class MeasurementDataGrid extends StatefulWidget {
  const MeasurementDataGrid({
    super.key,
    required this.meta,
    required this.initial,
    required this.themeController,
    required this.controller,
    required this.onChanged,
    this.headerTitles = const {},
    this.onEditHeader,
    this.onHeaderTitleChanged,
    this.onOpenMaps,
    this.filterQuery,
    this.aiEnabled = false,
    this.showPhotoRail = false,
  });

  final SheetMeta meta;
  final List<Measurement> initial;
  final GridnoteThemeController themeController;
  final MeasurementGridController controller;
  final RowsChanged onChanged;

  final Map<String, String> headerTitles;
  final EditHeader? onEditHeader;
  final HeaderTitleChanged? onHeaderTitleChanged;
  final OpenMaps? onOpenMaps;
  final String? filterQuery;
  final bool aiEnabled;
  final bool showPhotoRail;

  @override
  State<MeasurementDataGrid> createState() => _MeasurementDataGridState();
}

class _MeasurementDataGridState extends State<MeasurementDataGrid> {
  late List<Measurement> _rows;
  final _fmt = DateFormat('dd/MM/yyyy');
  int _selected = -1;
  final Map<int, Color> _rowTint = {};

  @override
  void initState() {
    super.initState();
    _rows = List<Measurement>.from(widget.initial);

    widget.controller._bind(
      colorRow: (color) => setState(() {
        if (_selected >= 0) _rowTint[_selected] = color;
      }),
      setLoc: (lat, lng) {
        if (_selected < 0 || _selected >= _rows.length) return;
        final m = _rows[_selected];
        _rows[_selected] = m.copyWith(latitude: lat, longitude: lng);
        widget.onChanged(List<Measurement>.from(_rows));
        setState(() {});
      },
      addPhoto: () async {
        if (_selected < 0 || _selected >= _rows.length) return;
        final picker = ImagePicker();
        final XFile? imageFile =
        await picker.pickImage(source: ImageSource.camera);
        if (!mounted || imageFile == null) return;

        final m = _rows[_selected];
        final updatedPhotos =
        List<String>.from(m.photos)..add(imageFile.path);
        _rows[_selected] = m.copyWith(photos: updatedPhotos);

        widget.onChanged(List<Measurement>.from(_rows));
        setState(() {});
      },
      setSelected: (index) => setState(() => _selected = index),
      getSelected: () => _selected,
    );
  }

  @override
  void didUpdateWidget(covariant MeasurementDataGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.initial, widget.initial)) {
      _rows = List<Measurement>.from(widget.initial);
      if (_selected >= _rows.length) _selected = -1;
    }
  }

  String _titleFor(String field, String fallback) {
    final custom = widget.headerTitles[field];
    return (custom != null && custom.trim().isNotEmpty)
        ? custom.trim()
        : fallback;
  }

  List<Measurement> _visible() {
    final q = (widget.filterQuery ?? '').trim().toLowerCase();
    if (q.isEmpty) return _rows;

    bool match(Measurement m) {
      if (m.progresiva.toLowerCase().contains(q)) return true;
      if (m.observations.toLowerCase().contains(q)) return true;
      if ('${m.ohm1m ?? ''}'.contains(q)) return true;
      if ('${m.ohm3m ?? ''}'.contains(q)) return true;
      return false;
    }

    final filtered = <Measurement>[];
    for (final m in _rows) {
      if (match(m)) filtered.add(m);
    }
    return filtered;
  }

  void _mutateRow(int absIndex, Measurement updated) {
    _rows[absIndex] = updated;
    widget.onChanged(List<Measurement>.from(_rows));
    setState(() {});
  }

  Future<void> _pickDate(int absIndex, DateTime? initialDate) async {
    final now = DateTime.now();
    final first = DateTime(now.year - 5, 1, 1);
    final last = DateTime(now.year + 5, 12, 31);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? now,
      firstDate: first,
      lastDate: last,
      confirmText: 'OK',
      cancelText: 'Cancelar',
    );
    if (!mounted || picked == null) return;

    _mutateRow(absIndex, _rows[absIndex].copyWith(date: picked));
  }

  DataColumn _col(String field, String defaultTitle) {
    final titleText = _titleFor(field, defaultTitle);
    return DataColumn(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: GestureDetector(
              onTap: () => widget.onEditHeader?.call(field),
              onLongPress: () async {
                final controller = TextEditingController(text: titleText);
                final newTitle = await showDialog<String>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('TÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­tulo de columna'),
                    content: TextField(
                      controller: controller,
                      autofocus: true,
                      decoration:
                      const InputDecoration(hintText: 'Nuevo tÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­tulo...'),
                    ),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancelar')),
                      FilledButton(
                          onPressed: () =>
                              Navigator.pop(ctx, controller.text.trim()),
                          child: const Text('Guardar')),
                    ],
                  ),
                );
                if (newTitle != null && newTitle.isNotEmpty) {
                  widget.onHeaderTitleChanged?.call(field, newTitle);
                }
              },
              child: Text(titleText, overflow: TextOverflow.ellipsis),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.edit_outlined, size: 14),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.themeController.theme;
    final visibleRows = _visible();

    // Map ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­ndice visible -> ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­ndice real
    final Map<int, int> v2abs = {};
    int vIndex = 0;
    for (int i = 0; i < _rows.length; i++) {
      final m = _rows[i];
      if (visibleRows.contains(m)) {
        v2abs[vIndex] = i;
        vIndex++;
      }
    }

    final columns = <DataColumn>[
      _col(MeasurementColumn.progresiva, 'Progresiva'),
      _col(MeasurementColumn.ohm1m, '1m (ÃƒÆ’Ã…Â½Ãƒâ€šÃ‚Â©)'),
      _col(MeasurementColumn.ohm3m, '3m (ÃƒÆ’Ã…Â½Ãƒâ€šÃ‚Â©)'),
      _col(MeasurementColumn.observations, 'Obs'),
      _col(MeasurementColumn.date, 'Fecha'),
      const DataColumn(label: Icon(Icons.map_outlined, size: 16)),
    ];

    final dataRows = <DataRow>[];
    for (int visIndex = 0; visIndex < visibleRows.length; visIndex++) {
      final absIndex = v2abs[visIndex]!;
      final m = _rows[absIndex];
      final isSelected = (absIndex == _selected);
      final tintColor = _rowTint[absIndex];

      Widget txtCell({
        required String initial,
        required ValueChanged<String> onChanged,
        TextInputType? type,
        int maxLines = 1,
      }) {
        final controller = TextEditingController(text: initial);
        return TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: type,
          decoration: const InputDecoration(
            isDense: true,
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          ),
          style: TextStyle(fontSize: 14, color: t.text),
          onTap: () => setState(() => _selected = absIndex),
          onChanged: onChanged,
        );
      }

      DataCell dateCell() {
        final d = m.date;
        final dateStr = d != null ? _fmt.format(d.toLocal()) : '-';
        return DataCell(
          TextButton(
            onPressed: () {
              setState(() => _selected = absIndex);
              _pickDate(absIndex, d);
            },
            child:
            Text(dateStr, style: TextStyle(fontSize: 13, color: t.accent)),
          ),
        );
      }

      DataCell mapCell() {
        return DataCell(
          IconButton(
            tooltip: 'Abrir en mapas',
            icon: const Icon(Icons.map_outlined),
            color: (m.latitude != null && m.longitude != null)
                ? t.accent
                : t.text.withAlpha(153),
            onPressed: widget.onOpenMaps == null
                ? null
                : () {
              setState(() => _selected = absIndex);
              widget.onOpenMaps!(m);
            },
          ),
        );
      }

      final cells = <DataCell>[
        DataCell(
          txtCell(
            initial: m.progresiva,
            onChanged: (val) =>
                _mutateRow(absIndex, m.copyWith(progresiva: val)),
          ),
        ),
        DataCell(
          txtCell(
            initial: m.ohm1m?.toString() ?? '',
            type: const TextInputType.numberWithOptions(
                decimal: true, signed: false),
            onChanged: (val) {
              final n = double.tryParse(val.replaceAll(',', '.'));
              _mutateRow(absIndex, m.copyWith(ohm1m: n));
            },
          ),
        ),
        DataCell(
          txtCell(
            initial: m.ohm3m?.toString() ?? '',
            type: const TextInputType.numberWithOptions(
                decimal: true, signed: false),
            onChanged: (val) {
              final n = double.tryParse(val.replaceAll(',', '.'));
              _mutateRow(absIndex, m.copyWith(ohm3m: n));
            },
          ),
        ),
        DataCell(
          txtCell(
            initial: m.observations,
            maxLines: 2,
            onChanged: (val) =>
                _mutateRow(absIndex, m.copyWith(observations: val)),
          ),
        ),
        dateCell(),
        mapCell(),
      ];

      dataRows.add(
        DataRow(
          selected: isSelected,
          color: WidgetStateProperty.resolveWith<Color?>(
                (states) => tintColor ?? (isSelected ? t.accent.withAlpha(46) : null),
          ),
          onSelectChanged: (_) => setState(() => _selected = absIndex),
          cells: cells,
        ),
      );
    }

    final headerBar = Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: t.divider.withAlpha(153)),
      ),
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Filas: ${visibleRows.length}  ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¢  Sel: ${_selected >= 0 ? (_selected + 1) : '-'}',
              style: TextStyle(color: t.text.withAlpha(217)),
            ),
          ),
          if (widget.aiEnabled)
            const Chip(
              visualDensity: VisualDensity.compact,
              avatar: Icon(Icons.auto_awesome),
              label: Text('IA'),
            ),
          if (widget.showPhotoRail) const SizedBox(width: 8),
          if (widget.showPhotoRail)
            Chip(
              visualDensity: VisualDensity.compact,
              avatar: const Icon(Icons.photo_library_outlined),
              label: Text(
                'Fotos: ${_selected >= 0 && _selected < _rows.length ? _rows[_selected].photos.length : '-'}',
              ),
            ),
          if (widget.showPhotoRail) const SizedBox(width: 8),
          if (widget.showPhotoRail)
            IconButton(
              icon: const Icon(Icons.camera_alt_outlined),
              tooltip: 'Adjuntar foto a esta fila',
              onPressed: _selected < 0
                  ? null
                  : () => widget.controller.addPhotoOnSelection(),
            ),
        ],
      ),
    );

    return Column(
      children: [
        headerBar,
        if (widget.showPhotoRail)
          Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: _selected >= 0 &&
                _selected < _rows.length &&
                _rows[_selected].photos.isNotEmpty
                ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _rows[_selected].photos
                    .map(
                      (path) => Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Image.file(
                      File(path),
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                )
                    .toList(),
              ),
            )
                : Text(
              'Sin fotos adjuntas en esta fila',
              style: TextStyle(color: t.text.withAlpha(179)),
            ),
          ),
        Expanded(
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 880),
                child: DataTable(
                  headingRowHeight: 40,
                  dataRowMinHeight: 48,
                  dataRowMaxHeight: 56,
                  headingRowColor: WidgetStatePropertyAll(t.surface),
                  columns: columns,
                  rows: dataRows,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
