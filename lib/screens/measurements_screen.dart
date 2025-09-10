// lib/screens/measurements_screen.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/measurement.dart';
import '../models/sheet_meta.dart';
import '../models/share_option.dart';
import '../theme/gridnote_theme.dart';
import '../widgets/measurement_pluto_grid.dart'; // MeasurementDataGrid + MeasurementGridController
import '../state/measurement_async_provider.dart';
import '../services/xlsx_export_service.dart';
import '../services/email_share_service.dart';
import '../services/location_service.dart';
import '../services/sheet_registry.dart';
import '../widgets/drum_picker.dart';
import '../providers/settings_provider.dart';
import '../routing/fade_scale_route.dart';
import '../services/notification_service.dart';

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
  bool _dirty = false;

  late final TextEditingController _titleCtrl = TextEditingController(text: widget.meta.name);

  // Controlador de la grilla
  final MeasurementGridController _grid = MeasurementGridController();

  String? _defaultEmail;
  double? _lat;
  double? _lng;
  String? _author;

  List<String> _nameSuggestions = const [];

  // Títulos de encabezados (persistentes por planilla)
  Map<String, String> _headerTitles = const {};
  String get _headersKey => 'sheet_${widget.meta.id}_headers_v2';

  // ------- CÁMARA SEGURA -------
  bool _pickingPhoto = false;
  Future<File?> _pickPhotoSafely() async {
    if (_pickingPhoto || !mounted) return null;
    setState(() => _pickingPhoto = true);
    try {
      final picker = ImagePicker();
      final x = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        requestFullMetadata: false,
        maxWidth: 1600,
        imageQuality: 80,
      );
      if (x == null || !mounted) return null;
      await Future<void>.delayed(const Duration(milliseconds: 60));
      final dir = await getTemporaryDirectory();
      final path = p.join(dir.path, 'gridnote_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await x.saveTo(path);
      return File(path);
    } catch (e, st) {
      _logError(e, st);
      if (mounted) _snack('No se pudo tomar la foto.');
      return null;
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  Future<File?> pickPhoto() => _pickPhotoSafely();

  String _fmtDate(DateTime d) => DateFormat("d 'de' MMM. 'de' y", 'es').format(d);

  @override
  void initState() {
    super.initState();
    _author = widget.meta.author;
    _loadDefaultEmail();
    _loadSavedLocation();
    _loadTitleSuggestions();
    _loadHeaderTitles();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(measurementAsyncProvider(widget.meta.id).notifier).reload());
      unawaited(SheetRegistry.instance.touch(widget.meta));
    });
  }

  @override
  void didUpdateWidget(covariant MeasurementScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.meta.name != widget.meta.name) _titleCtrl.text = widget.meta.name;
    if (oldWidget.meta.author != widget.meta.author) _author = widget.meta.author;
    if (oldWidget.meta.id != widget.meta.id) _loadHeaderTitles();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  // ------- HELPERS -------
  Future<void> _loadTitleSuggestions() async {
    final list = await SheetRegistry.instance.getAllSorted();
    if (!mounted) return;
    setState(() => _nameSuggestions = list.map((e) => e.name).toSet().toList());
  }

  Future<void> _loadHeaderTitles() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_headersKey);
    final map = (raw == null || raw.isEmpty) ? <String, String>{} : Map<String, String>.from(Uri.splitQueryString(raw));
    if (mounted) setState(() => _headerTitles = map);
  }

  Future<void> _saveHeaderTitle(String field, String value) async {
    final sp = await SharedPreferences.getInstance();
    final next = Map<String, String>.from(_headerTitles)..[field] = value;
    await sp.setString(_headersKey, Uri(queryParameters: next).query);
    if (mounted) setState(() => _headerTitles = next);
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

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
        content: Text(msg, style: TextStyle(color: t.text, fontWeight: FontWeight.w700)),
        actions: [TextButton(onPressed: messenger.removeCurrentMaterialBanner, child: const Text('OK'))],
      ),
    );
    Future.delayed(duration, () {
      if (mounted) messenger.removeCurrentMaterialBanner();
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

  SettingsService get _settings => ref.read(settingsServiceProvider);

  Future<void> _loadDefaultEmail() async {
    final v = await _settings.getDefaultEmail();
    if (mounted) setState(() => _defaultEmail = v);
  }

  Future<void> _saveDefaultEmail(String? email) async {
    await _settings.saveDefaultEmail(email);
    if (mounted) {
      setState(() => _defaultEmail = (email == null || email.trim().isEmpty) ? null : email.trim());
    }
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

  // Fuente de verdad de filas (para callbacks)
  List<Measurement> _rowsNow() {
    final asyncAll = ref.read(measurementAsyncProvider(widget.meta.id));
    return asyncAll.maybeWhen(
      data: (v) => (v ?? const <Measurement>[]),
      orElse: () => const <Measurement>[],
    );
  }

  void _updateRowsSafely(List<Measurement> rows) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Future<void>.delayed(Duration.zero, () {
        if (!mounted) return;
        ref.read(measurementAsyncProvider(widget.meta.id).notifier).setAll(rows);
        if (mounted) setState(() => _dirty = true);
      });
    });
  }

  Future<void> _addRow() async {
    final current = _rowsNow();
    final rows = List<Measurement>.from(current.isEmpty ? widget.initial : current);
    final maxId = rows.isEmpty ? 0 : rows.map((e) => e.id ?? 0).reduce((a, b) => a > b ? a : b);
    rows.add(
      Measurement(
        id: maxId + 1,
        progresiva: '',
        // Si el renderer oculta 0, mantenemos 0.0; si tu modelo permite null, podés cambiar a null.
        ohm1m: 0.0,
        ohm3m: 0.0,
        observations: '',
        date: DateTime.now(),
        latitude: _lat,
        longitude: _lng,
      ),
    );
    _updateRowsSafely(rows);
    _notifyTop('Fila agregada');
    HapticFeedback.selectionClick();
  }

  Future<void> _saveChanges() async {
    if (!_dirty) {
      _snack('No hay cambios para guardar.');
      return;
    }
    await _withBusy(() async {
      final items = _rowsNow();
      final repo = ref.read(measurementRepoProvider(widget.meta.id));
      await repo.saveMany(items);
      if (mounted) setState(() => _dirty = false);
      _notifyTop('Cambios guardados');
      unawaited(_exportBackupAndNotify(items));
    });
  }

  Future<void> _saveTitle() async {
    final v = _titleCtrl.text.trim();
    if (v.isNotEmpty && v != widget.meta.name) {
      final updated = widget.meta.copyWith(name: v, author: _author);
      await SheetRegistry.instance.upsert(updated);
      widget.onTitleChanged?.call(v);
      if (mounted) setState(() => _dirty = true);
      _loadTitleSuggestions();
    }
    if (!mounted) return;
    setState(() => _editingTitle = false);
    HapticFeedback.selectionClick();
  }

  Future<void> _editAuthor() async {
    final navigator = Navigator.of(context);
    final ctl = TextEditingController(text: _author ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Autor de la planilla'),
        content: TextField(
          controller: ctl,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(labelText: 'Nombre del empleado', prefixIcon: Icon(Icons.person_outline)),
          onSubmitted: (_) => navigator.pop(ctl.text.trim()),
        ),
        actions: [
          TextButton(onPressed: () => navigator.pop(), child: const Text('Cancelar')),
          FilledButton(onPressed: () => navigator.pop(ctl.text.trim()), child: const Text('Guardar')),
        ],
      ),
    );
    if (value == null) return;
    final trimmed = value.isEmpty ? null : value;
    final updated = widget.meta.copyWith(author: trimmed);
    await SheetRegistry.instance.upsert(updated);
    if (!mounted) return;
    setState(() {
      _author = trimmed;
      _dirty = true;
    });
    _snack('Autor actualizado.');
  }

  // ------- COMPARTIR -------
  String _buildEmailBody(List<Measurement> rows) {
    final b = StringBuffer();
    b.writeln('Adjunto XLSX generado con Gridnote para "${widget.meta.name}".');
    if ((_author ?? '').isNotEmpty) b.writeln('Hecha por: ${_author!}');
    final locSvc = ref.read(locationServiceProvider);
    if (_lat != null && _lng != null) {
      b.writeln('');
      b.writeln('Ubicación general:');
      b.writeln(locSvc.mapsUrl(_lat!, _lng!));
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
      if (withCoords.length > 10) b.writeln('• (+${withCoords.length - 10} más)');
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
      defaultLat: _lat ?? 0.0,
      defaultLng: _lng ?? 0.0,
    );
    final bodyText = _buildEmailBody(rows);
    await ref.read(emailShareServiceProvider).sendWithFallback(
      to: trimmed,
      subject: 'Gridnote – ${widget.meta.name}',
      body: bodyText,
      attachment: file,
    );
    _notifyTop('XLSX listo para enviar');
  }

  Future<String?> _askForEmail({String? initial}) async {
    final ctl = TextEditingController(text: initial ?? '');
    var saveAsDefault = false;
    final navigator = Navigator.of(context);
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
                  const ListTile(title: Text('Enviar por correo'), subtitle: Text('Podés guardar el email como frecuente')),
                  TextField(
                    controller: ctl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email destino', prefixIcon: Icon(Icons.alternate_email)),
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
                          navigator.pop<String?>(null);
                          _saveDefaultEmail(null);
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Borrar guardado'),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: () {
                          final v = ctl.text.trim();
                          if (saveAsDefault && v.isNotEmpty) _saveDefaultEmail(v);
                          navigator.pop<String?>(v.isEmpty ? null : v);
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

  Future<void> _openSheetDrum() async {
    final nav = Navigator.of(context); // evitar usar context tras awaits
    final t = widget.themeController.theme;
    final items = await SheetRegistry.instance.getAllSorted()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
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
    await nav.push(
      FadeScaleRoute(
        child: MeasurementScreen(
          id: selected.id,
          meta: selected,
          initial: const <Measurement>[],
          themeController: widget.themeController,
        ),
      ),
    );
  }

  // ------- BACKUP + NOTIF -------
  Future<void> _exportBackupAndNotify(List<Measurement> rows) async {
    try {
      final temp = await ref.read(xlsxServiceProvider).buildFile(
        sheetId: widget.meta.id,
        title: widget.meta.name,
        data: rows,
        defaultLat: _lat ?? 0.0,
        defaultLng: _lng ?? 0.0,
      );
      final docs = await getExternalStorageDirectories(type: StorageDirectory.documents);
      final base = (docs != null && docs.isNotEmpty) ? docs.first : await getExternalStorageDirectory();
      if (base == null) return;
      final dir = Directory(p.join(base.path, 'Gridnote'));
      if (!await dir.exists()) await dir.create(recursive: true);
      final safeTitle = widget.meta.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
      final stamp = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());
      final saved = await temp.copy(p.join(dir.path, '$safeTitle-$stamp.xlsx'));
      await NotificationService.instance.showSavedSheet(
        title: 'Planilla guardada',
        body: 'Tocá para abrir: ${p.basename(saved.path)}',
        filePath: saved.path,
      );
    } catch (e, st) {
      _logError(e, st);
    }
  }

  Future<bool> _confirmLeaveIfDirty() async {
    if (!_dirty || _isLoading) return true;
    final navigator = Navigator.of(context);
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hay cambios sin guardar'),
        content: const Text('¿Querés guardar antes de salir?'),
        actions: [
          TextButton(onPressed: () => navigator.pop('discard'), child: const Text('Salir')),
          TextButton(onPressed: () => navigator.pop('cancel'), child: const Text('Cancelar')),
          FilledButton(onPressed: () => navigator.pop('save'), child: const Text('Guardar')),
        ],
      ),
    );
    if (res == 'save') {
      await _saveChanges();
      return true;
    }
    if (res == 'discard') return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = ref.watch(isSavingProvider);
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    final allRows = ref.watch(measurementAsyncProvider(widget.meta.id)).maybeWhen(
      data: (v) => (v ?? const <Measurement>[]),
      orElse: () => const <Measurement>[],
    );
    final initialForGrid = allRows.isEmpty ? widget.initial : allRows;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final ok = await _confirmLeaveIfDirty();
        if (ok && context.mounted) Navigator.of(context).pop();
      },
      child: AnimatedBuilder(
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
              final ok = await ref.read(locationServiceProvider).openInMaps(lat: _lat!, lng: _lng!);
              if (!ok) _snack('No se pudo abrir la app de mapas.');
            }
                : () => _withBusy(_saveLocation),
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
            nameSuggestions: _nameSuggestions,
          );

          final grid = RepaintBoundary(
            child: MeasurementDataGrid(
              meta: widget.meta,
              initial: initialForGrid,
              themeController: widget.themeController,
              controller: _grid,
              headerTitles: _headerTitles,
              onEditHeader: (_) {},
              onHeaderTitleChanged: (field, value) => _saveHeaderTitle(field, value),
              onOpenMaps: (m) async {
                final lat = m.latitude ?? _lat;
                final lng = m.longitude ?? _lng;
                if (lat == null || lng == null) return;
                final ok = await ref.read(locationServiceProvider).openInMaps(lat: lat, lng: lng);
                if (!ok) _snack('No se pudo abrir la app de mapas.');
              },
              onChanged: (rows) => _updateRowsSafely(rows),
              aiEnabled: true,
              showPhotoRail: true,
            ),
          );

          return Scaffold(
            resizeToAvoidBottomInset: true,
            backgroundColor: t.scaffold,
            appBar: AppBar(
              title: Text('Planilla: ${widget.meta.id}', overflow: TextOverflow.ellipsis),
              actions: [
                IconButton(
                  tooltip: 'Guardar',
                  onPressed: (_isLoading || isSaving || !_dirty) ? null : _saveChanges,
                  icon: const Icon(Icons.save_outlined),
                ),
                IconButton(
                  tooltip: 'Planillas (tambor)',
                  icon: const Icon(CupertinoIcons.square_stack_3d_up),
                  onPressed: _openSheetDrum,
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
                          final rows = _rowsNow();
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
                      child: ListTile(leading: Icon(Icons.filter_alt_outlined), title: Text('Enviar XLSX (solo visible)')),
                    ),
                    PopupMenuItem(
                      value: ShareOption.sendAll,
                      child: ListTile(leading: Icon(Icons.grid_on_outlined), title: Text('Enviar XLSX (todas las filas)')),
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
            floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
            floatingActionButton: keyboardOpen
                ? null
                : FloatingActionButton(
              onPressed: _addRow,
              backgroundColor: t.accent,
              foregroundColor: Colors.black,
              child: const Icon(Icons.add),
            ),
          );
        },
      ),
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
    required this.author,
    required this.onEditAuthor,
    required this.onSharePressed,
    required this.nameSuggestions,
  });

  final GridnoteTheme theme;
  final TextEditingController titleCtrl;
  final bool editingTitle;
  final VoidCallback onTapEditTitle;
  final Future<void> Function() onSaveTitle;
  final bool hasLocation;
  final Future<void> Function() onLocationPressed;
  final String? author;
  final Future<void> Function() onEditAuthor;
  final Future<void> Function() onSharePressed;
  final List<String> nameSuggestions;

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
        ? Autocomplete<String>(
      optionsBuilder: (t) {
        final q = t.text.trim().toLowerCase();
        if (q.isEmpty) return const Iterable<String>.empty();
        return nameSuggestions.where((n) => n.toLowerCase().contains(q)).take(10);
      },
      onSelected: (_) => onSaveTitle(),
      fieldViewBuilder: (ctx, ctl, focus, onSubmit) {
        ctl.text = titleCtrl.text;
        ctl.selection = titleCtrl.selection;
        ctl.addListener(() => titleCtrl.value = ctl.value);
        return TextField(
          controller: ctl,
          autofocus: true,
          focusNode: focus,
          textInputAction: TextInputAction.done,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          decoration: const InputDecoration(isCollapsed: true, border: InputBorder.none),
          onSubmitted: (_) => onSaveTitle(),
          onTapOutside: (_) => onSaveTitle(),
        );
      },
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
                  Row(children: [Expanded(child: titleWidget), const SizedBox(width: 8), shareBtn]),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [locBtn, authorBtn]),
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

class _BounceBehavior extends ScrollBehavior {
  const _BounceBehavior();
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  @override
  Widget buildOverscrollIndicator(
      BuildContext context,
      Widget child,
      ScrollableDetails details,
      ) =>
      StretchingOverscrollIndicator(axisDirection: details.direction, child: child);
}
