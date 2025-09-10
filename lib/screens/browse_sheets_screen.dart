import 'package:flutter/material.dart';
import '../theme/gridnote_theme.dart';
import '../models/sheet_meta.dart';
import '../services/sheet_registry.dart';
import 'measurements_screen.dart';
import 'settings_screen.dart';
import 'recover_sheets_screen.dart';

/// Explorador de planillas 2025: sin “tambor”, con búsqueda + refresh.
class BrowseSheetsScreen extends StatefulWidget {
  const BrowseSheetsScreen({super.key, required this.theme});
  final GridnoteThemeController theme;

  @override
  State<BrowseSheetsScreen> createState() => _BrowseSheetsScreenState();
}

class _BrowseSheetsScreenState extends State<BrowseSheetsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab =
  TabController(length: 2, vsync: this, initialIndex: 0);

  final ValueNotifier<bool> _loading = ValueNotifier<bool>(true);
  final ValueNotifier<List<SheetMeta>> _items =
  ValueNotifier<List<SheetMeta>>(<SheetMeta>[]);
  String _query = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _tab.dispose();
    _loading.dispose();
    _items.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    _loading.value = true;
    try {
      final all = await SheetRegistry.instance.getAllSorted();
      // ordenamos por última modificación desc (ya suele venir así)
      all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _items.value = all;
    } catch (_) {
      // Mantener lista previa si algo falla
    } finally {
      _loading.value = false;
    }
  }

  List<SheetMeta> _filtered(List<SheetMeta> src) {
    if (_query.trim().isEmpty) return src;
    final q = _query.toLowerCase();
    return src
        .where((m) =>
    m.name.toLowerCase().contains(q) ||
        m.id.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme.theme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Explorar planillas'),
        actions: [
          IconButton(
            tooltip: 'Recargar',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Planillas'),
            Tab(text: 'Opciones'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          // ---------- Pestaña PLANILLAS ----------
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Buscar por título o ID…',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ValueListenableBuilder<bool>(
                  valueListenable: _loading,
                  builder: (_, loading, __) {
                    if (loading) {
                      return const _ListSkeleton();
                    }
                    return RefreshIndicator(
                      onRefresh: _reload,
                      child: ValueListenableBuilder<List<SheetMeta>>(
                        valueListenable: _items,
                        builder: (_, list, __) {
                          final items = _filtered(list);
                          if (items.isEmpty) {
                            return ListView(
                              padding: const EdgeInsets.all(24),
                              children: [
                                Center(
                                  child: Text(
                                    _query.isEmpty
                                        ? 'No hay planillas aún.'
                                        : 'Sin resultados para “$_query”.',
                                    style: TextStyle(
                                      color: t.textFaint,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }
                          return ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemBuilder: (_, i) => _SheetTile(
                              theme: t,
                              meta: items[i],
                              onOpen: () async {
                                await SheetRegistry.instance.touch(items[i]);
                                if (!mounted) return;
                                await Navigator.of(context).push(
                                  _FadeRoute(
                                    child: MeasurementScreen(
                                      id: items[i].id,
                                      meta: items[i],
                                      initial: const [],
                                      themeController: widget.theme,
                                    ),
                                  ),
                                );
                              },
                            ),
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemCount: items.length,
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding:
                  const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        final meta = await SheetRegistry.instance
                            .create(name: 'Planilla nueva');
                        await _reload();
                        if (!mounted) return;
                        await Navigator.of(context).push(
                          _FadeRoute(
                            child: MeasurementScreen(
                              id: meta.id,
                              meta: meta,
                              initial: const [],
                              themeController: widget.theme,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Nueva planilla'),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ---------- Pestaña OPCIONES ----------
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Ajustes'),
                subtitle: const Text('Preferencias, cuentas, endpoint, etc.'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
              const Divider(height: 24),
              ListTile(
                leading: const Icon(Icons.restore_from_trash_outlined),
                title: const Text('Recuperar planillas'),
                subtitle: const Text(
                  'Restaura planillas eliminadas recientemente.',
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RecoverSheetsScreen(theme: widget.theme),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              Text(
                'Las planillas se pueden recuperar si el borrado es “suave” '
                    '(papelera temporal).',
                style:
                TextStyle(color: t.text.withValues(alpha: .7), fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SheetTile extends StatelessWidget {
  const _SheetTile({
    required this.theme,
    required this.meta,
    required this.onOpen,
  });

  final GridnoteTheme theme;
  final SheetMeta meta;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final when = meta.createdAt;
    final dd =
        '${when.day.toString().padLeft(2, '0')}/${when.month.toString().padLeft(2, '0')}/${when.year}';

    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: theme.surface,
      onTap: onOpen,
      leading: CircleAvatar(
        backgroundColor: theme.accent.withOpacity(.15),
        child: const Icon(Icons.description_outlined),
      ),
      title: Text(
        meta.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: theme.text, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        'ID: ${meta.id}  •  Mod.: $dd',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: theme.textFaint, fontSize: 12),
      ),
      trailing: Icon(Icons.chevron_right, color: theme.textFaint),
    );
  }
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemBuilder: (_, __) => _Shimmer(
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.08),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemCount: 8,
    );
  }
}

class _Shimmer extends StatefulWidget {
  const _Shimmer({required this.child});
  final Widget child;
  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _c.drive(Tween(begin: .45, end: .9)),
      child: widget.child,
    );
  }
}

class _FadeRoute extends PageRouteBuilder {
  _FadeRoute({required Widget child})
      : super(
    transitionDuration: const Duration(milliseconds: 200),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (_, __, ___) => child,
    transitionsBuilder: (_, a, __, c) =>
        FadeTransition(opacity: a, child: c),
  );
}
