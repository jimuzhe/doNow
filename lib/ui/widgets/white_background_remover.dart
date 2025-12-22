import 'package:flutter/material.dart';

/// A widget that applies a ColorFilter to remove white background from an image.
/// It treats brightness as alpha (inverted).
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

    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        1, 0, 0, 0, 0,
        0, 1, 0, 0, 0,
        0, 0, 1, 0, 0,
        -0.33, -0.33, -0.33, 1, 1, // Subtract RGB from Alpha. White (1,1,1,1) -> (1,1,1,0)
      ]),
      child: child,
    );
  }
}
