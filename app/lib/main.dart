import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:app/screens/alerts_screen.dart';
import 'package:app/screens/city_setup_screen.dart';
import 'package:app/services/api_client.dart';
import 'package:app/services/push_service.dart';
import 'package:app/state/app_settings.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage _) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Initialization can fail in test/misconfigured environments; app still runs.
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Allow startup even when Firebase native config is not present yet.
  }
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.settings, this.apiClient, this.pushService});

  final AppSettings? settings;
  final AlertsApi? apiClient;
  final PushSyncService? pushService;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AppSettings _settings;
  late final AlertsApi _apiClient;
  late final PushSyncService _pushService;
  late final Future<void> _initialLoad;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings ?? AppSettings();
    _apiClient = widget.apiClient ?? ApiClient();
    _pushService = widget.pushService ?? PushService();
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

              return AlertsScreen(
                settings: _settings,
                apiClient: _apiClient,
                pushService: _pushService,
              );
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
