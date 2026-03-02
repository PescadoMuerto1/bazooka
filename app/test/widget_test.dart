import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app/main.dart';
import 'package:app/models/alert_dto.dart';
import 'package:app/services/api_client.dart';
import 'package:app/services/push_service.dart';
import 'package:app/state/app_settings.dart';

class _FakeAlertsApi implements AlertsApi {
  _FakeAlertsApi({this.alerts = const <AlertDto>[]});

  final List<AlertDto> alerts;

  @override
  Future<List<AlertDto>> fetchRecentAlerts({
    required String cityKey,
    int limit = 20,
  }) async {
    return alerts.take(limit).toList(growable: false);
  }

  @override
  Future<void> registerDevice({
    required String deviceId,
    required String fcmToken,
    required String locale,
    required String appVersion,
  }) async {}

  @override
  Future<void> updateSubscription({
    required String deviceId,
    required String cityKey,
    required String cityDisplay,
    required String lang,
  }) async {}
}

class _NoopPushSyncService implements PushSyncService {
  int syncCalls = 0;

  @override
  Future<void> initializeAndSync({
    required AppSettings settings,
    required AlertsApi apiClient,
  }) async {
    syncCalls += 1;
  }
}

void main() {
  testWidgets('shows city setup on first launch', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(
      MyApp(apiClient: _FakeAlertsApi(), pushService: _NoopPushSyncService()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Choose your city'), findsOneWidget);
    expect(find.byKey(const Key('saveCityButton')), findsOneWidget);
  });

  testWidgets('saves city and transitions to home', (
    WidgetTester tester,
  ) async {
    final pushService = _NoopPushSyncService();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(
      MyApp(apiClient: _FakeAlertsApi(), pushService: pushService),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('cityDropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tel Aviv (תל אביב)').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('saveCityButton')));
    await tester.pumpAndSettle();

    expect(find.text('Recent alerts'), findsOneWidget);
    expect(find.text('City: Tel Aviv'), findsOneWidget);
    expect(pushService.syncCalls, 1);
  });

  testWidgets('uses persisted city on startup', (WidgetTester tester) async {
    final fakeAlerts = <AlertDto>[
      AlertDto(
        alertId: 'a-1',
        title: 'Rocket Alert',
        category: '1',
        areas: const <String>['תל אביב-יפו'],
        desc: 'Take shelter',
        sourceTimestamp: DateTime.parse('2026-03-02T10:00:00.000Z'),
        ingestedAt: DateTime.parse('2026-03-02T10:00:01.000Z'),
      ),
    ];

    SharedPreferences.setMockInitialValues(<String, Object>{
      'city_key': 'תל אביב',
      'city_display': 'Tel Aviv',
      'language_code': 'en',
    });
    await tester.pumpWidget(
      MyApp(
        apiClient: _FakeAlertsApi(alerts: fakeAlerts),
        pushService: _NoopPushSyncService(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Recent alerts'), findsOneWidget);
    expect(find.text('City: Tel Aviv'), findsOneWidget);
    expect(find.text('Language: English'), findsOneWidget);
    expect(find.text('Rocket Alert'), findsOneWidget);
  });
}
