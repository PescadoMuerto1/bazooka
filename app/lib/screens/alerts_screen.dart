import 'dart:async';

import 'package:flutter/material.dart';

import '../models/alert_dto.dart';
import 'notification_popup_screen.dart';
import '../screens/settings_screen.dart';
import '../services/api_client.dart';
import '../services/app_logger.dart';
import '../services/push_service.dart';
import '../state/app_settings.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({
    super.key,
    required this.settings,
    required this.apiClient,
    required this.pushService,
  });

  final AppSettings settings;
  final AlertsApi apiClient;
  final PushSyncService pushService;

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  static const Map<String, String> _languageNames = <String, String>{
    'he': 'Hebrew',
    'en': 'English',
    'ru': 'Russian',
    'ar': 'Arabic',
  };

  List<AlertDto> _alerts = const <AlertDto>[];
  bool _isLoading = true;
  String? _errorMessage;
  StreamSubscription<PushAlertEvent>? _pushAlertSubscription;

  Future<void> _openSettings() async {
    AppLogger.info('AlertsScreen', 'Opening settings screen');
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => SettingsScreen(
          settings: widget.settings,
          apiClient: widget.apiClient,
          pushService: widget.pushService,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    AppLogger.info('AlertsScreen', 'Returned from settings; refreshing alerts');
    await _fetchAlerts();
  }

  @override
  void initState() {
    super.initState();
    AppLogger.info('AlertsScreen', 'initState');
    _pushAlertSubscription = widget.pushService.alertEvents.listen(
      _handlePushAlertEvent,
    );
    unawaited(
      widget.pushService.initializeAndSync(
        settings: widget.settings,
        apiClient: widget.apiClient,
      ),
    );
    unawaited(_fetchAlerts());
  }

  @override
  void dispose() {
    AppLogger.info('AlertsScreen', 'dispose');
    _pushAlertSubscription?.cancel();
    super.dispose();
  }

  void _handlePushAlertEvent(PushAlertEvent event) {
    if (!mounted) {
      return;
    }
    AppLogger.info(
      'AlertsScreen',
      'Push alert event received',
      <String, Object?>{'title': event.title, 'areasCount': event.areas.length},
    );

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => NotificationPopupScreen(
          title: event.title,
          body: event.body,
          areas: event.areas,
        ),
      ),
    );
  }

  Future<void> _fetchAlerts() async {
    final cityKey = widget.settings.cityKey;
    if (cityKey == null || cityKey.trim().isEmpty) {
      AppLogger.warn('AlertsScreen', 'Fetch skipped: city key missing');
      setState(() {
        _alerts = const <AlertDto>[];
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    AppLogger.info('AlertsScreen', 'Fetching alerts', <String, Object?>{
      'cityKey': cityKey,
    });

    try {
      final alerts = await widget.apiClient.fetchRecentAlerts(cityKey: cityKey);
      if (!mounted) {
        return;
      }

      setState(() {
        _alerts = alerts;
        _isLoading = false;
      });
      AppLogger.info('AlertsScreen', 'Alerts fetched', <String, Object?>{
        'cityKey': cityKey,
        'count': alerts.length,
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _alerts = const <AlertDto>[];
        _isLoading = false;
        _errorMessage = 'Could not fetch recent alerts';
      });
      AppLogger.error(
        'AlertsScreen',
        'Alerts fetch failed',
        error: error,
        context: <String, Object?>{'cityKey': cityKey},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cityDisplay =
        widget.settings.cityDisplay ?? widget.settings.cityKey ?? 'Unknown';

    final now = DateTime.now();
    final dateDisplay = '${now.day}/${now.month}/${now.year}';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Stack(
        children: <Widget>[
          // Yellow Header Background
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 300,
            child: Container(color: const Color(0xFFFFC107)),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Custom Top App Bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Row(
                    children: <Widget>[
                      const SizedBox(width: 12),
                      const Text(
                        'BAZOOKA',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        key: const Key('openSettingsButton'),
                        icon: const CircleAvatar(
                          backgroundColor: Colors.white54,
                          child: Icon(Icons.settings, color: Colors.black87),
                        ),
                        onPressed: _openSettings,
                      ),
                    ],
                  ),
                ),
                // Subheader
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      const Text(
                        'Current Status',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        dateDisplay,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1976D2), // Deep Blue
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text(
                              cityDisplay.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                letterSpacing: 1.1,
                              ),
                            ),
                            InkWell(
                              key: const Key('refreshAlertsButton'),
                              onTap: _fetchAlerts,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.refresh,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _alerts.isEmpty ? 'NORMAL' : 'ALERTS',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: _alerts.isEmpty
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFFFF5252),
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _alerts.isEmpty
                              ? 'System Monitoring'
                              : 'Recent alarms detected',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Recent Alerts',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                Expanded(child: _buildAlertsBody()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_alerts.isEmpty) {
      return const Center(
        child: Text(
          'No recent alerts yet',
          style: TextStyle(color: Colors.black54, fontSize: 16),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchAlerts,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        itemCount: _alerts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final alert = _alerts[index];
          final hasTimestamp = alert.sourceTimestamp != null;
          final timeStr = hasTimestamp
              ? '${alert.sourceTimestamp!.hour}:${alert.sourceTimestamp!.minute.toString().padLeft(2, '0')}'
              : 'Recently';

          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFC107).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFFF9800),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          alert.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          alert.desc.isNotEmpty
                              ? alert.desc
                              : 'Caution advised in your area.',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          timeStr,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black38,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Opacity(
                    opacity: 0.2,
                    child: Image.asset(
                      'assets/missile.png',
                      width: 24,
                      color: Colors.transparent,
                      colorBlendMode: BlendMode.multiply,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
