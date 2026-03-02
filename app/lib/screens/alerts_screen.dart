import 'dart:async';

import 'package:flutter/material.dart';

import '../models/alert_dto.dart';
import '../services/api_client.dart';
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

  @override
  void initState() {
    super.initState();
    unawaited(
      widget.pushService.initializeAndSync(
        settings: widget.settings,
        apiClient: widget.apiClient,
      ),
    );
    unawaited(_fetchAlerts());
  }

  Future<void> _fetchAlerts() async {
    final cityKey = widget.settings.cityKey;
    if (cityKey == null || cityKey.trim().isEmpty) {
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

    try {
      final alerts = await widget.apiClient.fetchRecentAlerts(cityKey: cityKey);
      if (!mounted) {
        return;
      }

      setState(() {
        _alerts = alerts;
        _isLoading = false;
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
      debugPrint('Alerts fetch failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cityDisplay =
        widget.settings.cityDisplay ?? widget.settings.cityKey ?? 'Unknown';
    final languageDisplay =
        _languageNames[widget.settings.languageCode] ??
        widget.settings.languageCode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bazooka Alerts'),
        actions: <Widget>[
          IconButton(
            key: const Key('refreshAlertsButton'),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _fetchAlerts,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('City: $cityDisplay'),
                    const SizedBox(height: 8),
                    Text('Language: $languageDisplay'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Recent alerts',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            Expanded(child: _buildAlertsBody()),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('changeCityButton'),
              onPressed: widget.settings.clearCitySelection,
              child: const Text('Change city'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_alerts.isEmpty) {
      return const Center(child: Text('No recent alerts yet'));
    }

    return RefreshIndicator(
      onRefresh: _fetchAlerts,
      child: ListView.separated(
        itemCount: _alerts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final alert = _alerts[index];
          final areaSummary = alert.areas.isEmpty
              ? 'Unknown area'
              : alert.areas.join(', ');
          final description = alert.desc.isEmpty
              ? 'No description'
              : alert.desc;

          return Card(
            child: ListTile(
              title: Text(alert.title),
              subtitle: Text('$areaSummary\n$description'),
              isThreeLine: true,
              trailing: Text(
                alert.category,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          );
        },
      ),
    );
  }
}
