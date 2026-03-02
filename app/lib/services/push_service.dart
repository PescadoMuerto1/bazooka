import 'dart:async';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../state/app_settings.dart';
import 'api_client.dart';

abstract class PushSyncService {
  Future<void> initializeAndSync({
    required AppSettings settings,
    required AlertsApi apiClient,
  });
}

class PushService implements PushSyncService {
  PushService({FirebaseMessaging? messaging})
    : _messaging = messaging ?? FirebaseMessaging.instance;

  static const _deviceIdStorageKey = 'device_id';
  static const _appVersion = '1.0.0';

  final FirebaseMessaging _messaging;
  StreamSubscription<String>? _tokenSubscription;
  bool _initialized = false;

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

    try {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
    } catch (error) {
      debugPrint('Notification permission request failed: $error');
      return;
    }

    final token = await _safeGetToken();
    if (token == null || token.isEmpty) {
      return;
    }

    await _syncBackend(
      apiClient: apiClient,
      settings: settings,
      deviceId: deviceId,
      token: token,
    );

    _tokenSubscription ??= _messaging.onTokenRefresh.listen((newToken) {
      if (newToken.isEmpty) {
        return;
      }

      unawaited(
        _syncBackend(
          apiClient: apiClient,
          settings: settings,
          deviceId: deviceId,
          token: newToken,
        ),
      );
    });
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
