// lib/screens/measurement_list_screen.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show compute; // ← nuevo
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/measurement.dart';
import '../services/archive_service.dart';
import '../services/autocomplete_service.dart';
import '../services/pdf_export_service.dart';
import '../data/measurement_repository.dart';
import '../screens/ai_sheet.dart';
import 'edit_measurement_sheet.dart';

enum _SortBy { date, progresiva }

class MeasurementListScreen extends StatefulWidget {
  const MeasurementListScreen({super.key});
  @override
  State<MeasurementListScreen> createState() => _MeasurementListScreenState();
}

class _MeasurementListScreenState extends State<MeasurementListScreen> {
  final _searchCtrl = TextEditingController();
  final _sel = <int>{};
  final _scroll = ScrollController();

  List<Measurement> _filtered = [];
  Set<String> _archived = {};
  bool _showArchived = false;
  bool _selectionMode = false;
  _SortBy _sortBy = _SortBy.date;
  bool _asc = false;

  bool _initializing = true;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 350), () {
        _applyFilter(); // Future ignorado a propósito
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) => _warmInit());
  }

  Future<void> _warmInit() async {
    if (!mounted) return;
    setState(() => _initializing = true);

    final repo = context.read<MeasurementRepository>();
    await repo.init();
    repo.addListener(_applyFilter);
    repo.focusKey.addListener(_onFocusRequest);

    final s = await ArchiveService.instance.load();
    if (!mounted) return;
    setState(() => _archived = s);
    await _applyFilter();

    if (!mounted) return;
    setState(() => _initializing = false);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _scroll.dispose();
    final repo = context.read<MeasurementRepository>();
    repo.removeListener(_applyFilter);
    repo.focusKey.removeListener(_onFocusRequest);
    super.dispose();
  }

  Future<void> _applyFilter() async {
    final repo = context.read<MeasurementRepository>();
    final all = repo.items;
    final keys = all.map(repo.keyFor).toList(growable: false);
    final args = _FilterArgs(
      items: all,
      keys: keys,
      qLower: _searchCtrl.text.trim().toLowerCase(),
      archivedKeys: _archived,
      showArchived: _showArchived,
      sortByDate: _sortBy == _SortBy.date,
      asc: _asc,
    );

    final result = await compute(_filterAndSort, args);
    if (!mounted) return;
    setState(() {
      _filtered = result;
      _sel.clear();
      _selectionMode = false;
    });
  }

  void _onFocusRequest() {
    final repo = context.read<MeasurementRepository>();
    final key = repo.focusKey.value;
    if (key == null) return;
    final idx = _filtered.indexWhere((m) => repo.keyFor(m) == key);
    if (idx < 0) {
      setState(() => _showArchived = false);
      _applyFilter();
      final idx2 = _filtered.indexWhere((m) => repo.keyFor(m) == key);
      if (idx2 < 0) {
        repo.clearFocus();
        return;
      }
      _scrollToAndEdit(idx2);
      return;
    }
    _scrollToAndEdit(idx);
  }

  void _scrollToAndEdit(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final off = index * 72.0;
      _scroll.animateTo(off,
          duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
      if (!mounted) return;
      final m = _filtered[index];
      await _openEditor(m);
      if (!mounted) return;
      context.read<MeasurementRepository>().clearFocus();
    });
  }

  String _keyFor(Measurement m) => context.read<MeasurementRepository>().keyFor(m);

  Future<void> _toggleArchive(Measurement m, bool value) async {
    final k = _keyFor(m);
    await ArchiveService.instance.toggle(k, value: value);
    final s = await ArchiveService.instance.load();
    if (!mounted) return;
    setState(() => _archived = s);
    await _applyFilter();
  }

  Future<void> _deleteOne(Measurement m) async {
    await context.read<MeasurementRepository>().removeByKey(_keyFor(m));
    await _applyFilter();
  }

  Future<void> _deleteSelected() async {
    final repo = context.read<MeasurementRepository>();
    final toDelete = _sel.map((i) => _filtered[i]).toList(growable: false);
    for (final m in toDelete) {
      await repo.removeByKey(_keyFor(m));
    }
    await _applyFilter();
  }

  Future<void> _exportSelectedPdf() async {
    final rows = _sel.map((i) => _filtered[i]).toList();
    if (rows.isEmpty) return;
    final file = await PdfExportService.exportMeasurementsPdf(
      data: rows,
      fileName: 'gridnote_seleccion.pdf',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('PDF listo: ${file.path}')));
  }

  String _buildDashboard() {
    final list =
    _filtered.where((m) => m.latitude != null && m.longitude != null).toList();
    if (list.length < 2) return 'Mediciones: ${_filtered.length} • Distancia: 0 m';
    list.sort((a, b) => a.date.compareTo(b.date));
    final d = _haversine(
        list.first.latitude!, list.first.longitude!, list.last.latitude!, list.last.longitude!);
    return 'Mediciones: ${_filtered.length} • Distancia: ${d.toStringAsFixed(0)} m';
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0;
    double toRad(double d) => d * math.pi / 180.0;
    final dLat = toRad(lat2 - lat1);
    final dLon = toRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(toRad(lat1)) *
            math.cos(toRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  @override
  Widget build(BuildContext context) {
    final isSelecting = _selectionMode && _sel.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchCtrl,
          decoration: const InputDecoration(
              hintText: 'Buscar por Progresiva u Observaciones',
              border: InputBorder.none),
          textInputAction: TextInputAction.search,
        ),
        actions: [
          IconButton(
            tooltip: 'Asistente IA',
            onPressed: () => showModalBottomSheet(
              context: context,
              showDragHandle: true,
              builder: (_) => const AiSheet(),
            ),
            icon: const Icon(Icons.smart_toy_outlined),
          ),
          IconButton(
            tooltip: _showArchived ? 'Ver activos' : 'Ver archivados',
            onPressed: () {
              setState(() => _showArchived = !_showArchived);
              _applyFilter();
            },
            icon: Icon(
                _showArchived ? Icons.inventory_2 : Icons.inventory_2_outlined),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              setState(() {
                if (v == 'date') _sortBy = _SortBy.date;
                if (v == 'prog') _sortBy = _SortBy.progresiva;
                if (v == 'dir') _asc = !_asc;
              });
              _applyFilter();
            },
            itemBuilder: (_) => [
              CheckedPopupMenuItem(
                  value: 'date',
                  checked: _sortBy == _SortBy.date,
                  child: const Text('Ordenar por fecha')),
              CheckedPopupMenuItem(
                  value: 'prog',
                  checked: _sortBy == _SortBy.progresiva,
                  child: const Text('Ordenar por progresiva')),
              PopupMenuItem(
                  value: 'dir', child: Text(_asc ? 'Ascendente' : 'Descendente')),
            ],
            icon: const Icon(Icons.sort),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_initializing) const LinearProgressIndicator(),
          _Dashboard(text: _buildDashboard()),
          Expanded(
            child: _filtered.isEmpty
                ? const Center(child: Text('Sin datos'))
                : ListView.separated(
              controller: _scroll,
              itemCount: _filtered.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final m = _filtered[i];
                final archived = _archived.contains(_keyFor(m));
                final selected = _sel.contains(i);
                return Dismissible(
                  key: ValueKey(_keyFor(m)),
                  background: _SwipeBg(
                      icon: archived ? Icons.unarchive : Icons.archive,
                      color: Colors.blueGrey),
                  secondaryBackground:
                  const _SwipeBg(icon: Icons.delete, color: Colors.red),
                  confirmDismiss: (dir) async {
                    if (dir == DismissDirection.startToEnd) {
                      await _toggleArchive(m, !archived);
                      return false;
                    } else {
                      final bool? ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Eliminar'),
                          content: const Text('¿Eliminar esta medición?'),
                          actions: [
                            TextButton(
                                onPressed: () =>
                                    Navigator.pop(context, false),
                                child: const Text('Cancelar')),
                            FilledButton(
                                onPressed: () =>
                                    Navigator.pop(context, true),
                                child: const Text('Eliminar')),
                          ],
                        ),
                      );
                      if (!mounted) return false;
                      if (ok != true) return false;
                      await _deleteOne(m);
                      return true;
                    }
                  },
                  child: ListTile(
                    onLongPress: () => setState(() {
                      _selectionMode = true;
                      _sel.add(i);
                    }),
                    onTap: () {
                      if (_selectionMode) {
                        setState(() =>
                        selected ? _sel.remove(i) : _sel.add(i));
                      } else {
                        _openEditor(m);
                      }
                    },
                    leading: _selectionMode
                        ? Checkbox(
                      value: selected,
                      onChanged: (v) => setState(() {
                        v == true ? _sel.add(i) : _sel.remove(i);
                      }),
                    )
                        : Icon(archived
                        ? Icons.inventory_2
                        : Icons.description_outlined),
                    title: Text(m.progresiva.isEmpty
                        ? '(sin progresiva)'
                        : m.progresiva),
                    subtitle: Text(
                      [
                        m.dateString,
                        '1m ${m.ohm1m ?? '-'}',
                        '3m ${m.ohm3m ?? '-'}',
                        if (m.observations.isNotEmpty) m.observations,
                      ].join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing:
                    _selectionMode ? null : const Icon(Icons.chevron_right),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: isSelecting
          ? SafeArea(
        child: Row(
          children: [
            const SizedBox(width: 8),
            Text('Seleccionados: ${_sel.length}'),
            const Spacer(),
            IconButton(
                tooltip: 'Exportar PDF selección',
                onPressed: _exportSelectedPdf,
                icon: const Icon(Icons.picture_as_pdf)),
            IconButton(
              tooltip: 'Eliminar selección',
              onPressed: () async {
                final bool? ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Eliminar'),
                    content: Text('¿Eliminar ${_sel.length} elementos?'),
                    actions: [
                      TextButton(
                          onPressed: () =>
                              Navigator.pop(context, false),
                          child: const Text('Cancelar')),
                      FilledButton(
                          onPressed: () =>
                              Navigator.pop(context, true),
                          child: const Text('Eliminar')),
                    ],
                  ),
                );
                if (!mounted) return;
                if (ok == true) await _deleteSelected();
              },
              icon: const Icon(Icons.delete),
            ),
            IconButton(
              tooltip: 'Salir selección',
              onPressed: () => setState(() {
                _sel.clear();
                _selectionMode = false;
              }),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      )
          : null,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final repo = context.read<MeasurementRepository>();
          final m = Measurement.empty().copyWith(
            date: DateTime.now(),
            progresiva: repo.suggestNextProgresiva(),
          );
          final edited = await showModalBottomSheet<Measurement>(
            context: context,
            isScrollControlled: true,
            builder: (_) => EditMeasurementSheet(model: m),
          );
          if (!mounted) return;
          if (edited == null) return;
          await repo.add(edited);
          if (!mounted) return;
          _applyFilter();
        },
        icon: const Icon(Icons.add),
        label: const Text('Nuevo'),
      ),
    );
  }

  Future<void> _openEditor(Measurement m) async {
    final edited = await showModalBottomSheet<Measurement>(
      context: context,
      isScrollControlled: true,
      builder: (_) => EditMeasurementSheet(model: m),
    );
    if (!mounted) return;
    if (edited == null) return;
    await context.read<MeasurementRepository>().replace(m, edited);
    if (!mounted) return;
    _applyFilter();
    await AutocompleteService.instance.addObservation(edited.observations);
  }
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        const Icon(Icons.insights),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ]),
    );
  }
}

class _SwipeBg extends StatelessWidget {
  const _SwipeBg({required this.icon, required this.color});
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      color: color.withValues(alpha: 0.15),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Icon(icon, color: color),
    );
  }
}

/// --------- Helpers para filtrar/ordenar en isolate ---------

class _FilterArgs {
  _FilterArgs({
    required this.items,
    required this.keys,
    required this.qLower,
    required this.archivedKeys,
    required this.showArchived,
    required this.sortByDate,
    required this.asc,
  });

  final List<Measurement> items;
  final List<String> keys;
  final String qLower;
  final Set<String> archivedKeys;
  final bool showArchived;
  final bool sortByDate;
  final bool asc;
}

List<Measurement> _filterAndSort(_FilterArgs a) {
  final out = <Measurement>[];
  for (var i = 0; i < a.items.length; i++) {
    final m = a.items[i];
    final isArchived = a.archivedKeys.contains(a.keys[i]);
    if (a.showArchived != isArchived) continue;

    if (a.qLower.isNotEmpty) {
      final p = m.progresiva.toLowerCase();
      final o = m.observations.toLowerCase();
      if (!p.contains(a.qLower) && !o.contains(a.qLower)) continue;
    }
    out.add(m);
  }

  out.sort((x, y) {
    final c = a.sortByDate
        ? x.date.compareTo(y.date)
        : x.progresiva.toLowerCase().compareTo(y.progresiva.toLowerCase());
    return a.asc ? c : -c;
  });
  return out;
}
