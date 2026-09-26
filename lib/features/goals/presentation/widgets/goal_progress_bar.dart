import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// Animated linear progress bar used on goal cards and detail screens.
class GoalProgressBar extends StatefulWidget {
  final double fraction;
  final Color? color;
  final double height;

  const GoalProgressBar({
    super.key,
    required this.fraction,
    this.color,
    this.height = 8,
  });

  @override
  State<GoalProgressBar> createState() => _GoalProgressBarState();
}

class _GoalProgressBarState extends State<GoalProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = Tween<double>(begin: 0, end: widget.fraction.clamp(0.0, 1.0))
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void didUpdateWidget(GoalProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fraction != widget.fraction) {
      _animation =
          Tween<double>(begin: _animation.value, end: widget.fraction.clamp(0.0, 1.0))
              .animate(
                  CurvedAnimation(parent: _controller, curve: Curves.easeOut));
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barColor = widget.color ??
        (widget.fraction >= 1.0 ? AppColors.mint : AppColors.electricCyan);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(widget.height),
          child: Stack(
            children: [
              // Background track
              Container(
                height: widget.height,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.navyMid : AppColors.lightSurfaceVariant,
                  borderRadius: BorderRadius.circular(widget.height),
                ),
              ),
              // Filled portion
              FractionallySizedBox(
                widthFactor: _animation.value,
                child: Container(
                  height: widget.height,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [barColor, barColor.withAlpha(200)],
                    ),
                    borderRadius: BorderRadius.circular(widget.height),
                    boxShadow: [
                      BoxShadow(
                        color: barColor.withAlpha(80),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
