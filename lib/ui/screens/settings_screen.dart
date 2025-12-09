import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Clipboard
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/localization.dart';
import '../../data/providers.dart';
import '../../data/models/ai_persona.dart';
import '../../utils/haptic_helper.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final isChinese = locale == 'zh';
    final themeMode = ref.watch(themeModeProvider);
    
    // Theme references
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    String t(String key) => AppStrings.get(key, locale);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.all(24.0),
              children: [
                Text(
                  t('settings').toUpperCase(),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.0,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(height: 32),
                
                // Language
                _SettingsTile(
                  icon: Icons.language,
                  title: t('language'),
                  trailing: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _LanguageOption(
                          text: "EN", 
                          isSelected: !isChinese, 
                          onTap: () {
                             ref.read(localeProvider.notifier).setLocale('en');
                             HapticHelper(ref).selectionClick();
                          },
                          isDark: isDark,
                        ),
                        _LanguageOption(
                          text: "中文", 
                          isSelected: isChinese, 
                          onTap: () {
                             ref.read(localeProvider.notifier).setLocale('zh');
                             HapticHelper(ref).selectionClick();
                          },
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                ),
                
                const Divider(height: 32),

                // Theme Mode Toggle
                _SettingsTile(
                  icon: isDark ? Icons.dark_mode : Icons.light_mode,
                  title: t('theme'),
                  trailing: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ThemeOption(
                          icon: Icons.light_mode,
                          isSelected: themeMode == ThemeMode.light,
                          onTap: () {
                            ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light);
                            HapticHelper(ref).selectionClick();
                          },
                          isDark: isDark,
                        ),
                        _ThemeOption(
                          icon: Icons.dark_mode,
                          isSelected: themeMode == ThemeMode.dark,
                          onTap: () {
                            ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark);
                            HapticHelper(ref).selectionClick();
                          },
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                ),
                
                const Divider(height: 32),
                
                // Vibration Intensity Slider
                _VibrationIntensityTile(isDark: isDark),

                const Divider(height: 32),

                // AI Persona Selector (Collapsible)
                _CollapsibleAIPersonaTile(isDark: isDark),

                const Divider(height: 32),

                 _SettingsTile(
                  icon: Icons.delete_outline,
                  title: t('clear_data'),
                  trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
                  onTap: () => _showClearDataConfirmation(context, ref),
                ),
                
                const Divider(height: 32),
                
                _SettingsTile(
                  icon: Icons.feedback_outlined,
                  title: t('feedback'),
                  trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
                  onTap: () => _showFeedbackModal(context, ref),
                ),
                
                _SettingsTile(
                  icon: Icons.psychology_outlined,
                  title: "AI Configuration", // Not localized for now or add to localization
                  trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
                  onTap: () => _showAiConfigModal(context, ref),
                ),

                _SettingsTile(
                  icon: Icons.info_outline,
                  title: t('about'),
                  trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
                  onTap: () => _showAboutModal(context, ref),
                ),
                 
                 const SizedBox(height: 48),
                 Center(
                   child: Text(
                     "${t('version')} 1.1.1", 
                     style: TextStyle(color: Colors.grey[400], fontSize: 12)
                   ),
                 ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showClearDataConfirmation(BuildContext context, WidgetRef ref) {
    HapticHelper(ref).lightImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String t(String key) => AppStrings.get(key, ref.read(localeProvider));
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                t('clear_data_title'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          t('clear_data_confirm'),
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
        ),
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
             Text("Version 1.1.1", style: TextStyle(color: Colors.grey[600])),
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
          bottom: MediaQuery.of(context).viewInsets.bottom + 24 // Keyboard padding
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
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? textColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.trailing,
    this.onTap,
    this.iconColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            Icon(icon, size: 22, color: iconColor ?? (isDark ? Colors.white70 : Colors.black87)),
            const SizedBox(width: 16),
            Expanded(child: Text(title, style: TextStyle(
              fontSize: 16, 
              fontWeight: FontWeight.w500, 
              color: textColor ?? (isDark ? Colors.white : Colors.black87)
            ))),
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
                    color: isDark ? Colors.white : Colors.black87,
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
                            color: isDark ? Colors.white : Colors.black87,
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
