import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:murkot/main.dart';
import 'package:murkot/services/auth_service.dart';
import 'package:murkot/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Shows auth screen when not logged in', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final authService = AuthService();
    final settingsService = SettingsService(prefs);

    await tester.pumpWidget(MurkotApp(
      prefs: prefs,
      authService: authService,
      settingsService: settingsService,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Murkot'), findsOneWidget);
    expect(find.text('Войти'), findsOneWidget);
  });
}
