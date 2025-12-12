
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/habit.dart';
import '../../data/providers.dart';
import '../../utils/haptic_helper.dart';
import 'create_habit_sheet.dart';

class HabitListWidget extends ConsumerWidget {
  const HabitListWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Use a fixed height container for the horizontal list
    return SizedBox(
      height: 100, 
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        scrollDirection: Axis.horizontal,
        itemCount: habits.length + 1, // +1 for Add button
        separatorBuilder: (context, index) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          if (index == habits.length) {
            return _buildAddButton(context, isDark);
          }
          return _HabitItem(habit: habits[index]);
        },
      ),
    );
  }

  Widget _buildAddButton(BuildContext context, bool isDark) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context, 
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const CreateHabitSheet()
        );
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? Colors.grey[800] : Colors.grey[200],
              border: Border.all(
                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                width: 1,
                style: BorderStyle.solid
              ) // Dashed border is hard in Flutter without package, solid is fine for MVP
            ),
            child: Icon(Icons.add, color: isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            "New",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          )
        ],
      ),
    );
  }
}

class _HabitItem extends ConsumerWidget {
  final Habit habit;

  const _HabitItem({required this.habit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCompleted = habit.isCompletedToday();
    final color = Color(habit.colorValue);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        HapticHelper(ref).mediumImpact();
        ref.read(habitListProvider.notifier).toggleToday(habit.id);
      },
      onLongPress: () {
         // Long press to delete
         HapticHelper(ref).heavyImpact();
         _showDeleteConfirm(context, ref);
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted ? color : Colors.transparent,
              border: Border.all(
                color: isCompleted ? color : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                width: 2,
              ),
              boxShadow: isCompleted ? [
                BoxShadow(color: color.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))
              ] : [],
            ),
            child: Icon(
              IconData(habit.iconCode, fontFamily: 'MaterialIcons'),
              color: isCompleted ? Colors.white : (isDark ? Colors.grey[500] : Colors.grey[400]),
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (habit.currentStreak > 0) ...[
                const Icon(Icons.local_fire_department, size: 12, color: Colors.orange),
                const SizedBox(width: 2),
                Text(
                  "${habit.currentStreak}",
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange),
                )
              ] else 
                Text(
                  habit.title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          )
        ],
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Delete Habit?"),
        content: Text("Delete '${habit.title}' and all its history?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel")),
          TextButton(
            onPressed: () {
              ref.read(habitListProvider.notifier).deleteHabit(habit.id);
              Navigator.pop(context);
            }, 
            child: Text("Delete", style: TextStyle(color: Colors.red))
          ),
        ],
      )
    );
  }
}
