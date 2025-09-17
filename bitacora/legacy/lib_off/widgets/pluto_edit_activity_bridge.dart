// lib/widgets/pluto_edit_activity_bridge.dart
// Shim sin dependencias de PlutoGrid. Mantiene el sÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­mbolo para no romper imports.

import 'package:flutter/foundation.dart';

/// Puente vacÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­o para compatibilidad tras remover PlutoGrid.
/// No hace nada; sÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³lo evita errores de compilaciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n.
class PlutoEditActivityBridge {
  final VoidCallback? onAnyEdit;

  PlutoEditActivityBridge({this.onAnyEdit});

  /// En caso de que algÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âºn cÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³digo antiguo llame a "attach"/"detach".
  void attach() {}
  void detach() {}

  /// Llamado cuando se edita algo (si querÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©s notificar manualmente).
  void notifyEdited() => onAnyEdit?.call();

  void dispose() {}
}
