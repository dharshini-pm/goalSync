import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../auth/services/auth_service.dart';
import '../../models/goal_model.dart';
import '../../services/goal_service.dart';
import '../widgets/goal_progress_bar.dart';
import 'create_goal_page.dart';

/// Detail view for a single goal with edit and delete actions.
class GoalDetailPage extends StatefulWidget {
  final GoalModel goal;

  const GoalDetailPage({super.key, required this.goal});

  @override
  State<GoalDetailPage> createState() => _GoalDetailPageState();
}

class _GoalDetailPageState extends State<GoalDetailPage> {
  late GoalModel _goal;

  @override
  void initState() {
    super.initState();
    _goal = widget.goal;
    GoalService.instance.addListener(_onGoalsChanged);
  }

  @override
  void dispose() {
    GoalService.instance.removeListener(_onGoalsChanged);
    super.dispose();
  }

  void _onGoalsChanged() {
    final userId = AuthService.instance.currentUser?.id ?? '';
    final updated = GoalService.instance
        .getGoalsForUser(userId)
        .where((g) => g.id == _goal.id)
        .firstOrNull;
    if (updated != null && mounted) {
      setState(() => _goal = updated);
    }
  }

  Future<void> _editGoal() async {
    final result = await Navigator.of(context).push<GoalModel>(
      MaterialPageRoute(
        builder: (_) => CreateGoalPage(existingGoal: _goal),
      ),
    );
    if (result != null) {
      setState(() => _goal = result);
    }
  }

  Future<void> _confirmDelete() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        ),
        title: Text(
          'Delete Goal',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${_goal.name}"? This action cannot be undone.',
          style: TextStyle(
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              ),
            ),
            child: const Text('Delete',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final userId = AuthService.instance.currentUser?.id ?? '';
      await GoalService.instance
          .deleteGoal(userId: userId, goalId: _goal.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(
          _goal.name,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor:
            isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
        actions: [
          IconButton(
            onPressed: _editGoal,
            icon: const Icon(Icons.edit_rounded),
            tooltip: 'Edit Goal',
          ),
          IconButton(
            onPressed: _confirmDelete,
            icon: const Icon(Icons.delete_rounded),
            color: AppColors.error,
            tooltip: 'Delete Goal',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.pagePaddingH,
            vertical: AppDimensions.space20,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Hero Card ─────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(AppDimensions.space24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          isDark ? AppColors.navyLight : const Color(0xFFEFF5FB),
                          isDark ? AppColors.navyMid : const Color(0xFFF4F8FD),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                      border: Border.all(
                        color: AppColors.electricCyan.withAlpha(60),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Icon + Category
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.electricCyan.withAlpha(30),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _categoryIcon(_goal.category),
                            size: 36,
                            color: AppColors.electricCyan,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.space12),
                        Text(
                          _goal.name,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _goal.category.displayName,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.electricCyan,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.space20),

                        // Progress
                        GoalProgressBar(
                            fraction: _goal.progressFraction, height: 12),
                        const SizedBox(height: AppDimensions.space12),

                        // Progress % + Status
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_goal.progressPercentage} complete',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: _goal.isCompleted
                                    ? AppColors.mint
                                    : AppColors.electricCyan,
                              ),
                            ),
                            _StatusBadge(goal: _goal),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space20),

                  // ── Details Grid ──────────────────────────────
                  _DetailGrid(goal: _goal, isDark: isDark),
                  const SizedBox(height: AppDimensions.space20),

                  // ── Meta Info ─────────────────────────────────
                  _MetaCard(goal: _goal, isDark: isDark),
                  const SizedBox(height: AppDimensions.space24),

                  // ── Action Buttons ────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _editGoal,
                          icon: const Icon(Icons.edit_rounded, size: 16),
                          label: const Text('Edit Goal'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.electricCyan,
                            side: const BorderSide(
                                color: AppColors.electricCyan),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppDimensions.radiusMd),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            textStyle: const TextStyle(
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppDimensions.space12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _confirmDelete,
                          icon: const Icon(Icons.delete_rounded, size: 16),
                          label: const Text('Delete'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error.withAlpha(200),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppDimensions.radiusMd),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            textStyle: const TextStyle(
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.space24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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

class _StatusBadge extends StatelessWidget {
  final GoalModel goal;
  const _StatusBadge({required this.goal});

  Color get _color {
    if (goal.isCompleted) return AppColors.mint;
    if (goal.daysRemaining < 0) return AppColors.error;
    if (goal.daysRemaining <= 30) return AppColors.warning;
    return AppColors.electricCyan;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withAlpha(30),
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        border: Border.all(color: _color.withAlpha(100)),
      ),
      child: Text(
        goal.statusLabel,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _color,
        ),
      ),
    );
  }
}

class _DetailGrid extends StatelessWidget {
  final GoalModel goal;
  final bool isDark;
  const _DetailGrid({required this.goal, required this.isDark});

  String _formatAmount(double amount) {
    if (amount >= 10000000) {
      return '₹${(amount / 10000000).toStringAsFixed(2)}Cr';
    } else if (amount >= 100000) {
      return '₹${(amount / 100000).toStringAsFixed(2)}L';
    } else if (amount >= 1000) {
      return '₹${(amount / 1000).toStringAsFixed(2)}K';
    }
    return '₹${amount.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      _DetailItem(
        icon: Icons.savings_rounded,
        label: 'Target Amount',
        value: _formatAmount(goal.targetAmount),
        valueColor: AppColors.electricCyan,
      ),
      _DetailItem(
        icon: Icons.account_balance_wallet_rounded,
        label: 'Amount Saved',
        value: _formatAmount(goal.currentAmount),
        valueColor: AppColors.mint,
      ),
      _DetailItem(
        icon: Icons.remove_circle_outline_rounded,
        label: 'Remaining',
        value: _formatAmount(goal.remainingAmount),
        valueColor: goal.isCompleted ? AppColors.mint : AppColors.warning,
      ),
      _DetailItem(
        icon: Icons.calendar_today_rounded,
        label: 'Target Date',
        value: _formatDate(goal.targetDate),
        valueColor: isDark
            ? AppColors.textPrimaryDark
            : AppColors.textPrimaryLight,
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppDimensions.space12,
      mainAxisSpacing: AppDimensions.space12,
      childAspectRatio: 2.0,
      children: items.map((item) => _buildDetailTile(item)).toList(),
    );
  }

  Widget _buildDetailTile(_DetailItem item) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(
          color: isDark ? AppColors.navyBorder : const Color(0xFFD6E4F0),
        ),
      ),
      child: Row(
        children: [
          Icon(item.icon, size: 16, color: item.valueColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: item.valueColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}

class _DetailItem {
  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;

  const _DetailItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
  });
}

class _MetaCard extends StatelessWidget {
  final GoalModel goal;
  final bool isDark;
  const _MetaCard({required this.goal, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(
          color: isDark ? AppColors.navyBorder : const Color(0xFFD6E4F0),
        ),
      ),
      child: Column(
        children: [
          _MetaRow(
            label: 'Priority',
            value: goal.priority.displayName,
            icon: Icons.flag_rounded,
            isDark: isDark,
            valueColor: _priorityColor(goal.priority),
          ),
          const Divider(height: 20),
          _MetaRow(
            label: 'Created',
            value: _formatDateTime(goal.createdAt),
            icon: Icons.add_circle_outline_rounded,
            isDark: isDark,
          ),
          const Divider(height: 20),
          _MetaRow(
            label: 'Last Updated',
            value: _formatDateTime(goal.updatedAt),
            icon: Icons.update_rounded,
            isDark: isDark,
          ),
          if (!goal.isCompleted && goal.daysRemaining >= 0) ...[
            const Divider(height: 20),
            _MetaRow(
              label: 'Days Remaining',
              value: '${goal.daysRemaining} days',
              icon: Icons.timer_outlined,
              isDark: isDark,
            ),
          ],
        ],
      ),
    );
  }

  Color _priorityColor(GoalPriority p) {
    switch (p) {
      case GoalPriority.essential:
        return AppColors.error;
      case GoalPriority.important:
        return AppColors.warning;
      case GoalPriority.flexible:
        return AppColors.mint;
    }
  }

  String _formatDateTime(DateTime dt) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isDark;
  final Color? valueColor;

  const _MetaRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.isDark,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: valueColor ??
                (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
          ),
        ),
      ],
    );
  }
}
