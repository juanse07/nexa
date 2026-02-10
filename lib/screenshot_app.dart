/// Simplified NexaApp for screenshot capture mode.
///
/// Skips splash screen and auth flow — goes straight to MainScreen
/// with mock data, preserving the real theme and localization.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'package:nexa/features/main/presentation/main_screen.dart';
import 'package:nexa/l10n/app_localizations.dart';
import 'package:nexa/services/terminology_provider.dart';
import 'package:nexa/shared/presentation/theme/theme.dart';

/// A minimal app shell for screenshot capture.
///
/// Differences from [NexaApp]:
/// - No splash screen (renders MainScreen immediately)
/// - No auth FutureBuilder (no token check)
/// - No forced-logout listener
/// - Accepts [locale] to force a specific language
/// - Accepts [terminologyProvider] for mock terminology
class ScreenshotApp extends StatelessWidget {
  /// The locale to force (defaults to English).
  final Locale locale;

  /// Custom terminology provider (mock for screenshots).
  final TerminologyProvider? terminologyProvider;

  /// Which tab to start on (default 0 = Events).
  final int initialTabIndex;

  const ScreenshotApp({
    super.key,
    this.locale = const Locale('en'),
    this.terminologyProvider,
    this.initialTabIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<TerminologyProvider>(
      create: (_) => terminologyProvider ?? TerminologyProvider(),
      child: MaterialApp(
        title: 'FlowShift Manager',
        debugShowCheckedModeBanner: false,

        // Force the requested locale
        locale: locale,

        // Localization delegates (same as NexaApp)
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en'),
          Locale('es'),
        ],

        // Theme (same as NexaApp)
        theme: AppTheme.lightTheme(),
        darkTheme: AppTheme.darkTheme(),
        themeMode: ThemeMode.light,

        // Go straight to MainScreen — no splash, no auth
        home: MainScreen(initialIndex: initialTabIndex),

        // Disable text scaling for consistent screenshots
        builder: (BuildContext context, Widget? child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.noScaling,
            ),
            child: child!,
          );
        },
      ),
    );
  }
}
