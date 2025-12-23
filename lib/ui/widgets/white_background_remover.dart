import 'package:flutter/material.dart';

/// A widget that applies a ColorFilter to remove white/light background from an image.
/// It treats high brightness as transparency.
class WhiteBackgroundRemover extends StatelessWidget {
  final Widget child;
  final bool enabled;

  const WhiteBackgroundRemover({
    super.key,
    required this.child,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    // Optimized matrix for background removal.
    // A' = 3*A - R - G - B
    // This formula ensures pure white (255,255,255,255) becomes transparent: 3*255 - 255 - 255 - 255 = 0
    // While solid colors like red (255,0,0,255) remain opaque: 3*255 - 255 - 0 - 0 = 510 -> clamped to 255
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        1, 0, 0, 0, 0,
        0, 1, 0, 0, 0,
        0, 0, 1, 0, 0,
        -1, -1, -1, 3, 0, 
      ]),
      child: child,
    );
  }
}
