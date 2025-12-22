import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/habit.dart';
import 'base_providers.dart';

// Habit List Provider
final habitListProvider = StateNotifierProvider<HabitListNotifier, List<Habit>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return HabitListNotifier(storage);
});

class HabitListNotifier extends StateNotifier<List<Habit>> {
  final _storage;

  HabitListNotifier(this._storage) : super([]) {
    _loadFromStorage();
  }

  void _loadFromStorage() {
    try {
      state = _storage.loadHabits();
    } catch (_) { }
  }

  void addHabit(Habit habit) {
    state = [...state, habit];
    _storage.saveHabits(state);
  }

  void updateHabit(Habit habit) {
    state = state.map((h) => h.id == habit.id ? habit : h).toList();
    _storage.saveHabits(state);
  }

  void deleteHabit(String id) {
    state = state.where((h) => h.id != id).toList();
    _storage.saveHabits(state);
  }

  void toggleToday(String id) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    state = state.map((h) {
      if (h.id != id) return h;
      
      final isCompleted = h.isCompletedToday();
      List<DateTime> newDates;
      
      if (isCompleted) {
        newDates = h.completedDates.where((d) => 
          !(d.year == today.year && d.month == today.month && d.day == today.day)
        ).toList();
      } else {
        newDates = [...h.completedDates, today];
      }
      
      return h.copyWith(completedDates: newDates);
    }).toList();
    
    _storage.saveHabits(state);
  }
}
