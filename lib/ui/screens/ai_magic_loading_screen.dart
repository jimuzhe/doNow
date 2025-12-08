import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers.dart';
import '../../data/localization.dart';
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
  int _loadingStage = 0;

  final List<String> _loadingStagesEn = [
    "Analyzing task...",
    "Breaking down structure...",
    "Calculating optimal steps...",
    "Finalizing atomic steps...",
  ];
  
  final List<String> _loadingStagesZh = [
    "正在分析任务...",
    "正在拆解结构...",
    "计算最优步骤...",
    "生成原子任务...",
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _startGeneration();
    _animateLoadingText();
  }

  void _animateLoadingText() {
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _loadingStage = 1);
    });
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _loadingStage = 2);
    });
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted) setState(() => _loadingStage = 3);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startGeneration() async {
    try {
      // Actual API Call
      final repository = ref.read(taskRepositoryProvider);
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
    final locale = ref.watch(localeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenSize = MediaQuery.of(context).size;
    
    final loadingStages = locale == 'zh' ? _loadingStagesZh : _loadingStagesEn;
    final currentText = loadingStages[_loadingStage.clamp(0, loadingStages.length - 1)];

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: Container(
        width: screenSize.width,
        height: screenSize.height,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
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
                          color: (isDark ? Colors.white : Colors.black).withOpacity(0.05 + (_controller.value * 0.1)),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: (isDark ? Colors.white : Colors.black).withOpacity(0.1 + (_controller.value * 0.4)),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.auto_awesome, 
                            size: 40, 
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 48),
                  
                  // Task Title
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Loading Text with Animation
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      currentText,
                      key: ValueKey<int>(_loadingStage),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.2,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 48),
                  
                  // Progress Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      final isActive = index <= _loadingStage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive 
                            ? (isDark ? Colors.white : Colors.black)
                            : (isDark ? Colors.grey[800] : Colors.grey[300]),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
