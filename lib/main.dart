// lib/main.dart
import 'package:flutter/material.dart';

import 'theme/gridnote_theme.dart';
import 'screens/initial_loading_screen.dart';
import 'screens/measurement_screen.dart';
import 'models/measurement.dart';
import 'models/sheet_meta.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = GridnoteThemeController();
  runApp(GridnoteApp(controller: controller));
}

class GridnoteApp extends StatelessWidget {
  const GridnoteApp({super.key, required this.controller});
  final GridnoteThemeController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Gridnote',
          theme: controller.theme.toThemeData(),
          routes: {
            '/': (_) => InitialLoadingScreen(
              themeController: controller,
              boot: _boot,
              nextRoute: '/home',
            ),
            '/home': (_) => MeasurementScreen(
              id: 'local-1',
              meta: SheetMeta(id: '175507', name: 'Planilla 1'),
              initial: _demoMeasurements(),
              themeController: controller,
            ),
          },
        );
      },
    );
  }
}

Future<void> _boot() async {
  await Future.delayed(const Duration(milliseconds: 300));
}

List<Measurement> _demoMeasurements() => [
  Measurement(
    progresiva: 'A-01', ohm1m: 1.2, ohm3m: 3.4,
    observations: 'OK', date: DateTime.now().subtract(const Duration(days: 2)),
  ),
  Measurement(
    progresiva: 'A-02', ohm1m: 0.9, ohm3m: 2.8,
    observations: 'Vibración leve', date: DateTime.now().subtract(const Duration(days: 1)),
  ),
  Measurement(
    progresiva: 'A-03', ohm1m: 1.5, ohm3m: 3.1,
    observations: '', date: DateTime.now(),
  ),
];
