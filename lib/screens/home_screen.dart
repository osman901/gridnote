import 'dart:ui' show ImageFilter;
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../theme/gridnote_theme.dart';
import '../models/measurement.dart';
import '../models/sheet_meta.dart';
import '../services/sheet_registry.dart';

// Pantallas
import 'measurements_screen.dart';
import 'import_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'browse_sheets_screen.dart';

// Permisos
import '../services/permissions_service.dart';
import '../constants/perf_flags.dart';

// Telemetría simple
import '../services/usage_analytics.dart';

// IA
import '../services/ai_service.dart';

// Galería rápida + IA de rendimiento
import '../widgets/smart_home_menu.dart';
import '../services/smart_turbo.dart';
import '../services/photo_store.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.theme});
  final GridnoteThemeController theme;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GridnoteTheme get t => widget.theme.theme;
  bool _autoPushed = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => PermissionsService.instance.requestStartupPermissions());
    SmartTurbo.registerPhotosLoader(() => PhotoStore.listRecentGlobal(limit: 120));
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _autoPushed) return;
      _autoPushed = true;
      UsageAnalytics.instance.bump('home_autopush_planillas');
      await _openSheetsBrowser();
    });
  }

  Future<void> _testAI() async {
    UsageAnalytics.instance.bump('home_test_ai');
    try {
      final ans = await AiService.instance.ask('Decí "ok" si me leés.');
      if (!mounted) return;
      _snack(ans);
    } catch (e) {
      if (!mounted) return;
      _snack('IA error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: t.scaffold,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: t.scaffold,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 16,
        title: Text(
          'Gridnote',
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: t.text, fontWeight: FontWeight.w800, fontSize: 28, letterSpacing: -0.5),
        ),
        actions: [
          IconButton(
            tooltip: 'Probar IA',
            icon: const Icon(CupertinoIcons.sparkles),
            onPressed: _testAI,
          ),
          IconButton(
            tooltip: 'Planillas',
            icon: const Icon(CupertinoIcons.square_stack_3d_up),
            onPressed: _openSheetsBrowser,
          ),
          IconButton(
            tooltip: 'Claro / Oscuro',
            onPressed: widget.theme.toggleDark,
            icon: const Icon(CupertinoIcons.moon_stars),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final isWide = c.maxWidth >= 640;
            final crossAxisCount = isWide ? 3 : 2;
            final cardHeight = isWide ? 140.0 : 164.0;

            final screenW = (c.maxWidth.isFinite && c.maxWidth > 0) ? c.maxWidth : MediaQuery.sizeOf(context).width;
            const spacing = 12.0;
            const hPadding = 32.0;
            final available = (screenW - hPadding - spacing * (crossAxisCount - 1)).clamp(1.0, double.infinity).toDouble();
            final itemWidth = available / crossAxisCount;
            final aspect = (itemWidth / cardHeight).clamp(0.7, 3.5).toDouble();

            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  sliver: SliverToBoxAdapter(
                    child: _HeaderCard(theme: t, onOpen: _openSheetsBrowser),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  sliver: SliverToBoxAdapter(
                    child: SizedBox(
                      height: 260,
                      child: _Surface(
                        theme: t,
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                        child: SmartHomeMenu(
                          theme: widget.theme,
                          photosLoader: () => PhotoStore.listRecentGlobal(limit: 120),
                          onOpenPhoto: (File f) {
                            UsageAnalytics.instance.bump('home_gallery_open_photo');
                            OpenFilex.open(f.path);
                          },
                          maxItems: 120,
                        ),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: spacing,
                      crossAxisSpacing: spacing,
                      childAspectRatio: aspect,
                    ),
                    delegate: SliverChildListDelegate.fixed([
                      _HomeTile(
                        theme: t,
                        height: cardHeight,
                        leading: CupertinoIcons.square_grid_2x2,
                        title: 'Planillas',
                        subtitle: 'Explorar y crear',
                        onTap: _openSheetsBrowser,
                      ),
                      _HomeTile(
                        theme: t,
                        height: cardHeight,
                        leading: CupertinoIcons.square_arrow_down,
                        title: 'Importar',
                        subtitle: 'CSV/XLSX a planilla',
                        onTap: _openImport,
                      ),
                      _HomeTile(
                        theme: t,
                        height: cardHeight,
                        leading: CupertinoIcons.chart_bar_alt_fill,
                        title: 'Reportes',
                        subtitle: 'PDF / XLSX',
                        onTap: _openReports,
                      ),
                      _HomeTile(
                        theme: t,
                        height: cardHeight,
                        leading: CupertinoIcons.gear_alt_fill,
                        title: 'Ajustes',
                        subtitle: 'Preferencias y temas',
                        onTap: () {
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
                        },
                      ),
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // --------- Navegación ----------
  Future<void> _openImport() async {
    final meta = await _selectSheetFromList();
    if (!mounted || meta == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ImportScreen(themeController: widget.theme, meta: meta),
    ));
  }

  Future<void> _openReports() async {
    final meta = await _selectSheetFromList();
    if (!mounted || meta == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ReportsScreen(themeController: widget.theme, meta: meta),
    ));
  }

  Future<void> _openSheetsBrowser() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BrowseSheetsScreen(theme: widget.theme)),
    );
  }

  /// Selector simple (bottom sheet) para elegir planilla.
  Future<SheetMeta?> _selectSheetFromList() async {
    final metas = await SheetRegistry.instance.getAllSorted();
    if (!mounted) return null;
    return showModalBottomSheet<SheetMeta>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: t.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * .6,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemBuilder: (ctx, i) {
              final m = metas[i];
              final when = m.createdAt;
              final dd =
                  '${when.day.toString().padLeft(2, '0')}/${when.month.toString().padLeft(2, '0')}/${when.year}';
              return ListTile(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                tileColor: t.scaffold,
                onTap: () => Navigator.of(ctx).pop(m),
                leading: const Icon(CupertinoIcons.doc_text),
                title: Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('Mod.: $dd  •  ID: ${m.id}',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemCount: metas.length,
          ),
        );
      },
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.theme, required this.onOpen});
  final GridnoteTheme theme;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      theme: theme,
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (_, c) {
          final isNarrow = c.maxWidth < 360;
          final title = Text(
            'Continuar donde quedaste',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: theme.text, fontWeight: FontWeight.w700, fontSize: 16),
          );
          final button = FilledButton.tonal(
            onPressed: onOpen,
            style: const ButtonStyle(
              shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),
            ),
            child: const Text('Abrir'),
          );
          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  _IconBadge(color: theme.accent, icon: CupertinoIcons.doc_text),
                  const SizedBox(width: 12),
                  Expanded(child: title),
                ]),
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: button),
              ],
            );
          }
          return Row(
            children: [
              _IconBadge(color: theme.accent, icon: CupertinoIcons.doc_text),
              const SizedBox(width: 12),
              Expanded(child: title),
              const SizedBox(width: 8),
              ConstrainedBox(constraints: const BoxConstraints(minWidth: 88, maxWidth: 140), child: button),
            ],
          );
        },
      ),
    );
  }
}

class _HomeTile extends StatelessWidget {
  const _HomeTile({
    required this.theme,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.height,
  });

  final GridnoteTheme theme;
  final IconData leading;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      theme: theme,
      padding: const EdgeInsets.all(16),
      constraints: BoxConstraints(minHeight: height),
      tap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconBadge(color: theme.accent, icon: leading),
          const SizedBox(height: 12),
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.text, fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 4),
          Expanded(child: Text(subtitle, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textFaint, fontSize: 13, height: 1.25))),
          Align(alignment: Alignment.bottomRight, child: Icon(CupertinoIcons.chevron_right, size: 18, color: theme.textFaint)),
        ],
      ),
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({required this.theme, this.child, this.padding, this.tap, this.constraints});

  final GridnoteTheme theme;
  final Widget? child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? tap;
  final BoxConstraints? constraints;

  static const _kBorderRadius = BorderRadius.all(Radius.circular(20));

  @override
  Widget build(BuildContext context) {
    final card = kLowSpec
        ? Container(
      constraints: constraints,
      padding: padding,
      decoration: BoxDecoration(color: theme.surface, borderRadius: _kBorderRadius, border: Border.all(color: theme.divider)),
      child: child,
    )
        : AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      constraints: constraints,
      padding: padding,
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: _kBorderRadius,
        border: Border.all(color: theme.divider),
        boxShadow: const [BoxShadow(blurRadius: 12, offset: Offset(0, 6), color: Color(0x12000000))],
      ),
      child: child,
    );
    if (tap == null) return card;
    return Material(type: MaterialType.transparency, child: InkWell(onTap: tap, borderRadius: _kBorderRadius, child: card));
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.color, required this.icon});
  final Color color;
  final IconData icon;

  static const double _kSize = 44;
  static const _kBadgeRadius = BorderRadius.all(Radius.circular(14));

  @override
  Widget build(BuildContext context) {
    if (kLowSpec) {
      return Container(
        width: _kSize,
        height: _kSize,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: _kBadgeRadius,
          border: Border.all(color: Colors.white.withValues(alpha: .10), width: 1),
        ),
        child: Center(child: Icon(icon, size: 22, color: color)),
      );
    }

    final glass = color.withValues(alpha: .16);
    return SizedBox(
      width: _kSize,
      height: _kSize,
      child: ClipRRect(
        borderRadius: _kBadgeRadius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            BackdropFilter(filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6), child: const SizedBox()),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [glass, const Color(0x22FFFFFF)]),
                border: Border.all(color: Colors.white.withValues(alpha: .22), width: 1),
                boxShadow: [BoxShadow(color: color.withValues(alpha: .28), blurRadius: 16, spreadRadius: -4, offset: const Offset(0, 6))],
              ),
            ),
            Align(
              alignment: Alignment.topLeft,
              child: Container(
                width: _kSize * .55,
                height: _kSize * .40,
                decoration: const BoxDecoration(color: Color.fromRGBO(255, 255, 255, .18), borderRadius: BorderRadius.only(bottomRight: Radius.circular(18))),
              ),
            ),
            Center(child: Icon(icon, size: 22, color: color)),
          ],
        ),
      ),
    );
  }
}
