// lib/screens/report_history_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;
import '../services/file_scanner.dart';

enum _ReportType { all, pdf, xlsx }

class ReportHistoryScreen extends StatefulWidget {
  const ReportHistoryScreen({super.key});

  @override
  State<ReportHistoryScreen> createState() => _ReportHistoryScreenState();
}

class _ReportHistoryScreenState extends State<ReportHistoryScreen> {
  late Future<List<FileInfo>> _future;
  final _dateFmt = DateFormat('dd/MM/yy HH:mm');

  _ReportType _type = _ReportType.all;
  DateTimeRange? _range;

  @override
  void initState() {
    super.initState();
    _future = scanReports();
  }

  void _refresh() => setState(() => _future = scanReports());

  List<FileInfo> _applyFilters(List<FileInfo> src) {
    Iterable<FileInfo> f = src;

    if (_type != _ReportType.all) {
      f = f.where((x) => _type == _ReportType.pdf ? x.ext == '.pdf' : x.ext == '.xlsx');
    }
    if (_range != null) {
      final start = DateTime(_range!.start.year, _range!.start.month, _range!.start.day);
      final end = DateTime(_range!.end.year, _range!.end.month, _range!.end.day, 23, 59, 59);
      f = f.where((x) => !x.modified.isBefore(start) && !x.modified.isAfter(end));
    }
    return f.toList();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _range ??
          DateTimeRange(
            start: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7)),
            end: DateTime(now.year, now.month, now.day),
          ),
      helpText: 'Filtrar por fechas',
      saveText: 'Aplicar',
    );
    if (picked != null) setState(() => _range = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de reportes'),
        actions: [
          IconButton(
            tooltip: 'Rango de fechas',
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: _pickDateRange,
          ),
          IconButton(
            tooltip: 'Limpiar filtros',
            icon: const Icon(Icons.filter_alt_off_outlined),
            onPressed: () => setState(() {
              _type = _ReportType.all;
              _range = null;
            }),
          ),
          IconButton(
            tooltip: 'Refrescar',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<List<FileInfo>>(
        future: _future,
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return const Center(child: Text('Error al cargar archivos.'));
          }
          final items = _applyFilters(snap.data ?? const []);
          if (items.isEmpty) {
            return Center(
              child: Text(
                _range == null && _type == _ReportType.all
                    ? 'Sin archivos recientes'
                    : 'Sin resultados con los filtros aplicados',
                style: theme.textTheme.bodyLarge,
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Todos'),
                      selected: _type == _ReportType.all,
                      onSelected: (_) => setState(() => _type = _ReportType.all),
                    ),
                    ChoiceChip(
                      label: const Text('PDF'),
                      selected: _type == _ReportType.pdf,
                      onSelected: (_) => setState(() => _type = _ReportType.pdf),
                    ),
                    ChoiceChip(
                      label: const Text('Excel'),
                      selected: _type == _ReportType.xlsx,
                      onSelected: (_) => setState(() => _type = _ReportType.xlsx),
                    ),
                    if (_range != null)
                      InputChip(
                        avatar: const Icon(Icons.calendar_today, size: 18),
                        label: Text(
                          '${DateFormat('dd/MM/yy').format(_range!.start)} → ${DateFormat('dd/MM/yy').format(_range!.end)}',
                        ),
                        onDeleted: () => setState(() => _range = null),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final it = items[i];
                    final isPdf = it.ext == '.pdf';
                    return ListTile(
                      leading: Icon(isPdf ? Icons.picture_as_pdf : Icons.grid_on),
                      title: Text(p.basename(it.file.path), maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        '${_dateFmt.format(it.modified)} • ${formatSize(it.sizeBytes)} • ${it.origin}',
                      ),
                      onTap: () => OpenFile.open(it.file.path),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) async {
                          switch (v) {
                            case 'open':
                              await OpenFile.open(it.file.path);
                              break;
                            case 'share':
                              await Share.shareXFiles([XFile(it.file.path)]);
                              break;
                            case 'delete':
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Eliminar archivo'),
                                  content: Text('¿Eliminar “${it.name}”?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Cancelar'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('Eliminar'),
                                    ),
                                  ],
                                ),
                              ) ??
                                  false;
                              if (!ok) return;
                              try {
                                await it.file.delete();
                                if (mounted) _refresh();
                              } catch (_) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('No se pudo eliminar.')),
                                );
                              }
                              break;
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'open', child: Text('Abrir')),
                          PopupMenuItem(value: 'share', child: Text('Compartir')),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Eliminar'),
                          ),
                        ],
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
