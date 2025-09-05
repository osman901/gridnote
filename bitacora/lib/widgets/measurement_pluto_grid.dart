// lib/widgets/measurement_pluto_grid.dart
//
// Reemplazo liviano del grid basado en widgets nativos (DataTable/ListView)
// para evitar PlutoGrid, manteniendo el API que usan tus pantallas.
//
// Soporta:
// - Edición inline de progresiva, ohm1m, ohm3m, observaciones y fecha
// - Títulos de columnas personalizables + callback onHeaderTitleChanged/onEditHeader
// - Filtro por texto (filterQuery)
// - Selección de fila (para que el Controller actúe sobre ella)
// - setLocationOnSelection (graba lat/lng en la fila seleccionada)
// - colorCellSelected (marca visual a nivel de fila)
// - addPhotoOnSelection (no-op aquí; deja el gancho para que no se rompa nada)

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/measurement.dart';
import '../models/sheet_meta.dart';
import '../theme/gridnote_theme.dart';

typedef RowsChanged = void Function(List<Measurement> rows);
typedef EditHeader = void Function(String field);
typedef HeaderTitleChanged = void Function(String field, String value);
typedef OpenMaps = void Function(Measurement m);

/// Campos que tu código usa como claves de encabezado.
class MeasurementColumn {
  static const progresiva = 'progresiva';
  static const ohm1m = 'ohm1m';
  static const ohm3m = 'ohm3m';
  static const observations = 'observations';
  static const date = 'date';

  // Opcionales/ocultos en UI, pero algunos modelos los tienen:
  static const maps = '_maps';
  static const photos = '_photos';
}

/// Controller para acciones sobre la selección actual.
class MeasurementGridController {
  void Function(Color)? _colorRow;
  void Function(double, double)? _setLoc;
  VoidCallback? _addPhoto;
  void Function(int)? _setSelectedRowExternal;
  int Function()? _getSelectedRowExternal;

  // Lo vincula el widget internamente
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
  Future<void> setLocationOnSelection(double lat, double lng) async => _setLoc?.call(lat, lng);
  Future<void> addPhotoOnSelection() async => _addPhoto?.call();

  /// Permite que desde fuera marques una fila como seleccionada.
  void setSelectedRow(int i) => _setSelectedRowExternal?.call(i);
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

  final Map<String, String> headerTitles;
  final EditHeader? onEditHeader;
  final HeaderTitleChanged? onHeaderTitleChanged;
  final OpenMaps? onOpenMaps;
  final RowsChanged onChanged;

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
      colorRow: (c) => setState(() {
        if (_selected >= 0) _rowTint[_selected] = c;
      }),
      setLoc: (la, lo) {
        if (_selected < 0 || _selected >= _rows.length) return;
        final m = _rows[_selected];
        _rows[_selected] = m.copyWith(latitude: la, longitude: lo);
        widget.onChanged(List<Measurement>.from(_rows));
        setState(() {});
      },
      addPhoto: () {
        // Placeholder: aquí podrías abrir tu flujo real de fotos si lo deseas.
        // Se deja no-op para no romper el API.
      },
      setSelected: (i) => setState(() => _selected = i),
      getSelected: () => _selected,
    );
  }

  @override
  void didUpdateWidget(covariant MeasurementDataGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si cambian las filas por arriba, sincronizamos
    if (!identical(oldWidget.initial, widget.initial)) {
      _rows = List<Measurement>.from(widget.initial);
      if (_selected >= _rows.length) _selected = -1;
    }
  }

  String _titleFor(String field, String fallback) =>
      widget.headerTitles[field]?.trim().isNotEmpty == true
          ? widget.headerTitles[field]!.trim()
          : fallback;

  List<Measurement> _visible() {
    final q = (widget.filterQuery ?? '').trim().toLowerCase();
    if (q.isEmpty) return _rows;
    bool match(Measurement m) {
      if (m.progresiva.toLowerCase().contains(q)) return true;
      if (m.observations.toLowerCase().contains(q)) return true;
      if ('${m.ohm1m}'.contains(q)) return true;
      if ('${m.ohm3m}'.contains(q)) return true;
      return false;
    }

    // Mantén índices relativos para selección visual
    final list = <Measurement>[];
    for (final m in _rows) {
      if (match(m)) list.add(m);
    }
    return list;
  }

  void _mutateRow(int absIndex, Measurement next) {
    _rows[absIndex] = next;
    widget.onChanged(List<Measurement>.from(_rows));
    setState(() {});
  }

  Future<void> _pickDate(int absIndex, DateTime? initial) async {
    final now = DateTime.now();
    final first = DateTime(now.year - 5, 1, 1);
    final last = DateTime(now.year + 5, 12, 31);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: first,
      lastDate: last,
    );
    if (picked == null) return;
    _mutateRow(absIndex, _rows[absIndex].copyWith(date: picked));
  }

  DataColumn _col(String field, String fallback) {
    final title = _titleFor(field, fallback);
    return DataColumn(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: GestureDetector(
              onTap: () => widget.onEditHeader?.call(field),
              onLongPress: () async {
                // edición rápida inline del título
                final ctl = TextEditingController(text: title);
                final txt = await showDialog<String>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Título de columna'),
                    content: TextField(
                      controller: ctl,
                      autofocus: true,
                      decoration: const InputDecoration(hintText: 'Nuevo título'),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                      FilledButton(onPressed: () => Navigator.pop(ctx, ctl.text.trim()), child: const Text('Guardar')),
                    ],
                  ),
                );
                if (txt != null && txt.isNotEmpty) {
                  widget.onHeaderTitleChanged?.call(field, txt);
                  setState(() {}); // pinta el nuevo label
                }
              },
              child: Text(title, overflow: TextOverflow.ellipsis),
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
    final rows = _visible();

    // Mapa visible->índice absoluto
    final Map<int, int> v2abs = {};
    int abs = 0;
    for (int i = 0; i < _rows.length; i++) {
      final m = _rows[i];
      if (rows.contains(m)) {
        v2abs[abs] = i;
        abs++;
      }
    }

    final columns = <DataColumn>[
      _col(MeasurementColumn.progresiva, 'Progresiva'),
      _col(MeasurementColumn.ohm1m, '1m (Ω)'),
      _col(MeasurementColumn.ohm3m, '3m (Ω)'),
      _col(MeasurementColumn.observations, 'Obs'),
      _col(MeasurementColumn.date, 'Fecha'),
      const DataColumn(label: Icon(Icons.map_outlined, size: 16)),
    ];

    final dataRows = <DataRow>[];
    for (int vIndex = 0; vIndex < rows.length; vIndex++) {
      final absIndex = v2abs[vIndex]!;
      final m = _rows[absIndex];
      final selected = absIndex == _selected;
      final tint = _rowTint[absIndex];

      Widget txtCell({
        required String initial,
        required ValueChanged<String> onChanged,
        TextInputType? type,
        int maxLines = 1,
      }) {
        final ctl = TextEditingController(text: initial);
        return TextField(
          controller: ctl,
          maxLines: maxLines,
          keyboardType: type,
          decoration: const InputDecoration(
            isDense: true,
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          ),
          onChanged: onChanged,
          onTap: () => setState(() => _selected = absIndex),
        );
      }

      DataCell dateCell() {
        final txt = m.date == null ? '-' : _fmt.format(m.date!.toLocal());
        return DataCell(
          InkWell(
            onTap: () {
              setState(() => _selected = absIndex);
              _pickDate(absIndex, m.date);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: Text(txt),
            ),
          ),
        );
      }

      DataCell mapCell() {
        return DataCell(
          IconButton(
            tooltip: 'Abrir en mapas',
            onPressed: widget.onOpenMaps == null ? null : () => widget.onOpenMaps!(m),
            icon: const Icon(Icons.map_outlined),
          ),
        );
      }

      final cells = <DataCell>[
        DataCell(
          txtCell(
            initial: m.progresiva,
            onChanged: (v) => _mutateRow(absIndex, m.copyWith(progresiva: v)),
          ),
        ),
        DataCell(
          txtCell(
            initial: (m.ohm1m ?? 0).toString(),
            type: const TextInputType.numberWithOptions(decimal: true, signed: false),
            onChanged: (v) {
              final n = double.tryParse(v.replaceAll(',', '.'));
              _mutateRow(absIndex, m.copyWith(ohm1m: n));
            },
          ),
        ),
        DataCell(
          txtCell(
            initial: (m.ohm3m ?? 0).toString(),
            type: const TextInputType.numberWithOptions(decimal: true, signed: false),
            onChanged: (v) {
              final n = double.tryParse(v.replaceAll(',', '.'));
              _mutateRow(absIndex, m.copyWith(ohm3m: n));
            },
          ),
        ),
        DataCell(
          txtCell(
            initial: m.observations,
            maxLines: 2,
            onChanged: (v) => _mutateRow(absIndex, m.copyWith(observations: v)),
          ),
        ),
        dateCell(),
        mapCell(),
      ];

      dataRows.add(
        DataRow(
          selected: selected,
          color: MaterialStateProperty.resolveWith<Color?>(
                (states) => tint ?? (selected ? t.accent.withOpacity(.18) : null),
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
        border: Border.all(color: t.divider),
      ),
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Filas: ${rows.length}  •  Sel: ${_selected >= 0 ? (_selected + 1) : '-'}',
              style: TextStyle(color: t.text.withOpacity(.85)),
            ),
          ),
          if (widget.aiEnabled)
            const Chip(visualDensity: VisualDensity.compact, avatar: Icon(Icons.auto_awesome), label: Text('IA')),
          if (widget.showPhotoRail)
            const SizedBox(width: 8),
          if (widget.showPhotoRail)
            const Chip(visualDensity: VisualDensity.compact, avatar: Icon(Icons.photo_library_outlined), label: Text('Fotos')),
        ],
      ),
    );

    return Column(
      children: [
        headerBar,
        Expanded(
          child: Scrollbar(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 880),
                child: SingleChildScrollView(
                  child: DataTable(
                    headingRowColor: MaterialStatePropertyAll(t.surface),
                    dataRowMinHeight: 48,
                    dataRowMaxHeight: 68,
                    columns: columns,
                    rows: dataRows,
                    border: TableBorder.symmetric(
                      inside: BorderSide(color: t.divider.withOpacity(.6)),
                      outside: BorderSide(color: t.divider),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
