import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/task.dart';
import '../../data/providers.dart';
import '../../data/services/sound_effect_service.dart';
import '../../data/localization.dart';
import '../../utils/haptic_helper.dart';
import '../widgets/task_completion_sheet.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async'; // For StreamSubscription

class DecisionScreen extends ConsumerStatefulWidget {
  final String? initialText;
  const DecisionScreen({super.key, this.initialText});

  @override
  ConsumerState<DecisionScreen> createState() => _DecisionScreenState();
}

class _DecisionScreenState extends ConsumerState<DecisionScreen> with TickerProviderStateMixin {
  late AnimationController _rotateController;
  late Animation<double> _rotateAnimation;
  

  late Animation<double> _heightAnimation;
  late Animation<double> _scaleAnimation;
  
  int _flipCount = 0;
  bool _isFlipping = false;
  bool _showResult = false;
  String _resultText = ""; // yes (head) or no (tail)
  int _headsCount = 0;
  int _tailsCount = 0;
  
  // Confirmed decision text
  final TextEditingController _decisionController = TextEditingController();

  bool _landSoundPlayed = false;
  int _wobbleStage = 0;
  StreamSubscription? _accelerometerSubscription;
  DateTime _lastShakeTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    
    // Main Controller for the entire sequence (Toss -> Land -> Settle)
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000), 
    );

    _rotateController.addListener(() {
      // Trigger sound and haptic at impact point (now at 80% progress)
      final val = _rotateController.value;
      
      if (val >= 0.8 && !_landSoundPlayed) {
         _landSoundPlayed = true;
         ref.read(soundEffectServiceProvider).playCoinLand();
         HapticHelper(ref).heavyImpact();
      }
      
      // Wobble vibrations during settle phase (0.8 -> 1.0)
      if (val >= 0.85 && _wobbleStage < 1) {
         _wobbleStage = 1;
         HapticHelper(ref).lightImpact();
      } else if (val >= 0.90 && _wobbleStage < 2) {
         _wobbleStage = 2;
         HapticHelper(ref).lightImpact();
      } else if (val >= 0.95 && _wobbleStage < 3) {
         _wobbleStage = 3;
         HapticHelper(ref).selectionClick();
      }
    });

    _rotateController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isFlipping = false;
          _showResult = true;
          _flipCount++;
          
          final angle = _rotateAnimation.value;
          // Check result
          final isHeads = cos(angle) > 0;
          _resultText = isHeads ? "yes" : "no";
          if (isHeads) {
            _headsCount++;
          } else {
            _tailsCount++;
          }
        });
      }
    });

    // Initialize with dummy animations, will be rebuilt on flip
    _rotateAnimation = AlwaysStoppedAnimation(0);
    _heightAnimation = AlwaysStoppedAnimation(0);
    _scaleAnimation = AlwaysStoppedAnimation(1);

    // Precache images
    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(const AssetImage('assets/coin/yuan_head.png'), context);
      precacheImage(const AssetImage('assets/coin/yuan_tail.png'), context);
    });
    
    // Initialize text if provided
    if (widget.initialText != null) {
      _decisionController.text = widget.initialText!;
    }

    _initShakeDetection();
  }

  @override
  void dispose() {
    try {
      // Reset Busy UI logic
      ref.read(isBusyUIProvider.notifier).state = false;
    } catch (_) {}
    
    _accelerometerSubscription?.cancel();
    _rotateController.dispose();
    _decisionController.dispose();
    super.dispose();
  }

  void _initShakeDetection() {
    // Mark as Busy UI (prevents auto-navigation)
    Future.microtask(() => ref.read(isBusyUIProvider.notifier).state = true);
    
    _accelerometerSubscription = userAccelerometerEventStream().listen((event) {
      if (_isFlipping) return;
      
      // Check for moderate shake on X axis (Left/Right)
      // Threshold lowered to 12 (approx 1.2g) for easier triggering
      if (event.x.abs() > 12) {
        final now = DateTime.now();
        // 500ms debounce
        if (now.difference(_lastShakeTime).inMilliseconds > 500) {
          _lastShakeTime = now;
          _flipCoin();
        }
      }
    });
  }



  void _flipCoin() {
    if (_isFlipping) return;
    if (_flipCount >= 3) return;

    // Haptic Start
    HapticHelper(ref).mediumImpact();
    // Play Throw Sound immediately
    ref.read(soundEffectServiceProvider).playCoinThrow();

    setState(() {
      _isFlipping = true;
      _showResult = false;
      _landSoundPlayed = false;
      _wobbleStage = 0;
      
      // 1. Determine Outcome
      final isHeads = Random().nextBool();
      
      // 2. Calculate Base Rotation (Multiple of 2pi)
      // We want to land roughly flat, so exact multiples or multiples + pi.
      // 5 to 8 full spins.
      final spins = 5 + Random().nextInt(4); 
      double targetBase = spins * 2 * pi;
      if (!isHeads) targetBase += pi;

      _rotateController.reset();

      // --- Animation Configuration ---
      // Total Duration: 2000ms (Slower for drama)
      // Structure:
      // 0.0 -> 0.4: Rise (Fast)
      // 0.4 -> 0.6: Apex (Slow Motion)
      // 0.6 -> 0.8: Fall (Fast)
      // 0.8 -> 1.0: Settle (Bounce)

      // HEIGHT ANIMATION
      // Peak height at 0.5 (middle of slow motion)
      _heightAnimation = TweenSequence<double>([
        // Rise Fast
        TweenSequenceItem(
          tween: Tween(begin: 0.0, end: -300.0).chain(CurveTween(curve: Curves.easeOutQuart)), 
          weight: 40
        ),
        // Apex Slow Float (Up a bit more then starts down)
        TweenSequenceItem(
          tween: Tween(begin: -300.0, end: -300.0).chain(CurveTween(curve: Curves.linear)), 
          weight: 20
        ),
        // Fall Fast
        TweenSequenceItem(
          tween: Tween(begin: -300.0, end: 0.0).chain(CurveTween(curve: Curves.easeInQuart)), 
          weight: 20
        ),
        // Settle / Bounces
        TweenSequenceItem(
          tween: TweenSequence([
             TweenSequenceItem(tween: Tween(begin: 0.0, end: -40.0).chain(CurveTween(curve: Curves.easeOut)), weight: 40),
             TweenSequenceItem(tween: Tween(begin: -40.0, end: 0.0).chain(CurveTween(curve: Curves.bounceOut)), weight: 60),
          ]), 
          weight: 20
        ),
      ]).animate(_rotateController);

      // SCALE ANIMATION
      _scaleAnimation = TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.5), weight: 40), // Grow fast
        TweenSequenceItem(tween: Tween(begin: 1.5, end: 1.5), weight: 20), // Stay big at apex
        TweenSequenceItem(tween: Tween(begin: 1.5, end: 1.0), weight: 20), // Shrink fast
        TweenSequenceItem(tween: ConstantTween(1.0), weight: 20),
      ]).animate(_rotateController);

      // ROTATION ANIMATION
      // Calculates target rotations
      // We want distinct speed changes: Fast -> Slow (almost stop) -> Fast -> Settle
      
      // Calculate split targets
      // 40% progress = 40% rotations
      // 60% progress = 50% rotations (slow down)
      // 80% progress = 100% rotations
      
      final double rotAtApexStart = targetBase * 0.45;
      final double rotAtApexEnd = targetBase * 0.55;

      _rotateAnimation = TweenSequence<double>([
        // Rise: Fast Spin
        TweenSequenceItem(
          tween: Tween(begin: 0.0, end: rotAtApexStart).chain(CurveTween(curve: Curves.linear)), 
          weight: 40
        ),
        // Apex: Slow Spin (The "Matrix" moment)
        TweenSequenceItem(
          tween: Tween(begin: rotAtApexStart, end: rotAtApexEnd).chain(CurveTween(curve: Curves.linear)), 
          weight: 20
        ),
        // Fall: Fast Spin to End
        TweenSequenceItem(
          tween: Tween(begin: rotAtApexEnd, end: targetBase).chain(CurveTween(curve: Curves.easeIn)), 
          weight: 20
        ),
        // Wobble Phase
        TweenSequenceItem(
          tween: TweenSequence([
             TweenSequenceItem(tween: Tween(begin: targetBase, end: targetBase + 0.15), weight: 25),
             TweenSequenceItem(tween: Tween(begin: targetBase + 0.15, end: targetBase - 0.08), weight: 25),
             TweenSequenceItem(tween: Tween(begin: targetBase - 0.08, end: targetBase + 0.04), weight: 25),
             TweenSequenceItem(tween: Tween(begin: targetBase + 0.04, end: targetBase), weight: 25),
          ]).chain(CurveTween(curve: Curves.easeInOut)), 
          weight: 20
        ),
      ]).animate(_rotateController);
      
      _rotateController.forward();
    });
  }

  Future<void> _confirmDecision() async {
      final locale = ref.read(localeProvider);
      
      // Text logic removed as requested: no default text record


      final now = DateTime.now();
      
      String noteText = "";
      // Default text removed as requested


      final decisionTask = Task(
        id: const Uuid().v4(),
        title: _decisionController.text.trim().isEmpty 
            ? AppStrings.get('make_decision', locale) 
            : _decisionController.text,
        totalDuration: Duration.zero,
        scheduledStart: now,
        subTasks: [],
        isCompleted: true,
        isDecision: true,
        completedAt: now,
        journalNote: noteText,
      );
      
      final result = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => TaskCompletionSheet(
          task: decisionTask,
          actualDuration: Duration.zero,
        ),
      );
      
      if (result == true && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.get("decision_recorded", locale))),
        );
      }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = ref.watch(localeProvider);
    String t(String key) => AppStrings.get(key, locale);
    
    String titleText;
    if (_flipCount < 3) {
      if (_flipCount == 0) titleText = t('flip_coin');
      else titleText = "${t('flip_again')} (${3-_flipCount})";
    } else {
      titleText = t('final_advice');
    }
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(titleText),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
             // Counters
             Padding(
               padding: const EdgeInsets.symmetric(vertical: 8),
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   Column(
                     children: [
                       Text(t('coin_heads'), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                       Text('$_headsCount', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                     ],
                   ),
                   const SizedBox(width: 40),
                   Column(
                     children: [
                       Text(t('coin_tails'), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                       Text('$_tailsCount', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                     ],
                   ),
                 ],
               ),
             ),

             Padding(
               padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
               child: TextField(
                 controller: _decisionController,
                 style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark?Colors.white:Colors.black),
                 decoration: InputDecoration(
                   hintText: t('decision_hint'),
                   border: InputBorder.none,
                   hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5)),
                 ),
                 textAlign: TextAlign.center,
               ),
             ),
             
             Expanded(
               child: Center(
                 child: Stack(
                   alignment: Alignment.center,
                   children: [
                     GestureDetector(
                       onTap: () {
                         if (!_isFlipping) _flipCoin();
                       },
                       child: AnimatedBuilder(
                         animation: Listenable.merge([_rotateAnimation, _heightAnimation]),
                         builder: (context, child) {
                           final angle = _rotateAnimation.value;
                           // Logic to show Head or Tail
                           // Normalize angle to 0..2pi for easy checking, but Math.cos handles it.
                           // cos(0) = 1 (Head), cos(pi) = -1 (Tail).
                           final isHeads = cos(angle) > 0;
                           
                           return Transform(
                             alignment: Alignment.center,
                             transform: Matrix4.identity()
                               ..setEntry(3, 2, 0.001) // Perspective
                               ..translate(0.0, _heightAnimation.value, 0.0) // Moving up/down
                               ..scale(_scaleAnimation.value) // Scaling
                               ..rotateX(angle),
                             child: Container(
                               width: 200,
                               height: 200,
                               decoration: BoxDecoration(
                                 shape: BoxShape.circle,
                                 boxShadow: [
                                   BoxShadow(
                                     color: Colors.black.withOpacity(0.3),
                                     blurRadius: 20,
                                     offset: const Offset(0, 10),
                                   )
                                 ],
                               ),
                               child: isHeads 
                                 ? Transform.scale(
                                     scale: 1.1,
                                     child: Image.asset('assets/coin/yuan_head.png', fit: BoxFit.contain)
                                   )
                                 : Transform(
                                     // Rotate the tail image so it appears 'upright' relative to the coin's flip
                                     // Reverted to rotateX for up-down flip
                                     alignment: Alignment.center,
                                     transform: Matrix4.rotationX(pi), 
                                     child: Image.asset('assets/coin/yuan_tail.png', fit: BoxFit.contain)
                                   ),
                             ),
                           );
                         },
                       ),
                     ),
                   ],
                 ),
               ),
             ),
             
             Padding(
               padding: const EdgeInsets.all(32.0),
               child: Column(
                 children: [
                   if (_flipCount < 3)
                     SizedBox(
                       width: double.infinity,
                       height: 56,
                       child: ElevatedButton(
                         onPressed: _isFlipping ? null : _flipCoin,
                         style: ElevatedButton.styleFrom(
                           backgroundColor: isDark ? Colors.white : Colors.black,
                           foregroundColor: isDark ? Colors.black : Colors.white,
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                         ),
                         child: Text(_flipCount == 0 ? t('flip_coin') : t('flip_again')),
                       ),
                     ),
                     
                   const SizedBox(height: 16),
                   
                   if (_flipCount > 0 && _flipCount < 3)  
                     TextButton(
                       onPressed: _confirmDecision,
                       child: Text(t('decision_made'), style: const TextStyle(fontSize: 16)),
                     ),
                     
                   if (_flipCount == 3)
                     SizedBox(
                       width: double.infinity,
                       height: 56,
                       child: ElevatedButton(
                         onPressed: _confirmDecision,
                         style: ElevatedButton.styleFrom(
                           backgroundColor: Colors.green,
                           foregroundColor: Colors.white,
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                         ),
                         child: Text(t('accept_fate')),
                       ),
                     ),
                 ],
               ),
             )
          ],
        ),
      ),
    );
  }
}
