import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../models/goal_model.dart';
import 'goal_progress_bar.dart';

/// Compact card showing a goal summary in the Goals list.
class GoalCard extends StatelessWidget {
  final GoalModel goal;
  final VoidCallback onTap;

  const GoalCard({super.key, required this.goal, required this.onTap});

  Color _statusColor() {
    if (goal.isCompleted) return AppColors.mint;
    if (goal.daysRemaining < 0) return AppColors.error;
    if (goal.daysRemaining <= 30) return AppColors.warning;
    return AppColors.electricCyan;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = _statusColor();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppDimensions.space12),
        padding: const EdgeInsets.all(AppDimensions.space16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          border: Border.all(
            color: isDark ? AppColors.navyBorder : const Color(0xFFD6E4F0),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withAlpha(30)
                  : Colors.black.withAlpha(8),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.navyMid
                        : AppColors.lightSurfaceVariant,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  ),
                  child: Icon(
                    _categoryIcon(goal.category),
                    size: 20,
                    color: AppColors.electricCyan,
                  ),
                ),
                const SizedBox(width: AppDimensions.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        goal.category.displayName,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(30),
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusFull),
                    border: Border.all(color: statusColor.withAlpha(80)),
                  ),
                  child: Text(
                    goal.statusLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.space12),

            // Progress bar
            GoalProgressBar(fraction: goal.progressFraction),
            const SizedBox(height: AppDimensions.space8),

            // Amounts row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _amountLabel(
                  label: 'Saved',
                  value: _formatAmount(goal.currentAmount),
                  isDark: isDark,
                ),
                Text(
                  goal.progressPercentage,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: goal.isCompleted
                        ? AppColors.mint
                        : AppColors.electricCyan,
                  ),
                ),
                _amountLabel(
                  label: 'Target',
                  value: _formatAmount(goal.targetAmount),
                  isDark: isDark,
                  alignRight: true,
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.space8),

            // Remaining & date row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  goal.isCompleted
                      ? 'Goal achieved!'
                      : '${_formatAmount(goal.remainingAmount)} remaining',
                  style: TextStyle(
                    fontSize: 12,
                    color: goal.isCompleted
                        ? AppColors.mint
                        : isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                  ),
                ),
                Text(
                  _formatDate(goal.targetDate),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _amountLabel({
    required String label,
    required String value,
    required bool isDark,
    bool alignRight = false,
  }) {
    return Column(
      crossAxisAlignment:
          alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
            letterSpacing: 0.5,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
      ],
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 10000000) {
      return '${(amount / 10000000).toStringAsFixed(1)}Cr';
    } else if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(0);
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec',
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }

  IconData _categoryIcon(GoalCategory cat) {
    switch (cat) {
      case GoalCategory.education:
        return Icons.school_rounded;
      case GoalCategory.travel:
        return Icons.flight_rounded;
      case GoalCategory.vehicle:
        return Icons.directions_car_rounded;
      case GoalCategory.home:
        return Icons.home_rounded;
      case GoalCategory.emergencyFund:
        return Icons.shield_rounded;
      case GoalCategory.investment:
        return Icons.trending_up_rounded;
      case GoalCategory.personal:
        return Icons.star_rounded;
      case GoalCategory.other:
        return Icons.flag_rounded;
    }
  }
}
