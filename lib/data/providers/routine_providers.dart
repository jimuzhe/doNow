import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/routine.dart';
import 'base_providers.dart';

// Routine List Provider
final routineListProvider = StateNotifierProvider<RoutineListNotifier, List<Routine>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return RoutineListNotifier(storage);
});

class RoutineListNotifier extends StateNotifier<List<Routine>> {
  final _storage;

  RoutineListNotifier(this._storage) : super([]) {
    _loadFromStorage();
  }

  void _loadFromStorage() {
    try {
      state = _storage.loadRoutines();
    } catch (_) { }
  }

  void addRoutine(Routine routine) {
    state = [...state, routine];
    _storage.saveRoutines(state);
  }

  void updateRoutine(Routine routine) {
    state = state.map((r) => r.id == routine.id ? routine : r).toList();
    _storage.saveRoutines(state);
  }

  void deleteRoutine(String id) {
    state = state.where((r) => r.id != id).toList();
    _storage.saveRoutines(state);
  }
}
