import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers.dart';
import 'task_detail_screen.dart';

class AIMagicLoadingScreen extends ConsumerStatefulWidget {
  final String title;
  final Duration duration;
  final DateTime startTime;

  const AIMagicLoadingScreen({
    super.key,
    required this.title,
    required this.duration,
    required this.startTime,
  });

  @override
  ConsumerState<AIMagicLoadingScreen> createState() => _AIMagicLoadingScreenState();
}

class _AIMagicLoadingScreenState extends ConsumerState<AIMagicLoadingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  String _loadingText = "Analyzing task...";

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _startGeneration();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startGeneration() async {
    try {
      // Show different text stages
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) setState(() => _loadingText = "Breaking down structure...");
      });
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (mounted) setState(() => _loadingText = "Finalizing atomic steps...");
      });

      // Actual API Call
      final repository = ref.read(taskRepositoryProvider);
      // Note: We use the notifier to call the method on the class
      final newTask = await repository.createTask(
        widget.title,
        widget.duration,
        widget.startTime,
      );

      if (mounted) {
        // Success! Replace this loading screen with the Detail Screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => TaskDetailScreen(task: newTask),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Go back on error
        Navigator.of(context).pop(); 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI Generation Failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Pulsing Animation
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.05 + (_controller.value * 0.1)),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.black.withOpacity(0.1 + (_controller.value * 0.4)),
                      width: 2,
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.auto_awesome, size: 40, color: Colors.black),
                  ),
                );
              },
            ),
            const SizedBox(height: 48),
            Text(
              _loadingText,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.2,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
