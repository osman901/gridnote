import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/sheets_store.dart';
import 'beta_sheet_screen.dart';

final sheetsStoreProvider = Provider<SheetsStore>((_) => SheetsStore());
final sheetsListProvider = FutureProvider<List<SheetSummary>>((ref) async {
  final store = ref.read(sheetsStoreProvider);
  return store.list();
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(sheetsListProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tus planillas'),
        actions: [
          IconButton(
            tooltip: 'Refrescar',
            onPressed: () => ref.refresh(sheetsListProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final store = ref.read(sheetsStoreProvider);
          final suggestions = await store.titleSuggestions();
          if (!context.mounted) return;
          final title = await _askTitle(context, suggestions);
          if (title == null) return;
          final id = await store.create(title: title);
          if (!context.mounted) return;
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => BetaSheetScreen(sheetId: id)));
          ref.invalidate(sheetsListProvider);
        },
        label: const Text('Nueva'),
        icon: const Icon(Icons.add),
      ),
      body: list.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No hay planillas aún'));
          }

          // Agrupar por Día / Semana / Mes
          final now = DateTime.now();
          bool isSameDay(DateTime a, DateTime b) =>
              a.year == b.year && a.month == b.month && a.day == b.day;
          bool isSameWeek(DateTime a, DateTime b) {
            final wa = DateTime(a.year, a.month, a.day - (a.weekday % 7));
            final wb = DateTime(b.year, b.month, b.day - (b.weekday % 7));
            return isSameDay(wa, wb);
          }
          bool isSameMonth(DateTime a, DateTime b) =>
              a.year == b.year && a.month == b.month;

          final today = items.where((s) => isSameDay(s.createdAt, now)).toList();
          final thisWeek =
          items.where((s) => isSameWeek(s.createdAt, now)).toList();
          final thisMonth =
          items.where((s) => isSameMonth(s.createdAt, now)).toList();

          Widget section(String title, List<SheetSummary> list) => list.isEmpty
              ? const SizedBox.shrink()
              : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(title,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              ...list.map((s) => Card(
                margin: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(s.title.isEmpty ? 'Sin título' : s.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                      '${s.rowsCount} filas · ${s.updatedAt}'),
                  trailing: IconButton(
                    tooltip: 'Abrir',
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BetaSheetScreen(sheetId: s.id),
                        ),
                      );
                      ref.invalidate(sheetsListProvider);
                    },
                  ),
                ),
              )),
            ],
          );

          return RefreshIndicator(
            onRefresh: () async => ref.refresh(sheetsListProvider),
            child: ListView(
              children: [
                section('Hoy', today),
                section('Esta semana', thisWeek),
                section('Este mes', thisMonth),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    'Sugerencia: mantené títulos cortos y claros.\nExportá cuando termines – más rápido desde la planilla.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: cs.outline),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<String?> _askTitle(BuildContext context, List<String> suggestions) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Título (opcional)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Ej: Catódica Norte'),
            ),
            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: -8,
                  children: suggestions
                      .map((s) => ActionChip(
                    label: Text(s, overflow: TextOverflow.ellipsis),
                    onPressed: () => ctrl.text = s,
                  ))
                      .toList(),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Omitir')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }
}
