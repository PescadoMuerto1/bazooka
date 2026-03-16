import 'package:audioplayers/audioplayers.dart';

class AlertSoundConfig {
  static const alertsChannelId = 'bazooka_alerts_channel';
  static const alertsChannelName = 'Bazooka Alerts';
  static const alertsChannelDescription = 'High-priority Bazooka safety alerts';
  static const alertsSoundResource = 'alert_song';

  static const preAlertChannelId = 'bazooka_pre_alert_channel';
  static const preAlertChannelName = 'Bazooka Pre-Alerts';
  static const preAlertChannelDescription =
      'High-priority Bazooka pre-alert warnings';
  static const preAlertSoundResource = 'pre_alert_song';

  static const allClearChannelId = 'bazooka_all_clear_channel';
  static const allClearChannelName = 'All Clear';
  static const allClearChannelDescription =
      'Notifications when it is safe to leave the shelter';

  static const defaultPopupAsset = 'alert_song.mp3';
  static const preAlertPopupAsset = 'pre_alert_song.mp3';
  static const popupVolume = 1.0;
  static const popupReleaseMode = ReleaseMode.release;

  static final popupAudioContext = AudioContext(
    android: AudioContextAndroid(
      stayAwake: true,
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.alarm,
      audioFocus: AndroidAudioFocus.gain,
    ),
  );

  static bool isPreAlert(String type) => type == 'pre_alert';

  static bool isAllClear(String type) => type == 'all_clear';

  static String popupAssetForType(String type) {
    return isPreAlert(type) ? preAlertPopupAsset : defaultPopupAsset;
  }

  static String notificationChannelIdForType(String type) {
    if (isAllClear(type)) {
      return allClearChannelId;
    }

    return isPreAlert(type) ? preAlertChannelId : alertsChannelId;
  }

  static String notificationChannelNameForType(String type) {
    if (isAllClear(type)) {
      return allClearChannelName;
    }

    return isPreAlert(type) ? preAlertChannelName : alertsChannelName;
  }

  static String notificationChannelDescriptionForType(String type) {
    if (isAllClear(type)) {
      return allClearChannelDescription;
    }

    return isPreAlert(type)
        ? preAlertChannelDescription
        : alertsChannelDescription;
  }

  static String? notificationSoundResourceForType(String type) {
    if (isAllClear(type)) {
      return null;
    }

    return isPreAlert(type) ? preAlertSoundResource : alertsSoundResource;
  }
}
