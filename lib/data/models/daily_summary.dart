class DailySummary {
  final DateTime date;
  final String summary;
  final String encouragement;
  final String improvement;
  final DateTime generatedAt;

  DailySummary({
    required this.date,
    required this.summary,
    required this.encouragement,
    required this.improvement,
    DateTime? generatedAt,
  }) : generatedAt = generatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'summary': summary,
      'encouragement': encouragement,
      'improvement': improvement,
      'generatedAt': generatedAt.toIso8601String(),
    };
  }

  factory DailySummary.fromJson(Map<String, dynamic> json) {
    return DailySummary(
      date: DateTime.parse(json['date'] as String),
      summary: json['summary'] as String,
      encouragement: json['encouragement'] as String,
      improvement: json['improvement'] as String,
      generatedAt: DateTime.parse(json['generatedAt'] as String),
    );
  }
}
