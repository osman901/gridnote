// lib/screens/sheet_screen.dart
import 'dart:ui' show ImageFilter, FontFeature;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/perf_flags.dart';
import '../models/measurement.dart';
import '../models/sheet_meta.dart';
import '../services/audit_log_service.dart';
import '../services/suggest_service.dart';
import '../services/validation_rules.dart';
import '../theme/gridnote_theme.dart';
import '../viewmodels/sheet_view_model.dart';
import '../widgets/measurement_pluto_grid.dart' as mg; // MeasurementDataGrid + Controller
import '../widgets/measurement_columns.dart' show MeasurementColumn;
import '../widgets/value_listenable_builder_2.dart';
import '../widgets/form_view.dart';
import '../widgets/chart_dialog.dart';
import '../services/service_locator.dart';

// Extras: guardar manual y Ajustes
import '../services/outbox_service.dart';
import 'settings_screen.dart';

/// --- Stub mínimo para evitar referencias rotas a GridnoteTableStyle ---
class GridnoteTableStyle {
  final Color gridLine;
  final Color cellBg;
  const GridnoteTableStyle({required this.gridLine, required this.cellBg});
  factory GridnoteTableStyle.from(GridnoteTheme t) =>
      GridnoteTableStyle(gridLine: t.divider, cellBg: t.surface);
}

class SheetScreen extends StatefulWidget {
  const SheetScreen({
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
  State<SheetScreen> createState() => _SheetScreenState();
}

class _SheetScreenState extends State<SheetScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _searchCtrl;

  late final SheetViewModel _vm;
  bool get _isIOS => defaultTargetPlatform == TargetPlatform.iOS;

  // Controlador de la grilla
  final mg.MeasurementGridController _grid = mg.MeasurementGridController();

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.meta.name);
    _searchCtrl = TextEditingController();

    _vm = SheetViewModel(
      sheetId: widget.id,
      initialTitle: widget.meta.name,
      initialRows: widget.initial,
      audit: getIt<AuditLogService>(param1: widget.meta.id),
      onSnack: _snack,
      onTitleChanged: (v) => widget.onTitleChanged?.call(v),
    )..init();
  }

  @override
  void didUpdateWidget(covariant SheetScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.meta.name != oldWidget.meta.name) {
      _titleCtrl.text = widget.meta.name;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _searchCtrl.dispose();
    _vm.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------- FILTRADO (para exportaciones / gráfico) ----------
  List<Measurement> _visibleRowsNow() {
    final q = _vm.searchQuery.value.trim().toLowerCase();
    final rows = _vm.measurements.value;
    if (q.isEmpty) return rows;
    bool match(Measurement m) {
      if (m.progresiva.toLowerCase().contains(q)) return true;
      if (m.observations.toLowerCase().contains(q)) return true;
      if ('${m.ohm1m}'.contains(q)) return true;
      if ('${m.ohm3m}'.contains(q)) return true;
      return false;
    }

    return rows.where(match).toList();
  }

  // ---------- Compartir / Exportar ----------
  Widget _shareMenuButton() {
    if (_isIOS) {
      return ValueListenableBuilder<bool>(
        valueListenable: _vm.isBusy,
        builder: (_, busy, __) {
          return CupertinoButton.filled(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            onPressed: busy ? null : _showShareSheetIOS,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [Icon(CupertinoIcons.share), SizedBox(width: 6), Text('Exportar')],
            ),
          );
        },
      );
    }

    return ValueListenableBuilder<bool>(
      valueListenable: _vm.isBusy,
      builder: (_, busy, __) {
        const child = Row(
          mainAxisSize: MainAxisSize.min,
          children: [Icon(Icons.ios_share_outlined), SizedBox(width: 8), Text('Exportar')],
        );
        final button = IgnorePointer(ignoring: true, child: FilledButton.tonal(onPressed: () {}, child: child));
        return PopupMenuButton<String>(
          tooltip: 'Compartir / Exportar',
          enabled: !busy,
          onSelected: (v) async {
            switch (v) {
              case 'send_visible_xlsx':
                final email = await _askForEmail();
                if (email != null) await _vm.shareViaEmailXlsx(rows: _visibleRowsNow(), email: email);
                break;
              case 'send_all_xlsx':
                final email2 = await _askForEmail();
                if (email2 != null) await _vm.shareViaEmailXlsx(rows: _vm.measurements.value, email: email2);
                break;
              case 'export_visible_csv':
                await _vm.shareCsv(rows: _visibleRowsNow());
                break;
              case 'export_all_csv':
                await _vm.shareCsv(rows: _vm.measurements.value);
                break;
              case 'export_pdf_visible':
                await _vm.exportPdf(rows: _visibleRowsNow());
                break;
              case 'export_pdf_all':
                await _vm.exportPdf(rows: _vm.measurements.value);
                break;
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'send_visible_xlsx',
              child: ListTile(leading: Icon(Icons.filter_alt_outlined), title: Text('Enviar XLSX (solo visible)')),
            ),
            PopupMenuItem(
              value: 'send_all_xlsx',
              child: ListTile(leading: Icon(Icons.grid_on_outlined), title: Text('Enviar XLSX (todas las filas)')),
            ),
            PopupMenuDivider(),
            PopupMenuItem(
              value: 'export_visible_csv',
              child: ListTile(leading: Icon(Icons.table_chart_outlined), title: Text('Exportar CSV (solo visible)')),
            ),
            PopupMenuItem(
              value: 'export_all_csv',
              child: ListTile(leading: Icon(Icons.table_rows_outlined), title: Text('Exportar CSV (todas las filas)')),
            ),
            PopupMenuDivider(),
            PopupMenuItem(
              value: 'export_pdf_visible',
              child: ListTile(leading: Icon(Icons.picture_as_pdf_outlined), title: Text('Exportar PDF (solo visible)')),
            ),
            PopupMenuItem(
              value: 'export_pdf_all',
              child: ListTile(leading: Icon(Icons.picture_as_pdf), title: Text('Exportar PDF (todas las filas)')),
            ),
          ],
          child: button,
        );
      },
    );
  }

  Future<void> _showShareSheetIOS() async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: const Text('Exportar / Compartir'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(context);
              final email = await _askForEmail();
              if (email != null) await _vm.shareViaEmailXlsx(rows: _visibleRowsNow(), email: email);
            },
            child: const Text('Enviar XLSX (solo visible)'),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(context);
              final email = await _askForEmail();
              if (email != null) await _vm.shareViaEmailXlsx(rows: _vm.measurements.value, email: email);
            },
            child: const Text('Enviar XLSX (todas)'),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(context);
              await _vm.shareCsv(rows: _visibleRowsNow());
            },
            child: const Text('Exportar CSV (solo visible)'),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(context);
              await _vm.shareCsv(rows: _vm.measurements.value);
            },
            child: const Text('Exportar CSV (todas)'),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(context);
              await _vm.exportPdf(rows: _visibleRowsNow());
            },
            child: const Text('Exportar PDF (solo visible)'),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(context);
              await _vm.exportPdf(rows: _vm.measurements.value);
            },
            child: const Text('Exportar PDF (todas)'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          isDefaultAction: true,
          child: const Text('Cancelar'),
        ),
      ),
    );
  }

  Future<String?> _askForEmail() async {
    final ctl = TextEditingController(text: _vm.defaultEmail.value ?? '');
    bool saveAsDefault = false;

    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        void submit() {
          final v = ctl.text.trim();
          if (saveAsDefault && v.isNotEmpty) _vm.saveDefaultEmail(v);
          Navigator.pop(ctx, v.isEmpty ? null : v);
        }

        final viewInsets = MediaQuery.of(ctx).viewInsets;
        return SafeArea(
          child: AnimatedPadding(
            padding: EdgeInsets.only(bottom: viewInsets.bottom),
            duration: const Duration(milliseconds: 150),
            curve: Curves.decelerate,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
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
                          autofocus: true,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => submit(),
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
                        OverflowBar(
                          alignment: MainAxisAlignment.spaceBetween,
                          overflowAlignment: OverflowBarAlignment.end,
                          spacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx, null);
                                _vm.saveDefaultEmail(null);
                              },
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Borrar guardado'),
                            ),
                            FilledButton.icon(
                              onPressed: submit,
                              icon: const Icon(Icons.check),
                              label: const Text('Aceptar'),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
    return result;
  }

  ButtonStyle _chipStyle(Color surface) => OutlinedButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    visualDensity: VisualDensity.compact,
    shape: const StadiumBorder(),
    backgroundColor: surface,
  );

  Future<void> _showLocationSheet() async {
    final la0 = _vm.lat.value, lo0 = _vm.lng.value;
    if (la0 == null || lo0 == null) {
      await _vm.saveLocation();
      return;
    }
    final double la = la0;
    final double lo = lo0;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text('Ubicación guardada'),
                subtitle: Text('Revisá o actualizá la ubicación de la planilla'),
              ),
              Row(
                children: [
                  Expanded(child: Text('Lat: ${la.toStringAsFixed(6)}\nLng: ${lo.toStringAsFixed(6)}')),
                  IconButton(
                    tooltip: 'Copiar',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: '$la,$lo'));
                      HapticFeedback.selectionClick();
                      Navigator.pop(ctx);
                      _snack('Coordenadas copiadas');
                    },
                    icon: const Icon(Icons.copy_all_outlined),
                  )
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _vm.openMapsFor(latParam: la, lngParam: lo);
                    },
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Ver en mapa'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _vm.saveLocation();
                    },
                    icon: const Icon(Icons.my_location_outlined),
                    label: const Text('Actualizar ubicación'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iosViewSegment() {
    return ValueListenableBuilder<bool>(
      valueListenable: _vm.formView,
      builder: (_, isForm, __) {
        return CupertinoSlidingSegmentedControl<int>(
          groupValue: isForm ? 1 : 0,
          children: const {
            0: Padding(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6), child: Text('Tabla')),
            1: Padding(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6), child: Text('Formulario')),
          },
          onValueChanged: (v) => _vm.formView.value = (v ?? 0) == 1,
        );
      },
    );
  }

  Widget _toolsBar(GridnoteTheme t) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: _vm.isBusy,
          builder: (_, busy, __) {
            return OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                final src = await showModalBottomSheet<String>(
                  context: context,
                  showDragHandle: true,
                  builder: (ctx) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const ListTile(title: Text('Importar tabla por OCR')),
                        ListTile(
                          leading: const Icon(Icons.photo_camera_outlined),
                          title: const Text('Usar cámara'),
                          onTap: () => Navigator.pop(ctx, 'camera'),
                        ),
                        ListTile(
                          leading: const Icon(Icons.photo_library_outlined),
                          title: const Text('Elegir de galería'),
                          onTap: () => Navigator.pop(ctx, 'gallery'),
                        ),
                      ],
                    ),
                  ),
                );
                if (src == null) return;
                if (src == 'camera') {
                  await _vm.importOcrFromCamera();
                } else {
                  await _vm.importOcrFromGallery();
                }
              },
              icon: const Icon(Icons.document_scanner_outlined),
              label: const Text('Importar (OCR)'),
            );
          },
        ),
        OutlinedButton.icon(
          onPressed: () => showChartDialog(context, _visibleRowsNow()),
          icon: const Icon(Icons.show_chart_outlined),
          label: const Text('Gráfico'),
        ),
        // Extras: Fotos / Guardar / Ajustes
        OutlinedButton.icon(
          onPressed: () {
            _snack('Abrir fotos (galería / cámara)');
          },
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Fotos'),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            try {
              await OutboxService.instance.flush();
              _snack('Cambios guardados');
            } catch (_) {
              _snack('No se pudo guardar ahora');
            }
          },
          icon: const Icon(Icons.save_outlined),
          label: const Text('Guardar'),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          },
          icon: const Icon(Icons.settings_outlined),
          label: const Text('Ajustes'),
        ),
        _isIOS
            ? _iosViewSegment()
            : ValueListenableBuilder<bool>(
          valueListenable: _vm.formView,
          builder: (_, isForm, __) {
            return FilterChip(
              label: const Text('Vista formulario'),
              selected: isForm,
              onSelected: (v) => _vm.formView.value = v,
            );
          },
        ),
      ],
    );
  }

  Widget _buildHeader(GridnoteTheme t, GridnoteTableStyle table) {
    final titleWidget = ValueListenableBuilder<String>(
      valueListenable: _vm.title,
      builder: (_, title, __) {
        return GestureDetector(
          onTap: () async {
            _titleCtrl.text = title;
            final txt = await showDialog<String>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Editar título'),
                content: TextField(
                  controller: _titleCtrl,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(hintText: 'Nuevo título'),
                  onSubmitted: (_) => Navigator.pop(ctx, _titleCtrl.text.trim()),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                  FilledButton(onPressed: () => Navigator.pop(ctx, _titleCtrl.text.trim()), child: const Text('Guardar')),
                ],
              ),
            );
            if (txt != null) await _vm.saveTitle(txt);
          },
          child: Text(
            title.isEmpty ? ' ' : title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
        );
      },
    );

    final search = _isIOS
        ? CupertinoSearchTextField(
      controller: _searchCtrl,
      placeholder: 'Buscar en la planilla...',
      onChanged: (v) => _vm.setQueryDebounced(v),
    )
        : TextField(
      controller: _searchCtrl,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => FocusScope.of(context).unfocus(),
      onChanged: (v) => _vm.setQueryDebounced(v),
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.search),
        hintText: 'Buscar en la planilla...',
        isDense: true,
        border: OutlineInputBorder(),
      ),
    );

    final locBtn = ValueListenableBuilder2<double?, double?>(
      first: _vm.lat,
      second: _vm.lng,
      builder: (_, la, lo, __) {
        final hasLoc = la != null && lo != null;
        return ValueListenableBuilder<bool>(
          valueListenable: _vm.isBusy,
          builder: (_, busy, __) {
            return OutlinedButton.icon(
              style: _chipStyle(t.surface),
              onPressed: busy ? null : (hasLoc ? _showLocationSheet : _vm.saveLocation),
              icon: busy
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(hasLoc ? Icons.check_circle : Icons.place_outlined),
              label: Text(hasLoc ? 'Ubicación guardada' : 'Guardar ubicación'),
            );
          },
        );
      },
    );

    final counts = ValueListenableBuilder2<List<Measurement>, String>(
      first: _vm.measurements,
      second: _vm.searchQuery,
      builder: (_, rows, q, __) {
        final visible = _visibleRowsNow().length;
        final total = rows.length;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: table.gridLine),
          ),
          child: Text(
            '$visible / $total',
            style: TextStyle(
              fontFeatures: const [FontFeature.tabularFigures()],
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .9),
            ),
          ),
        );
      },
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: table.gridLine),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: titleWidget),
                  const SizedBox(width: 8),
                  Flexible(fit: FlexFit.loose, child: search),
                  const SizedBox(width: 8),
                  counts,
                  const SizedBox(width: 8),
                  _shareMenuButton(),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Flexible(fit: FlexFit.loose, child: locBtn),
                  const SizedBox(width: 8),
                  Expanded(child: _toolsBar(t)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Placeholder para “editor avanzado” de encabezados
  void _editHeader(String field) {
    _snack('Editar encabezado: $field');
  }

  @override
  Widget build(BuildContext context) {
    // Quitamos AnimatedBuilder: algunos ThemeControllers no son Listenable.
    final t = widget.themeController.theme;
    final table = GridnoteTableStyle.from(t);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: t.scaffold,
      appBar: AppBar(
        centerTitle: _isIOS,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: t.surface.withValues(alpha: .65)),
          ),
        ),
        title: ValueListenableBuilder<String>(
          valueListenable: _vm.title,
          builder: (_, title, __) => Text(title.isEmpty ? ' ' : title, overflow: TextOverflow.ellipsis),
        ),
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: _vm.canUndo,
            builder: (_, canUndo, __) {
              if (!canUndo) return const SizedBox.shrink();
              return IconButton(
                tooltip: 'Deshacer',
                onPressed: _vm.undoLast,
                icon: const Icon(Icons.undo),
              );
            },
          ),
          if (_isIOS)
            ValueListenableBuilder<bool>(
              valueListenable: _vm.isBusy,
              builder: (_, busy, __) => IconButton(
                tooltip: 'Agregar fila',
                onPressed: busy ? null : _vm.addRow,
                icon: const Icon(CupertinoIcons.add_circled),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: ValueListenableBuilder<bool>(
            valueListenable: _vm.isBusy,
            builder: (_, busy, __) => busy ? const LinearProgressIndicator(minHeight: 2) : const SizedBox(height: 2),
          ),
        ),
      ),
      body: Container(
        color: table.cellBg,
        child: Column(
          children: [
            _buildHeader(t, table),
            Expanded(
              child: ValueListenableBuilder<bool>(
                valueListenable: _vm.formView,
                builder: (_, form, __) {
                  if (form) {
                    return ValueListenableBuilder<List<Measurement>>(
                      valueListenable: _vm.measurements,
                      builder: (_, rows, __) {
                        return FormView(
                          rows: rows,
                          suggest: getIt<SuggestService>(),
                          rules: defaultRules(),
                          onChanged: (next) => _vm.replaceRows(next),
                        );
                      },
                    );
                  }

                  // GRID NUEVA (MeasurementDataGrid)
                  return ValueListenableBuilder2<List<Measurement>, String>(
                    first: _vm.measurements,
                    second: _vm.searchQuery,
                    builder: (_, rows, q, __) {
                      return mg.MeasurementDataGrid(
                        meta: widget.meta,
                        initial: rows,
                        themeController: widget.themeController,
                        controller: _grid,
                        onChanged: (next) => _vm.replaceRows(next),
                        headerTitles: const {
                          MeasurementColumn.progresiva: 'Progresiva',
                          MeasurementColumn.ohm1m: '1m (O)',
                          MeasurementColumn.ohm3m: '3m (O)',
                          MeasurementColumn.observations: 'Obs',
                          MeasurementColumn.date: 'Fecha',
                        },
                        onEditHeader: _editHeader,
                        onHeaderTitleChanged: (field, title) {
                          // persistir título si querés
                        },
                        onOpenMaps: (m) {
                          final la = m.latitude, lo = m.longitude;
                          if (la != null && lo != null) {
                            _vm.openMapsFor(latParam: la, lngParam: lo);
                          }
                        },
                        filterQuery: q,
                        aiEnabled: kAiEnabled,
                        showPhotoRail: true,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _isIOS
          ? null
          : ValueListenableBuilder<bool>(
        valueListenable: _vm.isBusy,
        builder: (_, busy, __) => FloatingActionButton.extended(
          onPressed: busy ? null : _vm.addRow,
          icon: const Icon(Icons.add),
          label: const Text('Agregar fila'),
          backgroundColor: t.accent,
        ),
      ),
    );
  }
}
