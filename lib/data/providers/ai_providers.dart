import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/api_settings.dart';
import '../models/ai_persona.dart';
import '../services/ai_service.dart';
import '../services/zhipu_ai_service.dart';
import '../api_config.dart';
import 'base_providers.dart';

// API Settings Provider - Now with persistence
final apiSettingsProvider = StateNotifierProvider<ApiSettingsNotifier, ApiSettings>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return ApiSettingsNotifier(storage);
});

class ApiSettingsNotifier extends StateNotifier<ApiSettings> {
  final _storage;

  ApiSettingsNotifier(this._storage) : super(const ApiSettings(
    apiKey: ApiConfig.apiKey,
    baseUrl: ApiConfig.baseUrl,
    model: ApiConfig.model,
  )) {
    _loadFromStorage();
  }

  void _loadFromStorage() {
    try {
      state = _storage.loadApiSettings();
    } catch (_) {
      // Storage not initialized yet, use defaults
    }
  }

  void update(ApiSettings settings) {
    state = settings;
    _storage.saveApiSettings(settings);
  }
}

// AI Persona Provider - Now with persistence
final aiPersonaProvider = StateNotifierProvider<AIPersonaNotifier, AIPersona>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return AIPersonaNotifier(storage);
});

class AIPersonaNotifier extends StateNotifier<AIPersona> {
  final _storage;

  AIPersonaNotifier(this._storage) : super(AIPersona.balanced) {
    _loadFromStorage();
  }

  void _loadFromStorage() {
    try {
      final personaName = _storage.loadAIPersona();
      state = AIPersonaExtension.fromStorageString(personaName);
    } catch (_) {
      // Storage not initialized yet, use defaults
    }
  }

  void setPersona(AIPersona persona) {
    state = persona;
    _storage.saveAIPersona(persona.toStorageString());
  }
}

// Service Provider - Refreshes when settings or persona change
final aiServiceProvider = Provider<AIService>((ref) {
  final settings = ref.watch(apiSettingsProvider);
  final persona = ref.watch(aiPersonaProvider);
  return ZhipuAIService(settings, persona: persona);
});
