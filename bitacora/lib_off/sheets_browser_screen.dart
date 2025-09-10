// lib/screens/sheets_browser_screen.dart
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/gridnote_theme.dart';
import '../services/sheet_registry.dart';

// Bloc de notas simple (tu pantalla)
import '../services/free_sheet_service.dart';
import 'daily_note_screen.dart';

/// Referencia mínima a una planilla
class SheetRef {
  final String id;
  final String title;
  final DateTime createdAt; // local
  final String? path;
  const SheetRef({
    required this.id,
    required this.title,
    required this.createdAt,
    this.path,
  });
}

typedef LoadSheets = Future<List<SheetRef>> Function();
typedef OpenSheet = Future<void> Function(SheetRef ref);

class SheetsBrowserScreen extends StatefulWidget {
  const SheetsBrowserScreen({
    super.key,
    required this.theme,
    required this.loadSheets,
    this.onOpen,
    this.initialTabIndex = 0, // 0: Calendario, 1: Planillas (todas)
  });

  final GridnoteThemeController theme;
  final LoadSheets loadSheets;
  final OpenSheet? onOpen;
  final int initialTabIndex;

  @override
  State<SheetsBrowserScreen> createState() => _SheetsBrowserScreenState();
}

class _SheetsBrowserScreenState extends State<SheetsBrowserScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  List<SheetRef> _all = const [];
  bool _loading = true;

  // calendario
  late DateTime _month;
  DateTime? _selectedDay;

  // filtros (planillas)
  DateTime? _filterDay;
  DateTime? _filterMonth;
  int _drumIndex = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
    final idx = math.max(0, math.min(1, widget.initialTabIndex));
    _tabs = TabController(length: 2, vsync: this, initialIndex: idx);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await widget.loadSheets();
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    setState(() {
      _all = items;
      _loading = false;
      _selectedDay ??= items.isNotEmpty
          ? DateTime(items.first.createdAt.year, items.first.createdAt.month, items.first.createdAt.day)
          : DateTime.now();
      _drumIndex = 0;
    });
  }

  DateTime _asDay(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  List<SheetRef> _scrollFiltered() {
    var list = _all;
    if (_filterDay != null) {
      final k = _asDay(_filterDay!);
      list = list.where((r) => _asDay(r.createdAt) == k).toList();
    }
    if (_filterMonth != null) {
      list = list
          .where((r) => r.createdAt.year == _filterMonth!.year && r.createdAt.month == _filterMonth!.month)
          .toList();
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> _open(SheetRef r) async {
    if (widget.onOpen != null) {
      await widget.onOpen!(r);
      if (mounted) await _load();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Abrir: ${r.title}')));
    }
  }

  /// Menú de creación: Medición clásica (app principal) o Bloc de notas
  Future<void> _createAndOpen() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.table_rows_outlined),
              title: const Text('Planilla de mediciones (clásica)'),
              onTap: () => Navigator.pop(context, 'measure'),
            ),
            ListTile(
              leading: const Icon(Icons.notes_outlined),
              title: const Text('Bloc de notas'),
              onTap: () => Navigator.pop(context, 'notes'),
            ),
          ],
        ),
      ),
    );

    if (choice == null) return;

    switch (choice) {
      case 'measure': {
        final meta = await SheetRegistry.instance.create(name: 'Planilla nueva');
        final ref = SheetRef(
          id: meta.id.toString(),                 // <— FIX: asegurar String
          title: meta.name,
          createdAt: meta.createdAt.toLocal(),
        );
        await _open(ref);
        break;
      }
      case 'notes': {
        final d = await FreeSheetService.instance.create(name: 'Bloc de notas');
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DailyNoteScreen(
              id: d.id.toString(),                // <— FIX: asegurar String
            ),
          ),
        );
        await _load();
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme.theme;

    return Scaffold(
      backgroundColor: t.scaffold,
      appBar: AppBar(
        title: const Text('Explorar planillas'),
        backgroundColor: t.scaffold,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: TabBar(
          controller: _tabs,
          tabs: const [Tab(text: 'Calendario'), Tab(text: 'Planillas')],
          indicatorColor: t.accent,
          labelColor: t.text,
          unselectedLabelColor: t.text.withValues(alpha: .6),
          dividerColor: Colors.transparent,
        ),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
        controller: _tabs,
        children: [
          _CalendarTab(
            theme: widget.theme,
            month: _month,
            selected: _selectedDay,
            onMonthChanged: (m) => setState(() => _month = m),
            onSelectDay: (d) => setState(() => _selectedDay = d),
            items: _all,
            onOpen: _open,
          ),
          _ScrollTab(
            theme: widget.theme,
            items: _scrollFiltered(),
            index: _drumIndex,
            filterDay: _filterDay,
            filterMonth: _filterMonth,
            onChanged: (i) => setState(() => _drumIndex = i),
            onPickDay: (d) => setState(() {
              _filterDay = d == null ? null : _asDay(d);
              _drumIndex = 0;
            }),
            onPickMonth: (m) => setState(() {
              _filterMonth = m == null ? null : DateTime(m.year, m.month, 1);
              _drumIndex = 0;
            }),
            onOpen: _open,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createAndOpen,
        icon: const Icon(Icons.add),
        label: const Text('Nueva planilla'),
        backgroundColor: Colors.grey.shade300,
        foregroundColor: Colors.black,
      ),
    );
  }
}

// ---------------- CALENDARIO ----------------

class _CalendarTab extends StatelessWidget {
  const _CalendarTab({
    required this.theme,
    required this.month,
    required this.selected,
    required this.onMonthChanged,
    required this.onSelectDay,
    required this.items,
    required this.onOpen,
  });

  final GridnoteThemeController theme;
  final DateTime month;
  final DateTime? selected;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onSelectDay;
  final List<SheetRef> items;
  final Future<void> Function(SheetRef) onOpen;

  @override
  Widget build(BuildContext context) {
    final t = theme.theme;
    final byDay = _groupByDay(items);
    final fmtDay = DateFormat('EEE d MMM', 'es');

    final sel = selected ?? DateTime.now();
    final list = byDay[DateTime(sel.year, sel.month, sel.day)] ?? const <SheetRef>[];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  fmtDay.format(sel),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 8),
              ActionChip(
                avatar: const Icon(Icons.calendar_month_rounded, size: 18),
                label: const Text('Calendario mensual'),
                onPressed: () => _openMonthModal(context, t, byDay),
                backgroundColor: t.accent.withValues(alpha: .14),
                shape: const StadiumBorder(),
                labelStyle: TextStyle(color: t.text, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        Expanded(child: _DayList(theme: theme, items: list, onOpen: onOpen)),
      ],
    );
  }

  void _openMonthModal(
      BuildContext context,
      GridnoteTheme t,
      Map<DateTime, List<SheetRef>> byDay,
      ) {
    final monthFmt = DateFormat.yMMMM('es');
    final weekdayShort = DateFormat('E', 'es');

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        DateTime m = month;

        List<DateTime> buildGrid(DateTime base) {
          final firstWeekday = DateTime(base.year, base.month, 1).weekday;
          final daysInMonth = DateUtils.getDaysInMonth(base.year, base.month);
          final prevFill = (firstWeekday + 6) % 7;
          final out = <DateTime>[];
          for (int i = prevFill; i > 0; i--) {
            out.add(DateTime(base.year, base.month, 1).subtract(Duration(days: i)));
          }
          for (int d = 1; d <= daysInMonth; d++) {
            out.add(DateTime(base.year, base.month, d));
          }
          while (out.length % 7 != 0) {
            out.add(out.last.add(const Duration(days: 1)));
          }
          while (out.length < 42) {
            out.add(out.last.add(const Duration(days: 1)));
          }
          return out;
        }

        return StatefulBuilder(
          builder: (ctx, setS) {
            final gridDays = buildGrid(m);
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Material(
                    color: t.surface,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chevron_left),
                                onPressed: () => setS(() => m = DateTime(m.year, m.month - 1, 1)),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    monthFmt
                                        .format(m)
                                        .replaceFirstMapped(RegExp(r'^\w'), (mm) => mm[0]!.toUpperCase()),
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_right),
                                onPressed: () => setS(() => m = DateTime(m.year, m.month + 1, 1)),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: Row(
                            children: List.generate(7, (i) {
                              final wd = weekdayShort.format(DateTime(2024, 1, 1 + i));
                              return Expanded(
                                child: Center(
                                  child: Text(
                                    wd.substring(0, 3).toUpperCase(),
                                    style: TextStyle(
                                      color: t.text.withValues(alpha: .7),
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: .5,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                          child: LayoutBuilder(
                            builder: (_, c) {
                              const spacing = 6.0;
                              final gridW = c.maxWidth - spacing * 6;
                              final cell = (gridW / 7.0).clamp(34.0, 64.0);
                              final gridH = (cell * 6) + spacing * 5;

                              return SizedBox(
                                height: gridH,
                                child: GridView.builder(
                                  padding: EdgeInsets.zero,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: gridDays.length,
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 7,
                                    mainAxisSpacing: spacing,
                                    crossAxisSpacing: spacing,
                                  ),
                                  itemBuilder: (_, i) {
                                    final day = gridDays[i];
                                    final isThisMonth = day.month == m.month && day.year == m.year;
                                    final k = DateTime(day.year, day.month, day.day);
                                    final list = byDay[k] ?? const <SheetRef>[];
                                    final now = DateTime.now();
                                    final today =
                                        now.year == k.year && now.month == k.month && now.day == k.day;

                                    return InkWell(
                                      borderRadius: BorderRadius.circular(10),
                                      onTap: () {
                                        onSelectDay(k);
                                        onMonthChanged(DateTime(m.year, m.month, 1));
                                        Navigator.pop(context);
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(10),
                                          color: isThisMonth ? t.surface : t.surface.withValues(alpha: .6),
                                          border: Border.all(
                                            color: today ? t.accent : t.divider,
                                            width: today ? 1.4 : 1,
                                          ),
                                        ),
                                        padding: const EdgeInsets.all(6),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${day.day}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                color: isThisMonth ? t.text : t.text.withValues(alpha: .5),
                                              ),
                                            ),
                                            const Spacer(),
                                            if (list.isNotEmpty)
                                              const Align(
                                                alignment: Alignment.bottomRight,
                                                child: _CountDot(),
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Map<DateTime, List<SheetRef>> _groupByDay(List<SheetRef> list) {
    final map = <DateTime, List<SheetRef>>{};
    for (final s in list) {
      final k = DateTime(s.createdAt.year, s.createdAt.month, s.createdAt.day);
      (map[k] ??= []).add(s);
    }
    return map;
  }
}

class _CountDot extends StatelessWidget {
  const _CountDot();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
    );
  }
}

class _DayList extends StatelessWidget {
  const _DayList({required this.theme, required this.items, required this.onOpen});
  final GridnoteThemeController theme;
  final List<SheetRef> items;
  final Future<void> Function(SheetRef) onOpen;

  @override
  Widget build(BuildContext context) {
    final t = theme.theme;
    final fmt = DateFormat('HH:mm');

    return Container(
      color: t.surface,
      child: items.isEmpty
          ? Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Sin planillas en este día',
            style: TextStyle(color: t.text.withValues(alpha: .7))),
      )
          : ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: items.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: t.divider),
        itemBuilder: (_, i) {
          final s = items[i];
          return ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(fmt.format(s.createdAt)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => onOpen(s),
          );
        },
      ),
    );
  }
}

// ---------------- LISTA / “DRUM” ----------------

class _ScrollTab extends StatelessWidget {
  const _ScrollTab({
    required this.theme,
    required this.items,
    required this.index,
    required this.onChanged,
    required this.onOpen,
    required this.filterDay,
    required this.filterMonth,
    required this.onPickDay,
    required this.onPickMonth,
  });

  final GridnoteThemeController theme;
  final List<SheetRef> items;
  final int index;
  final ValueChanged<int> onChanged;
  final Future<void> Function(SheetRef) onOpen;

  final DateTime? filterDay;
  final DateTime? filterMonth;
  final ValueChanged<DateTime?> onPickDay;
  final ValueChanged<DateTime?> onPickMonth;

  @override
  Widget build(BuildContext context) {
    final t = theme.theme;
    final fmt = DateFormat('EEE d MMM • HH:mm', 'es');

    Widget quick(String title, String subtitle, IconData icon, VoidCallback onTap) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: t.surface,
            border: Border.all(color: t.divider),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: t.accent.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: t.accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(color: t.textFaint, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        // Filtros
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ActionChip(
              avatar: const Icon(Icons.today, size: 18),
              label: Text(
                filterDay == null ? 'Filtrar por día' : DateFormat('dd/MM/yyyy').format(filterDay!),
              ),
              onPressed: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: filterDay ?? now,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                  helpText: 'Elegí un día',
                );
                onPickDay(picked);
              },
              backgroundColor: t.surface,
            ),
            ActionChip(
              avatar: const Icon(Icons.calendar_month, size: 18),
              label: Text(
                filterMonth == null
                    ? 'Filtrar por mes'
                    : DateFormat('MMMM yyyy', 'es')
                    .format(filterMonth!)
                    .replaceFirstMapped(RegExp(r'^\w'), (m) => m[0]!.toUpperCase()),
              ),
              onPressed: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: filterMonth ?? DateTime(now.year, now.month, 1),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                  helpText: 'Elegí un mes (cualquier día)',
                );
                onPickMonth(picked == null ? null : DateTime(picked.year, picked.month, 1));
              },
              backgroundColor: t.surface,
            ),
            if (filterDay != null || filterMonth != null)
              ActionChip(
                avatar: const Icon(Icons.clear, size: 18),
                label: const Text('Quitar filtros'),
                onPressed: () {
                  onPickDay(null);
                  onPickMonth(null);
                },
                backgroundColor: t.surface,
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Drum selector
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: t.surface,
            border: Border.all(color: t.divider),
            borderRadius: BorderRadius.circular(14),
          ),
          child: items.isEmpty
              ? Padding(
            padding: const EdgeInsets.all(16),
            child: Text('No hay planillas para el filtro seleccionado.',
                style: TextStyle(color: t.text.withValues(alpha: .7))),
          )
              : SizedBox(
            height: 220,
            child: CupertinoPicker(
              itemExtent: 44,
              scrollController: FixedExtentScrollController(
                initialItem: math.min(index, items.length - 1),
              ),
              onSelectedItemChanged: onChanged,
              children: [
                for (final s in items)
                  Center(
                    child: Text(
                      '${s.title} — ${fmt.format(s.createdAt)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        Align(
          alignment: Alignment.center,
          child: FilledButton.icon(
            onPressed: items.isEmpty ? null : () => onOpen(items[math.min(index, items.length - 1)]),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Abrir'),
          ),
        ),

        const SizedBox(height: 20),
        quick('Consejo', 'Mantené pulsado para pintar celdas en el Bloc de notas', Icons.palette_outlined, () {}),
      ],
    );
  }
}
