import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/routine.dart';
import '../../data/providers.dart';
import '../../data/localization.dart';
import '../../utils/haptic_helper.dart';

class RoutineSelectorSheet extends ConsumerWidget {
  final Function(Routine) onSelect;

  const RoutineSelectorSheet({super.key, required this.onSelect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routines = ref.watch(routineListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = ref.watch(localeProvider);
    String t(String key) => AppStrings.get(key, locale);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.inventory_2_outlined, color: isDark ? Colors.white : Colors.black),
                const SizedBox(width: 8),
                Text(
                  t('routines'), 
                  style: TextStyle(
                    fontSize: 20, 
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black
                  )
                ),
              ],
            ),
          ),
          
          const Divider(),
          
          if (routines.isEmpty)
            Padding(
              padding: const EdgeInsets.all(48.0),
              child: Column(
                children: [
                   Icon(Icons.bookmark_border, size: 48, color: Colors.grey[300]),
                   const SizedBox(height: 16),
                   Text(
                     t('no_activity'), // Reusing "No activity yet" or similar, maybe add 'no_routines' later
                     style: TextStyle(color: Colors.grey[400]),
                   ),
                ],
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shrinkWrap: true,
                itemCount: routines.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final routine = routines[index];
                  return Dismissible(
                    key: Key(routine.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      color: Colors.red,
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (_) async {
                      return await showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(t('delete_routine_confirm')),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(t('cancel')),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text(t('slide_drop'), style: const TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                    },
                    onDismissed: (_) {
                      ref.read(routineListProvider.notifier).deleteRoutine(routine.id);
                    },
                    child: InkWell(
                      onTap: () {
                         HapticHelper(ref).mediumImpact();
                         onSelect(routine);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[900] : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.transparent),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.grey[800] : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.flash_on_rounded, size: 20, color: Colors.orange),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    routine.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: isDark ? Colors.white : Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "${routine.totalDuration.inMinutes} ${t('minutes')} • ${routine.subTasks.length} ${t('steps')}",
                                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
