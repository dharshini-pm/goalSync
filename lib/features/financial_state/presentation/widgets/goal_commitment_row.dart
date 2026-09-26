import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../goals/models/goal_model.dart';

/// Compact row showing a goal commitment inside Financial State page.
class GoalCommitmentRow extends StatelessWidget {
  final GoalModel goal;
  final bool isDark;

  const GoalCommitmentRow({super.key, required this.goal, required this.isDark});

  String _fmt(double v) {
    if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(2)}Cr';
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(2)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}K';
    return '₹${v.toStringAsFixed(0)}';
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                goal.name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.electricCyan.withAlpha(20),
                borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                border: Border.all(
                    color: AppColors.electricCyan.withAlpha(60)),
              ),
              child: Text(
                goal.category.displayName,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.electricCyan,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.space8),
        Row(
          children: [
            _AmountPill(
              label: 'Target',
              value: _fmt(goal.targetAmount),
              color: AppColors.electricCyan,
              isDark: isDark,
            ),
            const SizedBox(width: 8),
            _AmountPill(
              label: 'Saved',
              value: _fmt(goal.currentAmount),
              color: AppColors.mint,
              isDark: isDark,
            ),
            const SizedBox(width: 8),
            _AmountPill(
              label: 'Remaining',
              value: _fmt(goal.remainingAmount),
              color: AppColors.warning,
              isDark: isDark,
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.space8),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: goal.progressFraction,
                  backgroundColor: isDark
                      ? AppColors.navyMid
                      : AppColors.lightSurfaceVariant,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    goal.isCompleted ? AppColors.mint : AppColors.electricCyan,
                  ),
                  minHeight: 5,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              goal.progressPercentage,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: goal.isCompleted
                    ? AppColors.mint
                    : AppColors.electricCyan,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Target: ${_formatDate(goal.targetDate)}',
          style: TextStyle(
            fontSize: 11,
            color: isDark
                ? AppColors.textTertiaryDark
                : AppColors.textTertiaryLight,
          ),
        ),
      ],
    );
  }
}

class _AmountPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _AmountPill({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          border: Border.all(color: color.withAlpha(50)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                letterSpacing: 0.3,
                color: isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textTertiaryLight,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
