
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/habit.dart';
import '../../data/providers.dart';
import '../../utils/haptic_helper.dart';

class CreateHabitSheet extends ConsumerStatefulWidget {
  const CreateHabitSheet({super.key});

  @override
  ConsumerState<CreateHabitSheet> createState() => _CreateHabitSheetState();
}

class _CreateHabitSheetState extends ConsumerState<CreateHabitSheet> {
  final TextEditingController _titleController = TextEditingController();
  
  // Pre-defined icons
  final List<IconData> _icons = [
    Icons.fitness_center,
    Icons.book,
    Icons.water_drop,
    Icons.bed,
    Icons.code,
    Icons.music_note,
    Icons.edit,
    Icons.directions_run,
    Icons.self_improvement,
    Icons.language,
    Icons.pets,
    Icons.cleaning_services,
  ];

  // Pre-defined colors
  final List<Color> _colors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
  ];

  late IconData _selectedIcon;
  late Color _selectedColor;

  @override
  void initState() {
    super.initState();
    _selectedIcon = _icons[0];
    _selectedColor = _colors[0];
  }

  void _save() {
    if (_titleController.text.trim().isEmpty) return;

    final newHabit = Habit(
      id: const Uuid().v4(),
      title: _titleController.text.trim(),
      iconCode: _selectedIcon.codePoint,
      colorValue: _selectedColor.value,
      completedDates: [],
    );

    ref.read(habitListProvider.notifier).addHabit(newHabit);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24,
        left: 24,
        right: 24,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "New Habit",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 24),
          
          // Name Input
          TextField(
            controller: _titleController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: "What do you want to persist?",
              filled: true,
              fillColor: isDark ? Colors.grey[900] : Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Icon Picker
          Text("Icon", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 12),
          SizedBox(
            height: 50,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _icons.length,
              separatorBuilder: (c, i) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final icon = _icons[index];
                final isSelected = icon == _selectedIcon;
                return GestureDetector(
                  onTap: () {
                    HapticHelper(ref).selectionClick();
                    setState(() => _selectedIcon = icon);
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: isSelected ? (isDark ? Colors.white : Colors.black) : (isDark ? Colors.grey[800] : Colors.grey[200]),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: isSelected ? (isDark ? Colors.black : Colors.white) : (isDark ? Colors.grey[400] : Colors.grey[600]),
                      size: 24,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // Color Picker
          Text("Color", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _colors.length,
              separatorBuilder: (c, i) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final color = _colors[index];
                final isSelected = color == _selectedColor;
                return GestureDetector(
                  onTap: () {
                    HapticHelper(ref).selectionClick();
                    setState(() => _selectedColor = color);
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected ? Border.all(color: isDark ? Colors.white : Colors.black, width: 3) : null,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 32),

          // Save Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.white : Colors.black,
                foregroundColor: isDark ? Colors.black : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text("Create Habit", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
