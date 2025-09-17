import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingGate extends StatefulWidget {
  const OnboardingGate({super.key, required this.child, required this.onboarding});
  final Widget child;
  final Widget onboarding;

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  static const _kKey = 'onboarding_done_v1';
  bool? _done;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((sp) {
      setState(() => _done = sp.getBool(_kKey) ?? false);
    });
  }

  Future<void> _complete() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kKey, true);
    if (mounted) setState(() => _done = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_done == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_done == true) return widget.child;
    return Scaffold(
      body: Stack(
        children: [
          widget.onboarding,
          Positioned(
            right: 16,
            bottom: 24,
            child: FilledButton.icon(
              onPressed: _complete,
              icon: const Icon(Icons.check),
              label: const Text('Empezar'),
            ),
          ),
        ],
      ),
    );
  }
}
