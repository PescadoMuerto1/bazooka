import 'dart:convert';

import 'package:flutter/foundation.dart';

class AppLogger {
  const AppLogger._();

  static void info(
    String scope,
    String message, [
    Map<String, Object?> context = const <String, Object?>{},
  ]) {
    _log('INFO', scope, message, context: context);
  }

  static void warn(
    String scope,
    String message, [
    Map<String, Object?> context = const <String, Object?>{},
  ]) {
    _log('WARN', scope, message, context: context);
  }

  static void error(
    String scope,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> context = const <String, Object?>{},
  }) {
    _log(
      'ERROR',
      scope,
      message,
      context: <String, Object?>{
        ...context,
        if (error != null) 'error': error.toString(),
      },
    );
    if (stackTrace != null) {
      debugPrint(
        '${DateTime.now().toIso8601String()} [ERROR][$scope] stack=$stackTrace',
      );
    }
  }

  static void _log(
    String level,
    String scope,
    String message, {
    Map<String, Object?> context = const <String, Object?>{},
  }) {
    final timestamp = DateTime.now().toIso8601String();
    final suffix = context.isEmpty ? '' : ' context=${_safeJson(context)}';
    debugPrint('$timestamp [$level][$scope] $message$suffix');
  }

  static String _safeJson(Map<String, Object?> context) {
    try {
      return jsonEncode(context);
    } catch (_) {
      return context.toString();
    }
  }
}
