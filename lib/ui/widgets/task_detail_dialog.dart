
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/task.dart';
import '../../data/localization.dart';
import 'video_player_dialog.dart';

class TaskDetailDialog extends StatelessWidget {
  final Task task;
  final bool isDark;
  final String locale;

  const TaskDetailDialog({
    super.key,
    required this.task,
    required this.isDark,
    required this.locale,
  });

  String t(String key) => AppStrings.get(key, locale);

  @override
  Widget build(BuildContext context) {
    // Colors
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.white54 : Colors.black54;
    
    // Status color
    Color statusColor;
    String statusText;
    if (task.isCompleted) {
      statusColor = Colors.green;
      statusText = t('completed');
    } else if (task.isAbandoned) {
      statusColor = Colors.red;
      statusText = t('abandoned');
    } else {
      statusColor = Colors.blue;
      statusText = t('pending_tasks');
    }

    final dateStr = DateFormat('MMM d, yyyy').format(task.scheduledStart);
    final isMultimedia = task.journalImagePath != null || task.journalVideoPath != null;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
             BoxShadow(
               color: Colors.black.withOpacity(0.2),
               blurRadius: 20,
               offset: const Offset(0, 10),
             )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header with Close Button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 20, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: statusColor.withOpacity(0.3)),
                          ),
                          child: Text(
                            statusText.toUpperCase(),
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          task.title,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateStr,
                          style: TextStyle(fontSize: 13, color: subTextColor),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: subTextColor),
                    style: IconButton.styleFrom(
                      backgroundColor: isDark ? Colors.white10 : Colors.grey[100],
                      padding: const EdgeInsets.all(8),
                      minimumSize: Size.zero, 
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  )
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 2. Stats Grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black26 : Colors.grey[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                     color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(isDark, Icons.schedule, t('planned_time'), '${task.totalDuration.inMinutes}m'),
                    Container(height: 30, width: 1, color: isDark ? Colors.white12 : Colors.grey[300]),
                    _buildStatItem(
                      isDark, 
                      Icons.timer, 
                      t('actual_time'), 
                      task.actualDuration != null ? '${task.actualDuration!.inMinutes}m' : '--'
                    ),
                  ],
                ),
              ),
            ),
            
            // 3. Journal Content (Location, Note, Media)
            if (task.journalLocation != null || (task.journalNote?.isNotEmpty ?? false) || isMultimedia) ...[
              const SizedBox(height: 20),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Location
                      if (task.journalLocation != null) ...[
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 14, color: Colors.blueAccent),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                task.journalLocation!,
                                style: TextStyle(color: subTextColor, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      
                      // Note
                      if (task.journalNote?.isNotEmpty ?? false) ...[
                         Container(
                           width: double.infinity,
                           padding: const EdgeInsets.all(12),
                           decoration: BoxDecoration(
                             color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                             borderRadius: BorderRadius.circular(12),
                             border: Border.all(color: isDark ? Colors.white10 : Colors.transparent),
                           ),
                           child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               Icon(Icons.format_quote, size: 16, color: subTextColor),
                               const SizedBox(height: 4),
                               Text(
                                 task.journalNote!,
                                 style: TextStyle(
                                   color: textColor, 
                                   fontSize: 14, 
                                   height: 1.5,
                                   fontStyle: FontStyle.italic,
                                 ),
                               ),
                             ],
                           ),
                         ),
                         const SizedBox(height: 16),
                      ],
                      
                      // Media
                      if (isMultimedia) ...[
                        GestureDetector(
                           onTap: () {
                             if (task.journalVideoPath != null) {
                               // Video still needs mirroring (file not processed)
                               Navigator.of(context).push(
                                 MaterialPageRoute(
                                   fullscreenDialog: true,
                                   builder: (_) => VideoPlayerDialog(
                                     videoPath: task.journalVideoPath!,
                                     isMirrored: task.journalMediaMirrored,
                                   ),
                                 ),
                               );
                             } else if (task.journalImagePath != null) {
                               // Image view with mirror support
                               showDialog(
                                 context: context,
                                 builder: (_) => Dialog(
                                   backgroundColor: Colors.transparent,
                                   child: ClipRRect(
                                     borderRadius: BorderRadius.circular(16),
                                     child: Transform.flip(
                                       flipX: task.journalMediaMirrored,
                                       child: kIsWeb
                                         ? Image.network(task.journalImagePath!)
                                         : Image.file(File(task.journalImagePath!)),
                                     ),
                                   ),
                                 ),
                               );
                             }
                           },
                           // Mirror front camera content
                           child: Transform.flip(
                             flipX: task.journalMediaMirrored,
                             child: Container(
                               height: 180,
                               width: double.infinity,
                               decoration: BoxDecoration(
                                 borderRadius: BorderRadius.circular(16),
                                 color: Colors.black,
                                 boxShadow: [
                                   BoxShadow(
                                     color: Colors.black.withOpacity(0.1),
                                     blurRadius: 10,
                                     offset: const Offset(0, 4),
                                   ),
                                 ],
                                 image: task.journalImagePath != null 
                                   ? DecorationImage(
                                       image: kIsWeb 
                                         ? NetworkImage(task.journalImagePath!) 
                                         : FileImage(File(task.journalImagePath!)) as ImageProvider,
                                       fit: BoxFit.cover,
                                     )
                                   : null,
                               ),
                               child: Stack(
                                 alignment: Alignment.center,
                                 children: [
                                   if (task.journalVideoPath != null)
                                     Container(
                                       padding: const EdgeInsets.all(12),
                                       decoration: const BoxDecoration(
                                         color: Colors.black45, 
                                         shape: BoxShape.circle,
                                       ),
                                       child: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
                                     ),
                                     
                                   // Type Badge
                                   Positioned(
                                     bottom: 12,
                                     right: 12,
                                     child: Container(
                                       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                       decoration: BoxDecoration(
                                         color: Colors.black54,
                                         borderRadius: BorderRadius.circular(6),
                                       ),
                                       child: Row(
                                         mainAxisSize: MainAxisSize.min,
                                         children: [
                                           Icon(
                                             task.journalVideoPath != null ? Icons.videocam : Icons.photo,
                                             color: Colors.white,
                                             size: 12,
                                           ),
                                           const SizedBox(width: 4),
                                           Text(
                                              task.journalVideoPath != null ? t('journal_video') : t('journal_photo'),
                                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                           ),
                                         ],
                                       ),
                                     ),
                                   ),
                                 ],
                               ),
                             ),
                           ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ] else 
              const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(bool isDark, IconData icon, String label, String value) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isDark ? Colors.white54 : Colors.black54),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
            fontFamily: 'RobotoMono', // Monospace if available for numbers
          ),
        ),
      ],
    );
  }
}
