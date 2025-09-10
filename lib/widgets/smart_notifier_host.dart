// Gridnote · SmartNotifierHost (banner discreto, animado, evita teclado)
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/ux/smart_notifier.dart';
import '../services/ux/activity_tracker.dart';

class SmartNotifierHost extends StatefulWidget {
  final Widget child;
  const SmartNotifierHost({super.key, required this.child});

  @override
  State<SmartNotifierHost> createState() => _SmartNotifierHostState();
}

class _SmartNotifierHostState extends State<SmartNotifierHost> with SingleTickerProviderStateMixin {
  final _notifier = SmartNotifier.instance;
  SmartToast? _current;
  Timer? _autoClose;

  @override
  void initState() {
    super.initState();
    _notifier.visibleToast.addListener(_onToastChanged);
  }

  @override
  void dispose() {
    _autoClose?.cancel();
    _notifier.visibleToast.removeListener(_onToastChanged);
    super.dispose();
  }

  void _onToastChanged() {
    _autoClose?.cancel();
    setState(() => _current = _notifier.visibleToast.value);
    if (_current != null) {
      _autoClose = Timer(_current!.duration, () {
        if (!mounted) return;
        _notifier.hideCurrent();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Captura de toques globales para informar actividad
    return Listener(
      onPointerDown: (_) => ActivityTracker.instance.pointerPulse(),
      onPointerSignal: (_) => ActivityTracker.instance.pointerPulse(),
      child: Stack(
        children: [
          widget.child,
          // Banner
          Positioned.fill(
            child: IgnorePointer(
              ignoring: true,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
                child: _current == null ? const SizedBox.shrink() : _ToastCard(data: _current!),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToastCard extends StatelessWidget {
  final SmartToast data;
  const _ToastCard({required this.data});

  Color _bg(BuildContext context) {
    switch (data.kind) {
      case SmartKind.success:
        return Colors.green.withOpacity(0.95);
      case SmartKind.warning:
        return Colors.orange.withOpacity(0.95);
      case SmartKind.error:
        return Colors.red.withOpacity(0.95);
      case SmartKind.info:
      default:
        return Colors.black.withOpacity(0.9);
    }
  }

  IconData _icon() {
    switch (data.kind) {
      case SmartKind.success:
        return Icons.check_circle;
      case SmartKind.warning:
        return Icons.warning_amber_rounded;
      case SmartKind.error:
        return Icons.error;
      case SmartKind.info:
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewInsetsOf(context); // evita tapar teclado
    final bottomPad = (insets.bottom > 0 ? insets.bottom + 8 : 24).toDouble();

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(left: 16, right: 16, bottom: bottomPad),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _bg(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_icon(), color: Colors.white),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    data.message,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
