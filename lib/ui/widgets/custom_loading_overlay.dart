import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/localization.dart';
import '../../data/providers.dart';

class CustomLoadingOverlay extends ConsumerStatefulWidget {
  final String? message;
  
  const CustomLoadingOverlay({super.key, this.message});

  @override
  ConsumerState<CustomLoadingOverlay> createState() => _CustomLoadingOverlayState();
}

class _CustomLoadingOverlayState extends ConsumerState<CustomLoadingOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late String _quote;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    // Be careful accessing localization in initState? No, define key here, resolve in build
    final random = Random().nextInt(3) + 1; 
    _quote = 'quote_$random';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.read(localeProvider);
    final quoteText = AppStrings.get(_quote, locale);

    return Scaffold(
      backgroundColor: Colors.white, // White background is less scary than black
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             AnimatedBuilder(
               animation: _controller,
               builder: (context, child) {
                 return Transform.scale(
                   scale: 0.95 + (_controller.value * 0.1),
                   child: child,
                 );
               },
               child: Container(
                 width: 120,
                 height: 120,
                 decoration: BoxDecoration(
                   color: Colors.black,
                   shape: BoxShape.circle,
                   boxShadow: [
                     BoxShadow(
                       color: Colors.black.withOpacity(0.2),
                       blurRadius: 20,
                       spreadRadius: 10 * _controller.value,
                     )
                   ],
                 ),
                 child: const Icon(Icons.auto_awesome, color: Colors.white, size: 48),
               ),
             ),
             const SizedBox(height: 48),
             Text(
               widget.message ?? "Loading...",
               style: const TextStyle(
                 color: Colors.black,
                 fontSize: 18, 
                 fontWeight: FontWeight.bold,
                 letterSpacing: 1.2
               ),
             ),
             const SizedBox(height: 16),
             Padding(
               padding: const EdgeInsets.symmetric(horizontal: 40),
               child: Text(
                 "\"$quoteText\"",
                 textAlign: TextAlign.center,
                 style: TextStyle(
                   color: Colors.grey[500],
                   fontSize: 14, 
                   fontStyle: FontStyle.italic,
                 ),
               ),
             )
          ],
        ),
      ),
    );
  }
}
