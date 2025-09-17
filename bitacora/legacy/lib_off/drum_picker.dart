// lib/widgets/drum_picker.dart
//
// Drum picker con animaciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n suave, bÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âºsqueda, segmentos,
// "Guardar comoÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¦", renombrar, elegir emoji y eliminar.
// Listo para Flutter 3.32+.

import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/sheet_meta.dart';

// ====== Callbacks / helpers ======

typedef SheetCreator = Future<SheetMeta?> Function();
typedef SubtitleBuilder = String Function(SheetMeta);
typedef SaveAsHandler = Future<SheetMeta?> Function(SheetMeta from, String newName);
typedef RenameHandler = Future<SheetMeta?> Function(SheetMeta meta, String newName);
typedef DeleteHandler = Future<bool> Function(SheetMeta meta);

class DrumPickerStrings {
  final String cancel, open, searchPlaceholder, noSheets, createFirst, newSheet, creating;
  final String tooltipClose, tooltipOpen, tooltipSearch, tooltipHideSearch, errorCreate;
  final String saveAs, nameHint, segmentAll;
  // Nuevos
  final String rename, delete, emoji, deleteConfirmTitle, deleteConfirmMsg, ok;

  const DrumPickerStrings({
    required this.cancel,
    required this.open,
    required this.searchPlaceholder,
    required this.noSheets,
    required this.createFirst,
    required this.newSheet,
    required this.creating,
    required this.tooltipClose,
    required this.tooltipOpen,
    required this.tooltipSearch,
    required this.tooltipHideSearch,
    required this.errorCreate,
    required this.saveAs,
    required this.nameHint,
    required this.segmentAll,
    required this.rename,
    required this.delete,
    required this.emoji,
    required this.deleteConfirmTitle,
    required this.deleteConfirmMsg,
    required this.ok,
  });

  const DrumPickerStrings.es()
      : cancel = 'Cancelar',
        open = 'Abrir',
        searchPlaceholder = 'Buscar planillas',
        noSheets = 'No hay planillas',
        createFirst = 'CreÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡ la primera para empezar',
        newSheet = 'Nueva planilla',
        creating = 'CreandoÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¦',
        tooltipClose = 'Cerrar',
        tooltipOpen = 'Abrir planilla',
        tooltipSearch = 'Buscar',
        tooltipHideSearch = 'Ocultar bÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âºsqueda',
        errorCreate = 'Error: No se pudo crear la planilla',
        saveAs = 'Guardar comoÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¦',
        nameHint = 'Nombre de la planilla',
        segmentAll = 'Todas',
        rename = 'Renombrar',
        delete = 'Eliminar',
        emoji = 'Emoji',
        deleteConfirmTitle = 'ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂEliminar planilla?',
        deleteConfirmMsg = 'Esta acciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n no se puede deshacer.',
        ok = 'Aceptar';
}

/// Segmento para modo masivo (agrupa planillas).
class SheetSegment {
  final String id;
  final String title;
  final bool Function(SheetMeta) test;
  const SheetSegment(this.id, this.title, this.test);
}

// ====== API de apertura ======

Future<SheetMeta?> showSheetDrumPickerThemed({
  required BuildContext context,
  required List<SheetMeta> items,
  required SheetMeta? initial,
  required String title,
  SheetCreator? onCreateNew,
  SubtitleBuilder? subtitleBuilder,
  DrumPickerStrings? strings,
  List<SheetSegment>? segments,
  String? initialSegmentId,
  SaveAsHandler? onSaveAs,
  RenameHandler? onRename,
  DeleteHandler? onDelete,
  List<String>? emojiChoices,
}) {
  final cs = Theme.of(context).colorScheme;
  return showSheetDrumPicker(
    context: context,
    items: items,
    initial: initial,
    title: title,
    accent: cs.primary,
    textColor: cs.onSurface,
    surface: cs.surface,
    divider: Theme.of(context).dividerColor,
    onCreateNew: onCreateNew,
    subtitleBuilder: subtitleBuilder,
    strings: strings,
    segments: segments,
    initialSegmentId: initialSegmentId,
    onSaveAs: onSaveAs,
    onRename: onRename,
    onDelete: onDelete,
    emojiChoices: emojiChoices,
  );
}

List<SheetMeta> filterSheets(
    List<SheetMeta> all,
    String query, {
      SubtitleBuilder? subtitleBuilder,
      bool Function(SheetMeta)? extraTest,
    }) {
  final q = query.trim().toLowerCase();
  final out = <SheetMeta>[];
  for (final m in all) {
    if (extraTest != null && !extraTest(m)) continue;
    if (q.isEmpty) {
      out.add(m);
      continue;
    }
    final name = m.name.toLowerCase();
    final sub = (subtitleBuilder?.call(m) ?? '').toLowerCase();
    final id = m.id.toLowerCase();
    if (name.contains(q) || sub.contains(q) || id.contains(q)) out.add(m);
  }
  return out;
}

Future<SheetMeta?> showSheetDrumPicker({
  required BuildContext context,
  required List<SheetMeta> items,
  required SheetMeta? initial,
  required String title,
  required Color accent,
  required Color textColor,
  required Color surface,
  required Color divider,
  SheetCreator? onCreateNew,
  SubtitleBuilder? subtitleBuilder,
  DrumPickerStrings? strings,
  List<SheetSegment>? segments,
  String? initialSegmentId,
  SaveAsHandler? onSaveAs,
  RenameHandler? onRename,
  DeleteHandler? onDelete,
  List<String>? emojiChoices,
}) {
  return showModalBottomSheet<SheetMeta>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: .25),
    useSafeArea: true,
    routeSettings: const RouteSettings(name: 'sheet_drum_picker'),
    builder: (_) => _SheetDrumPickerSheet(
      items: items,
      initial: initial,
      title: title,
      accent: accent,
      textColor: textColor,
      surface: surface,
      divider: divider,
      onCreateNew: onCreateNew,
      subtitleBuilder: subtitleBuilder,
      strings: strings ?? const DrumPickerStrings.es(),
      segments: segments,
      initialSegmentId: initialSegmentId,
      onSaveAs: onSaveAs,
      onRename: onRename,
      onDelete: onDelete,
      emojiChoices: emojiChoices ??
          const ['ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¹', 'ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸Ãƒâ€šÃ‚Â§Ãƒâ€šÃ‚Âª', 'ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œÃƒâ€šÃ‚Â¦', 'ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œÃƒâ€šÃ‚Â¸', 'ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œÃƒâ€šÃ‚Â', 'ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã¢â‚¬Å“ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦', 'ÃƒÆ’Ã‚Â¢Ãƒâ€šÃ‚Â­Ãƒâ€šÃ‚ÂÃƒÆ’Ã‚Â¯Ãƒâ€šÃ‚Â¸Ãƒâ€šÃ‚Â', 'ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸Ãƒâ€šÃ‚Â§Ãƒâ€šÃ‚Â¾', 'ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒâ€šÃ‚Â§', 'ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬ÂÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã‚Â¯Ãƒâ€šÃ‚Â¸Ãƒâ€šÃ‚Â'],
    ),
  );
}

// ====== Hoja ======

class _SheetDrumPickerSheet extends StatefulWidget {
  const _SheetDrumPickerSheet({
    required this.items,
    required this.initial,
    required this.title,
    required this.accent,
    required this.textColor,
    required this.surface,
    required this.divider,
    required this.strings,
    this.onCreateNew,
    this.subtitleBuilder,
    this.segments,
    this.initialSegmentId,
    this.onSaveAs,
    this.onRename,
    this.onDelete,
    this.emojiChoices = const [],
  });

  final List<SheetMeta> items;
  final SheetMeta? initial;
  final String title;
  final Color accent, textColor, surface, divider;
  final DrumPickerStrings strings;
  final SheetCreator? onCreateNew;
  final SubtitleBuilder? subtitleBuilder;
  final List<SheetSegment>? segments;
  final String? initialSegmentId;
  final SaveAsHandler? onSaveAs;
  final RenameHandler? onRename;
  final DeleteHandler? onDelete;
  final List<String> emojiChoices;

  @override
  State<_SheetDrumPickerSheet> createState() => _SheetDrumPickerSheetState();
}

class _SheetDrumPickerSheetState extends State<_SheetDrumPickerSheet> {
  static const double _baseItemExtent = 72.0;
  double _itemExtentFor(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1.0);
    return _baseItemExtent + (scale - 1.0) * 18.0;
  }

  late final ValueNotifier<List<SheetMeta>> _all =
  ValueNotifier<List<SheetMeta>>(List<SheetMeta>.from(widget.items));
  late final ValueNotifier<List<SheetMeta>> _view =
  ValueNotifier<List<SheetMeta>>(List<SheetMeta>.from(widget.items));

  late final TextEditingController _searchCtrl = TextEditingController();
  late final ValueNotifier<bool> _searching = ValueNotifier<bool>(false);
  late final ValueNotifier<bool> _busy = ValueNotifier<bool>(false);

  late final List<SheetSegment> _segments = (widget.segments?.isNotEmpty ?? false)
      ? widget.segments!
      : [SheetSegment('all', widget.strings.segmentAll, (_) => true)];
  late String _segmentId = widget.initialSegmentId ?? _segments.first.id;

  int _initialIndex(List<SheetMeta> list) {
    if (list.isEmpty || widget.initial == null) return 0;
    final i = list.indexWhere((e) => e.id == widget.initial!.id);
    return i < 0 ? 0 : i.clamp(0, list.length - 1);
  }

  late final FixedExtentScrollController _controller =
  FixedExtentScrollController(initialItem: _initialIndex(_view.value));
  late final ValueNotifier<int> _selected =
  ValueNotifier<int>(_initialIndex(_view.value));

  Timer? _debounce;
  bool _popped = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _selected.dispose();
    _view.dispose();
    _all.dispose();
    _searchCtrl.dispose();
    _searching.dispose();
    _busy.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _hSel() {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      HapticFeedback.selectionClick();
    }
  }

  void _hOpen() {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      HapticFeedback.lightImpact();
    }
  }

  void _confirmIndex(BuildContext ctx, int i) {
    if (_popped) return;
    _popped = true;
    final list = _view.value;
    if (!mounted || list.isEmpty || i < 0 || i >= list.length) {
      Navigator.of(ctx).pop<SheetMeta?>(null);
      return;
    }
    _hOpen();
    Navigator.of(ctx).pop<SheetMeta?>(list[i]);
  }

  bool Function(SheetMeta) get _segmentTest =>
      _segments.firstWhere((s) => s.id == _segmentId, orElse: () => _segments.first).test;

  void _applyFilters() {
    final list = filterSheets(
      _all.value,
      _searchCtrl.text,
      subtitleBuilder: widget.subtitleBuilder,
      extraTest: _segmentTest,
    );
    _view.value = list;
    final newIdx = list.isEmpty ? 0 : _selected.value.clamp(0, list.length - 1);
    _selected.value = newIdx;
    if (list.isNotEmpty) _controller.jumpToItem(newIdx);
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _applyFilters);
  }

  // -------- Quick edit --------

  Future<void> _promptRename(SheetMeta m) async {
    final s = widget.strings;
    final ctrl = TextEditingController(text: m.name);
    final newName = await showCupertinoDialog<String?>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text(s.rename),
        content: Column(children: [
          const SizedBox(height: 8),
          CupertinoTextField(autofocus: true, controller: ctrl, placeholder: s.nameHint),
        ]),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(context, null), child: Text(s.cancel)),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              final v = ctrl.text.trim();
              Navigator.pop(context, v.isEmpty ? null : v);
            },
            child: Text(s.ok),
          ),
        ],
      ),
    );
    if (newName == null) return;

    if (widget.onRename != null) {
      final updated = await widget.onRename!(m, newName);
      if (updated != null) {
        _replaceMeta(updated);
        _applyFilters();
      }
    } else {
      _replaceMeta(m.copyWith(name: newName));
      _applyFilters();
    }
    _hSel();
  }

  Future<void> _promptEmoji(SheetMeta m) async {
    if (widget.emojiChoices.isEmpty) return;
    final chosen = await showCupertinoModalPopup<String>(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: Text(widget.strings.emoji),
        actions: [
          SizedBox(
            height: 220,
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6, mainAxisSpacing: 8, crossAxisSpacing: 8,
              ),
              itemCount: widget.emojiChoices.length,
              itemBuilder: (_, i) => CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.pop(context, widget.emojiChoices[i]),
                child: Text(widget.emojiChoices[i], style: const TextStyle(fontSize: 24)),
              ),
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.strings.cancel),
        ),
      ),
    );
    if (chosen == null || chosen.isEmpty) return;

    final newName = _applyEmojiToName(chosen, m.name);
    if (widget.onRename != null) {
      final updated = await widget.onRename!(m, newName);
      if (updated != null) _replaceMeta(updated);
    } else {
      _replaceMeta(m.copyWith(name: newName));
    }
    _applyFilters();
    _hSel();
  }

  String _applyEmojiToName(String emoji, String name) {
    final trimmed = name.trimLeft();
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.isNotEmpty && _looksLikeEmoji(parts.first)) {
      parts[0] = emoji;
      return parts.join(' ');
    }
    return '$emoji $name';
  }

  bool _looksLikeEmoji(String s) => s.runes.length <= 3; // heurÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­stica simple

  Future<void> _confirmDelete(SheetMeta m) async {
    if (widget.onDelete == null) return;
    final s = widget.strings;
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text(s.deleteConfirmTitle),
        content: Text(s.deleteConfirmMsg),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(context, false), child: Text(s.cancel)),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final removed = await widget.onDelete!(m);
    if (removed) {
      final list = List<SheetMeta>.from(_all.value)..removeWhere((e) => e.id == m.id);
      _all.value = list;
      _applyFilters();
      _hSel();
    }
  }

  void _replaceMeta(SheetMeta updated) {
    final list = List<SheetMeta>.from(_all.value);
    final i = list.indexWhere((e) => e.id == updated.id);
    if (i != -1) list[i] = updated;
    _all.value = list;
  }

  Future<void> _showItemActions(SheetMeta m) async {
    final s = widget.strings;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          CupertinoActionSheetAction(onPressed: () { Navigator.pop(context); _promptRename(m); }, child: Text(s.rename)),
          if (widget.onSaveAs != null)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _promptSaveAs(m, s);
              },
              child: Text(s.saveAs),
            ),
          if (widget.emojiChoices.isNotEmpty)
            CupertinoActionSheetAction(onPressed: () { Navigator.pop(context); _promptEmoji(m); }, child: Text(s.emoji)),
          if (widget.onDelete != null)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () { Navigator.pop(context); _confirmDelete(m); },
              child: Text(s.delete),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: Text(s.cancel),
        ),
      ),
    );
  }

  Future<void> _promptSaveAs(SheetMeta base, DrumPickerStrings s) async {
    if (widget.onSaveAs == null) return;
    final ctrl = TextEditingController(text: '${base.name} copia');
    final newName = await showCupertinoDialog<String?>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text(s.saveAs),
        content: Column(
          children: [
            const SizedBox(height: 8),
            CupertinoTextField(controller: ctrl, placeholder: s.nameHint, autofocus: true),
          ],
        ),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(context, null), child: Text(s.cancel)),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              final v = ctrl.text.trim();
              Navigator.pop(context, v.isEmpty ? null : v);
            },
            child: Text(s.ok),
          ),
        ],
      ),
    );
    if (newName == null) return;
    final created = await widget.onSaveAs!(base, newName);
    if (created == null) return;
    final list = List<SheetMeta>.from(_all.value)..insert(0, created);
    _all.value = list;
    _applyFilters();
    _controller.jumpToItem(0);
    _selected.value = 0;
    _hSel();
  }

  // -------- UI --------

  Widget _pillTile(SheetMeta m, bool isSelected, double itemExtent) {
    final sub = widget.subtitleBuilder?.call(m) ?? '';
    final noAnim = MediaQuery.of(context).disableAnimations;
    return TweenAnimationBuilder<double>(
      key: ValueKey('${m.id}_${isSelected ? 1 : 0}'),
      tween: Tween<double>(begin: isSelected ? .97 : .92, end: isSelected ? 1 : .92),
      duration: noAnim ? Duration.zero : const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      builder: (_, scale, __) => Transform.scale(
        scale: scale,
        child: _GlassPill(
          title: m.name,
          subtitle: sub,
          selected: isSelected,
          accent: widget.accent,
          textColor: widget.textColor,
          maxHeight: itemExtent,
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              splashRadius: 18,
              onPressed: () => _promptRename(m),
              icon: const Icon(CupertinoIcons.pencil),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              splashRadius: 18,
              onPressed: () => _showItemActions(m),
              icon: const Icon(CupertinoIcons.ellipsis),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final surface = widget.surface, divider = widget.divider, accent = widget.accent, textColor = widget.textColor;
    final noAnim = MediaQuery.of(context).disableAnimations;
    final d140 = noAnim ? Duration.zero : const Duration(milliseconds: 140);
    final d160 = noAnim ? Duration.zero : const Duration(milliseconds: 160);
    final messenger = ScaffoldMessenger.maybeOf(context);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(color: Colors.black.withValues(alpha: .18)),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: surface.withValues(alpha: .86),
              border: Border(top: BorderSide(color: divider)),
            ),
            child: SafeArea(
              top: false,
              child: Shortcuts(
                shortcuts: const <ShortcutActivator, Intent>{
                  SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
                  SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
                  SingleActivator(LogicalKeyboardKey.arrowUp): _MoveIntent(-1),
                  SingleActivator(LogicalKeyboardKey.arrowDown): _MoveIntent(1),
                },
                child: Actions(
                  actions: <Type, Action<Intent>>{
                    ActivateIntent: CallbackAction<ActivateIntent>(
                      onInvoke: (_) {
                        _confirmIndex(context, _selected.value);
                        return null;
                      },
                    ),
                    DismissIntent: CallbackAction<DismissIntent>(
                      onInvoke: (_) {
                        if (mounted) Navigator.of(context).maybePop();
                        return null;
                      },
                    ),
                    _MoveIntent: CallbackAction<_MoveIntent>(
                      onInvoke: (i) {
                        final list = _view.value;
                        if (list.isEmpty) return null;
                        final next = (_selected.value + i.delta).clamp(0, list.length - 1);
                        if (next != _selected.value) {
                          _controller.animateToItem(next, duration: d140, curve: Curves.easeOutCubic);
                          _selected.value = next;
                          _hSel();
                        }
                        return null;
                      },
                    ),
                  },
                  child: Focus(
                    autofocus: true,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _SheetGrabHandle(),
                        // Top bar
                        SizedBox(
                          height: 52,
                          child: Row(
                            children: [
                              const SizedBox(width: 4),
                              Tooltip(
                                message: s.tooltipClose,
                                child: TextButton(
                                  onPressed: () => Navigator.of(context).maybePop(),
                                  child: Text(s.cancel),
                                ),
                              ),
                              Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.center,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const _SheetIcon(size: 18),
                                      const SizedBox(width: 6),
                                      Text(
                                        widget.title,
                                        overflow: TextOverflow.ellipsis,
                                        softWrap: false,
                                        style: TextStyle(fontWeight: FontWeight.w700, color: textColor),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // "Guardar comoÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¦"
                              ValueListenableBuilder<int>(
                                valueListenable: _selected,
                                builder: (_, sel, __) => IconButton(
                                  tooltip: s.saveAs,
                                  onPressed: widget.onSaveAs == null
                                      ? null
                                      : () {
                                    final list = _view.value;
                                    if (list.isEmpty) return;
                                    _promptSaveAs(list[sel.clamp(0, list.length - 1)], s);
                                  },
                                  icon: const Icon(CupertinoIcons.tray_full),
                                ),
                              ),
                              // Toggle bÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âºsqueda
                              ValueListenableBuilder<bool>(
                                valueListenable: _searching,
                                builder: (_, on, __) => IconButton(
                                  tooltip: on ? s.tooltipHideSearch : s.tooltipSearch,
                                  onPressed: () {
                                    _searching.value = !on;
                                    if (!on) {
                                      _searchCtrl.clear();
                                      _applyFilters();
                                    }
                                  },
                                  icon: Icon(on ? CupertinoIcons.xmark : CupertinoIcons.search),
                                ),
                              ),
                              // Abrir
                              ValueListenableBuilder<int>(
                                valueListenable: _selected,
                                builder: (_, sel, __) => Tooltip(
                                  message: s.tooltipOpen,
                                  child: TextButton(
                                    onPressed: () => _confirmIndex(context, sel),
                                    child: Text(s.open),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                          ),
                        ),
                        Divider(height: 1, color: divider),

                        // Buscador
                        ValueListenableBuilder<bool>(
                          valueListenable: _searching,
                          builder: (_, on, __) => AnimatedCrossFade(
                            duration: d160,
                            crossFadeState: on ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                            firstChild: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: CupertinoSearchTextField(
                                controller: _searchCtrl,
                                placeholder: s.searchPlaceholder,
                                onChanged: _onSearchChanged,
                              ),
                            ),
                            secondChild: const SizedBox.shrink(),
                          ),
                        ),

                        // Segmentos
                        if (_segments.length > 1)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 2),
                            child: CupertinoSlidingSegmentedControl<String>(
                              groupValue: _segmentId,
                              children: {
                                for (final seg in _segments)
                                  seg.id: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                                    child: Text(seg.title),
                                  ),
                              },
                              onValueChanged: (v) {
                                if (v == null) return;
                                setState(() => _segmentId = v);
                                _applyFilters();
                              },
                            ),
                          ),

                        // Crear nueva
                        if (widget.onCreateNew != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: ValueListenableBuilder<bool>(
                                valueListenable: _busy,
                                builder: (_, busy, __) => TextButton.icon(
                                  onPressed: busy
                                      ? null
                                      : () async {
                                    _busy.value = true;
                                    try {
                                      final created = await widget.onCreateNew!.call();
                                      if (!mounted || created == null) return;
                                      final list = List<SheetMeta>.from(_all.value)..insert(0, created);
                                      _all.value = list;
                                      _applyFilters();
                                      if (_searchCtrl.text.isEmpty) {
                                        _controller.jumpToItem(0);
                                        _selected.value = 0;
                                      }
                                      _hSel();
                                    } catch (_) {
                                      messenger?.showSnackBar(
                                        SnackBar(content: Text(widget.strings.errorCreate)),
                                      );
                                    } finally {
                                      if (mounted) _busy.value = false;
                                    }
                                  },
                                  icon: busy
                                      ? const SizedBox(width: 18, height: 18, child: CupertinoActivityIndicator())
                                      : const Icon(CupertinoIcons.add_circled),
                                  label: Text(busy ? s.creating : s.newSheet),
                                ),
                              ),
                            ),
                          ),

                        const SizedBox(height: 6),

                        // Tambor
                        Flexible(
                          child: LayoutBuilder(
                            builder: (context, c) {
                              final itemExtent = _itemExtentFor(context);
                              final desired = itemExtent * 3.6;
                              final minOk = itemExtent * 2.2;
                              final wheelH = desired.clamp(minOk, c.maxHeight);
                              return Center(
                                child: SizedBox(
                                  height: wheelH,
                                  child: Stack(
                                    children: [
                                      // vignettes
                                      Positioned.fill(
                                        child: IgnorePointer(
                                          child: Column(
                                            children: [
                                              Container(
                                                height: 16,
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    begin: Alignment.topCenter,
                                                    end: Alignment.bottomCenter,
                                                    colors: [
                                                      surface.withValues(alpha: .86),
                                                      surface.withValues(alpha: 0),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              const Spacer(),
                                              Container(
                                                height: 16,
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    begin: Alignment.bottomCenter,
                                                    end: Alignment.topCenter,
                                                    colors: [
                                                      surface.withValues(alpha: .86),
                                                      surface.withValues(alpha: 0),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      // picker
                                      ValueListenableBuilder<List<SheetMeta>>(
                                        valueListenable: _view,
                                        builder: (ctx, list, _) {
                                          if (list.isEmpty) {
                                            return _emptyState(textColor, s, widget.onCreateNew != null);
                                          }
                                          return CupertinoPicker.builder(
                                            scrollController: _controller,
                                            itemExtent: itemExtent,
                                            diameterRatio: 1.45,
                                            squeeze: 1.05,
                                            useMagnifier: true,
                                            magnification: 1.045,
                                            selectionOverlay: _IOSSelectionOverlay(
                                              height: itemExtent,
                                              accent: accent,
                                            ),
                                            onSelectedItemChanged: (i) {
                                              if (i != _selected.value) {
                                                _selected.value = i;
                                                _hSel();
                                              }
                                            },
                                            childCount: list.length,
                                            itemBuilder: (ctx, i) {
                                              final m = list[i];
                                              return ValueListenableBuilder<int>(
                                                valueListenable: _selected,
                                                builder: (_, sel, __) {
                                                  final isSel = i == sel;
                                                  return GestureDetector(
                                                    behavior: HitTestBehavior.opaque,
                                                    onTap: () {
                                                      if (isSel) {
                                                        _confirmIndex(context, i);
                                                      } else {
                                                        _controller.animateToItem(
                                                          i,
                                                          duration: d140,
                                                          curve: Curves.easeOutCubic,
                                                        );
                                                      }
                                                    },
                                                    onDoubleTap: () => _confirmIndex(context, i),
                                                    child: Center(child: _pillTile(m, isSel, itemExtent)),
                                                  );
                                                },
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ====== Widgets de apoyo ======

class _MoveIntent extends Intent {
  const _MoveIntent(this.delta);
  final int delta;
}

class _SheetGrabHandle extends StatelessWidget {
  const _SheetGrabHandle();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Center(
        child: Container(
          width: 38,
          height: 5,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .18),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: Colors.white.withValues(alpha: .10)),
          ),
        ),
      ),
    );
  }
}

class _IOSSelectionOverlay extends StatelessWidget {
  const _IOSSelectionOverlay({required this.height, required this.accent});
  final double height;
  final Color accent;
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          height: height,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withValues(alpha: .90), width: 1.5),
          ),
        ),
      ),
    );
  }
}

Widget _emptyState(Color textColor, DrumPickerStrings s, bool showCreateHint) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _SheetIcon(size: 28),
          const SizedBox(height: 10),
          Text(s.noSheets, style: TextStyle(color: textColor.withValues(alpha: .8), fontWeight: FontWeight.w600)),
          if (showCreateHint)
            Text(s.createFirst, style: TextStyle(color: textColor.withValues(alpha: .6), fontSize: 12.5)),
        ],
      ),
    ),
  );
}

class _SheetIcon extends StatelessWidget {
  const _SheetIcon({this.size = 20});
  final double size;
  @override
  Widget build(BuildContext context) {
    return Icon(Icons.description_rounded, size: size, color: Theme.of(context).colorScheme.primary);
  }
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.accent,
    required this.textColor,
    required this.maxHeight,
    this.trailing,
  });

  final String title, subtitle;
  final bool selected;
  final Color accent, textColor;
  final double maxHeight;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final noAnim = MediaQuery.of(context).disableAnimations;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    const double vPad = 6;
    const double titleSize = 16.5;
    const double subtitleSize = 11.5;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight - 8),
      child: AnimatedContainer(
        duration: noAnim ? Duration.zero : const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: vPad),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? accent : accent.withValues(alpha: .35), width: selected ? 2 : 1),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              (isDark ? const Color(0xFF0E1D0E) : const Color(0xFFEBF6EB)).withValues(alpha: isDark ? .45 : .55),
              (isDark ? const Color(0xFF1D3A1D) : const Color(0xFFDFF0DF)).withValues(alpha: isDark ? .35 : .45),
            ],
          ),
          boxShadow: selected
              ? [BoxShadow(color: accent.withValues(alpha: .25), blurRadius: 18, spreadRadius: 1, offset: const Offset(0, 6))]
              : null,
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                    child: Container(color: Colors.white.withValues(alpha: .04)),
                  ),
                ),
              ),
            ),
            if (selected && !noAnim) const _SweepShine(),
            Row(
              children: [
                const _SheetIcon(size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textHeightBehavior: const TextHeightBehavior(
                          applyHeightToFirstAscent: false,
                          applyHeightToLastDescent: false,
                        ),
                        style: TextStyle(
                          color: textColor,
                          fontSize: titleSize,
                          height: 1.00,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .2,
                        ),
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textHeightBehavior: const TextHeightBehavior(
                            applyHeightToFirstAscent: false,
                            applyHeightToLastDescent: false,
                          ),
                          style: TextStyle(
                            color: textColor.withValues(alpha: .72),
                            fontSize: subtitleSize,
                            height: 1.00,
                          ),
                        ),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SweepShine extends StatefulWidget {
  const _SweepShine();
  @override
  State<_SweepShine> createState() => _SweepShineState();
}

class _SweepShineState extends State<_SweepShine> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();

  @override
  void didUpdateWidget(covariant _SweepShine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_c.isAnimating) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        return ShaderMask(
          shaderCallback: (r) {
            final x = r.width * (_c.value - .3);
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.transparent,
                Colors.white.withValues(alpha: .22),
                Colors.transparent,
              ],
              stops: [
                (x / r.width).clamp(0, 1),
                (_c.value).clamp(0, 1),
                ((_c.value) + .15).clamp(0, 1),
              ],
            ).createShader(r);
          },
          blendMode: BlendMode.plus,
          child: const ColoredBox(color: Colors.white),
        );
      },
    );
  }
}
