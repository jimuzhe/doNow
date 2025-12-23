import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/gamification_service.dart';
import '../models/gamification_state.dart';
import 'base_providers.dart';

import '../services/auth_service.dart';

// Gamification Service Provider
final gamificationServiceProvider = StateNotifierProvider<GamificationService, GamificationState>((ref) {
  // Watch auth state changes to reload gamification data when user switches
  ref.watch(authStateProvider);
  
  final storage = ref.watch(storageServiceProvider);
  return GamificationService(storage, ref);
});
