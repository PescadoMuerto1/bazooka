import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

import '../services/app_logger.dart';

class NotificationPopupScreen extends StatefulWidget {
  const NotificationPopupScreen({
    super.key,
    required this.title,
    required this.body,
    required this.areas,
  });

  final String title;
  final String body;
  final List<String> areas;

  @override
  State<NotificationPopupScreen> createState() =>
      _NotificationPopupScreenState();
}

class _NotificationPopupScreenState extends State<NotificationPopupScreen>
    with SingleTickerProviderStateMixin {
  late final AudioPlayer _audioPlayer;
  late final AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    AppLogger.info('NotificationPopup', 'Popup opened', <String, Object?>{
      'title': widget.title,
      'areasCount': widget.areas.length,
    });
    _startAlertSong();
  }

  Future<void> _startAlertSong() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource('alert_song.mp3'));
      AppLogger.info('NotificationPopup', 'Alert song started');
    } catch (error, stackTrace) {
      // Keep popup functional even if playback fails on a specific device.
      AppLogger.error(
        'NotificationPopup',
        'Alert song playback failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  void dispose() {
    AppLogger.info('NotificationPopup', 'Popup disposed');
    _animationController.dispose();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final areaText = widget.areas.isEmpty
        ? 'Unknown area'
        : widget.areas.join(', ');

    return Scaffold(
      backgroundColor: const Color(0xFFFFC107), // App Yellow
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            Positioned(
              top: 40,
              left: 0,
              right: 0,
              bottom: 250,
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  final t = _animationController.value;
                  // Circular trajectory
                  final x = math.sin(t * 2 * math.pi) * 0.4;
                  final y = math.cos(t * 2 * math.pi) * -0.4;

                  return Align(
                    alignment: Alignment(x, y),
                    child: Transform.rotate(
                      angle:
                          x *
                          0.4, // Slight tilt corresponding to horizontal position
                      child: child,
                    ),
                  );
                },
                child: Image.asset(
                  'assets/missile.png',
                  width: 220,
                  color: const Color(0xFFFFC107), // Blend white bg with yellow
                  colorBlendMode: BlendMode.multiply,
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      widget.title,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: const Color(0xFF1976D2), // App Blue
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      areaText,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: const Color(0xFF1976D2).withOpacity(0.9),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (widget.body.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: 16),
                      Text(
                        widget.body,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: const Color(0xFF1976D2).withOpacity(0.8),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 32),
                    FilledButton.icon(
                      key: const Key('closeNotificationPopupButton'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1976D2), // App Blue
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 56),
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      icon: const Icon(Icons.close),
                      label: const Text('DISMISS'),
                      onPressed: () {
                        AppLogger.info(
                          'NotificationPopup',
                          'Close button pressed',
                        );
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
