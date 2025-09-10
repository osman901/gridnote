// lib/main.dart
import 'dart:ui' show PointerDeviceKind, PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/gn_perf.dart';
import 'models/sheet_meta_hive.dart' as sheet_hive;
import 'screens/home_screen.dart';
import 'services/outbox_service.dart';
import 'theme/gridnote_theme.dart';
import 'services/service_locator.dart';
import 'services/notification_service.dart';
import 'auth_gate.dart';
import 'services/ai_service.dart';
import 'widgets/smart_notifier_host.dart';

// 👇 NUEVO: gate de licencia
import 'widgets/license_gate.dart';

class GNScrollBehavior extends MaterialScrollBehavior {
  const GNScrollBehavior({this.alwaysBounce = false});
  final bool alwaysBounce;

  @override
  Widget buildOverscrollIndicator(
      BuildContext context,
      Widget child,
      ScrollableDetails details,
      ) =>
      child;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    final p = getPlatform(context);
    final isCupertino = p == TargetPlatform.iOS || p == TargetPlatform.macOS;
    return isCupertino || alwaysBounce
        ? const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics())
        : const ClampingScrollPhysics();
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  final l = PlatformDispatcher.instance.locale;
  final code =
  l.countryCode == null ? l.languageCode : '${l.languageCode}_${l.countryCode}';
  Intl.defaultLocale = code;
  await initializeDateFormatting(code);

  bool handlingFlutterError = false, handlingPlatformError = false;
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

  ErrorWidget.builder = (details) => Material(
    color: Colors.transparent,
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Card(
          color: Colors.red.withValues(alpha: .08),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Ocurrió un problema.\n${details.exceptionAsString()}',
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    ),
  );

  await GNPerf.bootstrap(imageCacheMb: 256);

  await Hive.initFlutter();
  try {
    final metaAdapter = sheet_hive.SheetMetaHiveAdapter();
    if (!Hive.isAdapterRegistered(metaAdapter.typeId)) {
      Hive.registerAdapter(metaAdapter);
    }
  } catch (_) {}

  await setupServiceLocator();
  _configureLoading();

  // IA
  await AiService.instance.init();

  // Firebase
  await Firebase.initializeApp();

  runApp(const ProviderScope(child: MyApp()));
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await OutboxService.open(autoFlushOnConnectivity: true);
    await NotificationService.instance.init();
  });
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
    final licenseId = dotenv.maybeGet('LICENSE_ID') ?? 'trial-demo'; // 👈 lee .env
    return AnimatedBuilder(
      animation: _theme,
      builder: (_, __) {
        final t = _theme.theme;
        return MaterialApp(
          title: 'Bitácora',
          debugShowCheckedModeBanner: false,
          themeMode: ThemeMode.dark,
          scrollBehavior: const GNScrollBehavior(alwaysBounce: true),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('es'), Locale('es', 'AR'), Locale('en')],
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: t.scaffold,
            colorScheme: ColorScheme.fromSeed(
              seedColor: t.accent,
              brightness: Brightness.dark,
              primary: t.accent,
            ),
            appBarTheme:
            AppBarTheme(backgroundColor: t.surface, foregroundColor: t.text, elevation: 0),
            cardColor: t.surface,
            dividerColor: t.divider,
            textTheme: const TextTheme().apply(bodyColor: t.text, displayColor: t.text),
            pageTransitionsTheme: const PageTransitionsTheme(builders: {
              TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
              TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
              TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
              TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
              TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
              TargetPlatform.fuchsia: FadeUpwardsPageTransitionsBuilder(),
            }),
          ),
          builder: (context, child) {
            final easy = EasyLoading.init()(context, child);
            final content = GestureDetector(
              onTap: () {
                final f = FocusManager.instance.primaryFocus;
                if (f != null && f.hasFocus) f.unfocus();
              },
              behavior: HitTestBehavior.deferToChild,
              child: easy,
            );
            return SmartNotifierHost(child: content);
          },
          // 👇 Envuelve todo con el LicenseGate
          home: LicenseGate(
            licenseId: licenseId,
            child: AuthGate(child: HomeScreen(theme: _theme)),
          ),
        );
      },
    );
  }
}
