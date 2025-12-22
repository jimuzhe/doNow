import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../data/models/task.dart';
import '../video_player_dialog.dart';

class TimelineItemWithLine extends StatelessWidget {
  final Task task;
  final bool isDark;
  final bool isLast;
  final VoidCallback? onLongPress;
  final VoidCallback onTap;

  const TimelineItemWithLine({
    super.key,
    required this.task,
    required this.isDark,
    required this.isLast,
    required this.onLongPress,
    required this.onTap,
  });

  void _showMediaViewer(BuildContext context, Task task) {
    if (task.journalVideoPath != null) {
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
      showDialog(
        context: context,
        barrierColor: Colors.black87,
        builder: (context) => GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Transform.flip(
                flipX: task.journalMediaMirrored,
                child: kIsWeb
                    ? Image.network(task.journalImagePath!, fit: BoxFit.contain)
                    : Image.file(File(task.journalImagePath!), fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = task.completedAt != null
        ? DateFormat('HH:mm').format(task.completedAt!)
        : DateFormat('HH:mm').format(task.scheduledStart);
    
    final statusColor = task.isCompleted ? Colors.green : Colors.red;
    
    String? timeDiffStr;
    Color? timeDiffColor;
    if (task.isCompleted && task.actualDuration != null && !task.isDecision) {
      final diff = task.actualDuration!.inMinutes - task.totalDuration.inMinutes;
      if (diff > 0) {
        timeDiffStr = '+${diff}m';
        timeDiffColor = Colors.orange;
      } else if (diff < 0) {
        timeDiffStr = '-${diff.abs()}m';
        timeDiffColor = Colors.green;
      }
    }

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              child: Column(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: task.isDecision 
                          ? Colors.purpleAccent 
                          : (task.isQuickFocus ? Colors.orangeAccent : statusColor),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? (Colors.grey[800] ?? Colors.black) : Colors.white,
                        width: 2,
                      ),
                    ),
                    child: task.isDecision 
                        ? const Center(child: Icon(Icons.star, size: 8, color: Colors.white))
                        : (task.isQuickFocus ? const Center(child: Icon(Icons.bolt, size: 8, color: Colors.white)) : null),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: isDark ? Colors.grey[700] : Colors.grey[300],
                      ),
                    ),
                ],
              ),
            ),
            
            const SizedBox(width: 12),
            
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!task.isDecision && !task.isQuickFocus)
                            Row(
                              children: [
                                Text(
                                  timeStr,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.white70 : Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${task.totalDuration.inMinutes}m',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.white54 : Colors.grey[500],
                                  ),
                                ),
                                if (task.actualDuration != null) ...[
                                  Text(
                                    '→${task.actualDuration!.inMinutes}m',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? Colors.white54 : Colors.grey[500],
                                    ),
                                  ),
                                ],
                                if (timeDiffStr != null) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: timeDiffColor!.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      timeDiffStr,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: timeDiffColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            )
                          else if (task.isQuickFocus)
                             Row(
                               children: [
                                 Text(
                                   timeStr,
                                   style: TextStyle(
                                     fontSize: 12,
                                     fontWeight: FontWeight.w500,
                                     color: isDark ? Colors.white70 : Colors.grey[700],
                                   ),
                                 ),
                                 const SizedBox(width: 8),
                                 Container(
                                   padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                   decoration: BoxDecoration(
                                     color: Colors.orange.withOpacity(0.1),
                                     borderRadius: BorderRadius.circular(4),
                                     border: Border.all(color: Colors.orange.withOpacity(0.3)),
                                   ),
                                   child: Row(
                                     mainAxisSize: MainAxisSize.min,
                                     children: [
                                       Icon(Icons.bolt, size: 10, color: Colors.orange[700]),
                                       const SizedBox(width: 2),
                                       Text(
                                         task.actualDuration != null ? '${task.actualDuration!.inMinutes}m' : 'Focus',
                                         style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange[700]),
                                       ),
                                     ],
                                   ),
                                 )
                               ],
                             )
                          else
                            Row(
                              children: [
                                Text(
                                  timeStr,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.white70 : Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.purple.withOpacity(0.3)),
                                  ),
                                  child: Text(
                                    "Decision", 
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purple[300]),
                                  ),
                                )
                              ],
                            ),

                          const SizedBox(height: 4),
                          Text(
                            task.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              decoration: task.isAbandoned ? TextDecoration.lineThrough : null,
                              color: task.isAbandoned
                                  ? Colors.grey
                                  : (isDark ? Colors.white : Colors.black),
                            ),
                          ),
                          if (task.journalLocation != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.location_on, size: 12, color: Colors.grey[500]),
                                const SizedBox(width: 2),
                                Flexible(
                                  child: Text(
                                    task.journalLocation!,
                                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (task.journalNote != null && task.journalNote!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: task.isDecision 
                                    ? (isDark ? Colors.purple.withOpacity(0.1) : Colors.purple.withOpacity(0.05))
                                    : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100]),
                                borderRadius: BorderRadius.circular(8),
                                border: task.isDecision ? Border.all(color: Colors.purple.withOpacity(0.2), width: 1) : null,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    task.isDecision ? Icons.psychology : Icons.format_quote, 
                                    size: 14, 
                                    color: task.isDecision ? Colors.purple[300] : Colors.grey[500]
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      task.journalNote!,
                                      style: TextStyle(
                                        color: isDark ? Colors.white70 : Colors.grey[700],
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                        fontWeight: task.isDecision ? FontWeight.w500 : FontWeight.normal,
                                      ),
                                      maxLines: 10, 
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (task.journalImagePath != null || task.journalVideoPath != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: GestureDetector(
                          onTap: () => _showMediaViewer(context, task),
                          child: Transform.flip(
                            flipX: task.journalMediaMirrored,
                            child: Container(
                              height: 50,
                              width: 50,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDark ? Colors.white12 : Colors.black12,
                                ),
                                color: task.journalImagePath == null && task.journalVideoPath != null
                                    ? (isDark ? Colors.grey[800] : Colors.grey[600])
                                    : Colors.black12,
                                image: task.journalImagePath != null
                                    ? DecorationImage(
                                        image: kIsWeb
                                            ? NetworkImage(task.journalImagePath!)
                                            : FileImage(File(task.journalImagePath!)) as ImageProvider,
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: task.journalVideoPath != null
                                  ? Center(
                                      child: Icon(
                                        Icons.play_circle_fill, 
                                        color: Colors.white.withOpacity(0.9), 
                                        size: 24,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
