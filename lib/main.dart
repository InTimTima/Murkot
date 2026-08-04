import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'l10n/app_strings.dart';
import 'screens/auth_screen.dart';
import 'screens/email_verification_screen.dart';
import 'screens/main_screen.dart';
import 'services/auth_service.dart';
import 'services/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
  );

  final prefs = await SharedPreferences.getInstance();
  final authService = AuthService();
  await authService.initialize();
  final settingsService = SettingsService(prefs);

  runApp(TujhMessengerApp(
    prefs: prefs,
    authService: authService,
    settingsService: settingsService,
  ));
}

class TujhMessengerApp extends StatelessWidget {
  const TujhMessengerApp({
    super.key,
    required this.prefs,
    required this.authService,
    required this.settingsService,
  });

  final SharedPreferences prefs;
  final AuthService authService;
  final SettingsService settingsService;

  ThemeData _buildTheme(Brightness brightness) {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF5B6CFF),
        brightness: brightness,
      ),
      useMaterial3: true,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brightness == Brightness.light
            ? Colors.grey.shade100
            : Colors.grey.shade900,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _homeScreen() {
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
            theme: _buildTheme(Brightness.light),
            darkTheme: _buildTheme(Brightness.dark),
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
