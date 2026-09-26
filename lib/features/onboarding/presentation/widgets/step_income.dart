import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';

/// Step 2: Income - Collects monthly primary income, income type, and additional income.
class StepIncome extends StatelessWidget {
  final TextEditingController monthlyIncomeController;
  final String selectedIncomeType;
  final TextEditingController additionalIncomeController;
  final String? monthlyIncomeError;
  final String? incomeTypeError;
  final ValueChanged<String> onIncomeTypeChanged;

  const StepIncome({
    super.key,
    required this.monthlyIncomeController,
    required this.selectedIncomeType,
    required this.additionalIncomeController,
    this.monthlyIncomeError,
    this.incomeTypeError,
    required this.onIncomeTypeChanged,
  });

  static const List<_IncomeTypeOption> _incomeTypes = [
    _IncomeTypeOption(
      type: 'Salary',
      icon: Icons.account_balance_rounded,
      description: 'Fixed regular monthly pay',
    ),
    _IncomeTypeOption(
      type: 'Business',
      icon: Icons.domain_rounded,
      description: 'Profits from enterprise or trade',
    ),
    _IncomeTypeOption(
      type: 'Freelance',
      icon: Icons.draw_rounded,
      description: 'Variable project-based earnings',
    ),
    _IncomeTypeOption(
      type: 'Other',
      icon: Icons.category_rounded,
      description: 'Investments, royalties, stipends',
    ),
  ];

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
            'Your monthly income',
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
            'GoalSync uses cash inflows to accurately measure liquidity and detect upcoming goal deficits.',
            style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: AppDimensions.space24),

          // 1. Primary Monthly Income
          _buildFieldLabel('Primary Monthly Inflow', isDark, isRequired: true),
          const SizedBox(height: AppDimensions.space6),
          TextFormField(
            controller: monthlyIncomeController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            decoration: _inputDecoration(
              hintText: 'e.g. 85000',
              prefixText: '₹ ',
              prefixIcon: Icons.payments_outlined,
              isDark: isDark,
              errorText: monthlyIncomeError,
            ),
          ),
          const SizedBox(height: AppDimensions.space20),

          // 2. Income Type
          _buildFieldLabel('Income Type', isDark, isRequired: true),
          const SizedBox(height: AppDimensions.space6),
          if (incomeTypeError != null) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                incomeTypeError!,
                style: const TextStyle(
                  color: AppColors.error,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],

          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.2,
            children: _incomeTypes.map((opt) {
              final isSelected = selectedIncomeType == opt.type;
              return InkWell(
                onTap: () => onIncomeTypeChanged(opt.type),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark
                            ? AppColors.navyMid
                            : const Color(0xFFF0F9FF))
                        : (isDark
                            ? AppColors.darkSurface
                            : AppColors.lightSurface),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.electricCyan
                          : (isDark
                              ? AppColors.navyBorder
                              : const Color(0xFFD6E4F0)),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.electricCyan.withAlpha(30),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.electricCyan.withAlpha(40)
                              : (isDark
                                  ? AppColors.navyMid
                                  : AppColors.lightSurfaceVariant),
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radiusSm),
                        ),
                        child: Icon(
                          opt.icon,
                          size: 18,
                          color: isSelected
                              ? AppColors.electricCyan
                              : (isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              opt.type,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                              ),
                            ),
                            Text(
                              opt.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppDimensions.space24),

          // 3. Additional Monthly Income (Optional)
          _buildFieldLabel(
            'Additional Monthly Inflow (Optional)',
            isDark,
            isRequired: false,
          ),
          const SizedBox(height: AppDimensions.space4),
          Text(
            'Rental properties, investment dividends, royalties or secondary consulting.',
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: AppDimensions.space6),
          TextFormField(
            controller: additionalIncomeController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            decoration: _inputDecoration(
              hintText: 'e.g. 15000 (leave empty if none)',
              prefixText: '₹ ',
              prefixIcon: Icons.add_chart_rounded,
              isDark: isDark,
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

class _IncomeTypeOption {
  final String type;
  final IconData icon;
  final String description;

  const _IncomeTypeOption({
    required this.type,
    required this.icon,
    required this.description,
  });
}
