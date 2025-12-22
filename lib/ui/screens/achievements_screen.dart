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

          return Column(
            children: [
              // Icon Container
              Container(
                width: 80, 
                height: 80,
                alignment: Alignment.center,
                child: isUnlocked
                    ? (achievement.icon.startsWith('http')
                        ? WhiteBackgroundRemover(
                            child: Image.network(
                              kIsWeb 
                                  ? 'https://corsproxy.io/?${Uri.encodeComponent(achievement.icon)}' 
                                  : achievement.icon,
                              width: 64, height: 64,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => const Icon(Icons.error_outline),
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
                                child: Image.network(
                                  kIsWeb 
                                      ? 'https://corsproxy.io/?${Uri.encodeComponent(achievement.icon)}' 
                                      : achievement.icon,
                                  width: 64, height: 64,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) => const SizedBox(),
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
          );
        },
      ),
    );
  }
}
