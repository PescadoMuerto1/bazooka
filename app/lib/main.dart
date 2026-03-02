import 'package:flutter/material.dart';
import 'package:app/screens/city_setup_screen.dart';
import 'package:app/state/app_settings.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AppSettings _settings = AppSettings();
  late final Future<void> _initialLoad;

  @override
  void initState() {
    super.initState();
    _initialLoad = _settings.load();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _settings,
      builder: (context, _) {
        return MaterialApp(
          title: 'Bazooka',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFB3261E),
            ),
          ),
          home: FutureBuilder<void>(
            future: _initialLoad,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done ||
                  !_settings.isLoaded) {
                return const _LoadingScreen();
              }

              if (!_settings.hasSelectedCity) {
                return CitySetupScreen(settings: _settings);
              }

              return _HomeScreen(settings: _settings);
            },
          ),
        );
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _HomeScreen extends StatelessWidget {
  const _HomeScreen({required this.settings});

  final AppSettings settings;

  static const Map<String, String> _languageNames = <String, String>{
    'he': 'Hebrew',
    'en': 'English',
    'ru': 'Russian',
    'ar': 'Arabic',
  };

  @override
  Widget build(BuildContext context) {
    final cityDisplay = settings.cityDisplay ?? settings.cityKey ?? 'Unknown';
    final languageDisplay =
        _languageNames[settings.languageCode] ?? settings.languageCode;

    return Scaffold(
      appBar: AppBar(title: const Text('Bazooka')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Notifications are set',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
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
            const Spacer(),
            OutlinedButton(
              key: const Key('changeCityButton'),
              onPressed: settings.clearCitySelection,
              child: const Text('Change city'),
            ),
          ],
        ),
      ),
    );
  }
}
