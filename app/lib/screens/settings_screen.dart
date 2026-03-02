import 'package:flutter/material.dart';

import '../services/api_client.dart';
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
  }

  Future<void> _saveLanguage() async {
    if (_isSavingLanguage) {
      return;
    }

    setState(() {
      _isSavingLanguage = true;
    });

    try {
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
    } catch (error) {
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
      return;
    }

    setState(() {
      _isTestingNotification = true;
    });

    try {
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
    } catch (error) {
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
    await widget.settings.clearCitySelection();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _enableAutoOpenAlerts() async {
    if (_isEnablingAutoOpen) {
      return;
    }

    setState(() {
      _isEnablingAutoOpen = true;
    });

    try {
      final granted = await widget.pushService
          .requestFullScreenIntentPermission();
      if (!mounted) {
        return;
      }
      final text = granted
          ? 'Auto-open permission granted. Lock/turn off screen to test full-screen launch.'
          : 'Auto-open permission not granted yet. Enable Full-screen notifications in Android settings.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    } catch (error) {
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
