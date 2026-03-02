import 'package:flutter/material.dart';
import '../state/app_settings.dart';

class CityOption {
  const CityOption({required this.key, required this.displayName});

  final String key;
  final String displayName;
}

class LanguageOption {
  const LanguageOption({required this.code, required this.displayName});

  final String code;
  final String displayName;
}

const List<CityOption> _cityOptions = <CityOption>[
  CityOption(key: 'תל אביב', displayName: 'Tel Aviv'),
  CityOption(key: 'ירושלים', displayName: 'Jerusalem'),
  CityOption(key: 'חיפה', displayName: 'Haifa'),
  CityOption(key: 'אשדוד', displayName: 'Ashdod'),
  CityOption(key: 'בארשבע', displayName: 'Be\'er Sheva'),
];

const List<LanguageOption> _languageOptions = <LanguageOption>[
  LanguageOption(code: 'he', displayName: 'Hebrew'),
  LanguageOption(code: 'en', displayName: 'English'),
  LanguageOption(code: 'ru', displayName: 'Russian'),
  LanguageOption(code: 'ar', displayName: 'Arabic'),
];

class CitySetupScreen extends StatefulWidget {
  const CitySetupScreen({super.key, required this.settings});

  final AppSettings settings;

  @override
  State<CitySetupScreen> createState() => _CitySetupScreenState();
}

class _CitySetupScreenState extends State<CitySetupScreen> {
  String? _selectedCityKey;
  late String _selectedLanguageCode;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedCityKey = widget.settings.cityKey;
    _selectedLanguageCode = widget.settings.languageCode;
  }

  Future<void> _saveSelection() async {
    final cityKey = _selectedCityKey;
    if (cityKey == null || _isSaving) {
      return;
    }

    final city = _cityOptions.firstWhere((option) => option.key == cityKey);

    setState(() {
      _isSaving = true;
    });

    await widget.settings.updateCitySelection(
      cityKey: city.key,
      cityDisplay: city.displayName,
      languageCode: _selectedLanguageCode,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = false;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('City saved')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bazooka Setup')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Choose your city',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Pick one city for MVP notifications. You can change it later.',
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              key: const Key('languageDropdown'),
              value: _selectedLanguageCode,
              decoration: const InputDecoration(
                labelText: 'Language',
                border: OutlineInputBorder(),
              ),
              items: _languageOptions
                  .map(
                    (option) => DropdownMenuItem<String>(
                      value: option.code,
                      child: Text(option.displayName),
                    ),
                  )
                  .toList(),
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
            DropdownButtonFormField<String>(
              key: const Key('cityDropdown'),
              value: _selectedCityKey,
              decoration: const InputDecoration(
                labelText: 'City',
                border: OutlineInputBorder(),
              ),
              items: _cityOptions
                  .map(
                    (option) => DropdownMenuItem<String>(
                      value: option.key,
                      child: Text('${option.displayName} (${option.key})'),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCityKey = value;
                });
              },
            ),
            const Spacer(),
            ElevatedButton(
              key: const Key('saveCityButton'),
              onPressed: _selectedCityKey == null || _isSaving
                  ? null
                  : _saveSelection,
              child: Text(_isSaving ? 'Saving...' : 'Save city'),
            ),
          ],
        ),
      ),
    );
  }
}
