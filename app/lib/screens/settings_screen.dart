import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/app_logger.dart';
import '../services/push_service.dart';
import '../state/app_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.settings,
    required this.apiClient,
    required this.pushService,
  });

  final AppSettings settings;
  final AlertsApi apiClient;
  final PushSyncService pushService;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const Map<String, String> _languageNames = <String, String>{
    'he': 'Hebrew',
    'en': 'English',
    'ru': 'Russian',
    'ar': 'Arabic',
  };

  late String _selectedLanguageCode;
  bool _isSavingLanguage = false;
  bool _isTestingNotification = false;
  bool _isEnablingAutoOpen = false;

  @override
  void initState() {
    super.initState();
    _selectedLanguageCode = widget.settings.languageCode;
    AppLogger.info(
      'SettingsScreen',
      'Initialized settings screen',
      <String, Object?>{
        'selectedLanguageCode': _selectedLanguageCode,
        'cityKey': widget.settings.cityKey ?? '',
      },
    );
  }

  Future<void> _saveLanguage() async {
    if (_isSavingLanguage) {
      AppLogger.warn('SettingsScreen', 'Save language skipped: already saving');
      return;
    }

    setState(() {
      _isSavingLanguage = true;
    });

    try {
      AppLogger.info('SettingsScreen', 'Saving language', <String, Object?>{
        'languageCode': _selectedLanguageCode,
      });
      await widget.settings.updateLanguage(_selectedLanguageCode);
      await widget.pushService.initializeAndSync(
        settings: widget.settings,
        apiClient: widget.apiClient,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Language saved')));
      AppLogger.info('SettingsScreen', 'Language saved');
    } catch (error) {
      AppLogger.error(
        'SettingsScreen',
        'Language save failed',
        error: error,
        context: <String, Object?>{'languageCode': _selectedLanguageCode},
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Language update failed: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isSavingLanguage = false;
        });
      }
    }
  }

  Future<void> _runNotificationTest() async {
    if (_isTestingNotification) {
      AppLogger.warn(
        'SettingsScreen',
        'Notification test skipped: already running',
      );
      return;
    }

    setState(() {
      _isTestingNotification = true;
    });

    try {
      AppLogger.info('SettingsScreen', 'Running notification sync test');
      await widget.pushService.initializeAndSync(
        settings: widget.settings,
        apiClient: widget.apiClient,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Notification sync test sent. Check backend delivery logs.',
          ),
        ),
      );
      AppLogger.info('SettingsScreen', 'Notification sync test completed');
    } catch (error) {
      AppLogger.error(
        'SettingsScreen',
        'Notification sync test failed',
        error: error,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Notification test failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isTestingNotification = false;
        });
      }
    }
  }

  Future<void> _changeCity() async {
    AppLogger.info('SettingsScreen', 'Changing city');
    await widget.settings.clearCitySelection();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _enableAutoOpenAlerts() async {
    if (_isEnablingAutoOpen) {
      AppLogger.warn(
        'SettingsScreen',
        'Enable auto-open skipped: already in progress',
      );
      return;
    }

    setState(() {
      _isEnablingAutoOpen = true;
    });

    try {
      AppLogger.info('SettingsScreen', 'Requesting auto-open permission');
      final granted = await widget.pushService
          .requestFullScreenIntentPermission();
      if (!mounted) {
        return;
      }
      final text = granted
          ? 'Auto-open permission granted. Lock/turn off screen to test full-screen launch.'
          : 'Auto-open permission not granted yet. Enable Full-screen notifications in Android settings.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
      AppLogger.info(
        'SettingsScreen',
        'Auto-open permission result',
        <String, Object?>{'granted': granted},
      );
    } catch (error) {
      AppLogger.error(
        'SettingsScreen',
        'Request auto-open permission failed',
        error: error,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not request auto-open permission: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isEnablingAutoOpen = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cityDisplay =
        widget.settings.cityDisplay ?? widget.settings.cityKey ?? 'Unknown';

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Subscription',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text('City: $cityDisplay'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Language',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: const Key('settingsLanguageDropdown'),
                    value: _selectedLanguageCode,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: _languageNames.entries
                        .map(
                          (entry) => DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _selectedLanguageCode = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    key: const Key('saveLanguageButton'),
                    onPressed: _isSavingLanguage ? null : _saveLanguage,
                    child: Text(
                      _isSavingLanguage ? 'Saving...' : 'Save language',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Notification Test',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This action refreshes your FCM token sync with the backend.',
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    key: const Key('testNotificationButton'),
                    onPressed: _isTestingNotification
                        ? null
                        : _runNotificationTest,
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: Text(
                      _isTestingNotification
                          ? 'Running test...'
                          : 'Run notification test',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Auto-open alerts',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Android only: allows full-screen notification launch when the screen is off/locked.',
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    key: const Key('enableFullScreenAlertsButton'),
                    onPressed: _isEnablingAutoOpen
                        ? null
                        : _enableAutoOpenAlerts,
                    icon: const Icon(Icons.screen_lock_portrait_outlined),
                    label: Text(
                      _isEnablingAutoOpen
                          ? 'Opening settings...'
                          : 'Enable auto-open alerts',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            key: const Key('settingsChangeCityButton'),
            onPressed: _changeCity,
            child: const Text('Change city'),
          ),
        ],
      ),
    );
  }
}
