/// AI Persona types that affect task estimation and decomposition
enum AIPersona {
  /// Rushed - shorter time estimates, faster task completion
  /// 匆忙型 - 估时更短，更快完成任务
  rushed,
  
  /// Balanced - standard time estimates (default)
  /// 平衡型 - 标准估时（默认）
  balanced,
  
  /// Relaxed - longer time estimates, more buffer time
  /// 从容型 - 估时更长，更多缓冲时间
  relaxed,
}

/// Extension methods for AIPersona
extension AIPersonaExtension on AIPersona {
  /// Get the time multiplier for this persona
  /// - Rushed: 0.7 (30% faster)
  /// - Balanced: 1.0 (standard)
  /// - Relaxed: 1.3 (30% more time)
  double get timeMultiplier {
    switch (this) {
      case AIPersona.rushed:
        return 0.7;
      case AIPersona.balanced:
        return 1.0;
      case AIPersona.relaxed:
        return 1.3;
    }
  }
  
  /// Get min/max step count adjustment
  /// Rushed: fewer steps, Relaxed: more detailed steps
  (int minAdjust, int maxAdjust) get stepCountAdjustment {
    switch (this) {
      case AIPersona.rushed:
        return (-1, -1); // Fewer steps
      case AIPersona.balanced:
        return (0, 0); // Standard
      case AIPersona.relaxed:
        return (1, 2); // More detailed steps
    }
  }
  
  /// Get the persona description for AI prompt
  String get aiPromptDescription {
    switch (this) {
      case AIPersona.rushed:
        return '''
【时间风格偏好】
- 用户是效率导向型，希望快速完成任务
- 估时应该偏紧凑，避免过多缓冲时间
- 步骤要精简高效，直击要点
- 每个步骤应该紧凑，减少准备和过渡时间''';
      case AIPersona.balanced:
        return '''
【时间风格偏好】
- 用户希望平衡效率与质量
- 估时应该合理，有适当的缓冲时间
- 步骤划分应该清晰，便于执行''';
      case AIPersona.relaxed:
        return '''
【时间风格偏好】
- 用户注重质量，不急于完成
- 估时应该充裕，包含足够的缓冲时间
- 步骤可以更详细，包含思考和复盘环节
- 可以加入休息和调整的时间''';
    }
  }
  
  /// Get the icon for this persona
  String get iconName {
    switch (this) {
      case AIPersona.rushed:
        return 'speed';
      case AIPersona.balanced:
        return 'balance';
      case AIPersona.relaxed:
        return 'self_improvement';
    }
  }
  
  /// Convert to string for storage
  String toStorageString() => name;
  
  /// Parse from storage string
  static AIPersona fromStorageString(String? value) {
    if (value == null) return AIPersona.balanced;
    return AIPersona.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AIPersona.balanced,
    );
  }
}
