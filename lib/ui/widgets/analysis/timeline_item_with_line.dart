import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart'; // Added just_audio
import '../../../data/models/task.dart';
import '../video_player_dialog.dart';

class TimelineItemWithLine extends StatefulWidget {
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

  @override
  State<TimelineItemWithLine> createState() => _TimelineItemWithLineState();
}

class _TimelineItemWithLineState extends State<TimelineItemWithLine> {
  bool _isExpanded = false;
  bool _isRecent = false;

  @override
  void initState() {
    super.initState();
    // Auto-expand if it's a very recent venting entry (e.g., within 15 seconds)
    // This provides immediate feedback after recording.
    final now = DateTime.now();
    _isRecent = widget.task.isVenting && 
                 widget.task.completedAt != null && 
                 now.difference(widget.task.completedAt!).inSeconds < 15;
    _isExpanded = _isRecent;
  }

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
    final task = widget.task;
    final isDark = widget.isDark;
    
    final localeStr = Localizations.maybeLocaleOf(context)?.toString() ?? 'en_US';
    final timeStr = task.completedAt != null
        ? DateFormat('HH:mm', localeStr).format(task.completedAt!)
        : DateFormat('HH:mm', localeStr).format(task.scheduledStart);
    
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

    // Determine interactions
    final effectiveOnTap = task.isVenting
        ? () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          }
        : widget.onTap;

    return GestureDetector(
      onTap: effectiveOnTap, 
      onLongPress: widget.onLongPress,
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
                          ? (isDark ? const Color(0xFF818CF8) : const Color(0xFF6366F1)) 
                          : (task.isVenting ? (isDark ? Colors.tealAccent[100] : Colors.teal) : (task.isQuickFocus ? (isDark ? Colors.orange[300] : Colors.orange) : statusColor)),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? (Colors.grey[800] ?? Colors.black) : Colors.white,
                        width: 2,
                      ),
                    ),
                    child: task.isDecision 
                        ? const Center(child: Icon(Icons.star, size: 8, color: Colors.white))
                        : (task.isVenting ? const Center(child: Icon(Icons.favorite, size: 6, color: Colors.white)) : (task.isQuickFocus ? const Center(child: Icon(Icons.bolt, size: 8, color: Colors.white)) : null)),
                  ),
                  if (!widget.isLast)
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
                padding: EdgeInsets.only(bottom: widget.isLast ? 0 : 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!task.isDecision && !task.isQuickFocus && !task.isVenting)
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
                                      Icon(Icons.bolt, size: 10, color: Colors.orange[400]),
                                      const SizedBox(width: 2),
                                      Text(
                                        "Focus",
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange[400]),
                                      ),
                                    ],
                                  ),
                                )
                              ],
                            )
                          else if (task.isVenting)
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
                                    color: Colors.teal.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.teal.withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.mic_none_rounded, size: 10, color: Colors.teal[400]),
                                      const SizedBox(width: 2),
                                      Text(
                                        "Venting",
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.teal[400]),
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
                                    color: isDark ? Colors.indigo.withOpacity(0.1) : Colors.indigo.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: isDark ? Colors.indigo.withOpacity(0.2) : Colors.indigo.withOpacity(0.1)),
                                  ),
                                  child: Text(
                                    "Decision", 
                                    style: TextStyle(
                                      fontSize: 10, 
                                      fontWeight: FontWeight.bold, 
                                      color: isDark ? Colors.indigo[200] : Colors.indigo[700]
                                    ),
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
                          
                          // Conditional Body:
                          // If venting: show note/audio ONLY if expanded
                          // Else: show note normally
                          if ((!task.isVenting || _isExpanded) && task.journalNote != null && task.journalNote!.isNotEmpty && task.journalNote != "语音倾诉") ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: task.isVenting
                                    ? (isDark ? Colors.teal.withOpacity(0.1) : Colors.teal.withOpacity(0.05))
                                    : (task.isDecision 
                                        ? (isDark ? Colors.indigo.withOpacity(0.1) : Colors.indigo.withOpacity(0.05))
                                        : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100])),
                                borderRadius: BorderRadius.circular(8),
                                border: (task.isDecision || task.isVenting) ? Border.all(
                                  color: task.isVenting 
                                      ? (isDark ? Colors.teal.withOpacity(0.2) : Colors.teal.withOpacity(0.1))
                                      : (isDark ? Colors.indigo.withOpacity(0.2) : Colors.indigo.withOpacity(0.1)), 
                                  width: 1) : null,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    task.isVenting ? Icons.bubble_chart : (task.isDecision ? Icons.psychology : Icons.format_quote), 
                                    size: 14, 
                                    color: task.isVenting 
                                        ? (isDark ? Colors.teal[200] : Colors.teal[400])
                                        : (task.isDecision ? (isDark ? Colors.indigo[200] : Colors.indigo[400]) : Colors.grey[500])
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      task.journalNote!,
                                      style: TextStyle(
                                        color: isDark ? Colors.white70 : Colors.grey[700],
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                        fontWeight: (task.isDecision || task.isVenting) ? FontWeight.w500 : FontWeight.normal,
                                      ),
                                      maxLines: _isExpanded ? 100 : 10, 
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          
                          // Expanded Audio Player for Venting
                          if (task.isVenting && _isExpanded && task.journalAudioPath != null) ...[
                             const SizedBox(height: 8),
                             InlineAudioPlayer(audioPath: task.journalAudioPath!, isDark: isDark),
                          ]
                        ],
                      ),
                    ),
                    
                    // Right side media icon
                    // Hide if Venting (since we use inline player on expand)
                    if (!task.isVenting && (task.journalImagePath != null || task.journalVideoPath != null || task.journalAudioPath != null))
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
                                color: (task.journalAudioPath != null)
                                    ? (isDark ? Colors.teal.withOpacity(0.1) : Colors.teal.withOpacity(0.05))
                                    : (task.journalImagePath == null && task.journalVideoPath != null
                                        ? (isDark ? Colors.grey[800] : Colors.grey[600])
                                        : Colors.black12),
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
                                    Icon(
                                      Icons.play_circle_fill, 
                                      color: Colors.white.withOpacity(0.9), 
                                      size: 24,
                                    ),
                                  if (task.journalAudioPath != null)
                                    Icon(
                                      Icons.graphic_eq, 
                                      color: isDark ? Colors.tealAccent : Colors.teal, 
                                      size: 24,
                                    ),
                                ],
                              ),
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

class InlineAudioPlayer extends StatefulWidget {
  final String audioPath;
  final bool isDark;

  const InlineAudioPlayer({super.key, required this.audioPath, required this.isDark});

  @override
  State<InlineAudioPlayer> createState() => _InlineAudioPlayerState();
}

class _InlineAudioPlayerState extends State<InlineAudioPlayer> {
  late AudioPlayer _player;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      await _player.setFilePath(widget.audioPath);
      _duration = _player.duration ?? Duration.zero;
      if (mounted) setState(() {});
      
      _player.playerStateStream.listen((state) {
        if (mounted) {
           setState(() {
              _isPlaying = state.playing && state.processingState != ProcessingState.completed;
           });
        }
      });

      _player.positionStream.listen((p) {
        if (mounted) setState(() => _position = p);
      });
      
    } catch (e) {
      debugPrint("Error loading audio: $e");
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.isDark ? Colors.tealAccent : Colors.teal;
    final bgColor = widget.isDark ? Colors.teal.withOpacity(0.15) : Colors.teal.withOpacity(0.08);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: primaryColor.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          if (!widget.isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Row(
        children: [
          // Play/Pause with subtle animation tint
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                 if (_isPlaying) {
                   _player.pause();
                 } else {
                   if (_player.processingState == ProcessingState.completed) {
                      _player.seek(Duration.zero);
                   }
                   _player.play();
                 }
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 24,
                  color: primaryColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Waveform-like bar
                Stack(
                  children: [
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: widget.isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      height: 4,
                      width: MediaQuery.of(context).size.width * 0.4 * 
                             (_duration.inMilliseconds > 0 
                                 ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0) 
                                 : 0.0),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primaryColor, primaryColor.withOpacity(0.5)],
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(_position),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: primaryColor.withOpacity(0.8),
                        fontFamily: 'monospace',
                      ),
                    ),
                    Text(
                      _formatDuration(_duration),
                      style: TextStyle(
                        fontSize: 10,
                        color: widget.isDark ? Colors.white38 : Colors.black26,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
