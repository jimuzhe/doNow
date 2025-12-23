import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // Add this
import '../../data/providers.dart';
import '../../data/models/gamification_state.dart';
import '../../data/models/gamification_state.dart';
import '../../data/localization.dart';
import '../widgets/white_background_remover.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gamificationServiceProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final locale = ref.watch(localeProvider);
    
    String t(String key) => AppStrings.get(key, locale);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          t('achievements_title'), // "Achievements"
          style: GoogleFonts.dotGothic16(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.75,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: state.achievements.length,
        itemBuilder: (context, index) {
          final achievement = state.achievements[index];
          final isUnlocked = achievement.isUnlocked;

          return GestureDetector(
            onTap: () => _showAchievementDetails(context, achievement, t, isDark, locale),
            child: Column(
              children: [
                // Icon Container
                Container(
                  width: 80, 
                  height: 80,
                  alignment: Alignment.center,
                  child: isUnlocked
                      ? (achievement.icon.startsWith('http')
                          ? WhiteBackgroundRemover(
                              child: CachedNetworkImage(
                                imageUrl: kIsWeb 
                                    ? 'https://corsproxy.io/?${Uri.encodeComponent(achievement.icon)}' 
                                    : achievement.icon,
                                width: 64, height: 64,
                                fit: BoxFit.contain,
                                placeholder: (context, url) => Container(
                                  width: 32, height: 32,
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                errorWidget: (context, url, error) => const Icon(Icons.error_outline),
                              ),
                            )
                          : Text(achievement.icon, style: const TextStyle(fontSize: 48)))  
                      : ColorFiltered(
                          colorFilter: const ColorFilter.matrix(<double>[
                            0.2126, 0.7152, 0.0722, 0, 0,
                            0.2126, 0.7152, 0.0722, 0, 0,
                            0.2126, 0.7152, 0.0722, 0, 0,
                            0,      0,      0,      1, 0,
                          ]),
                          child: achievement.icon.startsWith('http')
                            ? Opacity(
                                opacity: 0.5,
                                child: WhiteBackgroundRemover(
                                  child: CachedNetworkImage(
                                      imageUrl: kIsWeb 
                                          ? 'https://corsproxy.io/?${Uri.encodeComponent(achievement.icon)}' 
                                          : achievement.icon,
                                      width: 64, height: 64,
                                      fit: BoxFit.contain,
                                      errorWidget: (context, url, error) => const SizedBox(),
                                    ),
                                ),
                              )
                            : Opacity(
                                opacity: 0.5,
                                child: Text(achievement.icon, style: const TextStyle(fontSize: 48)),
                              ),
                        ),
                ),
                const SizedBox(height: 8),
                
                // Title
                Text(
                  t('ach_${achievement.id}_title') != 'ach_${achievement.id}_title' 
                      ? t('ach_${achievement.id}_title') 
                      : achievement.title, // Fallback to stored title if key missing
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dotGothic16(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isUnlocked 
                        ? (isDark ? Colors.white : Colors.black) 
                        : Colors.grey,
                  ),
                ),
                
                // Description / Condition
                const SizedBox(height: 4),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Text(
                       t('ach_${achievement.id}_desc') != 'ach_${achievement.id}_desc' 
                          ? t('ach_${achievement.id}_desc') 
                          : achievement.description, // Fallback
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.2,
                        color: isUnlocked 
                            ? (isDark ? Colors.grey[400] : Colors.grey[600]) 
                            : Colors.grey[400], // Visible but dim
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAchievementDetails(BuildContext context, Achievement achievement, String Function(String) t, bool isDark, String locale) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final title = t('ach_${achievement.id}_title') != 'ach_${achievement.id}_title' 
            ? t('ach_${achievement.id}_title') 
            : achievement.title;
        final desc = t('ach_${achievement.id}_desc') != 'ach_${achievement.id}_desc' 
            ? t('ach_${achievement.id}_desc') 
            : achievement.description;
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Enlarged Icon (No circular background)
              SizedBox(
                width: 120,
                height: 120,
                child: Center(
                  child: achievement.isUnlocked
                      ? (achievement.icon.startsWith('http')
                          ? WhiteBackgroundRemover(
                              child: CachedNetworkImage(
                                imageUrl: kIsWeb 
                                    ? 'https://corsproxy.io/?${Uri.encodeComponent(achievement.icon)}' 
                                    : achievement.icon,
                                width: 100, height: 100,
                                fit: BoxFit.contain,
                              ),
                            )
                          : Text(achievement.icon, style: const TextStyle(fontSize: 72)))
                      : ColorFiltered(
                          colorFilter: const ColorFilter.matrix(<double>[
                            0.2126, 0.7152, 0.0722, 0, 0,
                            0.2126, 0.7152, 0.0722, 0, 0,
                            0.2126, 0.7152, 0.0722, 0, 0,
                            0,      0,      0,      1, 0,
                          ]),
                          child: achievement.icon.startsWith('http')
                            ? Opacity(
                                opacity: 0.5,
                                child: WhiteBackgroundRemover(
                                  child: CachedNetworkImage(
                                    imageUrl: kIsWeb 
                                        ? 'https://corsproxy.io/?${Uri.encodeComponent(achievement.icon)}' 
                                        : achievement.icon,
                                    width: 100, height: 100,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              )
                            : Opacity(
                                opacity: 0.5,
                                child: Text(achievement.icon, style: const TextStyle(fontSize: 72)),
                              ),
                        ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Title
              Text(
                title,
                style: GoogleFonts.dotGothic16(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: achievement.isUnlocked ? (isDark ? Colors.white : Colors.black) : Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 12),
              
              // Description
              Text(
                desc,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
              
              if (achievement.isUnlocked && achievement.unlockedAt != null) ...[
                const SizedBox(height: 24),
                Divider(color: isDark ? Colors.white10 : Colors.black12),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_today, size: 14, color: isDark ? Colors.white54 : Colors.black54),
                    const SizedBox(width: 8),
                    Text(
                      "${t('unlocked_at')}: ${_formatDate(achievement.unlockedAt!, locale)}",
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white54 : Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
              
              const SizedBox(height: 32),
              
              // Close Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.white : Colors.black,
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(t('ok_cool'), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date, String locale) {
    if (locale == 'zh') {
      return "${date.year}年${date.month}月${date.day}日";
    }
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return "${months[date.month - 1]} ${date.day}, ${date.year}";
  }
}
