class MorningReport {
  final String date;
  final List<String> news;
  final String weiyu;
  final String headImage;

  MorningReport({
    required this.date,
    required this.news,
    required this.weiyu,
    required this.headImage,
  });

  factory MorningReport.fromJson(Map<String, dynamic> json) {
    return MorningReport(
      date: json['date'] as String,
      news: (json['news'] as List).map((e) => e as String).toList(),
      weiyu: json['weiyu'] as String,
      headImage: json['head_image'] as String,
    );
  }
}
