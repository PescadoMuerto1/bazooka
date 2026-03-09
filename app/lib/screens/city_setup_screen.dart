import 'package:flutter/material.dart';

import '../data/oref_cities.dart';
import '../services/app_logger.dart';
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
        .map((cityName) => CityOption(key: cityName, displayName: cityName))
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
    final query = _searchQuery.trim();
    if (query.isEmpty) {
      return _allCityOptions;
    }

    return _allCityOptions
        .where((option) {
          return option.key.contains(query) ||
              option.displayName.contains(query);
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
      orElse: () => CityOption(key: cityKey, displayName: cityKey),
    );

    setState(() {
      _isSaving = true;
    });
    AppLogger.info(
      'CitySetupScreen',
      'Saving city selection',
      <String, Object?>{
        'cityKey': city.key,
        'cityDisplay': city.displayName,
        'languageCode': _selectedLanguageCode,
      },
    );

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
    AppLogger.info('CitySetupScreen', 'City selection saved');

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('City saved')));
  }

  @override
  Widget build(BuildContext context) {
    final filteredCityOptions = _filteredCityOptions;
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
                        final hasSecondLine = city.displayName != city.key;

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
                                        city.displayName,
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
                                            Text(
                                              city.key,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.black54,
                                                fontWeight: FontWeight.w500,
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
}
