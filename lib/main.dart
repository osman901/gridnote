// lib/main.dart
import 'dart:ui' show PointerDeviceKind, PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/gn_perf.dart';
import 'models/sheet_meta_hive.dart' as sheet_hive; // Adapter generado
import 'screens/home_screen.dart';
import 'services/outbox_service.dart';
import 'theme/gridnote_theme.dart';
import 'services/service_locator.dart';
import 'services/permissions_service.dart'; // 👈 nuevo

/// Scroll behavior sin glow y con rebote iOS-like en todas las plataformas.
class GNScrollBehavior extends MaterialScrollBehavior {
  const GNScrollBehavior({this.alwaysBounce = false});
  final bool alwaysBounce;

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    final platform = getPlatform(context);
    final isCupertino = platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
    if (isCupertino || alwaysBounce) {
      return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
    }
    return const ClampingScrollPhysics();
  }

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.trackpad,
  };
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Manejo global de errores
  bool handlingFlutterError = false;
  bool handlingPlatformError = false;

  FlutterError.onError = (details) {
    if (handlingFlutterError) return;
    handlingFlutterError = true;
    try {
      FlutterError.presentError(details);
      GNPerf.reportError(details.exception, details.stack ?? StackTrace.current);
    } finally {
      handlingFlutterError = false;
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    if (handlingPlatformError) return true;
    handlingPlatformError = true;
    try {
      GNPerf.reportError(error, stack);
    } finally {
      handlingPlatformError = false;
    }
    return true;
  };

  await GNPerf.bootstrap(imageCacheMb: 256);

  // Hive (solo para metadatos de planillas)
  await Hive.initFlutter();
  try {
    final metaAdapter = sheet_hive.SheetMetaHiveAdapter();
    if (!Hive.isAdapterRegistered(metaAdapter.typeId)) {
      Hive.registerAdapter(metaAdapter);
    }
  } catch (_) {
    // Ejecutá: flutter pub run build_runner build
  }

  await setupServiceLocator();
  _configureLoading();
  await OutboxService.open(autoFlushOnConnectivity: true);

  // 👇 pedir permisos clave (Android 13/14+ para notifs y fotos seleccionadas)
  await PermissionsService.instance.requestStartupPermissions();

  runApp(const ProviderScope(child: MyApp()));
}

void _configureLoading() {
  EasyLoading.instance
    ..indicatorType = EasyLoadingIndicatorType.fadingCircle
    ..maskType = EasyLoadingMaskType.black
    ..userInteractions = false
    ..dismissOnTap = false;
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final GridnoteThemeController _theme = GridnoteThemeController();

  @override
  void dispose() {
    _theme.dispose();
    OutboxService.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _theme,
      builder: (_, __) {
        final t = _theme.theme;
        return MaterialApp(
          title: 'Gridnote Measurements',
          debugShowCheckedModeBanner: false,
          themeMode: ThemeMode.dark,
          scrollBehavior: const GNScrollBehavior(alwaysBounce: true),
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: t.scaffold,
            colorScheme: ColorScheme.fromSeed(
              seedColor: t.accent,
              brightness: Brightness.dark,
              primary: t.accent,
            ),
            appBarTheme: AppBarTheme(
              backgroundColor: t.surface,
              foregroundColor: t.text,
              elevation: 0,
            ),
            cardColor: t.surface,
            dividerColor: t.divider,
            textTheme: const TextTheme().apply(
              bodyColor: t.text,
              displayColor: t.text,
            ),
            pageTransitionsTheme: const PageTransitionsTheme(builders: {
              TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
              TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
              TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
              TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
              TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
              TargetPlatform.fuchsia: FadeUpwardsPageTransitionsBuilder(),
            }),
          ),
          builder: EasyLoading.init(),
          home: HomeScreen(theme: _theme),
        );
      },
    );
  }
}
