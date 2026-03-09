import 'package:flutter/material.dart';

import 'city_setup_screen.dart';
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
  static const Color _pageBackground = Color(0xFFF3F6FB);
  static const Color _cardBackground = Colors.white;
  static const Color _accentColor = Color(0xFF1976D2);
  static const Color _primaryTextColor = Color(0xFF0F172A);
  static const Color _secondaryTextColor = Color(0xFF475569);

  static const Map<String, String> _languageNames = <String, String>{
    'he': 'Hebrew',
    'en': 'English',
    'ru': 'Russian',
    'ar': 'Arabic',
  };

  late String _selectedLanguageCode;
  bool _isSavingLanguage = false;

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

  Future<void> _changeCity() async {
    AppLogger.info('SettingsScreen', 'Opening city setup screen');
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => CitySetupScreen(settings: widget.settings),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cityDisplay =
        widget.settings.cityDisplay ?? widget.settings.cityKey ?? 'Unknown';

    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: AppBar(
        backgroundColor: _pageBackground,
        elevation: 0,
        iconTheme: const IconThemeData(color: _primaryTextColor),
        title: const Text(
          'Settings',
          style: TextStyle(
            color: _primaryTextColor,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          children: <Widget>[
            const Text(
              'Account Preferences',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: _primaryTextColor,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Manage your alert city and interface language.',
              style: TextStyle(
                fontSize: 14,
                color: _secondaryTextColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: _cardBackground,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x140F172A),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Text(
                    'City',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: _primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Material(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      key: const Key('settingsChangeCityButton'),
                      borderRadius: BorderRadius.circular(14),
                      onTap: _changeCity,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        child: Row(
                          children: <Widget>[
                            Container(
                              width: 36,
                              height: 36,
                              decoration: const BoxDecoration(
                                color: Color(0xFFE8F1FF),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.location_city,
                                color: _accentColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                cityDisplay,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: _primaryTextColor,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: Color(0xFF94A3B8),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: _cardBackground,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x140F172A),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Text(
                    'Language',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: _primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Choose the app language for alerts and labels.',
                    style: TextStyle(
                      fontSize: 13,
                      color: _secondaryTextColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    key: const Key('settingsLanguageDropdown'),
                    value: _selectedLanguageCode,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFD5DFEB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: _accentColor,
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
                            child: Text(
                              entry.value,
                              style: const TextStyle(
                                color: _primaryTextColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: _isSavingLanguage
                        ? null
                        : (value) {
                            if (value == null ||
                                value == _selectedLanguageCode) {
                              return;
                            }
                            setState(() {
                              _selectedLanguageCode = value;
                            });
                            _saveLanguage();
                          },
                  ),
                  if (_isSavingLanguage) ...[
                    const SizedBox(height: 14),
                    const Text(
                      'Saving language...',
                      style: TextStyle(
                        fontSize: 13,
                        color: _secondaryTextColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
