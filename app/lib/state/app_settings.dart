import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  static const _cityKeyStorage = 'city_key';
  static const _cityDisplayStorage = 'city_display';
  static const _languageCodeStorage = 'language_code';

  String? _cityKey;
  String? _cityDisplay;
  String _languageCode = 'he';
  bool _isLoaded = false;

  String? get cityKey => _cityKey;
  String? get cityDisplay => _cityDisplay;
  String get languageCode => _languageCode;
  bool get isLoaded => _isLoaded;

  bool get hasSelectedCity {
    return _cityKey != null && _cityKey!.trim().isNotEmpty;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _cityKey = prefs.getString(_cityKeyStorage);
    _cityDisplay = prefs.getString(_cityDisplayStorage);
    _languageCode = prefs.getString(_languageCodeStorage) ?? 'he';
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> updateLanguage(String languageCode) async {
    _languageCode = languageCode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageCodeStorage, _languageCode);
    notifyListeners();
  }

  Future<void> updateCitySelection({
    required String cityKey,
    required String cityDisplay,
    required String languageCode,
  }) async {
    _cityKey = cityKey;
    _cityDisplay = cityDisplay;
    _languageCode = languageCode;

    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_cityKeyStorage, cityKey),
      prefs.setString(_cityDisplayStorage, cityDisplay),
      prefs.setString(_languageCodeStorage, languageCode),
    ]);

    notifyListeners();
  }

  Future<void> clearCitySelection() async {
    _cityKey = null;
    _cityDisplay = null;

    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_cityKeyStorage),
      prefs.remove(_cityDisplayStorage),
    ]);

    notifyListeners();
  }
}
