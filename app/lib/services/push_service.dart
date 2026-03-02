import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../state/app_settings.dart';
import 'api_client.dart';

class PushAlertEvent {
  const PushAlertEvent({
    required this.title,
    required this.body,
    required this.areas,
  });

  final String title;
  final String body;
  final List<String> areas;

  factory PushAlertEvent.fromRemoteMessage(RemoteMessage message) {
    final notification = message.notification;
    final rawAreas = message.data['areas'] ?? '';
    final areas = rawAreas
        .toString()
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);

    return PushAlertEvent(
      title:
          notification?.title ??
          message.data['title']?.toString() ??
          'Bazooka Alert',
      body: notification?.body ?? message.data['body']?.toString() ?? '',
      areas: areas,
    );
  }

  factory PushAlertEvent.fromPayloadJson(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) {
        return const PushAlertEvent(
          title: 'Bazooka Alert',
          body: '',
          areas: <String>[],
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

      return PushAlertEvent(
        title: decoded['title']?.toString() ?? 'Bazooka Alert',
        body: decoded['body']?.toString() ?? '',
        areas: areas,
      );
    } catch (_) {
      return const PushAlertEvent(
        title: 'Bazooka Alert',
        body: '',
        areas: <String>[],
      );
    }
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'title': title, 'body': body, 'areas': areas};
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
    if (!settings.hasSelectedCity) {
      return;
    }

    final deviceId = await _loadOrCreateDeviceId();

    if (!_initialized) {
      try {
        await Firebase.initializeApp();
      } catch (error) {
        debugPrint('Firebase initialize skipped: $error');
      }
      _initialized = true;
    }

    await _initializeLocalNotifications();
    await _initializePushEventListeners();
    _emitPendingLaunchEventIfAny();

    try {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (error) {
      debugPrint('Notification permission request failed: $error');
      return;
    }

    final token = await _safeGetToken();
    if (token == null || token.isEmpty) {
      return;
    }

    try {
      await _syncBackend(
        apiClient: apiClient,
        settings: settings,
        deviceId: deviceId,
        token: token,
      );
    } catch (error) {
      debugPrint('Initial FCM backend sync failed: $error');
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
          } catch (error) {
            debugPrint('Token refresh backend sync failed: $error');
          }
        }),
      );
    });
  }

  Future<void> _initializeLocalNotifications() async {
    if (_localNotificationsInitialized) {
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

        _alertEventsController.add(PushAlertEvent.fromPayloadJson(payload));
      },
    );

    await _createAlertsChannel(_localNotificationsPlugin);
    await requestFullScreenIntentPermission();
    await _captureNotificationLaunchPayload();
    _localNotificationsInitialized = true;
  }

  Future<void> _initializePushEventListeners() async {
    if (_pushListenersInitialized) {
      return;
    }

    FirebaseMessaging.onMessage.listen((message) {
      unawaited(_showForegroundNotification(message));
      _alertEventsController.add(PushAlertEvent.fromRemoteMessage(message));
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _alertEventsController.add(PushAlertEvent.fromRemoteMessage(message));
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _alertEventsController.add(
        PushAlertEvent.fromRemoteMessage(initialMessage),
      );
    }

    _pushListenersInitialized = true;
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final event = PushAlertEvent.fromRemoteMessage(message);

    await _localNotificationsPlugin.show(
      event.hashCode,
      event.title,
      event.body,
      _alertNotificationDetails(),
      payload: jsonEncode(event.toJson()),
    );
  }

  void _emitPendingLaunchEventIfAny() {
    final pending = _pendingLaunchAlertEvent;
    if (pending == null) {
      return;
    }

    _pendingLaunchAlertEvent = null;
    _alertEventsController.add(pending);
  }

  Future<void> _captureNotificationLaunchPayload() async {
    final launchDetails = await _localNotificationsPlugin
        .getNotificationAppLaunchDetails();
    final payload = launchDetails?.notificationResponse?.payload;
    if (payload == null || payload.isEmpty) {
      return;
    }

    _pendingLaunchAlertEvent = PushAlertEvent.fromPayloadJson(payload);
  }

  static Future<void> _createAlertsChannel(
    FlutterLocalNotificationsPlugin plugin,
  ) async {
    const channel = AndroidNotificationChannel(
      _alertsChannelId,
      _alertsChannelName,
      description: _alertsChannelDescription,
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(_alertsSoundResource),
    );

    final androidPlugin = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(channel);
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

  @pragma('vm:entry-point')
  static Future<void> showBackgroundAlertNotification(
    RemoteMessage message,
  ) async {
    try {
      await Firebase.initializeApp();
    } catch (_) {
      // Firebase can already be initialized in this isolate.
    }

    final plugin = FlutterLocalNotificationsPlugin();
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/launcher_icon'),
    );
    await plugin.initialize(initializationSettings);
    await _createAlertsChannel(plugin);

    final event = PushAlertEvent.fromRemoteMessage(message);
    await plugin.show(
      event.hashCode,
      event.title,
      event.body,
      _alertNotificationDetails(),
      payload: jsonEncode(event.toJson()),
    );
  }

  @override
  Future<bool> requestFullScreenIntentPermission() async {
    final androidPlugin = _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin == null) {
      return true;
    }

    final notificationsGranted =
        await androidPlugin.requestNotificationsPermission() ?? true;
    final fullScreenGranted =
        await androidPlugin.requestFullScreenIntentPermission() ?? true;
    return notificationsGranted && fullScreenGranted;
  }

  Future<String?> _safeGetToken() async {
    try {
      return await _messaging.getToken();
    } catch (error) {
      debugPrint('FCM token retrieval failed: $error');
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
      return;
    }

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
  }

  Future<String> _loadOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdStorageKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final generated =
        'android-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 32)}';
    await prefs.setString(_deviceIdStorageKey, generated);
    return generated;
  }
}
