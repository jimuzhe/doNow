import 'package:flutter/material.dart';

/// Alternative white background remover using ShaderMask instead of ColorFilter.
/// This may have better compatibility on some devices.
class WhiteBgRemoverV2 extends StatelessWidget {
  final Widget child;
  final bool enabled;

  const WhiteBgRemoverV2({
    super.key,
    required this.child,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    // Use ShaderMask with a simpler blend mode
    // This treats the luminance of the image as its alpha channel
    return ShaderMask(
      shaderCallback: (Rect bounds) {
        // A simple gradient that covers the entire area
        return const LinearGradient(
          colors: [Colors.white, Colors.white],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn, // Use destination in: shows image where mask is opaque
      child: ColorFiltered(
        // Invert colors so dark parts become light (opaque in mask)
        // and light parts become dark (transparent in mask)
        colorFilter: const ColorFilter.matrix(<double>[
          -1, 0, 0, 0, 255,
          0, -1, 0, 0, 255,
          0, 0, -1, 0, 255,
          0, 0, 0, 1, 0,
        ]),
        child: child,
      ),
    );
  }
}
