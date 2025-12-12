import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/localization.dart';
import '../../data/services/focus_audio_service.dart';
import '../../utils/haptic_helper.dart';

class FocusSoundSheet extends ConsumerWidget {
  const FocusSoundSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final focusService = ref.watch(focusAudioServiceProvider);
    
    // Helper for translation
    String t(String key) => AppStrings.get(key, locale);
    
    // Current state (note: FocusAudioService isn't a Notifier, so we might not see changes 
    // unless we make it one or use a StateProvider for the UI state. 
    // For now, we will rely on checking currentType which should have been set.
    // However, FocusAudioService is just a plain Provider, so changes don't trigger rebuilds unless
    // we change how we provide it or use a separate state provider.
    // Let's create a small local state for the UI, but we should probably refactor service later 
    // to be a ChangeNotifier or StateNotifier if we want reactive UI. 
    // For this simple sheet, we can use a Stateful component or just read the service state
    // assuming it won't change from *outside* this sheet while open.
    final currentType = focusService.currentType;
    final currentVolume = focusService.currentVolume;

    return Container(
      padding: const EdgeInsets.only(top: 16, bottom: 32, left: 24, right: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            t('sound_bgm'),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          
          // Sound Options Grid
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: FocusSoundType.values.map((type) {
              final isSelected = currentType == type;
              return _SoundOption(
                type: type,
                isSelected: isSelected,
                label: t(type.labelKey),
                onTap: () {
                  HapticHelper(ref).selectionClick();
                  // Update service
                  focusService.setSoundType(type);
                  // Force rebuild to show selection (since service isn't reactive)
                  (context as Element).markNeedsBuild();
                },
              );
            }).toList(),
          ),
          
          const SizedBox(height: 32),
          
          // Volume Slider
          if (currentType != FocusSoundType.none) ...[
            Text(
              t('sound_volume'),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(CupertinoIcons.speaker_1, size: 20, color: Colors.grey),
                Expanded(
                  child: CupertinoSlider(
                    value: currentVolume,
                    min: 0.0,
                    max: 1.0,
                    activeColor: Theme.of(context).primaryColor,
                    onChanged: (val) {
                      focusService.setVolume(val);
                    },
                    onChangeEnd: (val) {
                       // Only rebuild on end to avoid spam
                       (context as Element).markNeedsBuild();
                    },
                  ),
                ),
                const Icon(CupertinoIcons.speaker_3, size: 20, color: Colors.grey),
              ],
            ),
          ],
          
          // Hint about missing files
          if (currentType != FocusSoundType.none)
             FutureBuilder<bool>(
               future: _checkAssetExists(context, currentType),
               builder: (context, snapshot) {
                 if (snapshot.hasData && snapshot.data == false) {
                   return Container(
                     margin: const EdgeInsets.only(top: 16),
                     padding: const EdgeInsets.all(12),
                     decoration: BoxDecoration(
                       color: Colors.orange.withOpacity(0.1),
                       borderRadius: BorderRadius.circular(8),
                       border: Border.all(color: Colors.orange.withOpacity(0.3)),
                     ),
                     child: Row(
                       children: [
                         const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                         const SizedBox(width: 8),
                         Expanded(
                           child: Text(
                             "${t('sound_missing_desc')} ${currentType.assetPath.split('/').last}",
                             style: const TextStyle(fontSize: 12, color: Colors.orange),
                           ),
                         ),
                       ],
                     ),
                   );
                 }
                 return const SizedBox();
               },
             ),
        ],
      ),
    );
  }
  
  Future<bool> _checkAssetExists(BuildContext context, FocusSoundType type) async {
    try {
      // Try to load the asset manifest or just the asset
      await DefaultAssetBundle.of(context).load(type.assetPath);
      return true;
    } catch (_) {
      return false;
    }
  }
}

class _SoundOption extends StatelessWidget {
  final FocusSoundType type;
  final bool isSelected;
  final String label;
  final VoidCallback onTap;

  const _SoundOption({
    required this.type,
    required this.isSelected,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isSelected 
        ? (isDark ? Colors.white : Colors.black)
        : (isDark ? Colors.grey[800] : Colors.grey[200]);
    final textColor = isSelected
        ? (isDark ? Colors.black : Colors.white)
        : (isDark ? Colors.grey[400] : Colors.black);

    IconData icon;
    switch (type) {
      case FocusSoundType.none: icon = CupertinoIcons.speaker_slash; break;
      case FocusSoundType.rain: icon = CupertinoIcons.cloud_rain; break;
      case FocusSoundType.fire: icon = CupertinoIcons.flame; break;
      case FocusSoundType.forest: icon = CupertinoIcons.tree; break;
      case FocusSoundType.stream: icon = CupertinoIcons.drop; break;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: textColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
