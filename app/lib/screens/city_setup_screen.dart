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
  CityOption(key: 'בית שמש', displayName: 'Beit Shemesh'),
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: 16),
              // Fun header image
              Center(
                child: Image.asset(
                  'assets/icon.png',
                  height: 120,
                  width: 120,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.rocket_launch,
                    size: 80,
                    color: Color(0xFF03A9F4),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Welcome to Bazooka!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF03A9F4),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pick your city for MVP notifications.\nYou can change it later.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 32),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
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
                  children: [
                    DropdownButtonFormField<String>(
                      key: const Key('languageDropdown'),
                      value: _selectedLanguageCode,
                      decoration: const InputDecoration(
                        labelText: 'Language',
                        prefixIcon: Icon(
                          Icons.language,
                          color: Color(0xFFFF9800),
                        ),
                      ),
                      items: _languageOptions
                          .map(
                            (option) => DropdownMenuItem<String>(
                              value: option.code,
                              child: Text(
                                option.displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
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
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      key: const Key('cityDropdown'),
                      value: _selectedCityKey,
                      decoration: const InputDecoration(
                        labelText: 'City',
                        prefixIcon: Icon(
                          Icons.location_city,
                          color: Color(0xFFFF9800),
                        ),
                      ),
                      items: _cityOptions
                          .map(
                            (option) => DropdownMenuItem<String>(
                              value: option.key,
                              child: Text(
                                '${option.displayName} (${option.key})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCityKey = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                key: const Key('saveCityButton'),
                onPressed: _selectedCityKey == null || _isSaving
                    ? null
                    : _saveSelection,
                child: Text(_isSaving ? 'Saving...' : 'LET\'S GO!'),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
