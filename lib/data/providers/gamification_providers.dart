import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/gamification_service.dart';
import '../models/gamification_state.dart';
import 'base_providers.dart';

// Gamification Service Provider
final gamificationServiceProvider = StateNotifierProvider<GamificationService, GamificationState>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return GamificationService(storage, ref);
});
