import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/brand_theme.dart';
import 'config/supabase_config.dart';
import 'l10n/app_strings.dart';
import 'screens/auth_screen.dart';
import 'screens/email_verification_screen.dart';
import 'screens/main_screen.dart';
import 'services/auth_service.dart';
import 'services/settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
  ).timeout(
    const Duration(seconds: 10),
    onTimeout: () => throw TimeoutException(
      'Supabase init > 10s — проверь сеть / VPN до supabase.co',
    ),
  );

  final prefs = await SharedPreferences.getInstance();
  final authService = AuthService();
  final settingsService = SettingsService(prefs);

  // Paint the first frame immediately; auth finishes in the background.
  runApp(MurkotApp(
    prefs: prefs,
    authService: authService,
    settingsService: settingsService,
  ));

  unawaited(authService.initialize());
}

class MurkotApp extends StatelessWidget {
  const MurkotApp({
    super.key,
    required this.prefs,
    required this.authService,
    required this.settingsService,
  });

  final SharedPreferences prefs;
  final AuthService authService;
  final SettingsService settingsService;

  Widget _homeScreen() {
    if (!authService.isReady) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (authService.isAuthenticated) {
      return MainScreen(
        authService: authService,
        settingsService: settingsService,
        prefs: prefs,
      );
    }
    if (authService.needsEmailVerification) {
      return EmailVerificationScreen(authService: authService);
    }
    return AuthScreen(authService: authService);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([authService, settingsService]),
      builder: (context, _) {
        final strings = AppStrings(settingsService.language, settingsService);

        return AppStringsScope(
          strings: strings,
          child: MaterialApp(
            title: strings.appTitle,
            debugShowCheckedModeBanner: false,
            locale: settingsService.locale,
            supportedLocales: const [Locale('ru'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            themeMode: settingsService.themeMode,
            theme: buildMurkotTheme(Brightness.light),
            darkTheme: buildMurkotTheme(Brightness.dark),
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(settingsService.textScaleFactor),
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: _homeScreen(),
          ),
        );
      },
    );
  }
}

/// Back-compat alias for older imports/tests.
typedef TujhMessengerApp = MurkotApp;
