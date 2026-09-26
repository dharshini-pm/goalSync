import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';

/// Step 4: Review - Displays comprehensive summary of entered data with
/// direct edit shortcuts to prior steps.
class StepReview extends StatelessWidget {
  final int age;
  final String occupation;
  final int dependents;
  final double monthlyIncome;
  final String incomeType;
  final double additionalIncome;
  final double currentSavings;
  final double monthlyFixedExpenses;
  final double monthlyVariableExpenses;
  final double existingLoanEmi;
  final int activeLoansCount;
  final ValueChanged<int> onEditStep;

  const StepReview({
    super.key,
    required this.age,
    required this.occupation,
    required this.dependents,
    required this.monthlyIncome,
    required this.incomeType,
    required this.additionalIncome,
    required this.currentSavings,
    required this.monthlyFixedExpenses,
    required this.monthlyVariableExpenses,
    required this.existingLoanEmi,
    required this.activeLoansCount,
    required this.onEditStep,
  });

  String _formatCurrency(double amount) {
    final intAmount = amount.toInt();
    // Indian currency comma separation or standard formatted string
    final str = intAmount.toString();
    if (str.length <= 3) return '₹$str';

    String lastThree = str.substring(str.length - 3);
    String remaining = str.substring(0, str.length - 3);
    RegExp exp = RegExp(r'\B(?=(\d{2})+(?!\d))');
    String formattedRemaining = remaining.replaceAll(exp, ',');
    return '₹$formattedRemaining,$lastThree';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Heading
          Text(
            'Review your profile',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: AppDimensions.space6),
          Text(
            'Verify your information before finishing setup. You can modify any section directly.',
            style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: AppDimensions.space20),

          // Card 1: About You
          _buildReviewCard(
            context: context,
            isDark: isDark,
            stepIndex: 0,
            title: 'About You',
            icon: Icons.person_outline_rounded,
            tagColor: AppColors.electricCyan,
            rows: [
              _buildRow('Age', '$age years', isDark),
              _buildRow('Occupation', occupation, isDark),
              _buildRow(
                'Dependents',
                dependents == 0 ? 'None (0)' : '$dependents family member(s)',
                isDark,
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.space16),

          // Card 2: Income
          _buildReviewCard(
            context: context,
            isDark: isDark,
            stepIndex: 1,
            title: 'Income',
            icon: Icons.trending_up_rounded,
            tagColor: AppColors.mint,
            rows: [
              _buildRow(
                'Primary Monthly Income',
                _formatCurrency(monthlyIncome),
                isDark,
                isHighlight: true,
              ),
              _buildRow('Income Type', incomeType, isDark),
              _buildRow(
                'Additional Monthly Income',
                additionalIncome > 0
                    ? _formatCurrency(additionalIncome)
                    : 'None (₹0)',
                isDark,
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.space16),

          // Card 3: Financial Position
          _buildReviewCard(
            context: context,
            isDark: isDark,
            stepIndex: 2,
            title: 'Current Financial Position',
            icon: Icons.account_balance_wallet_outlined,
            tagColor: const Color(0xFF64B5F6),
            rows: [
              _buildRow(
                'Total Savings',
                _formatCurrency(currentSavings),
                isDark,
                isHighlight: true,
              ),
              _buildRow(
                'Monthly Fixed Expenses',
                _formatCurrency(monthlyFixedExpenses),
                isDark,
              ),
              _buildRow(
                'Monthly Variable Expenses',
                _formatCurrency(monthlyVariableExpenses),
                isDark,
              ),
              _buildRow(
                'Monthly Loan EMIs',
                existingLoanEmi > 0
                    ? _formatCurrency(existingLoanEmi)
                    : 'None (₹0)',
                isDark,
              ),
              _buildRow(
                'Active Loans',
                activeLoansCount == 0 ? 'None (0)' : '$activeLoansCount loan(s)',
                isDark,
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.space20),

          // Privacy Note
          Container(
            padding: const EdgeInsets.all(AppDimensions.space16),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkSurfaceVariant.withAlpha(140)
                  : AppColors.lightSurfaceVariant.withAlpha(160),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              border: Border.all(
                color: isDark
                    ? AppColors.navyBorder.withAlpha(70)
                    : const Color(0xFFD6E4F0),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.shield_outlined,
                  size: 20,
                  color: AppColors.mint,
                ),
                const SizedBox(width: AppDimensions.space12),
                Expanded(
                  child: Text(
                    'Your financial baseline is securely persisted locally on your device. '
                    'GoalSync never shares your sensitive details.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.space24),
        ],
      ),
    );
  }

  Widget _buildReviewCard({
    required BuildContext context,
    required bool isDark,
    required int stepIndex,
    required String title,
    required IconData icon,
    required Color tagColor,
    required List<Widget> rows,
  }) {
    return Container(
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
          // Header with Edit button
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: tagColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                ),
                child: Icon(icon, size: 16, color: tagColor),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => onEditStep(stepIndex),
                icon: const Icon(Icons.edit_outlined, size: 14),
                label: const Text('Edit'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.electricCyan,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.space12),
          const Divider(height: 1),
          const SizedBox(height: AppDimensions.space8),

          // Items
          ...rows,
        ],
      ),
    );
  }

  Widget _buildRow(
    String label,
    String value,
    bool isDark, {
    bool isHighlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
              color: isHighlight
                  ? AppColors.electricCyan
                  : (isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight),
            ),
          ),
        ],
      ),
    );
  }
}
