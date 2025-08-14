// lib/screens/planillas_screen.dart
import 'package:flutter/material.dart';
import '../theme/gridnote_theme.dart';
import '../models/measurement.dart';
import '../models/sheet_meta.dart';
import 'sheet_screen.dart';

class PlanillasScreen extends StatefulWidget {
  const PlanillasScreen({super.key, required this.themeController});
  final GridnoteThemeController themeController;

  @override
  State<PlanillasScreen> createState() => _PlanillasScreenState();
}

class _PlanillasScreenState extends State<PlanillasScreen> {
  // Estado principal: múltiples planillas + filas por id
  final List<SheetMeta> _sheets = <SheetMeta>[];
  final Map<String, List<Measurement>> _rowsById = <String, List<Measurement>>{};
  String? _selectedId; // planilla activa (modo escritorio)

  @override
  void initState() {
    super.initState();
    // Seed de ejemplo (reemplazá por tu carga persistente)
    final demo = SheetMeta(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: 'Planilla 1',
      createdAt: DateTime.now(),
    );
    _sheets.add(demo);
    _rowsById[demo.id] = _sampleRows();
    _selectedId = demo.id;
  }

  List<Measurement> _sampleRows() => List.generate(
    10,
        (i) => Measurement(
      progresiva: '${i + 1}',
      ohm1m: 0.11 + i * 0.01,
      ohm3m: 0.12 + i * 0.02,
      observations: ['A', 'B', 'C', 'D', 'N'][i % 5],
      date: DateTime(2011, 4, 20 + i),
    ),
  );

  Future<void> _openOnMobile(SheetMeta meta) async {
    final rows = List<Measurement>.from(_rowsById[meta.id] ?? const <Measurement>[]);
    final result = await Navigator.push<List<Measurement>>(
      context,
      MaterialPageRoute(
        builder: (_) => SheetScreen(
          id: meta.id,
          meta: meta,
          initial: rows,
          themeController: widget.themeController,
        ),
      ),
    );
    if (result != null) {
      setState(() => _rowsById[meta.id] = result);
    }
  }

  void _selectOnDesktop(SheetMeta meta) {
    setState(() => _selectedId = meta.id);
  }

  void _createSheet({required bool push}) {
    final meta = SheetMeta(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: 'Nueva planilla',
      createdAt: DateTime.now(),
    );
    setState(() {
      _sheets.insert(0, meta);
      _rowsById[meta.id] = <Measurement>[];
    });

    if (push) {
      _openOnMobile(meta);
    } else {
      _selectOnDesktop(meta);
    }
  }

  // ---------- UI bits ----------
  Widget _pill({
    required String text,
    required VoidCallback onPressed,
    IconData icon = Icons.add_rounded,
    bool filled = true,
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
  }) {
    final t = widget.themeController.theme;
    final bg = filled ? t.accent : t.surface;
    final fg = filled ? Colors.white : t.text;
    return Material(
      color: bg,
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: padding,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: fg),
              const SizedBox(width: 8),
              Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w700, letterSpacing: .2)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ghostSheet(GridnoteTheme t) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.divider),
      ),
      child: CustomPaint(painter: _GhostLinesPainter(t.divider.withValues(alpha: .55))),
    );
  }

  Widget _welcome(GridnoteTheme t) {
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: t.divider),
        boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 14, offset: Offset(0, 4))],
      ),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insert_drive_file_rounded, size: 52, color: t.text.withValues(alpha: .28)),
          const SizedBox(height: 16),
          Text('Bienvenido 👋', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: t.text)),
          const SizedBox(height: 8),
          Text('Creá una planilla nueva o importá un archivo CSV.', textAlign: TextAlign.center, style: TextStyle(color: t.textFaint)),
          const SizedBox(height: 18),
          _pill(text: 'Crear planilla', onPressed: () => _createSheet(push: true)),
          const SizedBox(height: 12),
          TextButton(onPressed: () {}, child: const Text('Importar CSV')),
        ],
      ),
    );
  }

  Widget _sheetTile(BuildContext context, SheetMeta meta, {VoidCallback? onTap}) {
    final t = widget.themeController.theme;
    return ListTile(
      leading: const Icon(Icons.grid_on_rounded),
      title: Text(meta.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        'Creada: ${meta.createdAt.toLocal()}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: t.textFaint, fontSize: 12),
      ),
      onTap: onTap,
    );
  }

  // ---------------- BUILD ----------------
  @override
  Widget build(BuildContext context) {
    final t = widget.themeController.theme;
    final table = GridnoteTableStyle.from(t);

    return LayoutBuilder(builder: (ctx, c) {
      final compact = c.maxWidth < 900;

      // ===== Mobile / Compact =====
      if (compact) {
        return Scaffold(
          backgroundColor: t.scaffold,
          appBar: AppBar(
            title: const Text('Gridnote', style: TextStyle(fontWeight: FontWeight.w800)),
            backgroundColor: t.scaffold,
            elevation: 0,
            centerTitle: false,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _pill(text: 'Nueva planilla', onPressed: () => _createSheet(push: true)),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
            children: [
              Row(
                children: [
                  Icon(Icons.history, color: t.text.withValues(alpha: .9)),
                  const SizedBox(width: 10),
                  Text('Recientes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: t.text)),
                ],
              ),
              const SizedBox(height: 12),
              if (_sheets.isEmpty) ...[
                _ghostSheet(t),
                const SizedBox(height: 18),
                _welcome(t),
              ] else ...[
                for (final meta in _sheets) _sheetTile(context, meta, onTap: () => _openOnMobile(meta)),
              ],
            ],
          ),
        );
      }

      // ===== Desktop / Tablet (two panes) =====
      final selected = _sheets.firstWhere(
            (m) => m.id == _selectedId,
        orElse: () => _sheets.isEmpty ? SheetMeta(id: '', name: '') : _sheets.first,
      );
      final hasSelection = _sheets.isNotEmpty && selected.id.isNotEmpty;

      return Scaffold(
        backgroundColor: t.scaffold,
        body: SafeArea(
          child: Row(
            children: [
              // Sidebar
              Container(
                width: 300,
                decoration: BoxDecoration(
                  color: t.surface,
                  border: Border(right: BorderSide(color: table.gridLine)),
                ),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  children: [
                    Text('Gridnote', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: t.text)),
                    const SizedBox(height: 16),
                    _pill(text: 'Nueva planilla', onPressed: () => _createSheet(push: false)),
                    const SizedBox(height: 18),
                    Text('Recientes', style: TextStyle(fontWeight: FontWeight.w700, color: t.text)),
                    const SizedBox(height: 8),
                    if (_sheets.isEmpty)
                      ListTile(
                        leading: const Icon(Icons.inbox_outlined),
                        title: Text('Sin planillas', style: TextStyle(color: t.textFaint)),
                      )
                    else
                      ..._sheets.map(
                            (m) => Container(
                          decoration: BoxDecoration(
                            color: m.id == _selectedId ? t.accent.withOpacity(.08) : null,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: _sheetTile(context, m, onTap: () => _selectOnDesktop(m)),
                        ),
                      ),
                  ],
                ),
              ),

              // Content area
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top bar
                    Container(
                      height: 64,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: t.scaffold,
                        border: Border(bottom: BorderSide(color: table.gridLine)),
                      ),
                      child: Row(
                        children: [
                          Text('Planillas', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: t.text)),
                          const Spacer(),
                          IconButton(tooltip: 'Más', onPressed: () {}, icon: const Icon(Icons.more_horiz_rounded)),
                          const SizedBox(width: 8),
                          _pill(text: 'Compartir', icon: Icons.ios_share_rounded, onPressed: () {}, filled: false),
                        ],
                      ),
                    ),

                    // Canvas
                    Expanded(
                      child: hasSelection
                          ? SheetScreen(
                        key: ValueKey(_selectedId), // fuerza rebuild al cambiar selección
                        id: selected.id,
                        meta: selected,
                        initial: _rowsById[selected.id] ?? const <Measurement>[],
                        themeController: widget.themeController,
                      )
                          : ListView(
                        padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
                        children: [
                          _ghostSheet(t),
                          const SizedBox(height: 18),
                          _welcome(t),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

// ---------- Painters ----------
class _GhostLinesPainter extends CustomPainter {
  _GhostLinesPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(20));
    canvas.drawRRect(r, p);

    final rowH = size.height / 4;
    for (int i = 1; i <= 3; i++) {
      final y = rowH * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p..color = color.withValues(alpha: .5));
    }
    final colW = size.width / 3;
    canvas.drawLine(Offset(colW, 0), Offset(colW, rowH), p..color = color.withValues(alpha: .5));
    canvas.drawLine(Offset(colW * 2, 0), Offset(colW * 2, rowH), p);
  }

  @override
  bool shouldRepaint(_GhostLinesPainter oldDelegate) => false;
}
