import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/notification_service.dart';

class DynamicIslandSimulation extends ConsumerStatefulWidget {
  final Widget child;
  const DynamicIslandSimulation({super.key, required this.child});

  @override
  ConsumerState<DynamicIslandSimulation> createState() => _DynamicIslandSimulationState();
}

class _DynamicIslandSimulationState extends ConsumerState<DynamicIslandSimulation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _widthAnimation;
  late Animation<double> _heightAnimation;
  
  ActivityState? _currentState;
  bool _isVisible = false;
  bool _isExpanded = false; // For showing buttons

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _widthAnimation = Tween<double>(begin: 0, end: 220).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    
    _heightAnimation = Tween<double>(begin: 0, end: 40).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Listen to stream
    final service = ref.read(notificationServiceProvider);
    service.activityStream.listen((state) {
      if (mounted) {
        setState(() {
          _currentState = state;
          if (state.isActive && !_isVisible) {
            _isVisible = true;
            _controller.forward();
          } else if (!state.isActive && _isVisible) {
            _isVisible = false;
            _isExpanded = false;
            _controller.reverse();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child, // The main app content
        
        // The Simulated Dynamic Island
        if (_isVisible)
          Positioned(
            top: 11, // Standard notch area
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _toggleExpanded,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutBack,
                      width: _isExpanded ? 280 : _widthAnimation.value,
                      height: _isExpanded ? 80 : _heightAnimation.value,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(_isExpanded ? 24 : 20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _isExpanded 
                        ? _buildExpandedContent()
                        : _buildCompactContent(),
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCompactContent() {
    if (_widthAnimation.value < 100) return const SizedBox();
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
           // Left Icon/Progress
           SizedBox(
             width: 20, height: 20,
             child: CircularProgressIndicator(
               value: _currentState?.progress ?? 0,
               strokeWidth: 3,
               backgroundColor: Colors.grey[800],
               valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
             ),
           ),
           
           // Middle Text
           Expanded(
             child: Text(
               _currentState?.currentStep ?? "",
               textAlign: TextAlign.center,
               style: const TextStyle(
                 color: Colors.white,
                 fontSize: 10,
                 fontWeight: FontWeight.bold,
                 decoration: TextDecoration.none,
                 fontFamily: 'Roboto',
               ),
               overflow: TextOverflow.ellipsis,
             ),
           ),
           
           // Expand hint icon
           const Icon(Icons.expand_more, color: Colors.white54, size: 16),
        ],
      ),
    );
  }

  Widget _buildExpandedContent() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top: Step name and progress
          Row(
            children: [
              SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(
                  value: _currentState?.progress ?? 0,
                  strokeWidth: 3,
                  backgroundColor: Colors.grey[800],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _currentState?.currentStep ?? "",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.none,
                    fontFamily: 'Roboto',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          
          // Bottom: Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Cancel button
              _ActionButton(
                icon: Icons.close,
                label: "取消",
                color: Colors.red,
                onTap: () {
                  ref.read(notificationServiceProvider).triggerCancel();
                },
              ),
              
              // Complete button
              _ActionButton(
                icon: Icons.check,
                label: "完成",
                color: Colors.greenAccent,
                onTap: () {
                  ref.read(notificationServiceProvider).triggerComplete();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.none,
                fontFamily: 'Roboto',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

