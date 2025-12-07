class ApiSettings {
  final String apiKey;
  final String baseUrl;
  final String model;
  
  const ApiSettings({
    required this.apiKey,
    required this.baseUrl,
    required this.model,
  });
  
  ApiSettings copyWith({String? apiKey, String? baseUrl, String? model}) {
    return ApiSettings(
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
    );
  }

  // JSON Serialization
  Map<String, dynamic> toJson() {
    return {
      'apiKey': apiKey,
      'baseUrl': baseUrl,
      'model': model,
    };
  }

  factory ApiSettings.fromJson(Map<String, dynamic> json) {
    return ApiSettings(
      apiKey: json['apiKey'] as String,
      baseUrl: json['baseUrl'] as String,
      model: json['model'] as String,
    );
  }
}
