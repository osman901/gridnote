// lib/screens/initial_loading_screen.dart
import 'package:flutter/material.dart';
import '../theme/gridnote_theme.dart';
import '../widgets/arrow_loader.dart';

class InitialLoadingScreen extends StatefulWidget {
  const InitialLoadingScreen({
    super.key,
    required this.themeController,
    this.boot, // tareas de arranque opcionales
    this.nextRoute = '/home',
    this.minShow = const Duration(milliseconds: 1200),
  });

  final GridnoteThemeController themeController;
  final Future<void> Function()? boot;
  final String nextRoute;
  final Duration minShow;

  @override
  State<InitialLoadingScreen> createState() => _InitialLoadingScreenState();
}

class _InitialLoadingScreenState extends State<InitialLoadingScreen> {
  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    await Future.wait([
      if (widget.boot != null) widget.boot!(),
      Future.delayed(widget.minShow),
    ]);
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(widget.nextRoute);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF101820), Color(0xFF0F2B1F)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ArrowLoader(size: 160),
              const SizedBox(height: 18),
              _ShimmerText(
                text: 'Cargando Gridnote…',
                color: cs.onPrimary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShimmerText extends StatefulWidget {
  const _ShimmerText({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  State<_ShimmerText> createState() => _ShimmerTextState();
}

class _ShimmerTextState extends State<_ShimmerText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final faded = widget.color.withValues(alpha: 0.25);

    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        return ShaderMask(
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment(-1 + _c.value * 2, 0),
            end: Alignment(1 + _c.value * 2, 0),
            colors: [faded, widget.color, faded],
            stops: const [0.25, 0.5, 0.75],
          ).createShader(rect),
          blendMode: BlendMode.srcIn,
          child: Text(
            widget.text,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        );
      },
    );
  }
}
