import 'dart:ui';
import 'package:flutter/material.dart';

class CustomDialog extends StatelessWidget {
  final String title;
  final String content;
  final List<Widget> actions;

  const CustomDialog({
    super.key, 
    required this.title, 
    required this.content, 
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return BackdropFilter(
       filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
       child: Dialog(
         elevation: 0,
         backgroundColor: Colors.transparent,
         insetPadding: const EdgeInsets.all(24),
         child: ConstrainedBox(
           constraints: const BoxConstraints(maxWidth: 340),
           child: Container(
             clipBehavior: Clip.hardEdge,
             padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
             decoration: BoxDecoration(
               color: isDark ? const Color(0xFF1C1C1E).withOpacity(0.98) : Colors.white.withOpacity(0.98),
               borderRadius: BorderRadius.circular(28),
             border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
             boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 24, offset: const Offset(0, 12))
             ]
           ),
           child: SingleChildScrollView(
             child: Column(
               mainAxisSize: MainAxisSize.min,
               children: [
               Text(title, style: TextStyle(
                  fontSize: 20, 
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                  letterSpacing: -0.5,
               ), textAlign: TextAlign.center),
               
               const SizedBox(height: 12),
               
               Text(content, style: TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: isDark ? Colors.white70 : Colors.grey[800]
               ), textAlign: TextAlign.center),
               
               const SizedBox(height: 24),
               
               // Adaptive Layout for Actions
               if (actions.length > 2)
                 Column(
                   crossAxisAlignment: CrossAxisAlignment.stretch,
                   children: actions.map((a) {
                     // Style tweaks for buttons if they are TextButtons
                     return Padding(
                       padding: const EdgeInsets.only(bottom: 8.0),
                       child: _styleActionButton(a, isDark),
                     );
                   }).toList(),
                 )
               else
                 Row(
                   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                   children: actions.map((a) => Expanded(child: _styleActionButton(a, isDark))).toList(),
                 ),
             ],
           ),
         ),
         ),
       ),
     ),
    );
  }

  Widget _styleActionButton(Widget original, bool isDark) {
    // If it's a TextButton, we can wrap it or style it. 
    // Here we just return it, trusting the caller provided styled buttons or simple TextButtons.
    // Ideally we would enforce a style here.
    return original; 
  }
}
