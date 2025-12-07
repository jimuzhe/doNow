import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Clipboard
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/localization.dart';
import '../../data/providers.dart';

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
                         ref.read(localeProvider.notifier).state = 'en';
                         HapticFeedback.selectionClick();
                      },
                      isDark: isDark,
                    ),
                    _LanguageOption(
                      text: "中文", 
                      isSelected: isChinese, 
                      onTap: () {
                         ref.read(localeProvider.notifier).state = 'zh';
                         HapticFeedback.selectionClick();
                      },
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ),
            
            const Divider(height: 32),
            
            // Theme Toggle

             _SettingsTile(
              icon: Icons.delete_outline,
              title: t('clear_data'),
              trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
              onTap: () {
                // Clear List Logic
                ref.read(taskListProvider.notifier).state = [];
                HapticFeedback.mediumImpact();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Data Cleared")));
              },
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
                 "${t('version')} 1.0.1", 
                 style: TextStyle(color: Colors.grey[400], fontSize: 12)
               ),
             ),
          ],
        ),
      ),
    );
  }

  void _showAboutModal(BuildContext context, WidgetRef ref) {
    HapticFeedback.lightImpact();
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
             Text("Version 1.0.1", style: TextStyle(color: Colors.grey[600])),
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
     HapticFeedback.lightImpact();
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
                      HapticFeedback.mediumImpact();
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
                  ref.read(apiSettingsProvider.notifier).state = currentSettings.copyWith(
                    apiKey: keyController.text.trim(),
                    baseUrl: urlController.text.trim(),
                    model: modelController.text.trim(),
                  );
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

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.trailing,
    this.onTap,
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
            Icon(icon, size: 22, color: isDark ? Colors.white70 : Colors.black87),
            const SizedBox(width: 16),
            Expanded(child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87))),
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
