// lib/screens/measurements_screen.dart
import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../models/measurement.dart';
import '../models/sheet_meta.dart';
import '../models/share_option.dart';
import '../theme/gridnote_theme.dart';
import '../widgets/measurement_pluto_grid.dart';
import '../state/measurement_async_provider.dart';
import '../state/measurement_repository.dart';
import '../services/xlsx_export_service.dart';
import '../services/email_share_service.dart';
import '../services/location_service.dart';
import '../services/usage_analytics.dart';
import '../services/sheet_registry.dart';
import '../widgets/drum_picker.dart';
import '../providers/settings_provider.dart';
import '../constants/app_styles.dart';
import '../routing/fade_scale_route.dart';

final xlsxServiceProvider = Provider<XlsxExportService>((_) => XlsxExportService());
final emailShareServiceProvider = Provider<EmailShareService>((_) => const EmailShareService());
final locationServiceProvider = Provider<LocationService>((_) => LocationService.instance);
final settingsServiceProvider = Provider<SettingsService>((_) => SettingsService());

class MeasurementScreen extends ConsumerStatefulWidget {
  const MeasurementScreen({
    super.key,
    required this.id,
    required this.meta,
    required this.initial,
    required this.themeController,
    this.onTitleChanged,
  });

  final String id;
  final SheetMeta meta;
  final List<Measurement> initial;
  final GridnoteThemeController themeController;
  final ValueChanged<String>? onTitleChanged;

  @override
  ConsumerState<MeasurementScreen> createState() => _MeasurementScreenState();
}

class _MeasurementScreenState extends ConsumerState<MeasurementScreen> {
  bool _editingTitle = false;
  bool _isLoading = false;
  bool _aiEnabled = true;

  late final TextEditingController _titleCtrl = TextEditingController(text: widget.meta.name);

  String? _defaultEmail;
  double? _lat;
  double? _lng;
  String? _author; // autor de la planilla

  final _gridCtrl = MeasurementGridController();

  String _fmtDate(DateTime d) => DateFormat("d 'de' MMM. 'de' y", 'es').format(d);

  @override
  void initState() {
    super.initState();
    _author = widget.meta.author;
    _loadDefaultEmail();
    _loadSavedLocation();
    _loadAiPref();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cur = ref.read(measurementAsyncProvider(widget.meta.id));
      final hasData = cur.hasValue && (cur.value?.isNotEmpty ?? false);
      if (!hasData && widget.initial.isNotEmpty && mounted) {
        ref.read(measurementAsyncProvider(widget.meta.id).notifier).setAll(widget.initial);
      }
      unawaited(SheetRegistry.instance.touch(widget.meta));
    });
  }

  @override
  void didUpdateWidget(covariant MeasurementScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.meta.name != widget.meta.name) {
      _titleCtrl.text = widget.meta.name;
    }
    if (oldWidget.meta.author != widget.meta.author) {
      _author = widget.meta.author;
    }
  }

  @override
  void dispose() {
    // Limpia banners que pudieran quedar visibles
    ScaffoldMessenger.maybeOf(context)?.clearMaterialBanners();
    _titleCtrl.dispose();
    super.dispose();
  }

  // ---------------- Avisos ----------------
  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // Banner superior (no tapa la grilla)
  void _notifyTop(
      String msg, {
        IconData icon = Icons.check_circle,
        Duration duration = const Duration(milliseconds: 1500),
      }) {
    if (!mounted) return;
    final t = widget.themeController.theme;
    final messenger = ScaffoldMessenger.of(context);

    messenger.clearMaterialBanners();
    messenger.showMaterialBanner(
      MaterialBanner(
        backgroundColor: t.surface,
        leading: Icon(icon, color: t.accent),
        content: Text(
          msg,
          style: TextStyle(color: t.text, fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton(
            onPressed: messenger.removeCurrentMaterialBanner,
            child: const Text('OK'),
          ),
        ],
      ),
    );

    Future.delayed(duration, () {
      if (!mounted) return;
      messenger.removeCurrentMaterialBanner();
    });
  }

  void _logError(Object error, [StackTrace? st]) {
    debugPrint('MeasurementScreen error: $error');
    if (st != null) debugPrint(st.toString());
  }

  Future<void> _withBusy(Future<void> Function() op) async {
    if (!mounted) {
      await op();
      return;
    }
    setState(() => _isLoading = true);
    try {
      await op();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ===== SettingsService (centralizado) =====
  SettingsService get _settings => ref.read(settingsServiceProvider);

  Future<void> _loadDefaultEmail() async {
    final v = await _settings.getDefaultEmail();
    if (!mounted) return;
    setState(() => _defaultEmail = v);
  }

  Future<void> _saveDefaultEmail(String? email) async {
    await _settings.saveDefaultEmail(email);
    if (!mounted) return;
    setState(() => _defaultEmail = (email == null || email.trim().isEmpty) ? null : email.trim());
  }

  Future<void> _loadSavedLocation() async {
    final loc = await _settings.getLocation(widget.meta.id);
    if (!mounted) return;
    setState(() {
      _lat = loc.lat;
      _lng = loc.lng;
    });
  }

  Future<void> _saveLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _snack('Activá el GPS para guardar la ubicación.');
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        _snack('Sin permisos de ubicación.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      await _settings.saveLocation(widget.meta.id, pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
      _snack('Ubicación guardada.');
    } catch (e, st) {
      _logError(e, st);
      _snack('No se pudo obtener la ubicación.');
    }
  }

  Future<void> _loadAiPref() async {
    final v = await _settings.getAiEnabled(widget.meta.id);
    if (!mounted) return;
    setState(() => _aiEnabled = v);
  }

  Future<void> _toggleAi() async {
    setState(() => _aiEnabled = !_aiEnabled);
    await _settings.setAiEnabled(widget.meta.id, _aiEnabled);
    UsageAnalytics.instance.bump(_aiEnabled ? 'ai_enabled_on' : 'ai_enabled_off');
    _snack(_aiEnabled ? 'IA activada' : 'IA desactivada');
  }
  // =========================================

  List<Measurement> _currentAllRows() {
    final asyncAll = ref.read(measurementAsyncProvider(widget.meta.id));
    return asyncAll.hasValue ? (asyncAll.value ?? const <Measurement>[]) : const <Measurement>[];
  }

  void _updateRowsSafely(List<Measurement> rows) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Future<void>.delayed(Duration.zero, () {
        if (!mounted) return;
        ref.read(measurementAsyncProvider(widget.meta.id).notifier).setAll(rows);
      });
    });
  }

  Future<void> _addRow() async {
    final current = _currentAllRows().isEmpty ? widget.initial : _currentAllRows();
    final rows = List<Measurement>.from(current);
    final maxId = rows.isEmpty ? 0 : rows.map((e) => e.id ?? 0).reduce((a, b) => a > b ? a : b);
    final nextId = maxId + 1;

    rows.add(Measurement(
      id: nextId,
      progresiva: '',
      ohm1m: 0.0,
      ohm3m: 0.0,
      observations: '',
      date: DateTime.now(),
      latitude: _lat,
      longitude: _lng,
    ));
    _updateRowsSafely(rows);
    _notifyTop('Fila agregada'); // banner arriba
    HapticFeedback.selectionClick();
  }

  Future<void> _saveChanges() async {
    await _withBusy(() async {
      final items = _currentAllRows();
      final repo = ref.read(measurementRepoProvider(widget.meta.id));
      await repo.saveAll(items);
      _notifyTop('Cambios guardados'); // antes: _snack(...)
    });
  }

  Future<void> _saveTitle() async {
    final v = _titleCtrl.text.trim();
    if (v.isNotEmpty && v != widget.meta.name) {
      final updated = widget.meta.copyWith(name: v, author: _author);
      await SheetRegistry.instance.upsert(updated);
      widget.onTitleChanged?.call(v);
    }
    if (!mounted) return;
    setState(() => _editingTitle = false);
    HapticFeedback.selectionClick();
  }

  Future<void> _editAuthor() async {
    final ctl = TextEditingController(text: _author ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Autor de la planilla'),
        content: TextField(
          controller: ctl,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Nombre del empleado',
            prefixIcon: Icon(Icons.person_outline),
          ),
          onSubmitted: (_) => Navigator.pop(ctx, ctl.text.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctl.text.trim()), child: const Text('Guardar')),
        ],
      ),
    );
    if (value == null) return;
    final trimmed = value.isEmpty ? null : value;
    final updated = widget.meta.copyWith(author: trimmed);
    await SheetRegistry.instance.upsert(updated);
    if (!mounted) return;
    setState(() => _author = trimmed);
    _snack('Autor actualizado.');
  }

  String _buildEmailBody(List<Measurement> rows) {
    final b = StringBuffer();
    b.writeln('Adjunto XLSX generado con Gridnote para "${widget.meta.name}".');
    if ((_author ?? '').isNotEmpty) {
      b.writeln('Hecha por: ${_author!}');
    }
    final lat = _lat, lng = _lng;
    final locSvc = ref.read(locationServiceProvider);
    if (lat != null && lng != null) {
      b.writeln('');
      b.writeln('Ubicación general:');
      b.writeln(locSvc.mapsUrl(lat, lng));
    }
    final withCoords = rows.where((m) => (m.latitude != null && m.longitude != null)).toList();
    if (withCoords.isNotEmpty) {
      b.writeln('');
      b.writeln('Enlaces por fila:');
      for (final m in withCoords.take(10)) {
        final url = locSvc.mapsUrl(m.latitude!, m.longitude!);
        final prog = (m.progresiva.isEmpty) ? '-' : m.progresiva;
        b.writeln('• $prog → $url');
      }
      if (withCoords.length > 10) {
        b.writeln('• (+${withCoords.length - 10} más)');
      }
    }
    return b.toString();
  }

  Future<void> _shareViaEmail({required List<Measurement> rows}) async {
    final email = await _askForEmail(initial: _defaultEmail);
    if (email == null) return;
    final trimmed = email.trim();
    final re = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');
    if (!re.hasMatch(trimmed)) {
      _snack('Email inválido. Revisá el destinatario.');
      return;
    }
    final file = await ref.read(xlsxServiceProvider).buildFile(
      sheetId: widget.meta.id,
      title: widget.meta.name,
      data: rows,
      defaultLat: _lat,
      defaultLng: _lng,
    );
    final bodyText = _buildEmailBody(rows);
    await ref.read(emailShareServiceProvider).sendWithFallback(
      to: trimmed,
      subject: 'Gridnote – ${widget.meta.name}',
      body: bodyText,
      attachment: file,
    );
    _notifyTop('XLSX listo para enviar'); // antes: _snack(...)
  }

  Future<String?> _askForEmail({String? initial}) async {
    final ctl = TextEditingController(text: initial ?? '');
    var saveAsDefault = false;

    final result = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final bottomPad = MediaQuery.viewInsetsOf(ctx).bottom + 20;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPad),
          child: StatefulBuilder(
            builder: (context, setSB) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ListTile(
                    title: Text('Enviar por correo'),
                    subtitle: Text('Podés guardar el email como frecuente'),
                  ),
                  TextField(
                    controller: ctl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email destino',
                      prefixIcon: Icon(Icons.alternate_email),
                    ),
                  ),
                  const SizedBox(height: 4),
                  CheckboxListTile(
                    value: saveAsDefault,
                    onChanged: (v) => setSB(() => saveAsDefault = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('Guardar como frecuente'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx, null);
                          _saveDefaultEmail(null);
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Borrar guardado'),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: () {
                          final v = ctl.text.trim();
                          if (saveAsDefault && v.isNotEmpty) {
                            _saveDefaultEmail(v);
                          }
                          Navigator.pop(ctx, v.isEmpty ? null : v);
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('Aceptar'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
    return result;
  }

  Future<void> _openAiMenu() async {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(color: Colors.black.withValues(alpha: 0.18)),
            ),
          ),
          DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.45,
            minChildSize: 0.30,
            maxChildSize: 0.85,
            builder: (ctx, controller) {
              final bottomPad = MediaQuery.viewInsetsOf(ctx).bottom + 16;
              final t = widget.themeController.theme;
              return Container(
                decoration: BoxDecoration(
                  color: t.surface.withValues(alpha: .86),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  border: Border(top: BorderSide(color: t.divider)),
                ),
                child: ListView(
                  controller: controller,
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPad),
                  children: [
                    ListTile(
                      leading: Icon(_aiEnabled ? Icons.psychology : Icons.psychology_outlined),
                      title: Text(_aiEnabled ? 'IA activada' : 'IA desactivada'),
                      subtitle: const Text('Sugerencias contextuales mientras editás'),
                      trailing: CupertinoSwitch(
                        value: _aiEnabled,
                        onChanged: (_) => _toggleAi(),
                      ),
                      onTap: _toggleAi,
                    ),
                    const Divider(height: 0),
                    const ListTile(
                      leading: Icon(Icons.smart_toy_outlined),
                      title: Text('Atajos IA'),
                      subtitle: Text('Acciones sobre la fila/celda seleccionada'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.place_outlined),
                      title: const Text('Poner ubicación general en la fila'),
                      onTap: () async {
                        Navigator.pop(ctx);
                        if (_lat == null || _lng == null) {
                          _snack('Guardá primero la ubicación general.');
                          return;
                        }
                        await _gridCtrl.setLocationOnSelection(_lat!, _lng!);
                        _snack('Ubicación aplicada a la fila.');
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.photo_camera_outlined),
                      title: const Text('Agregar foto a la fila'),
                      onTap: () async {
                        Navigator.pop(ctx);
                        await _gridCtrl.addPhotoOnSelection();
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.format_color_fill),
                      title: const Text('Resaltar celda'),
                      onTap: () async {
                        Navigator.pop(ctx);
                        await _gridCtrl.colorCellSelected(AppStyles.cellHighlight);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.font_download_outlined),
                      title: const Text('Usar fuente monoespaciada'),
                      onTap: () {
                        Navigator.pop(ctx);
                        _gridCtrl.setFontFamily(AppStyles.monoFontFamily);
                      },
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openSheetDrum() async {
    final t = widget.themeController.theme;
    final items = await SheetRegistry.instance.getAllSorted();

    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (!mounted) return;

    final selected = await showSheetDrumPicker(
      context: context,
      items: items,
      title: 'Planillas',
      accent: t.accent,
      textColor: t.text,
      surface: t.surface,
      divider: t.divider,
      onCreateNew: () => SheetRegistry.instance.create(name: 'Planilla nueva'),
      initial: widget.meta,
      subtitleBuilder: (m) => 'Modificado: ${_fmtDate(m.createdAt)}',
    );
    if (!mounted || selected == null || selected.id == widget.meta.id) return;

    await SheetRegistry.instance.touch(selected);
    if (!mounted) return;

    Navigator.of(context).push(FadeScaleRoute(
      child: MeasurementScreen(
        id: selected.id,
        meta: selected,
        initial: const <Measurement>[],
        themeController: widget.themeController,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = ref.watch(isSavingProvider);
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return AnimatedBuilder(
      animation: widget.themeController,
      builder: (_, __) {
        final t = widget.themeController.theme;
        final table = GridnoteTableStyle.from(t);

        final headerCard = _HeaderBar(
          theme: t,
          titleCtrl: _titleCtrl,
          editingTitle: _editingTitle,
          onTapEditTitle: () => setState(() => _editingTitle = true),
          onSaveTitle: _saveTitle,
          hasLocation: _lat != null && _lng != null,
          onLocationPressed: (_lat != null && _lng != null)
              ? () async {
            final ok = await ref.read(locationServiceProvider).openInMaps(
              lat: _lat!,
              lng: _lng!,
            );
            if (!ok) _snack('No se pudo abrir la app de mapas.');
          }
              : () => _withBusy(_saveLocation),
          aiEnabled: _aiEnabled,
          onToggleAi: _toggleAi,
          author: _author,
          onEditAuthor: _editAuthor,
          onSharePressed: () => _withBusy(() async {
            final rows = ref.read(measurementFilteredAsyncProvider(widget.meta.id)).maybeWhen(
              data: (r) => r,
              orElse: () => const <Measurement>[],
            );
            if (rows.isEmpty) {
              _snack('No hay filas visibles para compartir.');
              return;
            }
            await _shareViaEmail(rows: rows);
          }),
        );

        final grid = RepaintBoundary(
          child: MeasurementDataGrid(
            meta: widget.meta,
            initial: _currentAllRows().isEmpty ? widget.initial : _currentAllRows(),
            themeController: widget.themeController,
            controller: _gridCtrl,
            headerTitles: const <String, String>{},
            onEditHeader: (_) {},
            onChanged: _updateRowsSafely,
            onOpenMaps: (m) async {
              final lat = m.latitude ?? _lat;
              final lng = m.longitude ?? _lng;
              if (lat == null || lng == null) return;
              final ok = await ref.read(locationServiceProvider).openInMaps(lat: lat, lng: lng);
              if (!ok) _snack('No se pudo abrir la app de mapas.');
            },
            aiEnabled: _aiEnabled,
          ),
        );

        final fabRail = (!keyboardOpen)
            ? _MiniRail(
          theme: t,
          table: table,
          isBusy: _isLoading || isSaving,
          onAddRow: _addRow,
          onSave: _saveChanges,
        )
            : const SizedBox.shrink();

        return Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: t.scaffold,
          appBar: AppBar(
            title: Text('Planilla: ${widget.meta.id}', overflow: TextOverflow.ellipsis),
            actions: [
              IconButton(
                tooltip: 'Planillas (tambor)',
                icon: const Icon(CupertinoIcons.square_stack_3d_up),
                onPressed: _openSheetDrum,
              ),
              IconButton(
                tooltip: _aiEnabled ? 'IA activada (tocar para desactivar)' : 'IA desactivada (tocar para activar)',
                icon: Icon(_aiEnabled ? Icons.psychology : Icons.psychology_outlined),
                onPressed: _toggleAi,
              ),
              IconButton(
                tooltip: 'Asistente IA',
                icon: const Icon(Icons.smart_toy_outlined),
                onPressed: _openAiMenu,
              ),
              PopupMenuButton<ShareOption>(
                tooltip: 'Compartir / Exportar',
                onSelected: (v) async {
                  switch (v) {
                    case ShareOption.sendVisible:
                      await _withBusy(() async {
                        final rows = ref.read(measurementFilteredAsyncProvider(widget.meta.id)).maybeWhen(
                          data: (r) => r,
                          orElse: () => const <Measurement>[],
                        );
                        if (rows.isEmpty) {
                          _snack('No hay filas visibles para compartir.');
                          return;
                        }
                        await _shareViaEmail(rows: rows);
                      });
                      break;
                    case ShareOption.sendAll:
                      await _withBusy(() async {
                        final rows = _currentAllRows();
                        if (rows.isEmpty) {
                          _snack('No hay filas para compartir.');
                          return;
                        }
                        await _shareViaEmail(rows: rows);
                      });
                      break;
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: ShareOption.sendVisible,
                    child: ListTile(
                      leading: Icon(Icons.filter_alt_outlined),
                      title: Text('Enviar XLSX (solo visible)'),
                    ),
                  ),
                  PopupMenuItem(
                    value: ShareOption.sendAll,
                    child: ListTile(
                      leading: Icon(Icons.grid_on_outlined),
                      title: Text('Enviar XLSX (todas las filas)'),
                    ),
                  ),
                ],
                icon: const Icon(Icons.ios_share_outlined),
              ),
            ],
          ),
          body: Stack(
            children: [
              Container(
                color: table.cellBg,
                child: Column(
                  children: [
                    RepaintBoundary(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: headerCard,
                      ),
                    ),
                    Expanded(
                      child: RefreshIndicator.adaptive(
                        displacement: 64,
                        onRefresh: () => ref.read(measurementAsyncProvider(widget.meta.id).notifier).reload(),
                        child: ScrollConfiguration(
                          behavior: const _BounceBehavior(),
                          child: grid,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!keyboardOpen) Positioned(right: 12, bottom: 12, child: RepaintBoundary(child: fabRail)),
              if (_isLoading || isSaving)
                const Positioned.fill(
                  child: AbsorbPointer(
                    child: ColoredBox(
                      color: Color(0x3F000000),
                      child: Center(child: CupertinoActivityIndicator()),
                    ),
                  ),
                ),
            ],
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
          floatingActionButton: keyboardOpen
              ? null
              : FloatingActionButton.extended(
            onPressed: _openAiMenu,
            backgroundColor: t.accent,
            icon: const Icon(Icons.smart_toy_outlined, color: Colors.black),
            label: const Text('IA'),
          ),
        );
      },
    );
  }
}

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({
    required this.theme,
    required this.titleCtrl,
    required this.editingTitle,
    required this.onTapEditTitle,
    required this.onSaveTitle,
    required this.hasLocation,
    required this.onLocationPressed,
    required this.aiEnabled,
    required this.onToggleAi,
    required this.author,
    required this.onEditAuthor,
    required this.onSharePressed,
  });

  final GridnoteTheme theme;
  final TextEditingController titleCtrl;
  final bool editingTitle;
  final VoidCallback onTapEditTitle;
  final Future<void> Function() onSaveTitle;
  final bool hasLocation;
  final Future<void> Function() onLocationPressed;
  final bool aiEnabled;
  final Future<void> Function() onToggleAi;
  final String? author;
  final Future<void> Function() onEditAuthor;
  final Future<void> Function() onSharePressed;

  ButtonStyle _chipStyle(Color surface) => OutlinedButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    visualDensity: VisualDensity.compact,
    shape: const StadiumBorder(),
    backgroundColor: surface,
  );

  @override
  Widget build(BuildContext context) {
    final table = GridnoteTableStyle.from(theme);

    final locBtn = OutlinedButton.icon(
      style: _chipStyle(theme.surface),
      onPressed: onLocationPressed,
      icon: Icon(hasLocation ? Icons.check_circle : Icons.place_outlined),
      label: Text(hasLocation ? 'Ubicación guardada' : 'Guardar ubicación'),
    );

    final authorBtn = OutlinedButton.icon(
      style: _chipStyle(theme.surface),
      onPressed: onEditAuthor,
      icon: const Icon(Icons.person_outline),
      label: Text(
        (author == null || author!.trim().isEmpty) ? 'Agregar autor' : 'Autor: ${author!}',
        overflow: TextOverflow.ellipsis,
      ),
    );

    final titleWidget = editingTitle
        ? TextField(
      controller: titleCtrl,
      autofocus: true,
      textInputAction: TextInputAction.done,
      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      decoration: const InputDecoration(isCollapsed: true, border: InputBorder.none),
      onSubmitted: (_) => onSaveTitle(),
      onTapOutside: (_) => onSaveTitle(),
    )
        : GestureDetector(
      onTap: onTapEditTitle,
      child: Text(
        titleCtrl.text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      ),
    );

    final shareBtn = FilledButton.tonalIcon(
      onPressed: onSharePressed,
      icon: const Icon(Icons.ios_share_outlined),
      label: const Text('Compartir'),
    );

    final aiPill = OutlinedButton.icon(
      style: _chipStyle(theme.surface),
      onPressed: onToggleAi,
      icon: Icon(aiEnabled ? Icons.psychology : Icons.psychology_outlined),
      label: Text(aiEnabled ? 'IA activada' : 'IA desactivada'),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: table.gridLine),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: LayoutBuilder(
          builder: (ctx, c) {
            final narrow = c.maxWidth < 520;
            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: titleWidget),
                    const SizedBox(width: 8),
                    shareBtn,
                  ]),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [locBtn, authorBtn, aiPill],
                  ),
                ],
              );
            } else {
              return Row(
                children: [
                  Expanded(child: titleWidget),
                  const SizedBox(width: 8),
                  Flexible(fit: FlexFit.loose, child: locBtn),
                  const SizedBox(width: 8),
                  Flexible(fit: FlexFit.loose, child: authorBtn),
                  const SizedBox(width: 8),
                  aiPill,
                  const SizedBox(width: 8),
                  shareBtn,
                ],
              );
            }
          },
        ),
      ),
    );
  }
}

class _MiniRail extends StatelessWidget {
  const _MiniRail({
    required this.theme,
    required this.table,
    required this.isBusy,
    required this.onAddRow,
    required this.onSave,
  });

  final GridnoteTheme theme;
  final GridnoteTableStyle table;
  final bool isBusy;
  final Future<void> Function() onAddRow;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.surface.withValues(alpha: .82),
            border: Border.all(color: table.gridLine),
            boxShadow: const [BoxShadow(blurRadius: 8, offset: Offset(0, 2), color: Color(0x42000000))],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Agregar fila',
                  onPressed: isBusy ? null : onAddRow,
                  icon: const Icon(Icons.add_circle_outline),
                ),
                const SizedBox(width: 6),
                FilledButton.icon(
                  onPressed: isBusy ? null : onSave,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Guardar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BounceBehavior extends ScrollBehavior {
  const _BounceBehavior();
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    return StretchingOverscrollIndicator(axisDirection: details.direction, child: child);
  }
}
