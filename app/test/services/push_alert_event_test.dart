import 'dart:convert';

import 'package:app/services/push_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('preserves alertId when a local notification payload is decoded', () {
    const event = PushAlertEvent(
      alertId: 'alert-123',
      title: 'Bazooka Alert',
      body: 'Take shelter now',
      type: 'rocket',
      areasCount: 2,
      matchedCityKey: 'tel-aviv',
      areas: <String>['Tel Aviv', 'Ramat Gan'],
      shouldDisplayPopup: true,
      shouldPlaySound: true,
    );

    final decoded = PushAlertEvent.fromPayloadJson(
      jsonEncode(event.toJson()),
      shouldDisplayPopup: true,
      shouldPlaySound: false,
    );

    expect(decoded.alertId, event.alertId);
    expect(decoded.title, event.title);
    expect(decoded.body, event.body);
    expect(decoded.type, event.type);
    expect(decoded.areasCount, event.areasCount);
    expect(decoded.matchedCityKey, event.matchedCityKey);
    expect(decoded.areas, event.areas);
    expect(decoded.shouldDisplayPopup, isTrue);
    expect(decoded.shouldPlaySound, isFalse);
  });

  test('dedupeKey stays stable across popup behavior changes', () {
    const popupEvent = PushAlertEvent(
      alertId: 'alert-123',
      title: 'Bazooka Alert',
      body: 'Take shelter now',
      type: 'rocket',
      areasCount: 1,
      matchedCityKey: 'tel-aviv',
      areas: <String>['Tel Aviv'],
      shouldDisplayPopup: true,
      shouldPlaySound: true,
    );
    const openEvent = PushAlertEvent(
      alertId: 'alert-123',
      title: 'Bazooka Alert',
      body: 'Take shelter now',
      type: 'rocket',
      areasCount: 1,
      matchedCityKey: 'tel-aviv',
      areas: <String>['Tel Aviv'],
      shouldDisplayPopup: false,
      shouldPlaySound: false,
    );

    expect(popupEvent.dedupeKey(), openEvent.dedupeKey());
  });

  test(
    'notification launch payloads can hand sound ownership to the popup',
    () {
      final decoded = PushAlertEvent.fromPayloadJson(
        jsonEncode(<String, Object?>{
          'alertId': 'alert-456',
          'title': 'Bazooka Alert',
          'body': 'Take shelter now',
          'type': 'rocket',
          'areasCount': 1,
          'matchedCityKey': 'tel-aviv',
          'areas': <String>['Tel Aviv'],
        }),
        shouldDisplayPopup: true,
        shouldPlaySound: true,
      );

      expect(decoded.shouldDisplayPopup, isTrue);
      expect(decoded.shouldPlaySound, isTrue);
    },
  );
}
