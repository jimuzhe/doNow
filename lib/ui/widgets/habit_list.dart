
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/habit.dart';
import '../../data/providers.dart';
import '../../utils/haptic_helper.dart';
import 'create_habit_sheet.dart';
import 'glass_container.dart';
import '../theme/app_theme.dart';

class HabitListWidget extends ConsumerWidget {
  const HabitListWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Use a fixed height container for the horizontal list
    return SizedBox(
      height: 110, 
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: habits.length + 1, // +1 for Add button
        separatorBuilder: (context, index) => const SizedBox(width: 20),
        itemBuilder: (context, index) {
          if (index == habits.length) {
            return _buildAddButton(context, isDark, ref);
          }
          return _HabitItem(habit: habits[index]);
        },
      ),
    );
  }

  Widget _buildAddButton(BuildContext context, bool isDark, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        HapticHelper(ref).selectionClick();
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
              color: isDark ? Colors.grey[800] : Colors.grey[100],
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                width: 1,
              ),
            ),
            child: Icon(
              Icons.add, 
              color: isDark ? Colors.white38 : Colors.black26,
              size: 24,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "NEW",
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: isDark ? Colors.white24 : Colors.black26,
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
         HapticHelper(ref).heavyImpact();
         _showDeleteConfirm(context, ref);
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.elasticOut,
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isCompleted 
                ? LinearGradient(
                    colors: [color, color.withOpacity(0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
              color: isCompleted ? null : Colors.transparent,
              border: Border.all(
                color: isCompleted ? color.withOpacity(0.3) : (isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                width: 2,
              ),
              boxShadow: isCompleted ? [
                BoxShadow(color: color.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 6))
              ] : [],
            ),
            child: Icon(
              IconData(habit.iconCode, fontFamily: 'MaterialIcons'),
              color: isCompleted ? Colors.white : (isDark ? Colors.white24 : Colors.black26),
              size: 26,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (habit.currentStreak > 0) ...[
                Icon(Icons.local_fire_department, size: 12, color: isCompleted ? Colors.orange : Colors.grey),
                const SizedBox(width: 4),
                Text(
                  "${habit.currentStreak}",
                  style: GoogleFonts.outfit(
                    fontSize: 11, 
                    fontWeight: FontWeight.w800, 
                    color: isCompleted ? Colors.orange : Colors.grey
                  ),
                )
              ] else 
                Text(
                  habit.title.toUpperCase(),
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: isDark ? Colors.white38 : Colors.black38,
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
