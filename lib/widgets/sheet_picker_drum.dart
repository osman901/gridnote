import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../models/sheet_meta.dart';

/// Devuelve la planilla elegida o null si cancelan.
Future<SheetMeta?> showSheetDrumPicker({
  required BuildContext context,
  required List<SheetMeta> sheets,
  int initialIndex = 0,
  String title = 'Elegí una planilla',
  String confirmText = 'Abrir',
  String cancelText = 'Cancelar',
}) async {
  if (sheets.isEmpty) return null;

  final start = initialIndex.clamp(0, sheets.length - 1);
  final controller = FixedExtentScrollController(initialItem: start);
  var index = start;

  return showCupertinoModalPopup<SheetMeta>(
    context: context,
    builder: (_) => SafeArea(
      top: false,
      child: Container(
        height: 320,
        decoration: const BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    onPressed: () => Navigator.pop(context, null),
                    child: Text(cancelText),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  CupertinoButton.filled(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      Navigator.pop(context, sheets[index]);
                    },
                    child: Text(confirmText),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: CupertinoPicker(
                itemExtent: 44,
                magnification: 1.06,
                squeeze: 1.1,
                useMagnifier: true,
                scrollController: controller,
                onSelectedItemChanged: (i) {
                  index = i;
                  // vibra en cada “click” del tambor
                  HapticFeedback.selectionClick();
                },
                children: [
                  for (final s in sheets)
                    Center(
                      child: Text(
                        s.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
