import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage_service.dart';

// Storage Service Provider - Singleton
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});
