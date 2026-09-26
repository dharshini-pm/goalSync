import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';

/// Step 3: Current Financial Position - Collects savings, fixed expenses,
/// variable expenses, existing loan EMIs, and active loans count.
class StepFinancialPosition extends StatelessWidget {
  final TextEditingController savingsController;
  final TextEditingController fixedExpensesController;
  final TextEditingController variableExpensesController;
  final TextEditingController loanEmiController;
  final TextEditingController activeLoansController;

  final String? savingsError;
  final String? fixedExpensesError;
  final String? variableExpensesError;
  final String? loanEmiError;
  final String? activeLoansError;

  const StepFinancialPosition({
    super.key,
    required this.savingsController,
    required this.fixedExpensesController,
    required this.variableExpensesController,
    required this.loanEmiController,
    required this.activeLoansController,
    this.savingsError,
    this.fixedExpensesError,
    this.variableExpensesError,
    this.loanEmiError,
    this.activeLoansError,
  });

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
            'Current financial position',
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
            'These balances help GoalSync monitor safety buffers, determine debt load, and identify conflicts.',
            style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: AppDimensions.space24),

          // 1. Current Savings
          _buildFieldLabel('Current Total Savings', isDark, isRequired: true),
          const SizedBox(height: AppDimensions.space4),
          Text(
            'Liquid bank accounts, fixed deposits, emergency funds (₹0 if none).',
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: AppDimensions.space6),
          TextFormField(
            controller: savingsController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            decoration: _inputDecoration(
              hintText: 'e.g. 250000',
              prefixText: '₹ ',
              prefixIcon: Icons.savings_outlined,
              isDark: isDark,
              errorText: savingsError,
            ),
          ),
          const SizedBox(height: AppDimensions.space20),

          // 2. Monthly Fixed Expenses
          _buildFieldLabel(
            'Monthly Fixed Obligations',
            isDark,
            isRequired: true,
          ),
          const SizedBox(height: AppDimensions.space4),
          Text(
            'Rent, electricity, insurance, maintenance, subscriptions, school fees.',
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: AppDimensions.space6),
          TextFormField(
            controller: fixedExpensesController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            decoration: _inputDecoration(
              hintText: 'e.g. 35000',
              prefixText: '₹ ',
              prefixIcon: Icons.receipt_outlined,
              isDark: isDark,
              errorText: fixedExpensesError,
            ),
          ),
          const SizedBox(height: AppDimensions.space20),

          // 3. Monthly Variable Expenses
          _buildFieldLabel(
            'Monthly Variable Expenses',
            isDark,
            isRequired: true,
          ),
          const SizedBox(height: AppDimensions.space4),
          Text(
            'Groceries, dining out, leisure, shopping, personal care, travel.',
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: AppDimensions.space6),
          TextFormField(
            controller: variableExpensesController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            decoration: _inputDecoration(
              hintText: 'e.g. 20000',
              prefixText: '₹ ',
              prefixIcon: Icons.shopping_bag_outlined,
              isDark: isDark,
              errorText: variableExpensesError,
            ),
          ),
          const SizedBox(height: AppDimensions.space20),

          // 4. Existing Loan / EMI Amount
          _buildFieldLabel(
            'Total Monthly Loan EMIs',
            isDark,
            isRequired: true,
          ),
          const SizedBox(height: AppDimensions.space4),
          Text(
            'Home loan, auto loan, education, credit card EMI (enter 0 if no debt).',
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: AppDimensions.space6),
          TextFormField(
            controller: loanEmiController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            decoration: _inputDecoration(
              hintText: 'e.g. 15000 (or 0)',
              prefixText: '₹ ',
              prefixIcon: Icons.credit_card_outlined,
              isDark: isDark,
              errorText: loanEmiError,
            ),
          ),
          const SizedBox(height: AppDimensions.space20),

          // 5. Number of Active Loans
          _buildFieldLabel(
            'Number of Active Loans',
            isDark,
            isRequired: true,
          ),
          const SizedBox(height: AppDimensions.space4),
          Text(
            'Count of active loan accounts currently open (enter 0 if none).',
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: AppDimensions.space6),
          TextFormField(
            controller: activeLoansController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(2),
            ],
            decoration: _inputDecoration(
              hintText: 'e.g. 1 (or 0)',
              prefixIcon: Icons.format_list_numbered_rounded,
              isDark: isDark,
              errorText: activeLoansError,
            ),
          ),
          const SizedBox(height: AppDimensions.space24),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label, bool isDark, {bool isRequired = false}) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color:
                isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
        if (isRequired)
          const Text(
            ' *',
            style: TextStyle(
              color: AppColors.electricCyan,
              fontWeight: FontWeight.w800,
            ),
          ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData prefixIcon,
    String? prefixText,
    required bool isDark,
    String? errorText,
  }) {
    return InputDecoration(
      hintText: hintText,
      errorText: errorText,
      prefixText: prefixText,
      prefixStyle: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 14,
        color: isDark ? AppColors.electricCyan : AppColors.deepNavy,
      ),
      prefixIcon: Icon(
        prefixIcon,
        size: 20,
        color: isDark
            ? AppColors.textSecondaryDark
            : AppColors.textSecondaryLight,
      ),
      filled: true,
      fillColor:
          isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        borderSide: BorderSide(
          color: isDark ? AppColors.navyBorder : const Color(0xFFD6E4F0),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        borderSide: BorderSide(
          color: isDark ? AppColors.navyBorder : const Color(0xFFD6E4F0),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        borderSide: const BorderSide(
          color: AppColors.electricCyan,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        borderSide: const BorderSide(
          color: AppColors.error,
          width: 1.2,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        borderSide: const BorderSide(
          color: AppColors.error,
          width: 1.5,
        ),
      ),
    );
  }
}
