import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../ai_copilot/presentation/pages/ai_copilot_page.dart';
import '../../../ai_copilot/services/ai_insights_service.dart';
import '../../../auth/services/auth_service.dart';
import '../../../financial_state/presentation/pages/financial_state_page.dart';
import '../../../goals/models/goal_model.dart';
import '../../../goals/presentation/pages/goals_page.dart';
import '../../../goals/services/goal_service.dart';
import '../../../onboarding/models/financial_profile_model.dart';
import '../../../onboarding/presentation/pages/financial_onboarding_page.dart';
import '../../../onboarding/services/financial_profile_service.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../../transactions/models/transaction_model.dart';
import '../../../transactions/presentation/pages/transaction_detail_page.dart';
import '../../../transactions/presentation/pages/transactions_page.dart';
import '../../../transactions/services/transaction_service.dart';


/// GoalSync Main Dashboard with 5-tab bottom navigation.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    GoalService.instance.init();
    FinancialProfileService.instance.init();
    TransactionService.instance.init();
    GoalService.instance.addListener(_refresh);
    FinancialProfileService.instance.addListener(_refresh);
    TransactionService.instance.addListener(_refresh);
    AiInsightsService.instance.addListener(_refresh);

    final userId = AuthService.instance.currentUser?.id;
    if (userId != null && userId.isNotEmpty) {
      GoalService.instance.fetchGoalsFromBackend(userId);
      FinancialProfileService.instance.fetchProfileFromBackend(userId);
      TransactionService.instance.fetchTransactionsFromBackend(userId);
      AiInsightsService.instance.refresh();
    }
  }

  @override
  void dispose() {
    GoalService.instance.removeListener(_refresh);
    FinancialProfileService.instance.removeListener(_refresh);
    TransactionService.instance.removeListener(_refresh);
    AiInsightsService.instance.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _HomeDashboardView(
            onNavigateToGoals: () => setState(() => _currentIndex = 1),
            onNavigateToTransactions: () => setState(() => _currentIndex = 2),
          ),
          const GoalsPage(),
          const TransactionsPage(),
          const AiCopilotPage(),
          const ProfilePage(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.navyBorder : const Color(0xFFD6E4F0),
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: AppColors.electricCyan,
          unselectedItemColor: isDark
              ? AppColors.textTertiaryDark
              : AppColors.textTertiaryLight,
          selectedLabelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.flag_outlined),
              activeIcon: Icon(Icons.flag_rounded),
              label: 'Goals',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long_rounded),
              label: 'Activity',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.auto_awesome_outlined),
              activeIcon: Icon(Icons.auto_awesome_rounded),
              label: 'AI',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Home tab body
// ─────────────────────────────────────────────────────────────
class _HomeDashboardView extends StatelessWidget {
  final VoidCallback onNavigateToGoals;
  final VoidCallback onNavigateToTransactions;

  const _HomeDashboardView({
    required this.onNavigateToGoals,
    required this.onNavigateToTransactions,
  });

  String _fmt(double v) {
    if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(2)}Cr';
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(2)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}K';
    return '₹${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = AuthService.instance.currentUser;
    final userName =
        user?.fullName.isNotEmpty == true ? user!.fullName : 'User';
    final userId = user?.id ?? '';
    final goals = GoalService.instance.getGoalsForUser(userId);
    final profile = FinancialProfileService.instance.getProfile(userId);
    final isOnboarded =
        FinancialProfileService.instance.isOnboardingCompleted(userId);
    final transactions =
        TransactionService.instance.getTransactionsForUser(userId);
    final insight = AiInsightsService.instance.latestInsight;
    final hasConflict = insight?.hasConflict ?? false;
    final conflicts = insight?.conflicts ?? [];

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
                // Top header
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: AppColors.gradientAccent),
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusSm),
                      ),
                      child: const Icon(Icons.hub_rounded,
                          size: 20, color: AppColors.deepNavy),
                    ),
                    const SizedBox(width: AppDimensions.space10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GoalSync',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                        Text(
                          'INTELLIGENCE DASHBOARD',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: AppColors.electricCyan,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.mintGlow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.mint.withAlpha(90)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded,
                              size: 12, color: AppColors.mint),
                          SizedBox(width: 4),
                          Text(
                            'ONLINE',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: AppColors.mint,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.space24),

                // Welcome card
                Container(
                  padding: const EdgeInsets.all(AppDimensions.space20),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurface
                        : AppColors.lightSurface,
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusLg),
                    border: Border.all(
                      color: isDark
                          ? AppColors.navyBorder
                          : const Color(0xFFD6E4F0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withAlpha(40)
                            : Colors.black.withAlpha(10),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back, $userName',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.space12),
                      const Divider(height: 1),
                      const SizedBox(height: AppDimensions.space12),
                      Wrap(
                        spacing: 16,
                        runSpacing: 10,
                        children: [
                          _profileChip(
                            icon: Icons.verified_user_outlined,
                            label: 'Account',
                            value: 'Personal Account',
                            isDark: isDark,
                          ),
                          _profileChip(
                            icon: Icons.phone_outlined,
                            label: 'Phone',
                            value: user?.fullPhoneNumber ?? 'Not set',
                            isDark: isDark,
                          ),
                          _profileChip(
                            icon: Icons.email_outlined,
                            label: 'Email',
                            value: user?.email ?? 'Not set',
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.space24),

                Text(
                  'FINANCIAL MODULES',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: AppDimensions.space12),

                // FINANCIAL STATE CARD
                _buildFinancialStateCard(
                  context: context,
                  isDark: isDark,
                  isOnboarded: isOnboarded,
                  profile: profile,
                ),
                const SizedBox(height: AppDimensions.space16),

                // YOUR GOALS CARD
                _buildGoalsCard(
                  context: context,
                  isDark: isDark,
                  goals: goals,
                  onNavigateToGoals: onNavigateToGoals,
                ),
                const SizedBox(height: AppDimensions.space16),

                // RECENT TRANSACTIONS
                _buildRecentTransactionsCard(
                  context: context,
                  isDark: isDark,
                  transactions: transactions,
                  onNavigateToTransactions: onNavigateToTransactions,
                ),
                const SizedBox(height: AppDimensions.space16),

                // AI ANALYSIS SUMMARY (from latest pipeline run)
                if (insight != null && insight.available) ...
                  [
                    _buildAiSummaryCard(
                      context: context,
                      isDark: isDark,
                      insight: insight,
                      onNavigateToAi: () => {},
                    ),
                    const SizedBox(height: AppDimensions.space16),
                  ],

                // GOAL CONFLICTS
                _buildGoalConflictsCard(
                  context: context,
                  isDark: isDark,
                  hasConflict: hasConflict,
                  conflicts: conflicts,
                ),
                const SizedBox(height: AppDimensions.space24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFinancialStateCard({
    required BuildContext context,
    required bool isDark,
    required bool isOnboarded,
    required FinancialProfile? profile,
  }) {
    if (!isOnboarded || profile == null) {
      return _buildModuleCard(
        context: context,
        isDark: isDark,
        headerTag: 'FINANCIAL STATE',
        tagColor: AppColors.electricCyan,
        icon: Icons.account_balance_wallet_outlined,
        message: 'No financial data connected yet.',
        actionButton: ElevatedButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => const FinancialOnboardingPage()),
          ),
          icon: const Icon(Icons.add_link_rounded, size: 16),
          label: const Text('Set Up Financial Profile'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.electricCyan,
            foregroundColor: AppColors.deepNavy,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            textStyle:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
      );
    }

    final surplus =
        profile.totalMonthlyIncome - profile.totalMonthlyExpenses;
    final isSurplus = surplus >= 0;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const FinancialStatePage()),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.space20),
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
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: AppColors.electricCyan),
                ),
                const SizedBox(width: 8),
                const Text(
                  'FINANCIAL STATE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: AppColors.electricCyan,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right_rounded,
                    size: 16, color: AppColors.electricCyan),
              ],
            ),
            const SizedBox(height: AppDimensions.space16),
            Row(
              children: [
                Expanded(
                  child: _FinSummaryTile(
                    label: 'Income',
                    value: _fmt(profile.totalMonthlyIncome),
                    color: AppColors.mint,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: AppDimensions.space8),
                Expanded(
                  child: _FinSummaryTile(
                    label: 'Outflow',
                    value: _fmt(profile.totalMonthlyExpenses),
                    color: AppColors.error,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.space8),
            Row(
              children: [
                Expanded(
                  child: _FinSummaryTile(
                    label: isSurplus ? 'Surplus' : 'Deficit',
                    value:
                        '${isSurplus ? "+" : "-"}${_fmt(surplus.abs())}',
                    color: isSurplus ? AppColors.electricCyan : AppColors.warning,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: AppDimensions.space8),
                Expanded(
                  child: _FinSummaryTile(
                    label: 'Savings',
                    value: _fmt(profile.currentSavings),
                    color: AppColors.electricCyan,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.space12),
            Text(
              'Tap to view detailed financial state',
              style: TextStyle(
                fontSize: 11,
                color: isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textTertiaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTransactionsCard({
    required BuildContext context,
    required bool isDark,
    required List<TransactionModel> transactions,
    required VoidCallback onNavigateToTransactions,
  }) {
    if (transactions.isEmpty) {
      return _buildModuleCard(
        context: context,
        isDark: isDark,
        headerTag: 'RECENT TRANSACTIONS',
        tagColor: const Color(0xFF64B5F6),
        icon: Icons.receipt_long_outlined,
        message: 'No transactions yet',
        submessage:
            'Transactions will appear here when your financial data is connected.',
        actionButton: TextButton.icon(
          onPressed: onNavigateToTransactions,
          icon: const Icon(Icons.arrow_forward_rounded, size: 16),
          label: const Text('View All Transactions'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.electricCyan,
            textStyle:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppDimensions.space20),
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
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: Color(0xFF64B5F6)),
              ),
              const SizedBox(width: 8),
              const Text(
                'RECENT TRANSACTIONS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: Color(0xFF64B5F6),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onNavigateToTransactions,
                child: const Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.electricCyan,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.space16),
          ...transactions.take(3).map(
                (tx) => Padding(
                  padding: const EdgeInsets.only(bottom: AppDimensions.space8),
                  child: _TransactionMiniRow(
                    transaction: tx,
                    isDark: isDark,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TransactionDetailPage(transaction: tx),
                      ),
                    ),
                  ),
                ),
              ),
          if (transactions.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: GestureDetector(
                onTap: onNavigateToTransactions,
                child: Text(
                  '+ ${transactions.length - 3} more transaction${transactions.length - 3 == 1 ? "" : "s"}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.electricCyan,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGoalsCard({
    required BuildContext context,
    required bool isDark,
    required List<GoalModel> goals,
    required VoidCallback onNavigateToGoals,
  }) {
    if (goals.isEmpty) {
      return _buildModuleCard(
        context: context,
        isDark: isDark,
        headerTag: 'YOUR GOALS',
        tagColor: AppColors.mint,
        icon: Icons.flag_outlined,
        message: 'No financial goals created yet.',
        submessage:
            'Create goals so GoalSync can analyze future financial conflicts.',
        actionButton: ElevatedButton.icon(
          onPressed: onNavigateToGoals,
          icon: const Icon(Icons.add_rounded, size: 16),
          label: const Text('Create Your First Goal'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.mint,
            foregroundColor: AppColors.deepNavy,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            textStyle:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppDimensions.space20),
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
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: AppColors.mint),
              ),
              const SizedBox(width: 8),
              const Text(
                'YOUR GOALS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: AppColors.mint,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onNavigateToGoals,
                child: const Text(
                  'See All',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.electricCyan,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.space16),
          Row(
            children: [
              _GoalStatChip(
                  label: 'Total',
                  value: '${goals.length}',
                  color: AppColors.electricCyan,
                  isDark: isDark),
              const SizedBox(width: 8),
              _GoalStatChip(
                  label: 'Completed',
                  value: '${goals.where((g) => g.isCompleted).length}',
                  color: AppColors.mint,
                  isDark: isDark),
              const SizedBox(width: 8),
              _GoalStatChip(
                  label: 'Overdue',
                  value:
                      '${goals.where((g) => g.daysRemaining < 0 && !g.isCompleted).length}',
                  color: AppColors.error,
                  isDark: isDark),
            ],
          ),
          const SizedBox(height: AppDimensions.space12),
          ...goals.take(2).map((g) => Padding(
                padding:
                    const EdgeInsets.only(bottom: AppDimensions.space8),
                child: _GoalMiniRow(goal: g, isDark: isDark),
              )),
          if (goals.length > 2)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: GestureDetector(
                onTap: onNavigateToGoals,
                child: Text(
                  '+ \${goals.length - 2} more goal\${goals.length - 2 == 1 ? "" : "s"}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.electricCyan,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _profileChip({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.navyMid.withAlpha(140)
            : AppColors.lightSurfaceVariant,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 14,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight),
          const SizedBox(width: 6),
          Text('$label: ',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              )),
          Text(value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              )),
        ],
      ),
    );
  }

  Widget _buildModuleCard({
    required BuildContext context,
    required bool isDark,
    required String headerTag,
    required Color tagColor,
    required IconData icon,
    required String message,
    String? submessage,
    Widget? actionButton,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space20),
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
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: tagColor),
              ),
              const SizedBox(width: 8),
              Text(headerTag,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: tagColor,
                  )),
            ],
          ),
          const SizedBox(height: AppDimensions.space16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.navyMid
                      : AppColors.lightSurfaceVariant,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusMd),
                ),
                child: Icon(icon,
                    size: 24,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight),
              ),
              const SizedBox(width: AppDimensions.space16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(message,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        )),
                    if (submessage != null) ...[
                      const SizedBox(height: 4),
                      Text(submessage,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                            height: 1.4,
                          )),
                    ],
                    if (actionButton != null) ...[
                      const SizedBox(height: AppDimensions.space12),
                      actionButton,
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAiSummaryCard({
    required BuildContext context,
    required bool isDark,
    required dynamic insight,
    required VoidCallback onNavigateToAi,
  }) {
    final headline = insight.headline as String? ?? 'Analysis complete';
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.electricCyan.withAlpha(20),
            AppColors.mint.withAlpha(12),
          ],
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.electricCyan.withAlpha(70)),
        boxShadow: [
          BoxShadow(
            color: AppColors.electricCyan.withAlpha(15),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: AppColors.electricCyan),
              ),
              const SizedBox(width: 7),
              const Text(
                'AI ANALYSIS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: AppColors.electricCyan,
                ),
              ),
              const Spacer(),
              const Icon(Icons.auto_awesome_rounded,
                  size: 14, color: AppColors.electricCyan),
            ],
          ),
          const SizedBox(height: AppDimensions.space10),
          Text(
            headline,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            'Tap AI tab for full multi-agent analysis',
            style: TextStyle(
              fontSize: 11,
              color: isDark
                  ? AppColors.textTertiaryDark
                  : AppColors.textTertiaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalConflictsCard({
    required BuildContext context,
    required bool isDark,
    required bool hasConflict,
    required List<Map<String, dynamic>> conflicts,
  }) {
    if (!hasConflict || conflicts.isEmpty) {
      return _buildModuleCard(
        context: context,
        isDark: isDark,
        headerTag: 'GOAL CONFLICTS',
        tagColor: AppColors.mint,
        icon: Icons.check_circle_outline_rounded,
        message: 'No conflicts detected.',
        submessage:
            'Your active goals are aligned with your financial capacity.',
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppDimensions.space20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.warning.withAlpha(120)),
        boxShadow: [
          BoxShadow(
            color: AppColors.warning.withAlpha(20),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: AppColors.warning),
              ),
              const SizedBox(width: 8),
              Text(
                'GOAL CONFLICTS (${conflicts.length})',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.space12),
          ...conflicts.take(2).map((c) {
            final desc = (c['description'] as String?) ??
                (c['message'] as String?) ??
                'Conflict detected between goals.';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withAlpha(18),
                  borderRadius: BorderRadius.circular(8),
                  border: const Border(
                      left: BorderSide(color: AppColors.warning, width: 3)),
                ),
                child: Text(
                  desc,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ),
            );
          }),
          if (conflicts.length > 2)
            Text(
              '+ ${conflicts.length - 2} more — see AI tab',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.warning,
              ),
            ),
        ],
      ),
    );
  }
}


class _FinSummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _FinSummaryTile({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 0.3,
              color: isDark
                  ? AppColors.textTertiaryDark
                  : AppColors.textTertiaryLight,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _GoalStatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _GoalStatChip({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: color)),
          Text(label,
              style: TextStyle(
                fontSize: 10,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              )),
        ],
      ),
    );
  }
}

class _GoalMiniRow extends StatelessWidget {
  final GoalModel goal;
  final bool isDark;

  const _GoalMiniRow({required this.goal, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                goal.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: goal.progressFraction,
                  backgroundColor: isDark
                      ? AppColors.navyMid
                      : AppColors.lightSurfaceVariant,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    goal.isCompleted ? AppColors.mint : AppColors.electricCyan,
                  ),
                  minHeight: 4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          goal.progressPercentage,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: goal.isCompleted ? AppColors.mint : AppColors.electricCyan,
          ),
        ),
      ],
    );
  }
}


class _TransactionMiniRow extends StatelessWidget {
  final TransactionModel transaction;
  final bool isDark;
  final VoidCallback onTap;

  const _TransactionMiniRow({
    required this.transaction,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDebit = transaction.isDebit;
    final badgeColor = isDebit ? AppColors.error : AppColors.mint;
    final badgeBg = isDebit
        ? AppColors.error.withAlpha(20)
        : AppColors.mint.withAlpha(20);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurfaceVariant
                    : AppColors.lightSurfaceVariant,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                isDebit ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                size: 16,
                color: badgeColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.merchantName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${transaction.category} • ${transaction.paymentMethod.displayName}',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    transaction.signedFormattedAmount,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: badgeColor,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  transaction.formattedDate,
                  style: TextStyle(
                    fontSize: 9,
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
}
