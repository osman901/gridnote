import 'package:flutter/material.dart';

class FabAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  FabAction({required this.icon, required this.label, required this.onTap});
}

class ExpandableFab extends StatefulWidget {
  const ExpandableFab({
    super.key,
    required this.actions,
    this.distance = 68, // separaciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n vertical entre botones
    this.mainTooltip = 'Acciones',
  });

  final List<FabAction> actions;
  final double distance;
  final String mainTooltip;

  @override
  State<ExpandableFab> createState() => _ExpandableFabState();
}

class _ExpandableFabState extends State<ExpandableFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  late final Animation<double> _fade;
  late final Animation<double> _rotate;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _fade = CurvedAnimation(parent: _ctl, curve: Curves.easeOut);
    _rotate = Tween<double>(begin: 0, end: 0.125).animate(_ctl); // +45ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â°
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    if (_open) {
      _ctl.forward();
    } else {
      _ctl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ocupa toda la pantalla para poder poner la barrera tÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡ctil
    return SizedBox.expand(
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          // Barrera para cerrar al tocar afuera
          IgnorePointer(
            ignoring: !_open,
            child: GestureDetector(
              onTap: _toggle,
              child: AnimatedBuilder(
                animation: _fade,
                builder: (_, __) => Container(
                  color: Colors.black.withValues(alpha: 0.18 * _fade.value),
                ),
              ),
            ),
          ),
          // Botones de acciones (suben en columna)
          ...List.generate(widget.actions.length, (i) {
            final action = widget.actions[i];
            return _ExpandingActionButton(
              indexFromBottom: i + 1,
              distance: widget.distance,
              fade: _fade,
              child: _ActionChipButton(
                icon: action.icon,
                label: action.label,
                onTap: () {
                  _toggle();
                  action.onTap();
                },
              ),
            );
          }),
          // FAB principal
          Padding(
            padding: const EdgeInsets.only(right: 16, bottom: 16),
            child: Tooltip(
              message: widget.mainTooltip,
              child: FloatingActionButton(
                heroTag: 'fab-main',
                onPressed: _toggle,
                child: AnimatedBuilder(
                  animation: _rotate,
                  builder: (_, __) => Transform.rotate(
                    angle: 3.14159 * 2 * _rotate.value,
                    child: Icon(_open ? Icons.close : Icons.add),
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

class _ExpandingActionButton extends StatelessWidget {
  const _ExpandingActionButton({
    required this.indexFromBottom,
    required this.distance,
    required this.fade,
    required this.child,
  });

  final int indexFromBottom; // 1 = primer botÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n arriba del FAB principal
  final double distance;
  final Animation<double> fade;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final offset = indexFromBottom * distance + 16; // +16 de padding
    return Positioned(
      right: 16,
      bottom: offset,
      child: FadeTransition(
        opacity: fade,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
              .animate(fade),
          child: child,
        ),
      ),
    );
  }
}

class _ActionChipButton extends StatelessWidget {
  const _ActionChipButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface.withValues(alpha: 0.95),
      elevation: 3,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
