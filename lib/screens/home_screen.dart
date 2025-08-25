// lib/screens/home_screen.dart
import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';

import '../theme/gridnote_theme.dart';
import '../models/measurement.dart';
import '../models/sheet_meta.dart';
import '../services/sheet_registry.dart';
import '../widgets/drum_picker.dart';

// NUEVOS: pantallas
import 'measurements_screen.dart';
import 'photos_screen.dart';
import 'location_screen.dart';
import 'import_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.theme});
  final GridnoteThemeController theme;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GridnoteTheme get t => widget.theme.theme;

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
          style: TextStyle(
            color: t.text,
            fontWeight: FontWeight.w800,
            fontSize: 28,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Planillas (tambor)',
            icon: const Icon(CupertinoIcons.square_stack_3d_up),
            onPressed: _openSheetDrum,
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

            final screenW =
            (c.maxWidth.isFinite && c.maxWidth > 0) ? c.maxWidth : MediaQuery.sizeOf(context).width;
            const spacing = 12.0;
            const hPadding = 32.0; // 16 + 16 del SliverPadding L/R
            final available =
            (screenW - hPadding - spacing * (crossAxisCount - 1)).clamp(1.0, double.infinity).toDouble();
            final itemWidth = available / crossAxisCount;
            final aspect = (itemWidth / cardHeight).clamp(0.7, 3.5).toDouble();

            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  sliver: SliverToBoxAdapter(
                    child: _HeaderCard(theme: t, onOpen: _openSheetDrum),
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
                        subtitle: 'Abrir con selector “tambor”',
                        onTap: _openSheetDrum,
                      ),
                      _HomeTile(
                        theme: t,
                        height: cardHeight,
                        leading: CupertinoIcons.photo_on_rectangle,
                        title: 'Fotos',
                        subtitle: 'Asociadas a filas',
                        onTap: _openPhotos,
                      ),
                      _HomeTile(
                        theme: t,
                        height: cardHeight,
                        leading: CupertinoIcons.location,
                        title: 'Ubicaciones',
                        subtitle: 'Accesos rápidos a Maps',
                        onTap: _openLocation,
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
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const SettingsScreen()),
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: _QuickActionsDial(
        color: t.accent,
        onNew: _openSheet,
        onContinue: _openSheetDrum,
        onImport: _openImport,
        onScan: () => _snack('Escanear texto/foto (próximamente)'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // --------- Helpers de navegación ----------
  Future<SheetMeta?> _pickSheet() async {
    final items = await SheetRegistry.instance.getAllSorted();
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // más reciente primero
    if (!mounted) return null;

    final selected = await showSheetDrumPicker(
      context: context,
      items: items,
      title: 'Planillas',
      accent: t.accent,
      textColor: t.text,
      surface: t.surface,
      divider: t.divider,
      onCreateNew: () => SheetRegistry.instance.create(name: 'Planilla nueva'),
      initial: items.isNotEmpty ? items.first : null,
      subtitleBuilder: (m) {
        final when = m.createdAt;
        final dd =
            '${when.day.toString().padLeft(2, '0')}/${when.month.toString().padLeft(2, '0')}/${when.year}';
        return 'Modificado: $dd';
      },
    );
    return selected;
  }

  Future<void> _openPhotos() async {
    final meta = await _pickSheet();
    if (!mounted || meta == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PhotosScreen(themeController: widget.theme, meta: meta),
    ));
  }

  Future<void> _openLocation() async {
    final meta = await _pickSheet();
    if (!mounted || meta == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LocationScreen(themeController: widget.theme, meta: meta),
    ));
  }

  Future<void> _openImport() async {
    final meta = await _pickSheet();
    if (!mounted || meta == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ImportScreen(themeController: widget.theme, meta: meta),
    ));
  }

  Future<void> _openReports() async {
    final meta = await _pickSheet();
    if (!mounted || meta == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ReportsScreen(themeController: widget.theme, meta: meta),
    ));
  }

  Future<void> _openSheet({bool continueLast = false}) async {
    final meta = await SheetRegistry.instance.create(
      name: continueLast ? 'Última planilla' : 'Planilla nueva',
    );
    if (!mounted) return;
    Navigator.of(context).push(_FadeScaleRoute(
      child: MeasurementScreen(
        id: meta.id,
        meta: meta,
        initial: const <Measurement>[],
        themeController: widget.theme,
      ),
    ));
  }

  Future<void> _openSheetDrum() async {
    final selected = await _pickSheet();
    if (!mounted || selected == null) return;
    await SheetRegistry.instance.touch(selected);
    if (!mounted) return;
    Navigator.of(context).push(_FadeScaleRoute(
      child: MeasurementScreen(
        id: selected.id,
        meta: selected,
        initial: const <Measurement>[],
        themeController: widget.theme,
      ),
    ));
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
          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _IconBadge(color: theme.accent, icon: CupertinoIcons.doc_text),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Continuar donde quedaste',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.text,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed: onOpen,
                    style: const ButtonStyle(
                      shape: WidgetStatePropertyAll(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                    ),
                    child: const Text('Abrir'),
                  ),
                ),
              ],
            );
          }
          return Row(
            children: [
              _IconBadge(color: theme.accent, icon: CupertinoIcons.doc_text),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Continuar donde quedaste',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: theme.text, fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                fit: FlexFit.loose,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 88, maxWidth: 140),
                  child: FilledButton.tonal(
                    onPressed: onOpen,
                    style: const ButtonStyle(
                      padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
                      shape: WidgetStatePropertyAll(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                    ),
                    child: const Text('Abrir', overflow: TextOverflow.ellipsis),
                  ),
                ),
              ),
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
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: theme.text, fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              subtitle,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: theme.textFaint, fontSize: 13, height: 1.25),
            ),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: Icon(CupertinoIcons.chevron_right, size: 18, color: theme.textFaint),
          ),
        ],
      ),
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({
    required this.theme,
    this.child,
    this.padding,
    this.tap,
    this.constraints,
  });

  final GridnoteTheme theme;
  final Widget? child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? tap;
  final BoxConstraints? constraints;

  static const _kBorderRadius = BorderRadius.all(Radius.circular(20));

  @override
  Widget build(BuildContext context) {
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      constraints: constraints,
      padding: padding,
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: _kBorderRadius,
        border: Border.all(color: theme.divider),
        boxShadow: const [
          BoxShadow(blurRadius: 12, offset: Offset(0, 6), color: Color(0x12000000)),
        ],
      ),
      child: child,
    );
    if (tap == null) return card;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: tap,
        borderRadius: _kBorderRadius,
        child: card,
      ),
    );
  }
}

/// Badge vidrioso (glassmorphism) estilo iOS 16+
class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.color, required this.icon});
  final Color color;
  final IconData icon;

  static const double _kSize = 44;
  static const _kBadgeRadius = BorderRadius.all(Radius.circular(14));

  @override
  Widget build(BuildContext context) {
    final glass = color.withValues(alpha: .16);
    return SizedBox(
      width: _kSize,
      height: _kSize,
      child: ClipRRect(
        borderRadius: _kBadgeRadius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Blur más barato
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6), // antes 12
              child: const SizedBox(),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [glass, const Color(0x22FFFFFF)],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: .22), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: .28),
                    blurRadius: 16,
                    spreadRadius: -4,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.topLeft,
              child: Container(
                width: _kSize * .55,
                height: _kSize * .40,
                decoration: const BoxDecoration(
                  color: Color.fromRGBO(255, 255, 255, .18),
                  borderRadius: BorderRadius.only(bottomRight: Radius.circular(18)),
                ),
              ),
            ),
            Center(child: Icon(icon, size: 22, color: color)),
          ],
        ),
      ),
    );
  }
}

class _QuickActionsDial extends StatelessWidget {
  const _QuickActionsDial({
    required this.color,
    required this.onNew,
    required this.onContinue,
    required this.onImport,
    required this.onScan,
  });

  final Color color;
  final VoidCallback onNew;
  final VoidCallback onContinue;
  final VoidCallback onImport;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return SpeedDial(
      icon: CupertinoIcons.add,
      activeIcon: CupertinoIcons.xmark,
      backgroundColor: color,
      foregroundColor: Colors.black,
      overlayColor: Colors.black,
      overlayOpacity: 0.25,
      spacing: 6,
      spaceBetweenChildren: 6,
      childrenButtonSize: const Size(54, 54),
      children: [
        SpeedDialChild(
          label: 'Escanear texto/foto',
          child: const Icon(CupertinoIcons.doc_text_viewfinder),
          onTap: onScan,
        ),
        SpeedDialChild(
          label: 'Importar',
          child: const Icon(CupertinoIcons.square_arrow_down),
          onTap: onImport,
        ),
        SpeedDialChild(
          label: 'Continuar (tambor)',
          child: const Icon(CupertinoIcons.square_stack_3d_up),
          onTap: onContinue,
        ),
        SpeedDialChild(
          label: 'Nueva planilla',
          child: const Icon(CupertinoIcons.square_grid_2x2),
          onTap: onNew,
        ),
      ],
    );
  }
}

class _FadeScaleRoute extends PageRouteBuilder {
  _FadeScaleRoute({required Widget child})
      : super(
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (_, __, ___) => child,
    transitionsBuilder: (_, anim, __, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: .98, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}
