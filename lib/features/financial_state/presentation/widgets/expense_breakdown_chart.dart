import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';

/// Visual breakdown of expense categories using proportional bars.
class ExpenseBreakdownChart extends StatefulWidget {
  final double fixedExpenses;
  final double variableExpenses;
  final double loanEmi;
  final bool isDark;

  const ExpenseBreakdownChart({
    super.key,
    required this.fixedExpenses,
    required this.variableExpenses,
    required this.loanEmi,
    required this.isDark,
  });

  @override
  State<ExpenseBreakdownChart> createState() => _ExpenseBreakdownChartState();
}

class _ExpenseBreakdownChartState extends State<ExpenseBreakdownChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total =
        widget.fixedExpenses + widget.variableExpenses + widget.loanEmi;

    if (total <= 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.space8),
        child: Text(
          'No expense data.',
          style: TextStyle(
            fontSize: 13,
            color: widget.isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
      );
    }

    final fixedFrac = widget.fixedExpenses / total;
    final varFrac = widget.variableExpenses / total;
    final loanFrac = widget.loanEmi / total;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final animated = _animation.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 16,
                child: Row(
                  children: [
                    if (fixedFrac > 0)
                      Flexible(
                        flex: (fixedFrac * animated * 1000).round().clamp(1, 100000),
                        child: Container(color: AppColors.electricCyan),
                      ),
                    if (varFrac > 0)
                      Flexible(
                        flex: (varFrac * animated * 1000).round().clamp(1, 100000),
                        child: Container(color: AppColors.warning),
                      ),
                    if (loanFrac > 0)
                      Flexible(
                        flex: (loanFrac * animated * 1000).round().clamp(1, 100000),
                        child: Container(color: AppColors.error),
                      ),
                    if (animated < 1.0)
                      Flexible(
                        flex: ((1 - animated) * 1000).round().clamp(1, 100000),
                        child: Container(
                          color: widget.isDark
                              ? AppColors.navyMid
                              : AppColors.lightSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.space12),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _LegendItem(
                    color: AppColors.electricCyan,
                    label:
                        'Fixed (${(fixedFrac * 100).toStringAsFixed(0)}%)'),
                _LegendItem(
                    color: AppColors.warning,
                    label:
                        'Variable (${(varFrac * 100).toStringAsFixed(0)}%)'),
                _LegendItem(
                    color: AppColors.error,
                    label:
                        'Loan/EMI (${(loanFrac * 100).toStringAsFixed(0)}%)'),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }
}
