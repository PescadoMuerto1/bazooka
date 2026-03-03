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

class _NotificationPopupScreenState extends State<NotificationPopupScreen> {
  late final AudioPlayer _audioPlayer;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
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
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final areaText = widget.areas.isEmpty
        ? 'Unknown area'
        : widget.areas.join(', ');
    final bodyText = widget.body.trim().isEmpty
        ? 'Stay alert and follow instructions.'
        : widget.body;

    return Scaffold(
      appBar: AppBar(title: const Text('Incoming Alert')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              elevation: 6,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      widget.title,
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      bodyText,
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Areas: $areaText',
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      key: const Key('closeNotificationPopupButton'),
                      onPressed: () {
                        AppLogger.info(
                          'NotificationPopup',
                          'Close button pressed',
                        );
                        Navigator.of(context).pop();
                      },
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
