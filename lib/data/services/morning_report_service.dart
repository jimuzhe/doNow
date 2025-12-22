import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/morning_report.dart';

class MorningReportService {
  static const String _url = 'https://api.zxki.cn/api/mrzb';

  Future<MorningReport> fetchReport() async {
    try {
      final response = await http.get(Uri.parse(_url));
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        if (json['code'] == 200 && json['data'] != null) {
          return MorningReport.fromJson(json['data']);
        } else {
          throw Exception('Failed to load morning report: ${json['msg']}');
        }
      } else {
        throw Exception('Failed to fetch morning report: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching morning report: $e');
    }
  }
}
