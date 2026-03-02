import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app/main.dart';

void main() {
  testWidgets('shows city setup on first launch', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Choose your city'), findsOneWidget);
    expect(find.byKey(const Key('saveCityButton')), findsOneWidget);
  });

  testWidgets('saves city and transitions to home', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('cityDropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tel Aviv (תל אביב)').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('saveCityButton')));
    await tester.pumpAndSettle();

    expect(find.text('Notifications are set'), findsOneWidget);
    expect(find.text('City: Tel Aviv'), findsOneWidget);
  });

  testWidgets('uses persisted city on startup', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'city_key': 'תל אביב',
      'city_display': 'Tel Aviv',
      'language_code': 'en',
    });
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Notifications are set'), findsOneWidget);
    expect(find.text('City: Tel Aviv'), findsOneWidget);
    expect(find.text('Language: English'), findsOneWidget);
  });
}
