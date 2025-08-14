// lib/splash/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:gridnote/widgets/arrow_loader.dart'; // ← usa package: para evitar paths rotos

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onReady});
  final Future<void> Function() onReady;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await Future.wait([
      widget.onReady(),
      Future.delayed(const Duration(milliseconds: 1200)),
    ]);
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  Widget build(BuildContext context) {
    final bg = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF101820), Color(0xFF0F2B1F)],
    );

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: bg),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ArrowLoader(size: 160),
              const SizedBox(height: 18),
              const _ShimmerText('Cargando Gridnote…'),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShimmerText extends StatefulWidget {
  const _ShimmerText(this.text);
  final String text;

  @override
  State<_ShimmerText> createState() => _ShimmerTextState();
}

class _ShimmerTextState extends State<_ShimmerText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat();

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
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment(-1 + _c.value * 2, 0),
            end: Alignment(1 + _c.value * 2, 0),
            colors: const [Colors.white24, Colors.white, Colors.white24],
            stops: const [0.25, 0.5, 0.75],
          ).createShader(rect),
          blendMode: BlendMode.srcIn,
          child: const Text(
            'Cargando Gridnote…',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.3),
          ),
        );
      },
    );
  }
}
