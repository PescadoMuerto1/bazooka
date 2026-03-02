class AlertDto {
  const AlertDto({
    required this.alertId,
    required this.title,
    required this.category,
    required this.areas,
    required this.desc,
    required this.sourceTimestamp,
    required this.ingestedAt,
  });

  final String alertId;
  final String title;
  final String category;
  final List<String> areas;
  final String desc;
  final DateTime? sourceTimestamp;
  final DateTime? ingestedAt;

  factory AlertDto.fromJson(Map<String, dynamic> json) {
    final rawAreas = json['areas'];
    final areas = rawAreas is List
        ? rawAreas
              .whereType<String>()
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toList(growable: false)
        : const <String>[];

    return AlertDto(
      alertId: json['alertId']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Home Front Alert',
      category: json['category']?.toString() ?? 'unknown',
      areas: areas,
      desc: json['desc']?.toString() ?? '',
      sourceTimestamp: _parseOptionalDateTime(json['sourceTimestamp']),
      ingestedAt: _parseOptionalDateTime(json['ingestedAt']),
    );
  }

  static DateTime? _parseOptionalDateTime(dynamic value) {
    if (value is! String || value.trim().isEmpty) {
      return null;
    }

    return DateTime.tryParse(value);
  }
}
