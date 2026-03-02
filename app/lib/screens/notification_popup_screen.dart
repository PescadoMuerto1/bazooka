import 'package:flutter/material.dart';

class NotificationPopupScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final areaText = areas.isEmpty ? 'Unknown area' : areas.join(', ');
    final bodyText = body.trim().isEmpty
        ? 'Stay alert and follow instructions.'
        : body;

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
                      title,
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
                      onPressed: () => Navigator.of(context).pop(),
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
