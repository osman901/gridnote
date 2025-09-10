// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import './core/gn_shader_warmup.dart';
import './core/gn_scroll_behavior.dart';
import './core/loading.dart';
import './screens/beta_sheet_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PaintingBinding.shaderWarmUp = const GridnoteShaderWarmUp();

  await initializeDateFormatting('es_AR', null);
  Intl.defaultLocale = 'es_AR';

  configureLoading(); // ahora es no-op
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bitácora',
      debugShowCheckedModeBanner: false,
      builder: (context, child) => child!, // <- sin EasyLoading
      scrollBehavior: const GNScrollBehavior(alwaysBounce: true),
      themeMode: ThemeMode.dark,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es', 'AR')],
      home: const BetaSheetScreen(),
    );
  }
}
