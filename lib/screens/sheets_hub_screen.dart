import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/sheet_meta.dart';
import '../services/sheet_registry.dart';
import '../theme/gridnote_theme.dart';
import 'measurements_screen.dart';

class SheetsHubScreen extends StatefulWidget {
  const SheetsHubScreen({super.key, required this.theme});
  final GridnoteThemeController theme;

  @override
  State<SheetsHubScreen> createState() => _SheetsHubScreenState();
}

class _SheetsHubScreenState extends State<SheetsHubScreen> {
  GridnoteTheme get t => widget.theme.theme;

  final TextEditingController _search = TextEditingController();
  List<SheetMeta> _all = const [];
  bool _loading = true;

  // Calendar
  DateTime _visibleMonth =
  DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _load();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await SheetRegistry.instance.getAllSorted();
    // Latest first
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (!mounted) return;
    setState(() {
      _all = list;
      _loading = false;
    });
  }

  // -------- Helpers --------
  List<SheetMeta> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _all;
    return _all.where((m) {
      final name = m.name.toLowerCase();
      final id = m.id.toLowerCase();
      return name.contains(q) || id.contains(q);
    }).toList();
  }

  static DateTime _dateOnly(DateTime d) =>
      DateTime(d.year, d.month, d.day);

  Map<DateTime, int> _countByDayForMonth(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final last = DateTime(month.year, month.month + 1, 0);
    final map = <DateTime, int>{};
    for (final m in _all) {
      final d = _dateOnly(m.createdAt);
      if (d.isBefore(first) || d.isAfter(last)) continue;
      map[d] = (map[d] ?? 0) + 1;
    }
    return map;
  }

  List<SheetMeta> _byDay(DateTime day) {
    final only = _dateOnly(day);
    return _all
        .where((m) => _dateOnly(m.createdAt) == only)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> _openSheet(SheetMeta meta) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MeasurementScreen(
          id: meta.id,
          meta: meta,
          initial: const [],
          themeController: widget.theme,
        ),
      ),
    );
    if (!mounted) return;
    // Refresh after potential changes
    _load();
  }

  // -------- UI --------
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: t.scaffold,
        appBar: AppBar(
          backgroundColor: t.surface,
          title: const Text('Planillas'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(92),
            child: Column(
              children: [
                Padding(
                  padding:
                  const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: _SearchField(
                    controller: _search,
                    hint: 'Buscar planilla por nombre o ID…',
                    theme: t,
                  ),
                ),
                const TabBar(
                  tabs: [
                    Tab(text: 'Lista'),
                    Tab(text: 'Calendario'),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : (_search.text.trim().isNotEmpty
        // Search mode (replaces tabs)
            ? _ResultsList(
          items: _filtered,
          theme: t,
          onOpen: _openSheet,
        )
        // Normal tabs
            : TabBarView(
          children: [
            _ResultsList(
                items: _all,
                theme: t,
                onOpen: _openSheet),
            _CalendarView(
              theme: t,
              month: _visibleMonth,
              selected: _selectedDay,
              counts:
              _countByDayForMonth(_visibleMonth),
              onPrev: () => setState(() {
                _visibleMonth = DateTime(
                    _visibleMonth.year,
                    _visibleMonth.month - 1);
                _selectedDay = null;
              }),
              onNext: () => setState(() {
                _visibleMonth = DateTime(
                    _visibleMonth.year,
                    _visibleMonth.month + 1);
                _selectedDay = null;
              }),
              onPick: (d) => setState(() => _selectedDay = d),
              bottom: _DayList(
                day: _selectedDay,
                items: _selectedDay == null
                    ? const []
                    : _byDay(_selectedDay!),
                theme: t,
                onOpen: _openSheet,
              ),
            ),
          ],
        )),
      ),
    );
  }
}

// ---------- Widgets ----------

class _SearchField extends StatelessWidget {
  const _SearchField(
      {required this.controller, required this.hint, required this.theme});
  final TextEditingController controller;
  final String hint;
  final GridnoteTheme theme;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: TextStyle(color: theme.text),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(CupertinoIcons.search),
        filled: true,
        fillColor: theme.surface,
        contentPadding:
        const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.divider),
        ),
      ),
    );
  }
}

class _ResultsList extends StatelessWidget {
  const _ResultsList(
      {required this.items, required this.theme, required this.onOpen});
  final List<SheetMeta> items;
  final GridnoteTheme theme;
  final void Function(SheetMeta) onOpen;

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text('Sin resultados',
            style: TextStyle(color: theme.text.withValues(alpha: .7))),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: items.length,
      separatorBuilder: (_, __) =>
      const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final m = items[i];
        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => onOpen(m),
          child: Ink(
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.divider),
            ),
            child: ListTile(
              title: Text(m.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              subtitle: Text('Modificado: ${_fmt(m.createdAt)}'),
              trailing: const Icon(
                  CupertinoIcons.chevron_right),
            ),
          ),
        );
      },
    );
  }
}

class _CalendarView extends StatelessWidget {
  const _CalendarView({
    required this.theme,
    required this.month,
    required this.selected,
    required this.counts,
    required this.onPrev,
    required this.onNext,
    required this.onPick,
    required this.bottom,
  });

  final GridnoteTheme theme;
  final DateTime month;
  final DateTime? selected;
  final Map<DateTime, int> counts; // day -> count
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onPick;
  final Widget bottom;

  String _monthTitle(DateTime m) {
    const names = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre'
    ];
    return '${names[m.month - 1]} ${m.year}';
  }

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth =
        DateTime(month.year, month.month + 1, 0).day;
    // Monday=1 ... Sunday=7. We want grid to start on Monday (1).
    final leadingBlanks = (first.weekday + 6) % 7;

    final cells = <Widget>[];
    // Header
    final wd = [
      'LU',
      'MA',
      'MI',
      'JU',
      'VI',
      'SA',
      'DO'
    ];
    cells.addAll(wd.map((e) => Center(
      child: Text(e,
          style: TextStyle(
              fontWeight: FontWeight.w700,
              color: theme.text)),
    )));

    // Days
    for (var i = 0; i < leadingBlanks; i++) {
      cells.add(const SizedBox());
    }
    for (var d = 1; d <= daysInMonth; d++) {
      final day = DateTime(month.year, month.month, d);
      final isSelected = selected != null &&
          day.year == selected!.year &&
          day.month == selected!.month &&
          day.day == selected!.day;
      final count =
          counts[DateTime(day.year, day.month, day.day)] ?? 0;

      cells.add(
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => onPick(day),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.accent.withValues(alpha: .25)
                  : null,
              borderRadius: BorderRadius.circular(10),
            ),
            padding:
            const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisAlignment:
              MainAxisAlignment.center,
              children: [
                Text('$d',
                    style:
                    TextStyle(color: theme.text)),
                const SizedBox(height: 4),
                if (count > 0)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: theme.accent,
                      borderRadius:
                      BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    // Complete last row to keep grid aligned
    final totalCells = wd.length + leadingBlanks + daysInMonth;
    final remainder = totalCells % 7;
    if (remainder != 0) {
      for (var i = 0; i < 7 - remainder; i++) {
        cells.add(const SizedBox());
      }
    }

    return Column(
      children: [
        Padding(
          padding:
          const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(
            children: [
              IconButton.filledTonal(
                onPressed: onPrev,
                icon: const Icon(
                    CupertinoIcons.chevron_left),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Center(
                  child: Text(
                    _monthTitle(month),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: onNext,
                icon: const Icon(
                    CupertinoIcons.chevron_right),
              ),
            ],
          ),
        ),
        Padding(
          padding:
          const EdgeInsets.symmetric(horizontal: 12),
          child: Container(
            decoration: BoxDecoration(
              color: theme.surface,
              border:
              Border.all(color: theme.divider),
              borderRadius:
              BorderRadius.circular(14),
            ),
            padding:
            const EdgeInsets.fromLTRB(8, 8, 8, 12),
            child: GridView.count(
              shrinkWrap: true,
              physics:
              const NeverScrollableScrollPhysics(),
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              children: cells,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: bottom),
      ],
    );
  }
}

class _DayList extends StatelessWidget {
  const _DayList(
      {required this.day,
        required this.items,
        required this.theme,
        required this.onOpen});
  final DateTime? day;
  final List<SheetMeta> items;
  final GridnoteTheme theme;
  final void Function(SheetMeta) onOpen;

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    if (day == null) {
      return Center(
        child: Text('Elegí un día',
            style: TextStyle(
                color: theme.text.withValues(alpha: .7))),
      );
    }
    if (items.isEmpty) {
      return Center(
        child: Text('Sin planillas el ${_fmt(day!)}',
            style: TextStyle(
                color: theme.text.withValues(alpha: .7))),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: items.length,
      separatorBuilder: (_, __) =>
      const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final m = items[i];
        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => onOpen(m),
          child: Ink(
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.divider),
            ),
            child: ListTile(
              title: Text(m.name,
                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis),
              subtitle: Text(
                  'Modificado: ${_fmt(m.createdAt)}'),
              trailing: const Icon(
                  CupertinoIcons.chevron_right),
            ),
          ),
        );
      },
    );
  }
}
