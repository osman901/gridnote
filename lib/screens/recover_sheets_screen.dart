// lib/screens/recover_sheets_screen.dart
import 'package:flutter/material.dart';
import '../theme/gridnote_theme.dart';

class RecoverSheetsScreen extends StatefulWidget {
  const RecoverSheetsScreen({
    super.key,
    required this.theme,
    this.loader,        // opcional: trae elementos de papelera
    this.onRestore,     // opcional: acción de restaurar
  });

  final GridnoteThemeController theme;
  final Future<List<TrashItem>> Function()? loader;
  final Future<void> Function(TrashItem item)? onRestore;

  @override
  State<RecoverSheetsScreen> createState() => _RecoverSheetsScreenState();
}

class _RecoverSheetsScreenState extends State<RecoverSheetsScreen> {
  late Future<List<TrashItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<TrashItem>> _load() async {
    if (widget.loader != null) return widget.loader!();
    // Mock vacío por defecto hasta conectar servicio real.
    return <TrashItem>[];
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme.theme;

    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar planillas')),
      body: FutureBuilder<List<TrashItem>>(
        future: _future,
        builder: (context, snap) {
          final waiting = snap.connectionState == ConnectionState.waiting;
          final items = snap.data ?? const <TrashItem>[];

          if (waiting) {
            return const _SkeletonList();
          }

          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No hay planillas en papelera.\n\n'
                      'Cuando el borrado sea “suave”, las planillas se mostrarán aquí\n'
                      'por un tiempo antes de eliminarse definitivamente.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: t.text.withValues(alpha: .7), height: 1.4),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              itemBuilder: (_, i) {
                final it = items[i];
                return ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: const Icon(Icons.description_outlined),
                  title: Text(it.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    'Eliminada hace ${_ago(it.deletedAt)}',
                    style: TextStyle(color: t.text.withValues(alpha: .7)),
                  ),
                  trailing: FilledButton(
                    onPressed: () async {
                      if (widget.onRestore != null) {
                        await widget.onRestore!(it);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Planilla restaurada')),
                        );
                        await _refresh();
                      } else {
                        // Demo sin backend
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Restaurado (demo)')),
                        );
                      }
                    },
                    child: const Text('Restaurar'),
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemCount: items.length,
            ),
          );
        },
      ),
    );
  }

  static String _ago(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'ahora';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours} h';
    return '${diff.inDays} d';
  }
}

/// Modelo simple para papelera.
/// Adaptalo a tu estructura real si ya la tenés.
class TrashItem {
  final String id;
  final String title;
  final DateTime deletedAt;
  const TrashItem({required this.id, required this.title, required this.deletedAt});
}

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemBuilder: (_, __) => Container(
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.08),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemCount: 8,
    );
  }
}
