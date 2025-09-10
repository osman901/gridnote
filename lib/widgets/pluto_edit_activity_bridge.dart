// Bridge: engancha eventos de PlutoGrid a ActivityTracker (edición/tipeo).
// Compila con PlutoGrid 8.x. Usa Timer (no Future.cancel) y stateManager.isEditing.
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:pluto_grid/pluto_grid.dart';
import '../services/ux/activity_tracker.dart';

class PlutoEditActivityBridge {
  PlutoEditActivityBridge(this.manager) {
    manager.addListener(_onChange);
  }

  final PlutoGridStateManager manager;
  Timer? _typingTimer;

  /// Llamá esto desde PlutoGrid.onChanged
  void handleOnChanged(PlutoGridOnChangedEvent e) {
    ActivityTracker.instance.setTyping(true);
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(milliseconds: 800), () {
      ActivityTracker.instance.setTyping(false);
    });
    ActivityTracker.instance.pointerPulse();
  }

  void _onChange() {
    final hasFocus = manager.hasFocus;
    final editing = hasFocus && (manager.isEditing == true);
    ActivityTracker.instance.setEditing(editing);
    if (hasFocus) ActivityTracker.instance.pointerPulse();
  }

  void dispose() {
    _typingTimer?.cancel();
    manager.removeListener(_onChange);
  }
}
