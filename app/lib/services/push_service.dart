import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../state/app_settings.dart';
import 'api_client.dart';
import 'app_logger.dart';

class PushAlertEvent {
  const PushAlertEvent({
    required this.title,
    required this.body,
    required this.type,
    required this.areasCount,
    required this.matchedCityKey,
    required this.areas,
    required this.shouldDisplayPopup,
  });

  final String title;
  final String body;
  final String type;
  final int areasCount;
  final String matchedCityKey;
  final List<String> areas;
  final bool shouldDisplayPopup;

  static int _parseAreasCount(Object? rawValue, int fallback) {
    if (rawValue == null) {
      return fallback;
    }

    final parsed = int.tryParse(rawValue.toString());
    if (parsed == null || parsed < 0) {
      return fallback;
    }

    return parsed;
  }

  factory PushAlertEvent.fromRemoteMessage(
    RemoteMessage message, {
    bool shouldDisplayPopup = false,
  }) {
    final notification = message.notification;
    final rawAreas = message.data['areas'] ?? '';
    final areas = rawAreas
        .toString()
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    final matchedCityKey =
        message.data['matchedCityKey']?.toString().trim() ?? '';
    final type = message.data['type']?.toString().trim() ?? 'update';
    final areasCount = _parseAreasCount(
      message.data['areasCount'],
      areas.length,
    );

    return PushAlertEvent(
      title:
          notification?.title ??
          message.data['title']?.toString() ??
          'Bazooka Alert',
      body: notification?.body ?? message.data['body']?.toString() ?? '',
      type: type.isEmpty ? 'update' : type,
      areasCount: areasCount,
      matchedCityKey: matchedCityKey,
      areas: areas,
      shouldDisplayPopup: shouldDisplayPopup,
    );
  }

  factory PushAlertEvent.fromPayloadJson(
    String payload, {
    bool shouldDisplayPopup = false,
  }) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) {
        return PushAlertEvent(
          title: 'Bazooka Alert',
          body: '',
          type: 'update',
          areasCount: 0,
          matchedCityKey: '',
          areas: <String>[],
          shouldDisplayPopup: shouldDisplayPopup,
        );
      }

      final rawAreas = decoded['areas'];
      final areas = rawAreas is List
          ? rawAreas
                .whereType<String>()
                .map((value) => value.trim())
                .where((value) => value.isNotEmpty)
                .toList(growable: false)
          : const <String>[];
      final type = decoded['type']?.toString().trim() ?? 'update';
      final matchedCityKey = decoded['matchedCityKey']?.toString().trim() ?? '';
      final areasCount = _parseAreasCount(decoded['areasCount'], areas.length);

      return PushAlertEvent(
        title: decoded['title']?.toString() ?? 'Bazooka Alert',
        body: decoded['body']?.toString() ?? '',
        type: type.isEmpty ? 'update' : type,
        areasCount: areasCount,
        matchedCityKey: matchedCityKey,
        areas: areas,
        shouldDisplayPopup: shouldDisplayPopup,
      );
    } catch (_) {
      return PushAlertEvent(
        title: 'Bazooka Alert',
        body: '',
        type: 'update',
        areasCount: 0,
        matchedCityKey: '',
        areas: <String>[],
        shouldDisplayPopup: shouldDisplayPopup,
      );
    }
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'title': title,
      'body': body,
      'type': type,
      'areasCount': areasCount,
      'matchedCityKey': matchedCityKey,
      'areas': areas,
    };
  }
}

abstract class PushSyncService {
  Future<void> initializeAndSync({
    required AppSettings settings,
    required AlertsApi apiClient,
  });

  Stream<PushAlertEvent> get alertEvents;

  Future<bool> requestFullScreenIntentPermission();
}

class PushService implements PushSyncService {
  PushService({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotificationsPlugin,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _localNotificationsPlugin =
           localNotificationsPlugin ?? FlutterLocalNotificationsPlugin();

  static const _deviceIdStorageKey = 'device_id';
  static const _appVersion = '1.0.0';
  static const _alertsChannelId = 'bazooka_alerts_channel';
  static const _alertsChannelName = 'Bazooka Alerts';
  static const _alertsChannelDescription =
      'High-priority Bazooka safety alerts';
  static const _alertsSoundResource = 'alert_song';
  static const _allClearChannelId = 'bazooka_all_clear_channel';
  static const _deviceStateChannel = MethodChannel(
    'com.bazooka.alerts/device_state',
  );
  static const _allClearChannelName = 'All Clear';
  static const _allClearChannelDescription =
      'Notifications when it is safe to leave the shelter';
  static PushAlertEvent? _pendingLaunchAlertEvent;

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin;
  final StreamController<PushAlertEvent> _alertEventsController =
      StreamController<PushAlertEvent>.broadcast();

  @override
  Stream<PushAlertEvent> get alertEvents => _alertEventsController.stream;

  StreamSubscription<String>? _tokenSubscription;
  bool _initialized = false;
  bool _localNotificationsInitialized = false;
  bool _pushListenersInitialized = false;

  @override
  Future<void> initializeAndSync({
    required AppSettings settings,
    required AlertsApi apiClient,
  }) async {
    AppLogger.info(
      'PushService',
      'initializeAndSync started',
      <String, Object?>{
        'hasSelectedCity': settings.hasSelectedCity,
        'cityKey': settings.cityKey ?? '',
        'languageCode': settings.languageCode,
      },
    );
    if (!settings.hasSelectedCity) {
      AppLogger.warn('PushService', 'Skipping push sync: no selected city');
      return;
    }

    final deviceId = await _loadOrCreateDeviceId();
    AppLogger.info('PushService', 'Device ID ready', <String, Object?>{
      'deviceId': deviceId,
    });

    if (!_initialized) {
      try {
        await Firebase.initializeApp();
        AppLogger.info('PushService', 'Firebase initialized');
      } catch (error) {
        AppLogger.warn(
          'PushService',
          'Firebase initialize skipped',
          <String, Object?>{'error': error.toString()},
        );
      }
      _initialized = true;
    }

    await _initializeLocalNotifications();
    await _initializePushEventListeners();
    _emitPendingLaunchEventIfAny();
    await _localNotificationsPlugin.cancelAll();

    try {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      AppLogger.info('PushService', 'Notification permissions requested');
    } catch (error) {
      AppLogger.error(
        'PushService',
        'Notification permission request failed',
        error: error,
      );
      return;
    }

    final token = await _safeGetToken();
    if (token == null || token.isEmpty) {
      AppLogger.warn('PushService', 'FCM token is missing, sync skipped');
      return;
    }

    try {
      await _syncBackend(
        apiClient: apiClient,
        settings: settings,
        deviceId: deviceId,
        token: token,
      );
      AppLogger.info('PushService', 'Initial backend sync completed');
    } catch (error) {
      AppLogger.error(
        'PushService',
        'Initial FCM backend sync failed',
        error: error,
      );
    }

    _tokenSubscription ??= _messaging.onTokenRefresh.listen((newToken) {
      if (newToken.isEmpty) {
        return;
      }

      unawaited(
        Future<void>(() async {
          try {
            await _syncBackend(
              apiClient: apiClient,
              settings: settings,
              deviceId: deviceId,
              token: newToken,
            );
            AppLogger.info('PushService', 'Token refresh sync completed');
          } catch (error) {
            AppLogger.error(
              'PushService',
              'Token refresh backend sync failed',
              error: error,
            );
          }
        }),
      );
    });
  }

  Future<void> _initializeLocalNotifications() async {
    if (_localNotificationsInitialized) {
      AppLogger.info('PushService', 'Local notifications already initialized');
      return;
    }

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/launcher_icon'),
    );

    await _localNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) {
          return;
        }

        unawaited(_handleNotificationResponse(payload));
      },
    );

    await _createAlertsChannel(_localNotificationsPlugin);
    await requestFullScreenIntentPermission();
    await _captureNotificationLaunchPayload();
    _localNotificationsInitialized = true;
    AppLogger.info('PushService', 'Local notifications initialized');
  }

  Future<void> _initializePushEventListeners() async {
    if (_pushListenersInitialized) {
      AppLogger.info('PushService', 'Push listeners already initialized');
      return;
    }

    FirebaseMessaging.onMessage.listen((message) {
      AppLogger.info(
        'PushService',
        'Foreground push received',
        <String, Object?>{'messageId': message.messageId ?? ''},
      );
      unawaited(_localNotificationsPlugin.cancelAll());
      _alertEventsController.add(
        PushAlertEvent.fromRemoteMessage(message, shouldDisplayPopup: true),
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      AppLogger.info('PushService', 'Push opened app', <String, Object?>{
        'messageId': message.messageId ?? '',
      });
      _alertEventsController.add(
        PushAlertEvent.fromRemoteMessage(message, shouldDisplayPopup: false),
      );
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      AppLogger.info(
        'PushService',
        'Initial push message found',
        <String, Object?>{'messageId': initialMessage.messageId ?? ''},
      );
      _alertEventsController.add(
        PushAlertEvent.fromRemoteMessage(
          initialMessage,
          shouldDisplayPopup: true,
        ),
      );
    }

    _pushListenersInitialized = true;
    AppLogger.info('PushService', 'Push listeners initialized');
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final event = PushAlertEvent.fromRemoteMessage(message);
    AppLogger.info(
      'PushService',
      'Showing foreground notification',
      <String, Object?>{
        'title': event.title,
        'areasCount': event.areasCount,
        'type': event.type,
      },
    );

    final details = event.type == 'all_clear'
        ? _allClearNotificationDetails()
        : _alertNotificationDetails();

    await _localNotificationsPlugin.show(
      event.hashCode,
      event.title,
      event.body,
      details,
      payload: jsonEncode(event.toJson()),
    );
  }

  Future<void> _handleNotificationResponse(String payload) async {
    final isLocked = await _isDeviceLocked();
    AppLogger.info(
      'PushService',
      'Notification response received',
      <String, Object?>{'isDeviceLocked': isLocked},
    );
    _alertEventsController.add(
      PushAlertEvent.fromPayloadJson(payload, shouldDisplayPopup: isLocked),
    );
  }

  static Future<bool> _isDeviceLocked() async {
    try {
      final result = await _deviceStateChannel.invokeMethod<bool>(
        'isDeviceLocked',
      );
      return result ?? false;
    } catch (error) {
      AppLogger.warn(
        'PushService',
        'Could not check device lock state',
        <String, Object?>{'error': error.toString()},
      );
      return false;
    }
  }

  void _emitPendingLaunchEventIfAny() {
    final pending = _pendingLaunchAlertEvent;
    if (pending == null) {
      return;
    }

    _pendingLaunchAlertEvent = null;
    AppLogger.info('PushService', 'Emitting pending launch notification event');
    _alertEventsController.add(pending);
  }

  Future<void> _captureNotificationLaunchPayload() async {
    final launchDetails = await _localNotificationsPlugin
        .getNotificationAppLaunchDetails();
    final payload = launchDetails?.notificationResponse?.payload;
    if (payload == null || payload.isEmpty) {
      return;
    }

    _pendingLaunchAlertEvent = PushAlertEvent.fromPayloadJson(
      payload,
      shouldDisplayPopup: true,
    );
    AppLogger.info('PushService', 'Captured launch payload from notification');
  }

  static Future<void> _createAlertsChannel(
    FlutterLocalNotificationsPlugin plugin,
  ) async {
    const alertChannel = AndroidNotificationChannel(
      _alertsChannelId,
      _alertsChannelName,
      description: _alertsChannelDescription,
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(_alertsSoundResource),
    );

    const allClearChannel = AndroidNotificationChannel(
      _allClearChannelId,
      _allClearChannelName,
      description: _allClearChannelDescription,
      importance: Importance.defaultImportance,
      playSound: true,
    );

    final androidPlugin = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(alertChannel);
    await androidPlugin?.createNotificationChannel(allClearChannel);
    AppLogger.info('PushService', 'Android notification channels ensured');
  }

  static NotificationDetails _alertNotificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _alertsChannelId,
        _alertsChannelName,
        channelDescription: _alertsChannelDescription,
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(_alertsSoundResource),
        audioAttributesUsage: AudioAttributesUsage.alarm,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.call,
        visibility: NotificationVisibility.public,
      ),
    );
  }

  static NotificationDetails _allClearNotificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _allClearChannelId,
        _allClearChannelName,
        channelDescription: _allClearChannelDescription,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        playSound: true,
        visibility: NotificationVisibility.public,
      ),
    );
  }

  @pragma('vm:entry-point')
  static Future<void> showBackgroundAlertNotification(
    RemoteMessage message,
  ) async {
    AppLogger.info(
      'PushService',
      'Showing background notification',
      <String, Object?>{'messageId': message.messageId ?? ''},
    );
    try {
      await Firebase.initializeApp();
    } catch (_) {
      // Firebase can already be initialized in this isolate.
      AppLogger.warn('PushService', 'Background Firebase initialize skipped');
    }

    final plugin = FlutterLocalNotificationsPlugin();
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/launcher_icon'),
    );
    await plugin.initialize(initializationSettings);
    await _createAlertsChannel(plugin);

    final event = PushAlertEvent.fromRemoteMessage(message);
    final details = event.type == 'all_clear'
        ? _allClearNotificationDetails()
        : _alertNotificationDetails();
    await plugin.show(
      event.hashCode,
      event.title,
      event.body,
      details,
      payload: jsonEncode(event.toJson()),
    );
    AppLogger.info('PushService', 'Background notification shown');
  }

  @override
  Future<bool> requestFullScreenIntentPermission() async {
    final androidPlugin = _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin == null) {
      AppLogger.info(
        'PushService',
        'No Android notifications plugin; permission assumed granted',
      );
      return true;
    }

    final notificationsGranted =
        await androidPlugin.requestNotificationsPermission() ?? true;
    final fullScreenGranted =
        await androidPlugin.requestFullScreenIntentPermission() ?? true;
    AppLogger.info(
      'PushService',
      'Requested full-screen intent permissions',
      <String, Object?>{
        'notificationsGranted': notificationsGranted,
        'fullScreenGranted': fullScreenGranted,
      },
    );
    return notificationsGranted && fullScreenGranted;
  }

  Future<String?> _safeGetToken() async {
    try {
      final token = await _messaging.getToken();
      AppLogger.info('PushService', 'FCM token fetched', <String, Object?>{
        'hasToken': token != null && token.isNotEmpty,
      });
      return token;
    } catch (error) {
      AppLogger.error(
        'PushService',
        'FCM token retrieval failed',
        error: error,
      );
      return null;
    }
  }

  Future<void> _syncBackend({
    required AlertsApi apiClient,
    required AppSettings settings,
    required String deviceId,
    required String token,
  }) async {
    final cityKey = settings.cityKey;
    final cityDisplay = settings.cityDisplay;
    if (cityKey == null || cityDisplay == null) {
      AppLogger.warn(
        'PushService',
        'Skipping backend sync: city settings missing',
      );
      return;
    }

    AppLogger.info(
      'PushService',
      'Syncing backend registration and subscription',
      <String, Object?>{
        'deviceId': deviceId,
        'cityKey': cityKey,
        'lang': settings.languageCode,
      },
    );
    await apiClient.registerDevice(
      deviceId: deviceId,
      fcmToken: token,
      locale: settings.languageCode,
      appVersion: _appVersion,
    );

    await apiClient.updateSubscription(
      deviceId: deviceId,
      cityKey: cityKey,
      cityDisplay: cityDisplay,
      lang: settings.languageCode,
    );
    AppLogger.info('PushService', 'Backend sync succeeded', <String, Object?>{
      'deviceId': deviceId,
      'cityKey': cityKey,
    });
  }

  Future<String> _loadOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdStorageKey);
    if (existing != null && existing.isNotEmpty) {
      AppLogger.info('PushService', 'Loaded existing device ID');
      return existing;
    }

    final generated =
        'android-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 32)}';
    await prefs.setString(_deviceIdStorageKey, generated);
    AppLogger.info('PushService', 'Generated new device ID');
    return generated;
  }
}
