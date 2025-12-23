import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// A widget that loads an image and removes white background by making white pixels transparent.
/// Uses pixel-level manipulation instead of ColorFilter for better device compatibility.
class TransparentWhiteImage extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  /// Threshold for considering a pixel as "white" (0-255). Default is 250.
  final int whiteThreshold;

  const TransparentWhiteImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.placeholder,
    this.errorWidget,
    this.whiteThreshold = 245,
  });

  @override
  State<TransparentWhiteImage> createState() => _TransparentWhiteImageState();
}

class _TransparentWhiteImageState extends State<TransparentWhiteImage> {
  ui.Image? _processedImage;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadAndProcessImage();
  }

  @override
  void didUpdateWidget(TransparentWhiteImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _loadAndProcessImage();
    }
  }

  Future<void> _loadAndProcessImage() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // Download image
      final response = await http.get(Uri.parse(widget.imageUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to load image');
      }

      // Decode image
      final codec = await ui.instantiateImageCodec(response.bodyBytes);
      final frame = await codec.getNextFrame();
      final originalImage = frame.image;

      // Get pixel data
      final byteData = await originalImage.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) {
        throw Exception('Failed to get image data');
      }

      // Process pixels - make white pixels transparent
      final pixels = byteData.buffer.asUint8List();
      for (int i = 0; i < pixels.length; i += 4) {
        final r = pixels[i];
        final g = pixels[i + 1];
        final b = pixels[i + 2];
        // final a = pixels[i + 3]; // Original alpha

        // Check if pixel is white (or near-white)
        if (r >= widget.whiteThreshold && 
            g >= widget.whiteThreshold && 
            b >= widget.whiteThreshold) {
          // Make it transparent
          pixels[i + 3] = 0;
        }
      }

      // Create new image from processed pixels
      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        pixels,
        originalImage.width,
        originalImage.height,
        ui.PixelFormat.rgba8888,
        completer.complete,
      );

      final processedImage = await completer.future;
      
      if (mounted) {
        setState(() {
          _processedImage = processedImage;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.placeholder ?? const SizedBox();
    }

    if (_hasError || _processedImage == null) {
      return widget.errorWidget ?? const Icon(Icons.error_outline);
    }

    return CustomPaint(
      size: Size(widget.width ?? _processedImage!.width.toDouble(), 
                 widget.height ?? _processedImage!.height.toDouble()),
      painter: _ImagePainter(_processedImage!, widget.fit),
    );
  }

  @override
  void dispose() {
    _processedImage?.dispose();
    super.dispose();
  }
}

class _ImagePainter extends CustomPainter {
  final ui.Image image;
  final BoxFit fit;

  _ImagePainter(this.image, this.fit);

  @override
  void paint(Canvas canvas, Size size) {
    final srcRect = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    
    // Calculate destination rect based on BoxFit
    final dstRect = _calculateDstRect(srcRect, size);
    
    canvas.drawImageRect(image, srcRect, dstRect, Paint());
  }

  Rect _calculateDstRect(Rect src, Size size) {
    switch (fit) {
      case BoxFit.contain:
        final scale = (size.width / src.width).clamp(0.0, size.height / src.height);
        final scaledWidth = src.width * scale;
        final scaledHeight = src.height * scale;
        return Rect.fromLTWH(
          (size.width - scaledWidth) / 2,
          (size.height - scaledHeight) / 2,
          scaledWidth,
          scaledHeight,
        );
      case BoxFit.cover:
        final scale = (size.width / src.width).clamp(size.height / src.height, double.infinity);
        final scaledWidth = src.width * scale;
        final scaledHeight = src.height * scale;
        return Rect.fromLTWH(
          (size.width - scaledWidth) / 2,
          (size.height - scaledHeight) / 2,
          scaledWidth,
          scaledHeight,
        );
      case BoxFit.fill:
        return Rect.fromLTWH(0, 0, size.width, size.height);
      default:
        return Rect.fromLTWH(0, 0, size.width, size.height);
    }
  }

  @override
  bool shouldRepaint(covariant _ImagePainter oldDelegate) {
    return image != oldDelegate.image;
  }
}
