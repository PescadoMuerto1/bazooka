import 'package:flutter/material.dart';

import '../data/oref_cities.dart';
import '../data/oref_city_name_pairs.dart';
import '../services/app_logger.dart';
import '../state/app_settings.dart';

final RegExp _hebrewScriptPattern = RegExp(r'[\u0590-\u05FF]');
final RegExp _latinScriptPattern = RegExp(r'[A-Za-z]');

const Map<String, List<String>> _englishCityAliases = <String, List<String>>{
  'תל אביב - יפו': <String>['Tel Aviv', 'Tel Aviv Yafo', 'Tel-Aviv'],
  'ירושלים': <String>['Jerusalem'],
  'באר שבע': <String>['Beer Sheva', 'Beersheba', "Be'er Sheva"],
  'פתח תקווה': <String>['Petah Tikva', 'Petach Tikva'],
  'בית שמש': <String>['Beit Shemesh'],
};

class CityOption {
  CityOption({
    required this.key,
    required this.hebrewName,
    required this.englishName,
    required this.hebrewSearchValue,
    required this.englishSearchValues,
  });

  final String key;
  final String hebrewName;
  final String englishName;
  final String hebrewSearchValue;
  final List<String> englishSearchValues;

  String displayNameForLanguage(String languageCode) {
    if (languageCode == 'en') {
      return englishName;
    }
    return hebrewName;
  }

  String secondaryNameForLanguage(String languageCode) {
    if (languageCode == 'en') {
      return hebrewName;
    }
    return englishName;
  }
}

class LanguageOption {
  const LanguageOption({required this.code, required this.displayName});

  final String code;
  final String displayName;
}

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
  late final List<CityOption> _allCityOptions;
  final TextEditingController _searchController = TextEditingController();
  String? _selectedCityKey;
  late String _selectedLanguageCode;
  String _searchQuery = '';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _allCityOptions = orefCityNames
        .map(_buildCityOption)
        .toList(growable: false);
    _selectedCityKey = widget.settings.cityKey;
    _selectedLanguageCode = widget.settings.languageCode;
    _searchController.addListener(_handleSearchChanged);
    AppLogger.info(
      'CitySetupScreen',
      'Initialized city setup screen',
      <String, Object?>{
        'availableCityCount': _allCityOptions.length,
        'selectedCityKey': _selectedCityKey ?? '',
        'selectedLanguageCode': _selectedLanguageCode,
      },
    );
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  List<CityOption> get _filteredCityOptions {
    final rawQuery = _searchQuery.trim();
    if (rawQuery.isEmpty) {
      return _allCityOptions;
    }

    final hasHebrewInput = _hebrewScriptPattern.hasMatch(rawQuery);
    final hasLatinInput = _latinScriptPattern.hasMatch(rawQuery);

    if (hasHebrewInput && !hasLatinInput) {
      final normalizedHebrewQuery = _normalizeHebrewForSearch(rawQuery);
      return _allCityOptions
          .where(
            (option) =>
                option.hebrewSearchValue.contains(normalizedHebrewQuery),
          )
          .toList(growable: false);
    }

    if (hasLatinInput && !hasHebrewInput) {
      final normalizedEnglishQuery = _normalizeEnglishForSearch(rawQuery);
      if (normalizedEnglishQuery.isEmpty) {
        return _allCityOptions;
      }

      return _allCityOptions
          .where(
            (option) => option.englishSearchValues.any(
              (searchValue) => searchValue.contains(normalizedEnglishQuery),
            ),
          )
          .toList(growable: false);
    }

    final normalizedHebrewQuery = _normalizeHebrewForSearch(rawQuery);
    final normalizedEnglishQuery = _normalizeEnglishForSearch(rawQuery);
    return _allCityOptions
        .where((option) {
          final matchesHebrew =
              normalizedHebrewQuery.isNotEmpty &&
              option.hebrewSearchValue.contains(normalizedHebrewQuery);
          final matchesEnglish =
              normalizedEnglishQuery.isNotEmpty &&
              option.englishSearchValues.any(
                (searchValue) => searchValue.contains(normalizedEnglishQuery),
              );
          return matchesHebrew || matchesEnglish;
        })
        .toList(growable: false);
  }

  void _handleSearchChanged() {
    final nextQuery = _searchController.text;
    if (nextQuery == _searchQuery) {
      return;
    }
    setState(() {
      _searchQuery = nextQuery;
    });
  }

  Future<void> _saveSelection() async {
    final cityKey = _selectedCityKey;
    if (cityKey == null || _isSaving) {
      AppLogger.warn('CitySetupScreen', 'Save skipped', <String, Object?>{
        'hasCity': cityKey != null,
        'isSaving': _isSaving,
      });
      return;
    }

    final city = _allCityOptions.firstWhere(
      (option) => option.key == cityKey,
      orElse: () => _buildCityOption(cityKey),
    );
    final cityDisplay = city.displayNameForLanguage(_selectedLanguageCode);

    setState(() {
      _isSaving = true;
    });
    AppLogger.info(
      'CitySetupScreen',
      'Saving city selection',
      <String, Object?>{
        'cityKey': city.key,
        'cityDisplay': cityDisplay,
        'languageCode': _selectedLanguageCode,
      },
    );

    await widget.settings.updateCitySelection(
      cityKey: city.key,
      cityDisplay: cityDisplay,
      languageCode: _selectedLanguageCode,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = false;
    });
    AppLogger.info('CitySetupScreen', 'City selection saved');

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('City saved')));
  }

  @override
  Widget build(BuildContext context) {
    final filteredCityOptions = _filteredCityOptions;
    final showSecondaryName =
        _selectedLanguageCode == 'en' ||
        _latinScriptPattern.hasMatch(_searchQuery);
    return Scaffold(
      backgroundColor: const Color(0xFF1976D2), // Deep App Blue
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Header Content
            Padding(
              padding: const EdgeInsets.only(
                top: 40,
                left: 24,
                right: 24,
                bottom: 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Opacity(
                      opacity: 0.5,
                      child: Image.asset(
                        'assets/missile.png',
                        width: 48,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Where are you\nlocated?',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.1,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Language picker
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 0,
                      vertical: 4,
                    ),
                    child: DropdownButtonFormField<String>(
                      key: const Key('languageDropdown'),
                      value: _selectedLanguageCode,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        prefixIcon: Icon(Icons.language, color: Colors.black54),
                      ),
                      icon: const Padding(
                        padding: EdgeInsets.only(right: 16),
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          color: Colors.black54,
                        ),
                      ),
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
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
                        if (value != null) {
                          setState(() {
                            _selectedLanguageCode = value;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Search field
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      key: const Key('citySearchField'),
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      decoration: const InputDecoration(
                        hintText: 'Search city',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        prefixIcon: Icon(Icons.search, color: Colors.black54),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Cities List
            Expanded(
              child: filteredCityOptions.isEmpty
                  ? const Center(
                      child: Text(
                        'No cities found',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      itemCount: filteredCityOptions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final city = filteredCityOptions[index];
                        final isSelected = city.key == _selectedCityKey;
                        final primaryName = city.displayNameForLanguage(
                          _selectedLanguageCode,
                        );
                        final secondaryName = city.secondaryNameForLanguage(
                          _selectedLanguageCode,
                        );
                        final hasSecondLine =
                            showSecondaryName &&
                            secondaryName.isNotEmpty &&
                            secondaryName != primaryName;

                        return InkWell(
                          key: Key('cityOption_${city.key}'),
                          onTap: () {
                            setState(() {
                              _selectedCityKey = city.key;
                            });
                            _saveSelection(); // Auto-save on tap for smoother UX
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFF0F7FF)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: isSelected
                                  ? Border.all(
                                      color: const Color(0xFFFFC107),
                                      width: 2,
                                    )
                                  : null,
                              boxShadow: const <BoxShadow>[
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 8,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFFF5F7FA),
                                    border: Border.all(color: Colors.black12),
                                  ),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.flag,
                                    size: 18,
                                    color: Color(0xFF1976D2),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        primaryName,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      if (hasSecondLine) ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.location_on,
                                              size: 12,
                                              color: Colors.black54,
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                secondaryName,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.black54,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (isSelected ||
                                    _isSaving && city.key == _selectedCityKey)
                                  _isSaving
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.check_circle,
                                          color: Color(0xFF4CAF50),
                                        ),
                                if (!isSelected && !_isSaving)
                                  const Icon(
                                    Icons.chevron_right,
                                    color: Colors.black26,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  CityOption _buildCityOption(String hebrewName) {
    final englishName = orefCityEnglishNames[hebrewName] ?? hebrewName;
    final aliases = _englishCityAliases[hebrewName] ?? const <String>[];
    final englishSearchValues = <String>{
      _normalizeEnglishForSearch(englishName),
      for (final alias in aliases) _normalizeEnglishForSearch(alias),
    }.where((value) => value.isNotEmpty).toList(growable: false);

    return CityOption(
      key: hebrewName,
      hebrewName: hebrewName,
      englishName: englishName,
      hebrewSearchValue: _normalizeHebrewForSearch(hebrewName),
      englishSearchValues: englishSearchValues,
    );
  }

  String _normalizeHebrewForSearch(String value) {
    return value
        .replaceAll(RegExp(r'''["'`׳״]'''), '')
        .replaceAll(RegExp(r'[-־]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _normalizeEnglishForSearch(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'''["'`׳״]'''), '')
        .replaceAll(RegExp(r'[-_/.,()]+'), ' ')
        .replaceAll('ph', 'f')
        .replaceAll(RegExp(r'(kh|ch)'), 'h')
        .replaceAll(RegExp(r'(tz|ts)'), 'z')
        .replaceAll('v', 'b')
        .replaceAll(RegExp(r'[aeiouyw]'), '')
        .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
