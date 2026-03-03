import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/alert_dto.dart';
import 'app_logger.dart';

abstract class AlertsApi {
  Future<List<AlertDto>> fetchRecentAlerts({
    required String cityKey,
    int limit,
  });

  Future<void> registerDevice({
    required String deviceId,
    required String fcmToken,
    required String locale,
    required String appVersion,
  });

  Future<void> updateSubscription({
    required String deviceId,
    required String cityKey,
    required String cityDisplay,
    required String lang,
  });
}

class ApiClient implements AlertsApi {
  static const _defaultBaseUrl = 'http://10.0.2.2:3000';

  ApiClient({String? baseUrl, http.Client? httpClient})
    : _baseUrl = _normalizeBaseUrl(_resolveBaseUrl(baseUrl)),
      _httpClient = httpClient ?? http.Client() {
    AppLogger.info('ApiClient', 'Initialized', <String, Object?>{
      'baseUrl': _baseUrl,
    });
  }

  final String _baseUrl;
  final http.Client _httpClient;

  static String _resolveBaseUrl(String? overrideBaseUrl) {
    if (overrideBaseUrl != null && overrideBaseUrl.trim().isNotEmpty) {
      return overrideBaseUrl;
    }

    const fromDefine = String.fromEnvironment(
      'BACKEND_BASE_URL',
      defaultValue: '',
    );
    if (fromDefine.trim().isNotEmpty) {
      return fromDefine;
    }

    final fromEnvFile = _tryReadEnvFileBaseUrl();
    if (fromEnvFile != null && fromEnvFile.trim().isNotEmpty) {
      return fromEnvFile;
    }

    return _defaultBaseUrl;
  }

  static String? _tryReadEnvFileBaseUrl() {
    try {
      return dotenv.env['BACKEND_BASE_URL'];
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<AlertDto>> fetchRecentAlerts({
    required String cityKey,
    int limit = 20,
  }) async {
    final uri = Uri.parse('$_baseUrl/alerts/recent').replace(
      queryParameters: <String, String>{'cityKey': cityKey, 'limit': '$limit'},
    );
    final startedAt = DateTime.now();
    AppLogger.info('ApiClient', 'Fetching recent alerts', <String, Object?>{
      'cityKey': cityKey,
      'limit': limit,
      'uri': uri.toString(),
    });
    try {
      final response = await _httpClient.get(uri);
      _throwOnBadResponse(response, action: 'fetchRecentAlerts', uri: uri);

      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        AppLogger.warn('ApiClient', 'Unexpected alerts payload type');
        return const <AlertDto>[];
      }

      final alerts = decoded
          .whereType<Map<String, dynamic>>()
          .map(AlertDto.fromJson)
          .toList(growable: false);
      AppLogger.info('ApiClient', 'Fetched recent alerts', <String, Object?>{
        'cityKey': cityKey,
        'count': alerts.length,
        'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
      });
      return alerts;
    } catch (error, stackTrace) {
      AppLogger.error(
        'ApiClient',
        'Fetch recent alerts failed',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{'cityKey': cityKey, 'limit': limit},
      );
      rethrow;
    }
  }

  @override
  Future<void> registerDevice({
    required String deviceId,
    required String fcmToken,
    required String locale,
    required String appVersion,
  }) async {
    final uri = Uri.parse('$_baseUrl/register-device');
    AppLogger.info('ApiClient', 'Registering device', <String, Object?>{
      'deviceId': deviceId,
      'locale': locale,
      'appVersion': appVersion,
    });
    try {
      final response = await _httpClient.post(
        uri,
        headers: const <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(<String, String>{
          'deviceId': deviceId,
          'fcmToken': fcmToken,
          'locale': locale,
          'appVersion': appVersion,
        }),
      );
      _throwOnBadResponse(response, action: 'registerDevice', uri: uri);
      AppLogger.info('ApiClient', 'Device registered', <String, Object?>{
        'deviceId': deviceId,
      });
    } catch (error, stackTrace) {
      AppLogger.error(
        'ApiClient',
        'Register device failed',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{'deviceId': deviceId},
      );
      rethrow;
    }
  }

  @override
  Future<void> updateSubscription({
    required String deviceId,
    required String cityKey,
    required String cityDisplay,
    required String lang,
  }) async {
    final uri = Uri.parse('$_baseUrl/subscription');
    AppLogger.info('ApiClient', 'Updating subscription', <String, Object?>{
      'deviceId': deviceId,
      'cityKey': cityKey,
      'lang': lang,
    });
    try {
      final response = await _httpClient.put(
        uri,
        headers: const <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(<String, String>{
          'deviceId': deviceId,
          'cityKey': cityKey,
          'cityDisplay': cityDisplay,
          'lang': lang,
        }),
      );
      _throwOnBadResponse(response, action: 'updateSubscription', uri: uri);
      AppLogger.info('ApiClient', 'Subscription updated', <String, Object?>{
        'deviceId': deviceId,
        'cityKey': cityKey,
      });
    } catch (error, stackTrace) {
      AppLogger.error(
        'ApiClient',
        'Update subscription failed',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{
          'deviceId': deviceId,
          'cityKey': cityKey,
          'lang': lang,
        },
      );
      rethrow;
    }
  }

  static String _normalizeBaseUrl(String rawBaseUrl) {
    return rawBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
  }

  static void _throwOnBadResponse(
    http.Response response, {
    required String action,
    required Uri uri,
  }) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    final preview = response.body.length <= 240
        ? response.body
        : '${response.body.substring(0, 240)}...';
    AppLogger.warn('ApiClient', 'HTTP call failed', <String, Object?>{
      'action': action,
      'uri': uri.toString(),
      'statusCode': response.statusCode,
      'responseBodyPreview': preview,
    });

    throw ApiException(statusCode: response.statusCode, body: response.body);
  }
}

class ApiException implements Exception {
  const ApiException({required this.statusCode, required this.body});

  final int statusCode;
  final String body;

  @override
  String toString() {
    return 'ApiException(statusCode: $statusCode, body: $body)';
  }
}
