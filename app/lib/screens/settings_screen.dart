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
      backgroundColor: const Color(0xFF1976D2), // Deep App Blue
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Settings',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          children: <Widget>[
            // Subscription Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Subscription',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey[800],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.location_city, color: Color(0xFF1976D2)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          cityDisplay,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      TextButton(
                        key: const Key('settingsChangeCityButton'),
                        onPressed: _changeCity,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFFFC107), // Yellow
                        ),
                        child: const Text(
                          'CHANGE',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Language Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Language',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey[800],
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: const Key('settingsLanguageDropdown'),
                    value: _selectedLanguageCode,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF1976D2),
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
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
                  const SizedBox(height: 16),
                  ElevatedButton(
                    key: const Key('saveLanguageButton'),
                    onPressed:
                        _isSavingLanguage ||
                            _selectedLanguageCode ==
                                widget.settings.languageCode
                        ? null
                        : _saveLanguage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFC107), // Yellow
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      _isSavingLanguage ? 'SAVING...' : 'SAVE LANGUAGE',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Diagnostic Notification Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Diagnostics',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Refreshes your FCM token sync to ensure you receive alerts.',
                    style: TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    key: const Key('testNotificationButton'),
                    onPressed: _isTestingNotification
                        ? null
                        : _runNotificationTest,
                    icon: const Icon(Icons.sync),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: const BorderSide(color: Color(0xFF1976D2)),
                      foregroundColor: const Color(0xFF1976D2),
                    ),
                    label: Text(
                      _isTestingNotification
                          ? 'Running sync...'
                          : 'Run token sync test',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Auto-open Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Auto-open Alerts (Android)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Allows full-screen notification launch when the screen is locked.',
                    style: TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    key: const Key('enableFullScreenAlertsButton'),
                    onPressed: _isEnablingAutoOpen
                        ? null
                        : _enableAutoOpenAlerts,
                    icon: const Icon(Icons.screen_lock_portrait_outlined),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1976D2).withOpacity(0.1),
                      foregroundColor: const Color(0xFF1976D2),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    label: Text(
                      _isEnablingAutoOpen
                          ? 'Opening settings...'
                          : 'Enable auto-open',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
