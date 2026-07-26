import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tujh_messenger/main.dart';
import 'package:tujh_messenger/services/auth_service.dart';
import 'package:tujh_messenger/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Shows auth screen when not logged in', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final authService = AuthService(prefs);
    final settingsService = SettingsService(prefs);

    await tester.pumpWidget(TujhMessengerApp(
      authService: authService,
      settingsService: settingsService,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Tujh Messenger'), findsOneWidget);
    expect(find.text('Войти'), findsOneWidget);
  });
}
