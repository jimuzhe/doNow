import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart'; // Add audio player support
import '../../../data/models/task.dart';
import 'time_info_chip.dart';

class TaskTimelineItem extends StatefulWidget {
  final Task task;
  final bool isDark;
  final VoidCallback onLongPress;
  final VoidCallback onSwipeLeft;

  const TaskTimelineItem({
    super.key,
    required this.task,
    required this.isDark,
    required this.onLongPress,
    required this.onSwipeLeft,
  });

  @override
  State<TaskTimelineItem> createState() => _TaskTimelineItemState();
}

class _TaskTimelineItemState extends State<TaskTimelineItem> {
  AudioPlayer? _player;
  bool _isPlaying = false;
  bool _isInit = false;

  @override
  void initState() {
    super.initState();
    if (widget.task.journalAudioPath != null) {
      _initAudio();
    }
  }

  Future<void> _initAudio() async {
    try {
      if (widget.task.journalAudioPath == null) return;
      
      final file = File(widget.task.journalAudioPath!);
      if (!await file.exists()) return;

      _player = AudioPlayer();
      await _player!.setFilePath(widget.task.journalAudioPath!);
      
      _player!.playerStateStream.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state.playing;
            if (state.processingState == ProcessingState.completed) {
              _isPlaying = false;
              _player!.seek(Duration.zero);
              _player!.pause();
            }
          });
        }
      });
      
      if (mounted) setState(() => _isInit = true);
    } catch (e) {
      debugPrint("Timeline audio init error: $e");
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final isDark = widget.isDark;
    
    final timeStr = task.completedAt != null 
        ? DateFormat('HH:mm').format(task.completedAt!)
        : DateFormat('HH:mm').format(task.scheduledStart);
        
    final statusColor = task.isCompleted ? Colors.green : Colors.red;
    
    // Calculate time difference (planned vs actual)
    String? timeDiffStr;
    Color? timeDiffColor;
    if (task.isCompleted && task.actualDuration != null) {
      final plannedMinutes = task.totalDuration.inMinutes;
      final actualMinutes = task.actualDuration!.inMinutes;
      final diff = actualMinutes - plannedMinutes;
      
      if (diff > 0) {
        timeDiffStr = '+${diff}m slower';
        timeDiffColor = Colors.orange;
      } else if (diff < 0) {
        timeDiffStr = '${diff.abs()}m faster';
        timeDiffColor = Colors.green;
      } else {
        timeDiffStr = 'On time';
        timeDiffColor = Colors.blue;
      }
    }
    
    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        widget.onSwipeLeft();
        return false; // Don't actually dismiss
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? Colors.purple.withOpacity(0.2) : Colors.purple.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, color: Colors.purple[300], size: 18),
            const SizedBox(width: 6),
            const Text(
              'Daily Summary',
              style: TextStyle(
                color: Color(0xFFBA68C8), // Colors.purple[300] roughly
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      child: GestureDetector(
        onLongPress: widget.onLongPress,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Time & Status Column
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(width: 16),
              
              // Content Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            task.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              decoration: task.isAbandoned ? TextDecoration.lineThrough : null,
                              color: task.isAbandoned 
                                  ? Colors.grey 
                                  : (isDark ? Colors.white : Colors.black),
                            ),
                          ),
                        ),
                        // Image thumbnail
                        if (task.journalImagePath != null)
                          Transform.flip(
                            flipX: task.journalMediaMirrored,
                            child: Container(
                              height: 48,
                              width: 48,
                              margin: const EdgeInsets.only(left: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDark ? Colors.white12 : Colors.black12,
                                ),
                                image: DecorationImage(
                                  image: kIsWeb 
                                      ? NetworkImage(task.journalImagePath!) 
                                      : FileImage(File(task.journalImagePath!)) as ImageProvider,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              child: task.journalVideoPath != null
                                  ? const Icon(Icons.play_circle_fill, color: Colors.white, size: 20)
                                  : null,
                            ),
                          ),
                      ],
                    ),
                    
                    // Audio Player Row (New)
                    if (task.journalAudioPath != null && _isInit)
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                if (_isPlaying) {
                                  _player?.pause();
                                } else {
                                  _player?.play();
                                }
                              },
                              child: Icon(
                                _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                                color: task.isVenting ? Colors.blueAccent : (isDark ? Colors.white70 : Colors.black54),
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Simple waveform visualization placeholder
                            Expanded(
                              child: SizedBox(
                                height: 24,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: List.generate(20, (index) {
                                    return Container(
                                      width: 3,
                                      height: 10 + (index % 5) * 3.0,
                                      decoration: BoxDecoration(
                                        color: _isPlaying 
                                           ? (index % 2 == 0 ? Colors.blueAccent : Colors.blueAccent.withOpacity(0.5))
                                           : (isDark ? Colors.white24 : Colors.black12),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Duration text (using actual duration or placeholder)
                            Text(
                              "语音",
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white54 : Colors.black54,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 8),
                    
                    // Time comparison row
                    Row(
                      children: [
                        TimeInfoChip(
                          label: 'Planned',
                          value: '${task.totalDuration.inMinutes}m',
                          isDark: isDark,
                        ),
                        const SizedBox(width: 8),
                        if (task.actualDuration != null)
                          TimeInfoChip(
                            label: 'Actual',
                            value: '${task.actualDuration!.inMinutes}m',
                            isDark: isDark,
                          ),
                        if (timeDiffStr != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: timeDiffColor!.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              timeDiffStr,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: timeDiffColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    
                    // Location if available
                    if (task.journalLocation != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              task.journalLocation!,
                              style: TextStyle(color: Colors.grey[500], fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
