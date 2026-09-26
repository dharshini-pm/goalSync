import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../auth/services/auth_service.dart';
import '../../../profile/presentation/pages/profile_page.dart';

/// GoalSync Main Dashboard with 5-tab bottom navigation and genuine empty-state cards.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _HomeDashboardView(
            onNavigateToGoals: () => setState(() => _currentIndex = 1),
          ),
          const _PlaceholderModuleView(
            moduleName: 'Goals',
            subtitle: 'Goals module coming next',
            icon: Icons.flag_rounded,
          ),
          const _PlaceholderModuleView(
            moduleName: 'Activity',
            subtitle: 'Activity module coming next',
            icon: Icons.receipt_long_rounded,
          ),
          const _PlaceholderModuleView(
            moduleName: 'AI Copilot',
            subtitle: 'AI Copilot module coming next',
            icon: Icons.auto_awesome_rounded,
          ),
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
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
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

/// Home tab view showing user profile summary & genuine empty-state cards.
class _HomeDashboardView extends StatelessWidget {
  final VoidCallback onNavigateToGoals;

  const _HomeDashboardView({required this.onNavigateToGoals});

  void _showNotice(BuildContext context, String title, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title: $message'),
        backgroundColor: AppColors.navyLight,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = AuthService.instance.currentUser;
    final userName = user?.fullName.isNotEmpty == true ? user!.fullName : 'User';

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
                // Top App Bar Header
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: AppColors.gradientAccent,
                        ),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                      ),
                      child: const Icon(
                        Icons.hub_rounded,
                        size: 20,
                        color: AppColors.deepNavy,
                      ),
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.mintGlow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.mint.withAlpha(90),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 12,
                            color: AppColors.mint,
                          ),
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

                // Welcome Back Header & Profile Info
                Container(
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

                      // User Profile Meta: Account, Phone, Email
                      Wrap(
                        spacing: 16,
                        runSpacing: 10,
                        children: [
                          _buildProfileMetaChip(
                            icon: Icons.verified_user_outlined,
                            label: 'Account',
                            value: 'Personal Account',
                            isDark: isDark,
                          ),
                          _buildProfileMetaChip(
                            icon: Icons.phone_outlined,
                            label: 'Phone',
                            value: user?.fullPhoneNumber ?? 'Not set',
                            isDark: isDark,
                          ),
                          _buildProfileMetaChip(
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

                // Section Label
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

                // Card 1: FINANCIAL STATE
                _buildModuleCard(
                  context: context,
                  isDark: isDark,
                  headerTag: 'FINANCIAL STATE',
                  tagColor: AppColors.electricCyan,
                  icon: Icons.account_balance_wallet_outlined,
                  message: 'No financial data connected yet.',
                  actionButton: ElevatedButton.icon(
                    onPressed: () => _showNotice(
                      context,
                      'Financial Profile',
                      'Financial onboarding module will be available in the next step.',
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.space16),

                // Card 2: YOUR GOALS
                _buildModuleCard(
                  context: context,
                  isDark: isDark,
                  headerTag: 'YOUR GOALS',
                  tagColor: AppColors.mint,
                  icon: Icons.flag_outlined,
                  message: 'No financial goals created yet.',
                  actionButton: ElevatedButton.icon(
                    onPressed: () => _showNotice(
                      context,
                      'Goals',
                      'Goal creation module will be available in the next step.',
                    ),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Create Your First Goal'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.mint,
                      foregroundColor: AppColors.deepNavy,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.space16),

                // Card 3: RECENT TRANSACTIONS
                _buildModuleCard(
                  context: context,
                  isDark: isDark,
                  headerTag: 'RECENT TRANSACTIONS',
                  tagColor: const Color(0xFF64B5F6),
                  icon: Icons.receipt_long_outlined,
                  message: 'No transactions available yet.',
                  submessage: 'Transactions will appear here when your financial data is connected.',
                ),
                const SizedBox(height: AppDimensions.space16),

                // Card 4: GOAL CONFLICTS
                _buildModuleCard(
                  context: context,
                  isDark: isDark,
                  headerTag: 'GOAL CONFLICTS',
                  tagColor: AppColors.warning,
                  icon: Icons.sync_problem_rounded,
                  message: 'No conflicts detected.',
                  submessage: 'Goal conflict analysis will appear here once financial data is available.',
                ),
                const SizedBox(height: AppDimensions.space24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileMetaChip({
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
          Icon(
            icon,
            size: 14,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
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
          // Header Tag
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tagColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                headerTag,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: tagColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.space16),

          // Content Box
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.navyMid
                      : AppColors.lightSurfaceVariant,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                child: Icon(
                  icon,
                  size: 24,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(width: AppDimensions.space16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                    if (submessage != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        submessage,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                          height: 1.4,
                        ),
                      ),
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
}

/// Simple placeholder screen for future modules (Goals, Activity, AI Copilot).
class _PlaceholderModuleView extends StatelessWidget {
  final String moduleName;
  final String subtitle;
  final IconData icon;

  const _PlaceholderModuleView({
    required this.moduleName,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(
          moduleName,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.space32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.navyMid
                      : AppColors.lightSurfaceVariant,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.electricCyan.withAlpha(80),
                  ),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: AppColors.electricCyan,
                ),
              ),
              const SizedBox(height: AppDimensions.space20),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: AppDimensions.space8),
              Text(
                'This feature is reserved for subsequent implementation.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
