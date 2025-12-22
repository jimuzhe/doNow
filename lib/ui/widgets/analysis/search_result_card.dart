import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../data/models/task.dart';

class SearchResultCard extends StatelessWidget {
  final Task task;
  final bool isDark;
  final String searchQuery;
  final VoidCallback onTap;

  const SearchResultCard({
    super.key,
    required this.task,
    required this.isDark,
    required this.searchQuery,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final date = task.completedAt ?? task.scheduledStart;
    final dateStr = DateFormat('MMM d, yyyy • HH:mm').format(date);
    
    final isCompleted = task.isCompleted;
    final isAbandoned = task.isAbandoned;
    
    String durationText = '';
    if (task.actualDuration != null && task.actualDuration!.inMinutes > 0) {
      durationText = '${task.actualDuration!.inMinutes} min';
    } else if (task.totalDuration.inMinutes > 0) {
      durationText = '${task.totalDuration.inMinutes} min';
    }
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: isDark ? Colors.white38 : Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.grey[600],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isCompleted 
                        ? Colors.green.withOpacity(0.15)
                        : isAbandoned
                            ? Colors.red.withOpacity(0.15)
                            : Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isCompleted 
                        ? '✓' 
                        : isAbandoned 
                            ? '✗' 
                            : '•••',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isCompleted 
                          ? Colors.green 
                          : isAbandoned 
                              ? Colors.red 
                              : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 10),
            
            _buildHighlightedText(
              task.title,
              searchQuery,
              TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
              isDark,
            ),
            
            if (task.journalNote != null && 
                task.journalNote!.toLowerCase().contains(searchQuery.toLowerCase())) ...[
              const SizedBox(height: 8),
              _buildHighlightedText(
                task.journalNote!.length > 80 
                    ? '${task.journalNote!.substring(0, 80)}...' 
                    : task.journalNote!,
                searchQuery,
                TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
                isDark,
              ),
            ],
            
            if (durationText.isNotEmpty || task.isQuickFocus || task.isDecision) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  if (durationText.isNotEmpty) ...[
                    Icon(
                      Icons.timer_outlined,
                      size: 14,
                      color: isDark ? Colors.white38 : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      durationText,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.grey[600],
                      ),
                    ),
                  ],
                  if (task.isQuickFocus) ...[
                    if (durationText.isNotEmpty) const SizedBox(width: 12),
                    const Icon(
                      Icons.hourglass_empty,
                      size: 14,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Quick Focus',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                  if (task.isDecision) ...[
                    if (durationText.isNotEmpty || task.isQuickFocus) const SizedBox(width: 12),
                    const Icon(
                      Icons.casino,
                      size: 14,
                      color: Colors.purple,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Decision',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.purple,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildHighlightedText(String text, String query, TextStyle baseStyle, bool isDark) {
    if (query.isEmpty) {
      return Text(text, style: baseStyle);
    }
    
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final startIndex = lowerText.indexOf(lowerQuery);
    
    if (startIndex == -1) {
      return Text(text, style: baseStyle);
    }
    
    final endIndex = startIndex + query.length;
    
    return RichText(
      text: TextSpan(
        style: baseStyle,
        children: [
          TextSpan(text: text.substring(0, startIndex)),
          TextSpan(
            text: text.substring(startIndex, endIndex),
            style: baseStyle.copyWith(
              backgroundColor: isDark 
                  ? Colors.yellow.withOpacity(0.3) 
                  : Colors.yellow.withOpacity(0.5),
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(text: text.substring(endIndex)),
        ],
      ),
    );
  }
}
