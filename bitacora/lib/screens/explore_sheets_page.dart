import 'package:flutter/material.dart';

import '../widgets/sheets_list_view.dart';
import '../theme/gridnote_theme.dart';
import '../services/free_sheet_service.dart';
import 'free_sheet_screen.dart';
import 'daily_note_screen.dart';

class ExploreSheetsPage extends StatelessWidget {
  const ExploreSheetsPage({super.key, this.theme});

  final GridnoteThemeController? theme;
  GridnoteThemeController get _tc => theme ?? GridnoteThemeController();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: 0,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Planillas'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Planillas'),
              Tab(text: 'Opciones'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _PlanillasTab(),
            _OpcionesTab(),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showCreateMenu(context),
          icon: const Icon(Icons.add),
          label: const Text('Nueva planilla'),
        ),
      ),
    );
  }

  Future<void> _showCreateMenu(BuildContext context) async {
    final nav = Navigator.of(context); // evitar usar BuildContext tras await
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.grid_on_outlined),
              title: const Text('Planilla libre (simple)'),
              subtitle: const Text('TÃƒÆ’Ã‚Â­tulos y datos editables'),
              onTap: () => Navigator.pop(_, 'free'),
            ),
            const Divider(height: 0),
            ListTile(
              leading: const Icon(Icons.notes_outlined),
              title: const Text('Bloc de notas (simple)'),
              subtitle: const Text('Dictado por voz y texto'),
              onTap: () => Navigator.pop(_, 'notes'),
            ),
          ],
        ),
      ),
    );

    if (choice == null) return;

    if (choice == 'free') {
      final d = await FreeSheetService.instance.create(name: 'Planilla libre');
      if (!nav.mounted) return;
      nav.push(MaterialPageRoute(builder: (_) => FreeSheetScreen(id: d.id, theme: _tc)));
      return;
    }

    if (choice == 'notes') {
      // Bloc de notas simple
      if (!nav.mounted) return;
      nav.push(MaterialPageRoute(builder: (_) => const DailyNoteScreen()));
      return;
    }
  }
}

class _PlanillasTab extends StatefulWidget {
  const _PlanillasTab();

  @override
  State<_PlanillasTab> createState() => _PlanillasTabState();
}

class _PlanillasTabState extends State<_PlanillasTab> {
  DateTime? _filtroFecha;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _filtroFecha ?? now,
                    firstDate: DateTime(now.year - 5, 1, 1),
                    lastDate: DateTime(now.year + 5, 12, 31),
                    helpText: 'Buscar por fecha',
                    cancelText: 'Cancelar',
                    confirmText: 'Buscar',
                    locale: const Locale('es'),
                  );
                  if (picked != null) setState(() => _filtroFecha = picked);
                },
                icon: const Icon(Icons.calendar_month),
                label: const Text('Calendario'),
              ),
              const SizedBox(width: 8),
              if (_filtroFecha != null)
                TextButton(
                  onPressed: () => setState(() => _filtroFecha = null),
                  child: const Text('Quitar filtro'),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: SheetsListView(filterDate: _filtroFecha)),
      ],
    );
  }
}

class _OpcionesTab extends StatelessWidget {
  const _OpcionesTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.restore_from_trash_outlined),
          title: const Text('Recuperar datos borrados'),
          subtitle: const Text('Ver y restaurar planillas eliminadas'),
          onTap: () => Navigator.of(context).pushNamed('/trash'),
        ),
        ListTile(
          leading: const Icon(Icons.settings_outlined),
          title: const Text('Otras opciones'),
          onTap: () => Navigator.of(context).pushNamed('/settings'),
        ),
      ],
    );
  }
}
