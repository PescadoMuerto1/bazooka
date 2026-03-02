import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/alert_dto.dart';

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
  ApiClient({String? baseUrl, http.Client? httpClient})
    : _baseUrl = _normalizeBaseUrl(
        baseUrl ??
            const String.fromEnvironment(
              'BACKEND_BASE_URL',
              defaultValue: 'http://10.0.2.2:3000',
            ),
      ),
      _httpClient = httpClient ?? http.Client();

  final String _baseUrl;
  final http.Client _httpClient;

  @override
  Future<List<AlertDto>> fetchRecentAlerts({
    required String cityKey,
    int limit = 20,
  }) async {
    final uri = Uri.parse('$_baseUrl/alerts/recent').replace(
      queryParameters: <String, String>{'cityKey': cityKey, 'limit': '$limit'},
    );

    final response = await _httpClient.get(uri);
    _throwOnBadResponse(response);

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      return const <AlertDto>[];
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(AlertDto.fromJson)
        .toList(growable: false);
  }

  @override
  Future<void> registerDevice({
    required String deviceId,
    required String fcmToken,
    required String locale,
    required String appVersion,
  }) async {
    final uri = Uri.parse('$_baseUrl/register-device');
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
    _throwOnBadResponse(response);
  }

  @override
  Future<void> updateSubscription({
    required String deviceId,
    required String cityKey,
    required String cityDisplay,
    required String lang,
  }) async {
    final uri = Uri.parse('$_baseUrl/subscription');
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
    _throwOnBadResponse(response);
  }

  static String _normalizeBaseUrl(String rawBaseUrl) {
    return rawBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
  }

  static void _throwOnBadResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

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
