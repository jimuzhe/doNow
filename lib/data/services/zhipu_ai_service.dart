import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/subtask.dart';
import 'ai_service.dart';
import '../models/api_settings.dart';

class ZhipuAIService implements AIService {
  final Uuid _uuid = const Uuid();
  final ApiSettings settings;

  ZhipuAIService(this.settings);

  @override
  Future<List<SubTask>> decomposeTask(String taskTitle, Duration totalDuration) async {
    if (settings.apiKey == 'YOUR_API_KEY_HERE') {
      throw Exception('Please set your API Key in Settings');
    }

    const maxAttempts = 3; // Increased retries for format validation
    int attempts = 0;
    
    while (attempts < maxAttempts) {
      try {
        attempts++;
        final prompt = _buildPrompt(taskTitle, totalDuration);

        final response = await http.post(
          Uri.parse(settings.baseUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${settings.apiKey}',
          },
          body: jsonEncode({
            "model": settings.model,
            "messages": [
              {"role": "user", "content": prompt}
            ]
          }),
        ).timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          
          if (data['error'] != null) {
              final error = data['error'];
              if (error['code'] == 'security_audit_fail') {
                  throw Exception('security_audit_fail'); 
              }
              throw Exception("AI Error: ${error['message']}");
          }

          final content = data['choices'][0]['message']['content'];
          
          // Try to parse and validate
          final result = _parseAndValidate(content, totalDuration.inMinutes);
          
          if (result != null) {
            return result; // Valid response
          }
          
          // Invalid format, will retry
          print('Attempt $attempts: Invalid format, retrying...');
          continue;
        } else {
          if (attempts == maxAttempts) throw Exception("AI Error: ${response.statusCode}");
        }
      } on TimeoutException {
        if (attempts == maxAttempts) throw Exception("timeout"); 
      } catch (e) {
        if (attempts == maxAttempts) throw Exception("generic");
      }
    }
    return [];
  }

  String _buildPrompt(String title, Duration duration) {
    final minutes = duration.inMinutes;
    
    // Calculate recommended step count based on duration
    int minSteps, maxSteps;
    if (minutes <= 15) {
      minSteps = 2;
      maxSteps = 3;
    } else if (minutes <= 30) {
      minSteps = 3;
      maxSteps = 5;
    } else if (minutes <= 60) {
      minSteps = 4;
      maxSteps = 7;
    } else if (minutes <= 120) {
      minSteps = 5;
      maxSteps = 10;
    } else {
      minSteps = 6;
      maxSteps = 12;
    }
    
    return '''
你是一个专业的任务规划助手。

【任务信息】
任务标题: "$title"
总时长: $minutes 分钟（必须精确分配）

【核心规则 - 必须严格遵守】

1. 语言规则（最重要）:
   - 检测任务标题的语言
   - 如果标题是中文，所有子任务标题必须用中文
   - 如果标题是英文，所有子任务标题必须用English
   - 绝对不要混用语言

2. 时间分配规则（绝对严格，0容差）:
   - ⚠️ 所有子任务的 duration_minutes 之和【必须精确等于】$minutes 分钟
   - ⚠️ 不能多一分钟，也不能少一分钟，必须刚好 $minutes 分钟
   - 每个子任务最少 1 分钟
   - 单个子任务最多 ${(minutes * 0.4).round()} 分钟（不超过总时长的40%）
   - 根据任务复杂度，拆分为 $minSteps-$maxSteps 个步骤
   - 【重要】在生成JSON前，请先计算所有 duration_minutes 的总和，确认等于 $minutes

3. 输出格式:
   - 只输出 JSON 数组，不要有任何其他文字
   - JSON 格式: [{"title": "步骤名称", "duration_minutes": 数字}, ...]
   - title 必须简洁、具体、以动词开头

【中文任务示例】(总时长60分钟，8+12+25+10+5=60✓):
[
  {"title": "准备工作材料", "duration_minutes": 8},
  {"title": "梳理核心要点", "duration_minutes": 12},
  {"title": "执行主要任务", "duration_minutes": 25},
  {"title": "检查和优化", "duration_minutes": 10},
  {"title": "总结归档", "duration_minutes": 5}
]

【English Task Example】(Total 30 minutes, 5+5+15+5=30✓):
[
  {"title": "Gather resources", "duration_minutes": 5},
  {"title": "Plan approach", "duration_minutes": 5},
  {"title": "Execute main work", "duration_minutes": 15},
  {"title": "Review and finalize", "duration_minutes": 5}
]

现在请为任务 "$title" 生成子任务计划，总时长必须精确等于 $minutes 分钟。只输出JSON数组:
''';
  }

  /// Parse and validate AI response
  /// Returns null if format is invalid (triggers retry)
  List<SubTask>? _parseAndValidate(String content, int expectedMinutes) {
    try {
      String jsonStr = content.trim();
      
      // Remove markdown code blocks if present
      if (jsonStr.startsWith('```json')) {
        jsonStr = jsonStr.replaceAll('```json', '').replaceAll('```', '');
      } else if (jsonStr.startsWith('```')) {
        jsonStr = jsonStr.replaceAll('```', '');
      }
      jsonStr = jsonStr.trim();
      
      // Must start with [ and end with ]
      if (!jsonStr.startsWith('[') || !jsonStr.endsWith(']')) {
        print('Validation failed: Not a JSON array');
        return null;
      }
      
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      
      // Must have at least 2 items
      if (jsonList.length < 2) {
        print('Validation failed: Less than 2 subtasks');
        return null;
      }
      
      // Validate each item has required fields
      int totalDuration = 0;
      List<SubTask> subtasks = [];
      
      for (var item in jsonList) {
        if (item is! Map) {
          print('Validation failed: Item is not a map');
          return null;
        }
        
        // Check required fields
        if (!item.containsKey('title') || !item.containsKey('duration_minutes')) {
          print('Validation failed: Missing required fields');
          return null;
        }
        
        final title = item['title'];
        final duration = item['duration_minutes'];
        
        // Validate types
        if (title is! String || title.isEmpty) {
          print('Validation failed: Invalid title');
          return null;
        }
        
        if (duration is! int || duration < 1) {
          // Try to parse as number
          final durationNum = duration is num ? duration.toInt() : null;
          if (durationNum == null || durationNum < 1) {
            print('Validation failed: Invalid duration');
            return null;
          }
          totalDuration += durationNum;
          subtasks.add(SubTask(
            id: _uuid.v4(),
            title: title,
            estimatedDuration: Duration(minutes: durationNum),
          ));
        } else {
          totalDuration += duration;
          subtasks.add(SubTask(
            id: _uuid.v4(),
            title: title,
            estimatedDuration: Duration(minutes: duration),
          ));
        }
      }
      
      // Validate total duration matches EXACTLY (0 tolerance)
      if (totalDuration != expectedMinutes) {
        print('Validation failed: Duration mismatch. Expected exactly $expectedMinutes, Got: $totalDuration');
        return null;
      }
      
      return subtasks;
      
    } catch (e) {
      print('Parse error: $e. Content was: $content');
      return null;
    }
  }
  
  @override
  Future<AIEstimateResult> estimateAndDecompose(String taskTitle) async {
    if (settings.apiKey == 'YOUR_API_KEY_HERE') {
      throw Exception('Please set your API Key in Settings');
    }

    const maxAttempts = 3;
    int attempts = 0;
    
    while (attempts < maxAttempts) {
      try {
        attempts++;
        final prompt = _buildEstimatePrompt(taskTitle);

        final response = await http.post(
          Uri.parse(settings.baseUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${settings.apiKey}',
          },
          body: jsonEncode({
            "model": settings.model,
            "messages": [
              {"role": "user", "content": prompt}
            ]
          }),
        ).timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          
          if (data['error'] != null) {
              final error = data['error'];
              if (error['code'] == 'security_audit_fail') {
                  throw Exception('security_audit_fail'); 
              }
              throw Exception("AI Error: ${error['message']}");
          }
          
          final content = data['choices'][0]['message']['content'];
          
          final result = _parseEstimateResult(content);
          
          if (result != null) {
            return result;
          }
          
          print('Attempt $attempts: Invalid format, retrying...');
          continue;
        } else {
          if (attempts == maxAttempts) throw Exception("AI Error: ${response.statusCode}");
        }
      } on TimeoutException {
        if (attempts == maxAttempts) throw Exception("timeout"); 
      } catch (e) {
        if (attempts == maxAttempts) rethrow;
      }
    }
    
    // Fallback: return default 60 min estimate
    return AIEstimateResult(
      estimatedDuration: const Duration(minutes: 60),
      subTasks: [],
    );
  }
  
  String _buildEstimatePrompt(String title) {
    return '''
你是一个专业的任务规划助手。

【任务】
用户想要完成: "$title"

【你的任务】
1. 根据任务标题，估算完成这个任务合理需要多少分钟（必须是5的倍数，最少15分钟，最多180分钟）
2. 将任务拆分为2-8个具体的子步骤，每个步骤分配合理的时间
3. 所有子步骤时间之和必须等于你估算的总时长

【语言规则】
- 如果任务标题是中文，输出中文
- 如果任务标题是英文，输出English

【输出格式 - 严格遵守】
只输出一个 JSON 对象，格式如下:
{
  "total_minutes": 数字,
  "steps": [
    {"title": "步骤名称", "duration_minutes": 数字},
    ...
  ]
}

【示例】
任务: "写一篇博客文章"
{
  "total_minutes": 60,
  "steps": [
    {"title": "确定主题和大纲", "duration_minutes": 10},
    {"title": "收集素材和资料", "duration_minutes": 15},
    {"title": "撰写正文内容", "duration_minutes": 25},
    {"title": "校对和排版", "duration_minutes": 10}
  ]
}

现在为任务 "$title" 生成估时和步骤。只输出JSON:
''';
  }
  
  AIEstimateResult? _parseEstimateResult(String content) {
    try {
      String jsonStr = content.trim();
      
      // Remove markdown code blocks if present
      if (jsonStr.startsWith('```json')) {
        jsonStr = jsonStr.replaceAll('```json', '').replaceAll('```', '');
      } else if (jsonStr.startsWith('```')) {
        jsonStr = jsonStr.replaceAll('```', '');
      }
      jsonStr = jsonStr.trim();
      
      // Must be a JSON object
      if (!jsonStr.startsWith('{') || !jsonStr.endsWith('}')) {
        print('Estimate parse failed: Not a JSON object');
        return null;
      }
      
      final Map<String, dynamic> jsonData = jsonDecode(jsonStr);
      
      // Extract total_minutes
      final totalMinutes = jsonData['total_minutes'];
      if (totalMinutes == null || totalMinutes is! num || totalMinutes < 15) {
        print('Estimate parse failed: Invalid total_minutes');
        return null;
      }
      
      // Extract steps
      final stepsData = jsonData['steps'];
      if (stepsData == null || stepsData is! List || stepsData.isEmpty) {
        print('Estimate parse failed: Invalid steps');
        return null;
      }
      
      int calculatedTotal = 0;
      List<SubTask> subtasks = [];
      
      for (var item in stepsData) {
        if (item is! Map) continue;
        
        final stepTitle = item['title'] as String?;
        final stepDuration = item['duration_minutes'];
        
        if (stepTitle == null || stepTitle.isEmpty) continue;
        
        int durationInt = 0;
        if (stepDuration is int) {
          durationInt = stepDuration;
        } else if (stepDuration is num) {
          durationInt = stepDuration.toInt();
        } else {
          continue;
        }
        
        if (durationInt < 1) continue;
        
        calculatedTotal += durationInt;
        subtasks.add(SubTask(
          id: _uuid.v4(),
          title: stepTitle,
          estimatedDuration: Duration(minutes: durationInt),
        ));
      }
      
      // Validate sum matches
      if (calculatedTotal != totalMinutes.toInt()) {
        print('Estimate parse failed: Sum mismatch. Expected $totalMinutes, got $calculatedTotal');
        return null;
      }
      
      if (subtasks.length < 2) {
        print('Estimate parse failed: Less than 2 valid steps');
        return null;
      }
      
      return AIEstimateResult(
        estimatedDuration: Duration(minutes: totalMinutes.toInt()),
        subTasks: subtasks,
      );
      
    } catch (e) {
      print('Estimate parse error: $e. Content was: $content');
      return null;
    }
  }
}

