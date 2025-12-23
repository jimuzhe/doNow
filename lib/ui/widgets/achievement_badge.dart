import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'white_background_remover.dart';

class AchievementBadge extends StatelessWidget {
  final String icon;
  final double size;
  final bool isUnlocked;
  final bool showBackground;
  final Color? backgroundColor;

  const AchievementBadge({
    super.key,
    required this.icon,
    this.size = 64,
    this.isUnlocked = true,
    this.showBackground = false, // Set to false by default
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cleanIcon = icon.trim();
    final isUrl = cleanIcon.startsWith('http');

    Widget iconWidget;
    if (isUrl) {
      final imageUrl = kIsWeb 
          ? 'https://corsproxy.io/?${Uri.encodeComponent(cleanIcon)}' 
          : cleanIcon;
      
      iconWidget = WhiteBackgroundRemover(
        enabled: true, // Always enable to ensure locked badges also have white backgrounds removed
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.contain,
          placeholder: (context, url) => Icon(
            Icons.emoji_events,
            size: size * 0.5,
            color: isDark ? Colors.white10 : Colors.grey[300],
          ),
          errorWidget: (context, url, error) => Icon(
            Icons.emoji_events,
            size: size * 0.5,
            color: Colors.amber[600],
          ),
        ),
      );
    } else {
      iconWidget = Center(
        child: Text(
          cleanIcon,
          style: TextStyle(fontSize: size * 0.6),
        ),
      );
    }

    if (!isUnlocked) {
      iconWidget = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0,      0,      0,      1, 0,
        ]),
        child: Opacity(
          opacity: 0.5,
          child: iconWidget,
        ),
      );
    }

    // No background, no border, just the natural image shape
    if (!showBackground) {
      return SizedBox(
        width: size,
        height: size,
        child: iconWidget,
      );
    }

    // Explicitly styled container only if showBackground is true
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.transparent,
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.08),
        child: iconWidget,
      ),
    );
  }
}
