import 'package:app/services/alert_sound_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pre-alert uses the custom popup asset', () {
    expect(
      AlertSoundConfig.popupAssetForType('pre_alert'),
      AlertSoundConfig.preAlertPopupAsset,
    );
  });

  test('pre-alert uses its dedicated Android channel and sound', () {
    expect(
      AlertSoundConfig.notificationChannelIdForType('pre_alert'),
      AlertSoundConfig.preAlertChannelId,
    );
    expect(
      AlertSoundConfig.notificationSoundResourceForType('pre_alert'),
      AlertSoundConfig.preAlertSoundResource,
    );
  });

  test('all-clear keeps the no-custom-sound notification path', () {
    expect(
      AlertSoundConfig.notificationChannelIdForType('all_clear'),
      AlertSoundConfig.allClearChannelId,
    );
    expect(
      AlertSoundConfig.notificationSoundResourceForType('all_clear'),
      isNull,
    );
  });
}
