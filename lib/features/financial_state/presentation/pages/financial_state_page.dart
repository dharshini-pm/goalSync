import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../auth/services/auth_service.dart';
import '../../../goals/services/goal_service.dart';
import '../../../onboarding/models/financial_profile_model.dart';
import '../../../onboarding/presentation/pages/financial_onboarding_page.dart';
import '../../../onboarding/services/financial_profile_service.dart';
import '../widgets/expense_breakdown_chart.dart';
import '../widgets/financial_stat_card.dart';
import '../widgets/goal_commitment_row.dart';

/// Full Financial State page opened from the Dashboard card.
class FinancialStatePage extends StatefulWidget {
  const FinancialStatePage({super.key});

  @override
  State<FinancialStatePage> createState() => _FinancialStatePageState();
}

class _FinancialStatePageState extends State<FinancialStatePage> {
  @override
  void initState() {
    super.initState();
    FinancialProfileService.instance.addListener(_refresh);
    GoalService.instance.addListener(_refresh);
  }

  @override
  void dispose() {
    FinancialProfileService.instance.removeListener(_refresh);
    GoalService.instance.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userId = AuthService.instance.currentUser?.id;
    final profile = FinancialProfileService.instance.getProfile(userId);
    final isOnboarded =
        FinancialProfileService.instance.isOnboardingCompleted(userId);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text(
          'Financial State',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor:
            isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
      ),
      body: isOnboarded && profile != null
          ? _FinancialStateBody(profile: profile, isDark: isDark, userId: userId ?? '')
          : _EmptyFinancialState(isDark: isDark),
    );
  }
}

class _EmptyFinancialState extends StatelessWidget {
  final bool isDark;
  const _EmptyFinancialState({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.space32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppColors.gradientAccent,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.electricCyan.withAlpha(60),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                size: 40,
                color: AppColors.deepNavy,
              ),
            ),
            const SizedBox(height: AppDimensions.space24),
            Text(
              'No Financial Data Yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: AppDimensions.space12),
            Text(
              'Complete your financial profile to see a real-time summary of your income, expenses, and savings.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: AppDimensions.space32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const FinancialOnboardingPage(),
                  ),
                ),
                icon: const Icon(Icons.add_link_rounded, size: 18),
                label: const Text('Set Up Financial Profile'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.electricCyan,
                  foregroundColor: AppColors.deepNavy,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinancialStateBody extends StatelessWidget {
  final FinancialProfile profile;
  final bool isDark;
  final String userId;

  const _FinancialStateBody({
    required this.profile,
    required this.isDark,
    required this.userId,
  });

  String _fmt(double v) {
    if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(2)}Cr';
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(2)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}K';
    return '₹${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final goals = GoalService.instance.getGoalsForUser(userId);
    final surplus = profile.totalMonthlyIncome - profile.totalMonthlyExpenses;
    final isSurplus = surplus >= 0;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.pagePaddingH,
          vertical: AppDimensions.space20,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionHeader(label: 'FINANCIAL OVERVIEW', isDark: isDark),
                const SizedBox(height: AppDimensions.space12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: AppDimensions.space12,
                  mainAxisSpacing: AppDimensions.space12,
                  childAspectRatio: 1.6,
                  children: [
                    FinancialStatCard(
                      label: 'Monthly Income',
                      value: _fmt(profile.totalMonthlyIncome),
                      icon: Icons.trending_up_rounded,
                      color: AppColors.mint,
                      isDark: isDark,
                    ),
                    FinancialStatCard(
                      label: 'Monthly Outflow',
                      value: _fmt(profile.totalMonthlyExpenses),
                      icon: Icons.trending_down_rounded,
                      color: AppColors.error,
                      isDark: isDark,
                    ),
                    FinancialStatCard(
                      label: 'Monthly Surplus',
                      value: _fmt(surplus.abs()),
                      valuePrefix: isSurplus ? '+' : '-',
                      icon: isSurplus
                          ? Icons.savings_rounded
                          : Icons.warning_rounded,
                      color: isSurplus ? AppColors.electricCyan : AppColors.warning,
                      isDark: isDark,
                    ),
                    FinancialStatCard(
                      label: 'Current Savings',
                      value: _fmt(profile.currentSavings),
                      icon: Icons.account_balance_rounded,
                      color: AppColors.electricCyan,
                      isDark: isDark,
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.space24),
                _SectionHeader(label: 'EXPENSE BREAKDOWN', isDark: isDark),
                const SizedBox(height: AppDimensions.space12),
                _Card(
                  isDark: isDark,
                  child: Column(
                    children: [
                      ExpenseBreakdownChart(
                        fixedExpenses: profile.monthlyFixedExpenses,
                        variableExpenses: profile.monthlyVariableExpenses,
                        loanEmi: profile.existingLoanEmi,
                        isDark: isDark,
                      ),
                      const SizedBox(height: AppDimensions.space16),
                      _ExpenseRow(
                        label: 'Fixed Expenses',
                        value: _fmt(profile.monthlyFixedExpenses),
                        color: AppColors.electricCyan,
                        isDark: isDark,
                      ),
                      const Divider(height: AppDimensions.space16),
                      _ExpenseRow(
                        label: 'Variable Expenses',
                        value: _fmt(profile.monthlyVariableExpenses),
                        color: AppColors.warning,
                        isDark: isDark,
                      ),
                      const Divider(height: AppDimensions.space16),
                      _ExpenseRow(
                        label: 'Loan / EMI',
                        value: _fmt(profile.existingLoanEmi),
                        color: AppColors.error,
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.space24),
                _SectionHeader(label: 'FINANCIAL SUMMARY', isDark: isDark),
                const SizedBox(height: AppDimensions.space12),
                _Card(
                  isDark: isDark,
                  child: Column(
                    children: [
                      _SummaryRow(
                        label: 'Total Monthly Income',
                        value: _fmt(profile.totalMonthlyIncome),
                        isDark: isDark,
                        valueColor: AppColors.mint,
                      ),
                      const Divider(height: AppDimensions.space16),
                      _SummaryRow(
                        label: 'Total Monthly Expenses',
                        value: _fmt(profile.totalMonthlyExpenses),
                        isDark: isDark,
                        valueColor: AppColors.error,
                      ),
                      const Divider(height: AppDimensions.space16),
                      _SummaryRow(
                        label: isSurplus ? 'Monthly Surplus' : 'Monthly Deficit',
                        value: '${isSurplus ? "+" : "-"}${_fmt(surplus.abs())}',
                        isDark: isDark,
                        valueColor:
                            isSurplus ? AppColors.electricCyan : AppColors.warning,
                        bold: true,
                      ),
                      const Divider(height: AppDimensions.space16),
                      _SummaryRow(
                        label: 'Current Savings',
                        value: _fmt(profile.currentSavings),
                        isDark: isDark,
                        valueColor: AppColors.electricCyan,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.space24),
                _SectionHeader(label: 'GOAL COMMITMENTS', isDark: isDark),
                const SizedBox(height: AppDimensions.space12),
                if (goals.isEmpty)
                  _Card(
                    isDark: isDark,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: AppDimensions.space8),
                      child: Text(
                        'No goals created yet. Add goals from the Goals tab.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ),
                  )
                else
                  _Card(
                    isDark: isDark,
                    child: Column(
                      children: goals
                          .asMap()
                          .entries
                          .map(
                            (entry) => Column(
                              children: [
                                GoalCommitmentRow(
                                    goal: entry.value, isDark: isDark),
                                if (entry.key < goals.length - 1)
                                  const Divider(height: AppDimensions.space16),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ),
                const SizedBox(height: AppDimensions.space32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final bool isDark;
  const _SectionHeader({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: AppColors.gradientAccent,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final bool isDark;
  const _Card({required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) {
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
      child: child,
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDark;
  const _ExpenseRow({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
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
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  final Color? valueColor;
  final bool bold;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.isDark,
    this.valueColor,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
            color: valueColor ??
                (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
          ),
        ),
      ],
    );
  }
}
