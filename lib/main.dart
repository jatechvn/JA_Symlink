// lib/main.dart
// Program entry point for JA Symlink Manager
// Bento Glassmorphism UI with Windows 10/11 Acrylic/Aero blur & MultiProvider

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'layout/dashboard_shell.dart';
import 'modules/app_config.dart';
import 'modules/build_info.dart';
import 'modules/constants.dart';
import 'modules/i18n.dart';
import 'modules/logger_config.dart';
import 'modules/logic.dart';
import 'modules/symlink_service.dart';
import 'theme/theme_provider.dart';
import 'theme/window_effect_helper.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (args.contains('-debug') ||
      args.contains('--debug') ||
      args.contains('-d')) {
    BuildInfo.isCliDebug = true;
  }

  // Initialize logger
  setupLogger();

  // Load config from disk (language preference, theme, etc.)
  await AppConfig.initialize();

  // Initialize window manager
  await windowManager.ensureInitialized();

  // Initialize flutter_acrylic for transparent blur
  await Window.initialize();

  // Configure window
  const windowOptions = WindowOptions(
    size: Size(1280, 760),
    minimumSize: Size(960, 560),
    title: '$appName  v$appVersion',
    backgroundColor: Colors.transparent,
    titleBarStyle: TitleBarStyle.normal,
  );

  // Detect Windows version to eliminate drag lag on Windows 10
  bool isWin11 = false;
  if (Platform.isWindows) {
    try {
      final versionStr = Platform.operatingSystemVersion;
      final match = RegExp(r'Build\s+(\d+)').firstMatch(versionStr);
      if (match != null) {
        final buildNumber = int.tryParse(match.group(1) ?? '') ?? 0;
        isWin11 = buildNumber >= 22000;
      }
    } catch (_) {}
  }

  // Restore saved theme mode and window backdrop effect
  final savedThemeStr = AppConfig.get('theme', defaultValue: 'dark');
  final isInitialDark = savedThemeStr == 'dark';
  final savedEffectStr = AppConfig.getWindowEffect();
  final effect = WindowEffectHelper.parseEffect(
    savedEffectStr,
    isWin11: isWin11,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
    try {
      await windowManager.setAlignment(Alignment.center);
    } catch (_) {}

    // Apply zero-lag blur effect inside waitUntilReadyToShow:
    // Acrylic on Win11 (DirectX 12 Frosted Glass blur), Aero on Win10 (GPU 0ms lag).
    // Safe non-zero alpha tint prevents Windows DWM solid color fallback.
    if (AppConfig.enableTransparency) {
      await WindowEffectHelper.apply(effect: effect, isDark: isInitialDark);
    } else {
      try {
        await Window.setEffect(effect: WindowEffect.disabled);
      } catch (_) {}
    }
  });

  // Initialize services & logic
  final symlinkService = SymlinkService();
  final symlinkLogic = SymlinkLogic(symlinkService);

  // Check if running as admin; if not, automatically request elevation and exit
  final isAdmin = await symlinkLogic.isAdmin();
  if (!isAdmin) {
    await symlinkLogic.elevateAdmin(args);
    exit(0);
  }

  // Recover any interrupted operations from previous runs (e.g. crash)
  await symlinkLogic.recoverInterruptedOperation();

  // Restore saved language
  final savedLang = AppLanguageExt.fromCode(
    AppConfig.get('language', defaultValue: 'en'),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(initialMode: savedThemeStr),
        ),
        ChangeNotifierProvider(create: (_) => LanguageNotifier(savedLang)),
      ],
      child: JaSymlinkApp(logic: symlinkLogic),
    ),
  );
}

class JaSymlinkApp extends StatelessWidget {
  final SymlinkLogic logic;

  const JaSymlinkApp({super.key, required this.logic});

  @override
  Widget build(BuildContext context) {
    final languageNotifier = context.watch<LanguageNotifier>();
    final themeProvider = context.watch<ThemeProvider>();

    return LanguageProvider(
      notifier: languageNotifier,
      child: MaterialApp(
        title: '$appName  v$appVersion',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: themeProvider.isDark ? Brightness.dark : Brightness.light,
          scaffoldBackgroundColor: Colors.transparent,
          fontFamily: 'Segoe UI',
        ),
        home: DashboardShell(
          logic: logic,
          appTitle: appName,
          appVersion: appVersion,
          isDebug: BuildInfo.isDebug,
          buildTimestamp: BuildInfo.debugTimestamp,
        ),
      ),
    );
  }
}
