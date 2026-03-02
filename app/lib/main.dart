import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:app/screens/alerts_screen.dart';
import 'package:app/screens/city_setup_screen.dart';
import 'package:app/services/api_client.dart';
import 'package:app/services/push_service.dart';
import 'package:app/state/app_settings.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await PushService.showBackgroundAlertNotification(message);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Fall back to defaults/dart-define when .env is missing.
  }
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
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFFFC107), // Yellow background
              primary: const Color(0xFF1976D2), // A much nicer deep blue
              onPrimary: Colors.white,
              secondary: const Color(0xFFFF9800), // Orange arms/legs
              onSecondary: Colors.white,
              surface: Colors.white,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFFFFC107),
              foregroundColor: Colors.black87,
              centerTitle: true,
              elevation: 0,
              titleTextStyle: TextStyle(
                color: Colors.black87,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
                foregroundColor: Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 32,
                ),
                textStyle: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(
                  color: Color(0xFF1976D2),
                  width: 3,
                ),
              ),
            ),
            scaffoldBackgroundColor: const Color(0xFFFFF8E1),
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
    return Scaffold(
      body: SizedBox.expand(
        child: Image.asset(
          'assets/splash.png',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}
