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

    // Matrix that removes white and near-white backgrounds.
    // Formula for Alpha channel: A' = -1*R - 1*G - 1*B + 1*A + offset
    // 
    // Calculation for offset to make white transparent:
    // For white (255, 255, 255, 255): A' = -765 + 255 + offset = 0 → offset = 510
    //
    // Results:
    // - Pure white (255,255,255): A = -765 + 255 + 510 = 0 → fully transparent
    // - Near-white (250,250,250): A = -750 + 255 + 510 = 15 → almost transparent
    // - Light gray (240,240,240): A = -720 + 255 + 510 = 45 → mostly transparent
    // - Mid gray (128,128,128): A = -384 + 255 + 510 = 381 → clamped to 255, opaque
    // - Black (0,0,0): A = 0 + 255 + 510 = 765 → clamped to 255, fully opaque
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        1, 0, 0, 0, 0,
        0, 1, 0, 0, 0,
        0, 0, 1, 0, 0,
        -1, -1, -1, 1, 510, // offset = 510, makes white (255,255,255) transparent
      ]),
      child: child,
    );
  }
}
