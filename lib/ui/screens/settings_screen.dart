import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Clipboard
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/localization.dart';
import '../../data/providers.dart';
import '../../data/models/ai_persona.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/self_hosted_auth_service.dart';
import '../../utils/haptic_helper.dart';
import '../widgets/custom_dialog.dart';
import '../../data/models/gamification_state.dart';
import '../../data/services/gamification_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'dart:io';
import 'achievements_screen.dart';
import '../widgets/white_background_remover.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Hidden developer options
  int _versionTapCount = 0;
  bool _showAIConfig = false;
  DateTime? _lastTapTime;

  void _handleVersionTap() {
    final now = DateTime.now();
    
    // Reset count if more than 1 second between taps
    if (_lastTapTime != null && now.difference(_lastTapTime!) > const Duration(seconds: 1)) {
      _versionTapCount = 0;
    }
    
    _lastTapTime = now;
    _versionTapCount++;
    
    if (_versionTapCount >= 3) {
      setState(() {
        _showAIConfig = !_showAIConfig;
        _versionTapCount = 0;
      });
      HapticHelper(ref).mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_showAIConfig ? 'Developer options enabled' : 'Developer options disabled'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final locale = ref.watch(localeProvider);
    final isChinese = locale == 'zh';
    final themeMode = ref.watch(themeModeProvider);
    
    // Theme references
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Providers
    final gamificationState = ref.watch(gamificationServiceProvider);
    final authService = ref.watch(authServiceProvider);
    final user = authService.currentUser;

    String t(String key) => AppStrings.get(key, locale);
    
    // Section Header Style
    final sectionHeaderStyle = TextStyle(
      fontSize: 14, 
      fontWeight: FontWeight.bold, 
      color: isDark ? Colors.grey[400] : Colors.grey[600],
      letterSpacing: 1.0,
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              children: [
                // === 1. Header & Profile ===
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      t('me_title') == 'me_title' ? 'Me' : t('me_title'), // Fallback if key missing
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.0,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Minimal Profile Card + Gamification
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50], // Minimalist bg
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          // Avatar
                          Container(
                            width: 64, height: 64,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark ? Colors.grey[800] : Colors.grey[200],
                            ),
                            child: (user?.avatarUrl != null) 
                              ? (user!.avatarUrl!.startsWith('http') 
                                  ? CachedNetworkImage(
                                      imageUrl: kIsWeb 
                                        ? 'https://corsproxy.io/?${Uri.encodeComponent(user.avatarUrl!)}'
                                        : user.avatarUrl!,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Center(child: CircularProgressIndicator(strokeWidth: 2, color: isDark ? Colors.white24 : Colors.black12)),
                                      errorWidget: (context, url, error) => Icon(Icons.person, size: 32, color: isDark ? Colors.white54 : Colors.grey[400]),
                                    )
                                  : Image.file(
                                      File(user.avatarUrl!), 
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Icon(Icons.person, size: 32, color: isDark ? Colors.white54 : Colors.grey[400]),
                                    ))
                              : Icon(Icons.person, size: 32, color: isDark ? Colors.white54 : Colors.grey[400]),
                          ),
                          const SizedBox(width: 20),
                          
                          // Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                      Text(
                                        user?.displayName ?? t('traveler'),
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.onSurface,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        "Lv.${gamificationState.level}",
                                        style: TextStyle(
                                          fontSize: 14, 
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.onSurface.withOpacity(0.7)
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      gamificationState.levelTitle, 
                                      style: TextStyle(
                                        fontSize: 14, 
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const AchievementsScreen()),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                Icons.emoji_events_outlined, 
                                color: isDark ? Colors.amber[300] : Colors.amber[600], // Make it golden/stand out more
                                size: 36, // Larger size as requested
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Achievements Preview (Moved Up & No Background)
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AchievementsScreen()),
                          );
                        },
                        child: Container(
                           width: double.infinity,
                           padding: const EdgeInsets.only(bottom: 4), // Reduced spacing below
                           // Removed decoration/background
                           child: Wrap(
                             spacing: 8,
                             runSpacing: 8,
                             children: [
                               // Only show unlocked badges here
                               if (gamificationState.achievements.where((a) => a.isUnlocked).isNotEmpty)
                                 ...gamificationState.achievements
                                     .where((a) => a.isUnlocked)
                                     .take(5) // Show max 5
                                     .map((a) {
                                        final cleanIcon = a.icon.trim();
                                        final isUrl = cleanIcon.toLowerCase().startsWith('http');
                                        return isUrl
                                          ? SizedBox(
                                              width: 32, height: 32,
                                              child: WhiteBackgroundRemover(
                                                child: CachedNetworkImage(
                                                   imageUrl: kIsWeb 
                                                      ? 'https://corsproxy.io/?${Uri.encodeComponent(cleanIcon)}' 
                                                      : cleanIcon,
                                                   fit: BoxFit.contain,
                                                   placeholder: (context, url) => Container(
                                                     width: 16, height: 16,
                                                     decoration: BoxDecoration(
                                                       color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                                                       shape: BoxShape.circle,
                                                     ),
                                                   ),
                                                   errorWidget: (context, url, error) => const Icon(Icons.error, size: 16),
                                                ),
                                              ),
                                            )
                                          : Text(a.icon, style: const TextStyle(fontSize: 24));
                                     }),
                             ],
                           ),
                        ),
                      ),

                      // Stats Row
                      // XP Progress
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t('xp_progress'), 
                            style: TextStyle(
                              fontSize: 12, 
                              fontWeight: FontWeight.bold, 
                              color: Colors.grey[500], 
                              letterSpacing: 1
                            ),
                          ),

                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: gamificationState.progressToNextLevel,
                              minHeight: 6,
                              backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(isDark ? Colors.white : Colors.black),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${gamificationState.currentXp} / ${gamificationState.xpToNextLevel} XP",
                            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16), // Reduced from 40
                
                // === 2. Preferences ===
                const SizedBox(height: 32),

                // === 2. Preferences Group ===
                _buildSettingsGroup(
                  context,
                  title: t('preferences'),
                  children: [
                    _SettingsTile(
                      icon: themeMode == ThemeMode.system 
                          ? Icons.brightness_auto 
                          : (isDark ? Icons.dark_mode : Icons.light_mode),
                      title: t('theme'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                           _ThemeOption(icon: Icons.light_mode, isSelected: themeMode == ThemeMode.light, onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light), isDark: isDark),
                           _ThemeOption(icon: Icons.brightness_auto, isSelected: themeMode == ThemeMode.system, onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.system), isDark: isDark),
                           _ThemeOption(icon: Icons.dark_mode, isSelected: themeMode == ThemeMode.dark, onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark), isDark: isDark),
                        ],
                      ),
                    ),
                    _SettingsTile(
                      icon: Icons.language,
                      title: t('language'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _LanguageOption(
                            text: "EN", 
                            isSelected: !isChinese, 
                            onTap: () {
                              ref.read(localeProvider.notifier).setLocale('en');
                              // Refresh home widget with new locale
                              ref.read(taskListProvider.notifier).refreshWidget();
                            }, 
                            isDark: isDark
                          ),
                          const SizedBox(width: 4),
                          _LanguageOption(
                            text: "中文", 
                            isSelected: isChinese, 
                            onTap: () {
                              ref.read(localeProvider.notifier).setLocale('zh');
                              // Refresh home widget with new locale
                              ref.read(taskListProvider.notifier).refreshWidget();
                            }, 
                            isDark: isDark
                          ),
                        ],
                      ),
                    ),
                    _SettingsTile(
                      icon: Icons.screen_rotation,
                      title: t('auto_focus_landscape'),
                      subtitle: t('auto_focus_landscape_desc'),
                      trailing: Consumer(
                        builder: (context, ref, _) {
                          final enabled = ref.watch(autoLandscapeFocusProvider);
                          return Switch(
                            value: enabled,
                            onChanged: (value) {
                              ref.read(autoLandscapeFocusProvider.notifier).setEnabled(value);
                            },
                            activeColor: isDark ? Colors.white : Colors.black,
                            activeTrackColor: isDark ? Colors.white38 : Colors.black38,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    _VibrationIntensityTile(isDark: isDark),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // === 3. Intelligence Group ===
                _buildSettingsGroup(
                  context,
                  title: t('intelligence'),
                  children: [
                    _CollapsibleAIPersonaTile(isDark: isDark),
                  ],
                ),

                const SizedBox(height: 16),

                // === 4. Account Group ===
                _buildSettingsGroup(
                  context, 
                  title: t('account_group'),
                  children: [
                     _SettingsTile(
                      icon: Icons.edit_note,
                      title: t('edit_profile'),
                      onTap: () {
                         if (user != null) _showEditProfileModal(context, ref, user);
                      },
                    ),
                     _SettingsTile(
                      icon: Icons.delete_outline,
                      title: t('clear_data'),
                      onTap: () => _showClearDataConfirmation(context, ref),
                    ),
                    _SettingsTile(
                       icon: Icons.logout,
                       title: t('sign_out'),
                       textColor: Colors.red,
                       iconColor: Colors.red,
                       onTap: () async {
                          final shouldLogout = await showDialog<bool>(
                            context: context,
                            builder: (context) => CustomDialog(
                              title: t('confirm_sign_out_title'),
                              content: t('confirm_sign_out_content'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t('cancel'))),
                                TextButton(onPressed: () => Navigator.pop(context, true), child: Text(t('sign_out'), style: const TextStyle(color: Colors.red))),
                              ],
                            ),
                          );
                          if (shouldLogout == true) {
                            await authService.signOut();
                          }
                       },
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),

                // === 5. App Group ===
                _buildSettingsGroup(
                  context,
                  title: t('app_group'),
                  children: [
                    _SettingsTile(
                      icon: Icons.feedback_outlined,
                      title: t('feedback'),
                      onTap: () => _showFeedbackModal(context, ref),
                    ),
                    _SettingsTile(
                      icon: Icons.info_outline,
                      title: t('about'),
                      onTap: () => _showAboutModal(context, ref),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                 // Beta Features
                 _buildSettingsGroup(
                   context,
                   title: t('beta_features'),
                   children: [
                     Consumer(
                        builder: (context, ref, _) {
                          // We need to watch a provider, but we added it to providers.dart
                          // Let's assume it's available as morningReportEnabledProvider
                          final enabled = ref.watch(morningReportEnabledProvider);
                          return _SettingsTile(
                            icon: Icons.newspaper_outlined,
                            title: t('morning_report'),
                            trailing: Switch(
                              value: enabled,
                              onChanged: (value) {
                                ref.read(morningReportEnabledProvider.notifier).toggle();
                              },
                              activeColor: isDark ? Colors.white : Colors.black,
                              activeTrackColor: isDark ? Colors.white38 : Colors.black38,
                            ),
                          );
                        },
                      ),
                   ],
                 ),

                // Dev Options
                if (_showAIConfig) ...[
                   const SizedBox(height: 16),
                   _buildSettingsGroup(
                     context,
                     title: t('developer_group'),
                     children: [
                        _SettingsTile(
                        icon: Icons.psychology_outlined,
                        title: t('ai_config'),
                        onTap: () => _showAiConfigModal(context, ref),
                      ),
                      Consumer(
                        builder: (context, ref, _) {
                          final debugEnabled = ref.watch(debugLogEnabledProvider);
                          return _SettingsTile(
                            icon: Icons.bug_report,
                            title: t('debug_logs'),
                            trailing: Switch(
                              value: debugEnabled,
                              onChanged: (value) => ref.read(debugLogEnabledProvider.notifier).state = value,
                              activeColor: isDark ? Colors.white : Colors.black,
                              activeTrackColor: isDark ? Colors.white38 : Colors.black38,
                            ),
                          );
                        },
                      ),
                     ],
                   ),
                ],

                 const SizedBox(height: 48),
                 Center(
                   child: GestureDetector(
                     onTap: _handleVersionTap,
                     child: Text(
                       "v4.0.0", 
                       style: TextStyle(color: Colors.grey[400], fontSize: 12)
                     ),
                   ),
                 ),
                 const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAchievementsList(BuildContext context, GamificationState state) {
    // Minimalist achievement sheet
     showModalBottomSheet(
       context: context,
       backgroundColor: Colors.transparent,
       isScrollControlled: true,
       builder: (context) {
         final isDark = Theme.of(context).brightness == Brightness.dark;
         return DraggableScrollableSheet(
           initialChildSize: 0.7,
           maxChildSize: 0.9,
           builder: (context, controller) => Container(
             decoration: BoxDecoration(
               color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
               borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
             ),
             child: Column(
               children: [
                 Container(
                   margin: const EdgeInsets.symmetric(vertical: 16),
                   width: 40, height: 4,
                   decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                 ),
                 Text(
                   "Achievements",
                   style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
                 ),
                 const SizedBox(height: 16),
                 Expanded(
                   child: ListView.separated(
                     controller: controller,
                     padding: const EdgeInsets.all(24),
                     itemCount: state.achievements.length,
                     separatorBuilder: (_,__) => const SizedBox(height: 24),
                     itemBuilder: (context, index) {
                       final a = state.achievements[index];
                       final isUnlocked = a.isUnlocked;
                       return Row(
                         children: [
                             Container(
                               width: 50, height: 50,
                               decoration: BoxDecoration(
                                 color: Colors.transparent, // Removed background
                                 shape: BoxShape.circle,
                                 // Removed border that might imply container
                               ),
                               alignment: Alignment.center,
                               child: Text(isUnlocked ? a.icon : "🔒", style: const TextStyle(fontSize: 24)),
                             ),
                           const SizedBox(width: 16),
                           Expanded(
                               child: Column(
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 children: [
                                   Text(
                                     a.title,
                                     style: TextStyle(
                                       fontWeight: FontWeight.bold,
                                       color: isUnlocked ? (isDark ? Colors.white : Colors.black) : Colors.grey[400],
                                     ),
                                   ),
                                   const SizedBox(height: 4),
                                    Text(
                                     a.description,
                                     style: TextStyle(
                                       fontSize: 12,
                                       color: isDark ? Colors.grey[500] : Colors.grey[600],
                                     ),
                                   ),
                                 ],
                               ),
                           ),
                         ],
                       );
                     },
                   ),
                 ),
               ],
             ),
           ),
         );
       },
     );
  }


  void _showClearDataConfirmation(BuildContext context, WidgetRef ref) {
    HapticHelper(ref).lightImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String t(String key) => AppStrings.get(key, ref.read(localeProvider));
    
    showDialog(
      context: context,
      builder: (context) => CustomDialog(
        title: t('clear_data_title'),
        content: t('clear_data_confirm'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t('cancel'), style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(taskListProvider.notifier).clear();
              HapticHelper(ref).mediumImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(t('data_cleared')),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(t('confirm_clear'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAboutModal(BuildContext context, WidgetRef ref) {
    HapticHelper(ref).lightImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // Transparent for rounded corners effect
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Text(AppStrings.get('about_title', ref.read(localeProvider)), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
            const SizedBox(height: 32),
             Container(
               width: 80, height: 80,
               decoration: BoxDecoration(
                 boxShadow: [
                   BoxShadow(
                     color: Colors.black.withOpacity(0.1),
                     blurRadius: 10,
                     offset: const Offset(0, 4),
                   )
                 ],
                 borderRadius: BorderRadius.circular(20),
               ),
               child: ClipRRect(
                 borderRadius: BorderRadius.circular(20),
                 child: Image.asset('assets/icon/app_icon.png', fit: BoxFit.cover),
               ),
             ),
             const SizedBox(height: 16),
             Text("Version 4.0.0", style: TextStyle(color: Colors.grey[600])),
             const SizedBox(height: 32),
             Padding(
               padding: const EdgeInsets.symmetric(horizontal: 32),
               child: Text(
                 AppStrings.get('about_content', ref.read(localeProvider)),
                 textAlign: TextAlign.center,
                 style: TextStyle(fontSize: 16, height: 1.5, color: isDark ? Colors.white70 : Colors.black87),
               ),
             ),
             const Spacer(),
             Padding(
               padding: const EdgeInsets.only(bottom: 32.0),
               child: Text("Designed with ❤️ by LongDz", style: TextStyle(color: Colors.grey[600])),
             )
          ],
        ),
      ),
    );
  }

  void _showFeedbackModal(BuildContext context, WidgetRef ref) {
     HapticHelper(ref).lightImpact();
     final locale = ref.read(localeProvider);
     final email = AppStrings.get('feedback_email', locale);
     final isDark = Theme.of(context).brightness == Brightness.dark;
     
     showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true, // Allow full height if needed
      builder: (context) => Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppStrings.get('feedback', locale), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: isDark ? Colors.black38 : Colors.grey[100], borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Icon(Icons.email_outlined, color: isDark ? Colors.white : Colors.black),
                  const SizedBox(width: 16),
                  Expanded(child: Text(email, style: TextStyle(fontSize: 16, color: isDark ? Colors.white : Colors.black))),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    color: isDark ? Colors.white : Colors.black,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: email));
                      HapticHelper(ref).mediumImpact();
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.get('email_copied', locale))));
                    },
                  )
                ],
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  void _showAiConfigModal(BuildContext context, WidgetRef ref) {
    final currentSettings = ref.read(apiSettingsProvider);
    final keyController = TextEditingController(text: currentSettings.apiKey);
    final urlController = TextEditingController(text: currentSettings.baseUrl);
    final modelController = TextEditingController(text: currentSettings.model);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 24, 
          right: 24, 
          top: 24, 
          bottom: MediaQuery.of(context).viewInsets.bottom + 16 // Reduced bottom padding
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "AI Configuration", 
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)
            ),
            const SizedBox(height: 24),
            
            // API Key
            _buildTextField(context, "API Key", keyController, isDark),
            const SizedBox(height: 16),
            
            // Base URL
            _buildTextField(context, "Base URL", urlController, isDark),
            const SizedBox(height: 16),

            // Model
            _buildTextField(context, "Model", modelController, isDark),
            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  // Update Provider
                  ref.read(apiSettingsProvider.notifier).update(currentSettings.copyWith(
                    apiKey: keyController.text.trim(),
                    baseUrl: urlController.text.trim(),
                    model: modelController.text.trim(),
                  ));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("AI Settings Updated")),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.white : Colors.black,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("SAVE CHANGES", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(BuildContext context, String label, TextEditingController controller, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.grey[700])),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark ? Colors.black38 : Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsGroup(BuildContext context, {required String title, required List<Widget> children}) {
     final theme = Theme.of(context);
     final isDark = theme.brightness == Brightness.dark;
     final borderColor = isDark ? Colors.white12 : Colors.grey[200]!;
     
     return Theme(
       data: theme.copyWith(dividerColor: Colors.transparent),
       child: ExpansionTile(
         tilePadding: const EdgeInsets.symmetric(horizontal: 0),
         title: Text(
           title,
           style: TextStyle(
             fontSize: 14, 
             fontWeight: FontWeight.bold, 
             color: theme.colorScheme.onSurface,
             letterSpacing: 1.0,
           ),
         ),
         collapsedShape: Border(bottom: BorderSide(color: borderColor)),
         shape: Border(bottom: BorderSide(color: borderColor)),
         collapsedBackgroundColor: Colors.transparent,
         backgroundColor: Colors.transparent,
         childrenPadding: const EdgeInsets.only(bottom: 16),
         initiallyExpanded: false,
         children: children,
       ),
     );
  }

  void _showEditProfileModal(BuildContext context, WidgetRef ref, AppUser user) {
    final locale = ref.read(localeProvider);
    final nameController = TextEditingController(text: user.displayName);
    
    Uint8List? newImageBytes;
    String? newImageFilename;
    String? selectedPresetUrl;
    bool isUploading = false;
    
    // Default preset avatars
    final List<String> presetAvatars = [
      'https://api.dicebear.com/7.x/adventurer/png?seed=Felix',
      'https://api.dicebear.com/7.x/adventurer/png?seed=Aneka',
      'https://api.dicebear.com/7.x/adventurer/png?seed=Bella',
      'https://api.dicebear.com/7.x/adventurer/png?seed=Coco',
      'https://api.dicebear.com/7.x/adventurer/png?seed=Daisy',
      'https://api.dicebear.com/7.x/adventurer/png?seed=Jack',
      'https://api.dicebear.com/7.x/adventurer/png?seed=Leo',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
               padding: EdgeInsets.only(
                 bottom: MediaQuery.of(context).viewInsets.bottom,
               ),
               decoration: BoxDecoration(
                 color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                 borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
               ),
               child: SingleChildScrollView(
                 child: Padding(
                   padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                   child: Column(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       Center(
                         child: Container(
                           width: 40, height: 4, 
                           decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))
                         ),
                       ),
                       const SizedBox(height: 24),
                       Text(
                         AppStrings.get('edit_profile', locale),
                         style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
                       ),
                       const SizedBox(height: 24),
                       
                       // Main Avatar Display & Picker
                       Center(
                         child: GestureDetector(
                           onTap: () async {
                             final picker = ImagePicker();
                             final pickedFile = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800);
                             if (pickedFile != null) {
                               final bytes = await pickedFile.readAsBytes();
                               setState(() {
                                 newImageBytes = bytes;
                                 newImageFilename = pickedFile.name;
                                 selectedPresetUrl = null; // Clear preset if custom uploaded
                               });
                             }
                           },
                           child: Stack(
                             children: [
                               Container(
                                 width: 100, height: 100,
                                 clipBehavior: Clip.antiAlias,
                                 decoration: BoxDecoration(
                                   shape: BoxShape.circle,
                                   color: isDark ? Colors.grey[800] : Colors.grey[200],
                                 ),
                                 child: newImageBytes != null
                                     ? Image.memory(newImageBytes!, fit: BoxFit.cover)
                                     : (selectedPresetUrl != null 
                                        ? CachedNetworkImage(
                                            imageUrl: selectedPresetUrl!,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) => Center(child: CircularProgressIndicator(strokeWidth: 2, color: isDark ? Colors.white24 : Colors.black12)),
                                            errorWidget: (context, url, error) => Icon(Icons.person, size: 50, color: Colors.grey[400]),
                                          )
                                        : (user.avatarUrl != null
                                             ? CachedNetworkImage(
                                                 imageUrl: user.avatarUrl!,
                                                 fit: BoxFit.cover,
                                                 placeholder: (context, url) => Center(child: CircularProgressIndicator(strokeWidth: 2, color: isDark ? Colors.white24 : Colors.black12)),
                                                 errorWidget: (context, url, error) => Icon(Icons.person, size: 50, color: Colors.grey[400]),
                                               )
                                             : Icon(Icons.person, size: 50, color: Colors.grey[400]))),
                               ),
                               Positioned(
                                 bottom: 0,
                                 right: 0,
                                 child: Container(
                                   padding: const EdgeInsets.all(6),
                                   decoration: BoxDecoration(
                                     color: isDark ? Colors.blueAccent : Colors.blue,
                                     shape: BoxShape.circle,
                                     border: Border.all(color: isDark ? const Color(0xFF1C1C1E) : Colors.white, width: 2),
                                   ),
                                   child: const Icon(Icons.edit, size: 16, color: Colors.white),
                                 ),
                               ),
                             ],
                           ),
                         ),
                       ),
                       const SizedBox(height: 24),

                       // Preset Avatars
                       SizedBox(
                         height: 60,
                         child: ListView.separated(
                           scrollDirection: Axis.horizontal,
                           itemCount: presetAvatars.length,
                           separatorBuilder: (_, __) => const SizedBox(width: 16),
                           itemBuilder: (context, index) {
                             final url = presetAvatars[index];
                             final isSelected = selectedPresetUrl == url;
                             return GestureDetector(
                               onTap: () {
                                 setState(() {
                                   selectedPresetUrl = url;
                                   newImageBytes = null; // Clear upload if preset selected
                                   newImageFilename = null;
                                 });
                               },
                               child: Container(
                                 width: 60, height: 60,
                                 clipBehavior: Clip.antiAlias,
                                 decoration: BoxDecoration(
                                   shape: BoxShape.circle,
                                   border: isSelected ? Border.all(color: Colors.blue, width: 3) : null,
                                 ),
                                 child: CachedNetworkImage(
                                   imageUrl: url,
                                   fit: BoxFit.cover,
                                   placeholder: (context, url) => Center(child: CircularProgressIndicator(strokeWidth: 2, color: isDark ? Colors.white24 : Colors.black12)),
                                   errorWidget: (context, url, error) => const Icon(Icons.error, size: 20),
                                 ),
                               ),
                             );
                           },
                         ),
                       ),
                       
                       const SizedBox(height: 24),
                       
                       // Name Input
                       _buildTextField(context, AppStrings.get('display_name', locale), nameController, isDark),
                       const SizedBox(height: 32),
                       
                       // Save Button
                       SizedBox(
                         width: double.infinity,
                         height: 50,
                         child: ElevatedButton(
                           onPressed: isUploading ? null : () async {
                             final newName = nameController.text.trim();
                             if (newName.isEmpty) return;
                             
                             setState(() => isUploading = true);
                             
                             try {
                                 final authService = ref.read(authServiceProvider);
                                 String? uploadedUrl;
                                 
                                  // 1. If custom image
                                 if (newImageBytes != null && newImageFilename != null) {
                                   // We need to use SelfHostedAuthService for upload if available.
                                   final auth = ref.read(authServiceProvider);
                                   if (auth is SelfHostedAuthService) {
                                      uploadedUrl = await (auth as SelfHostedAuthService).uploadAvatar(newImageBytes!, newImageFilename!);
                                   } else {
                                      // Fallback: Try instantiating directly if we know we are in a context where it works
                                      // Or throw error / show message that upload not supported on this backend
                                      final service = SelfHostedAuthService(); 
                                      uploadedUrl = await service.uploadAvatar(newImageBytes!, newImageFilename!);
                                   }
                                 } 
                                 // 2. If preset selected
                                 else if (selectedPresetUrl != null) {
                                   uploadedUrl = selectedPresetUrl;
                                 }
                                 
                                 await authService.updateProfile(
                                   displayName: newName,
                                   avatarUrl: uploadedUrl, 
                                 );
                                 
                                 if (context.mounted) {
                                   Navigator.pop(context);
                                   HapticHelper(ref).mediumImpact();
                                 }
                             } catch (e) {
                                 if (context.mounted) {
                                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                                 }
                             } finally {
                                 if (context.mounted) setState(() => isUploading = false);
                             }
                           },
                           style: ElevatedButton.styleFrom(
                             backgroundColor: isDark ? Colors.white : Colors.black,
                             foregroundColor: isDark ? Colors.black : Colors.white,
                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                           ),
                           child: isUploading 
                             ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                             : Text(AppStrings.get('save_profile', locale), style: const TextStyle(fontWeight: FontWeight.bold)),
                         ),
                       ),
                     ],
                   ),
                 ),
               ),
            );
          },
        );
      },
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? textColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            Icon(icon, size: 22, color: iconColor ?? theme.colorScheme.onSurface.withOpacity(0.7)),
            const SizedBox(width: 16),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: TextStyle(
                  fontSize: 16, 
                  fontWeight: FontWeight.w500, 
                  color: textColor ?? theme.colorScheme.onSurface.withOpacity(0.6)
                )),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                  )),
                ],
              ],
            )),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  final String text;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _LanguageOption({required this.text, required this.isSelected, required this.onTap, required this.isDark, super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? (isDark ? Colors.white : Colors.black) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? (isDark ? Colors.black : Colors.white) : Colors.grey[500],
          ),
        ),
      ),
    );
  }
}

class _VibrationIntensityTile extends ConsumerWidget {
  final bool isDark;

  const _VibrationIntensityTile({required this.isDark});

  String _getIntensityLabel(double intensity, String locale) {
    if (intensity <= 0) {
      return AppStrings.get('vibration_off', locale);
    } else if (intensity < 0.4) {
      return AppStrings.get('vibration_light', locale);
    } else if (intensity < 0.7) {
      return AppStrings.get('vibration_medium', locale);
    } else {
      return AppStrings.get('vibration_strong', locale);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final intensity = ref.watch(vibrationIntensityProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.vibration, size: 22, color: isDark ? Colors.white70 : Colors.black87),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  AppStrings.get('vibration_intensity', locale),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getIntensityLabel(intensity, locale),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: intensity <= 0 ? Colors.grey : (isDark ? Colors.white : Colors.black),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: isDark ? Colors.white : Colors.black,
              inactiveTrackColor: isDark ? Colors.grey[700] : Colors.grey[300],
              thumbColor: isDark ? Colors.white : Colors.black,
              overlayColor: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
              trackHeight: 4,
            ),
            child: Slider(
              value: intensity,
              min: 0.0,
              max: 1.0,
              divisions: 10,
              onChanged: (value) {
                ref.read(vibrationIntensityProvider.notifier).setIntensity(value);
                // Give feedback with new intensity
                if (value > 0) {
                   HapticHelper(ref).mediumImpact();
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _ThemeOption({
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? (isDark ? Colors.white : Colors.black) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isSelected ? (isDark ? Colors.black : Colors.white) : Colors.grey[500],
        ),
      ),
    );
  }
}

class _CollapsibleAIPersonaTile extends ConsumerStatefulWidget {
  final bool isDark;

  const _CollapsibleAIPersonaTile({required this.isDark});

  @override
  ConsumerState<_CollapsibleAIPersonaTile> createState() => _CollapsibleAIPersonaTileState();
}

class _CollapsibleAIPersonaTileState extends ConsumerState<_CollapsibleAIPersonaTile> 
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
    HapticHelper(ref).lightImpact();
  }

  IconData _getPersonaIcon(AIPersona persona) {
    switch (persona) {
      case AIPersona.rushed:
        return Icons.speed;
      case AIPersona.balanced:
        return Icons.balance;
      case AIPersona.relaxed:
        return Icons.self_improvement;
    }
  }

  String _getPersonaName(AIPersona persona, String locale) {
    switch (persona) {
      case AIPersona.rushed:
        return AppStrings.get('persona_rushed', locale);
      case AIPersona.balanced:
        return AppStrings.get('persona_balanced', locale);
      case AIPersona.relaxed:
        return AppStrings.get('persona_relaxed', locale);
    }
  }

  String _getPersonaDesc(AIPersona persona, String locale) {
    switch (persona) {
      case AIPersona.rushed:
        return AppStrings.get('persona_rushed_desc', locale);
      case AIPersona.balanced:
        return AppStrings.get('persona_balanced_desc', locale);
      case AIPersona.relaxed:
        return AppStrings.get('persona_relaxed_desc', locale);
    }
  }

  Color _getPersonaColor(AIPersona persona) {
    switch (persona) {
      case AIPersona.rushed:
        return Colors.orange;
      case AIPersona.balanced:
        return Colors.blue;
      case AIPersona.relaxed:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final currentPersona = ref.watch(aiPersonaProvider);
    final isDark = widget.isDark;
    final personaColor = _getPersonaColor(currentPersona);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row (Clickable to expand/collapse)
          InkWell(
            onTap: _toggleExpand,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.psychology, size: 22, color: isDark ? Colors.white70 : Colors.black87),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.get('ai_persona', locale),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 2),
                        // Show current selection when collapsed
                        Row(
                          children: [
                            Icon(
                              _getPersonaIcon(currentPersona),
                              size: 14,
                              color: personaColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _getPersonaName(currentPersona, locale),
                              style: TextStyle(
                                fontSize: 12,
                                color: personaColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Expandable Content
          SizeTransition(
            sizeFactor: CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[900] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: AIPersona.values.map((persona) {
                      final isSelected = persona == currentPersona;
                      final pColor = _getPersonaColor(persona);
                      
                      return InkWell(
                        onTap: () {
                          ref.read(aiPersonaProvider.notifier).setPersona(persona);
                          HapticHelper(ref).selectionClick();
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? (isDark ? pColor.withOpacity(0.2) : pColor.withOpacity(0.1))
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected 
                                ? Border.all(color: pColor.withOpacity(0.5), width: 1.5)
                                : null,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isSelected 
                                      ? pColor.withOpacity(0.2)
                                      : (isDark ? Colors.grey[800] : Colors.grey[200]),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  _getPersonaIcon(persona),
                                  color: isSelected ? pColor : Colors.grey[500],
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _getPersonaName(persona, locale),
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                        color: isSelected 
                                            ? pColor 
                                            : (isDark ? Colors.white : Colors.black87),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _getPersonaDesc(persona, locale),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle,
                                  color: pColor,
                                  size: 22,
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// _AccountTile removed as it's now integrated into the main view

