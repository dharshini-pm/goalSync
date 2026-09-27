import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../auth/services/auth_service.dart';
import '../../../ai_copilot/services/ai_insights_service.dart';

/// Profile Page showing verified account details and session termination.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  void initState() {
    super.initState();
    AuthService.instance.addListener(_onAuthChanged);
    AuthService.instance.syncUserFromBackend();
  }

  @override
  void dispose() {
    AuthService.instance.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _handleLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          ),
          title: const Text('Log Out'),
          content: const Text(
            'Are you sure you want to log out of GoalSync on this device?',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
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
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                ),
              ),
              child: const Text('Log Out'),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true && context.mounted) {
      await AuthService.instance.logout();
      AiInsightsService.instance.clear();
      if (!context.mounted) return;
      // Navigate to Login Page and clear all routes
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = AuthService.instance.currentUser;

    final userName = user?.fullName.isNotEmpty == true ? user!.fullName : 'User';
    final userEmail = user?.email.isNotEmpty == true ? user!.email : 'Not provided';
    final userPhone = user != null ? user.fullPhoneNumber : 'Not provided';

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.pagePaddingH,
            vertical: AppDimensions.space16,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Profile Avatar & Name Card
                  Container(
                    padding: const EdgeInsets.all(AppDimensions.space24),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                      border: Border.all(
                        color: isDark
                            ? AppColors.navyBorder
                            : const Color(0xFFD6E4F0),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withAlpha(50)
                              : Colors.black.withAlpha(10),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Avatar Initials
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: AppColors.gradientAccent,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.electricCyan.withAlpha(80),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              _getInitials(userName),
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: AppColors.deepNavy,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppDimensions.space16),

                        Text(
                          userName,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.space4),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.cyanGlow,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.electricCyan.withAlpha(80),
                            ),
                          ),
                          child: const Text(
                            'Personal Account',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.electricCyan,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space20),

                  // Account Information Section
                  Text(
                    'ACCOUNT INFORMATION',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space8),

                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                      border: Border.all(
                        color: isDark
                            ? AppColors.navyBorder
                            : const Color(0xFFD6E4F0),
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildInfoTile(
                          icon: Icons.person_outline_rounded,
                          title: 'Full Name',
                          value: userName,
                          isDark: isDark,
                        ),
                        const Divider(height: 1),
                        _buildInfoTile(
                          icon: Icons.phone_outlined,
                          title: 'Phone',
                          value: userPhone,
                          isDark: isDark,
                        ),
                        const Divider(height: 1),
                        _buildInfoTile(
                          icon: Icons.email_outlined,
                          title: 'Email',
                          value: userEmail,
                          isDark: isDark,
                        ),
                        const Divider(height: 1),
                        _buildInfoTile(
                          icon: Icons.security_rounded,
                          title: 'Account Status',
                          value: 'Active (Local Session)',
                          isDark: isDark,
                          trailingColor: AppColors.mint,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space32),

                  // Logout Button
                  OutlinedButton.icon(
                    onPressed: () => _handleLogout(context),
                    icon: const Icon(Icons.logout_rounded, size: 20),
                    label: const Text(
                      'Logout',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(
                        color: AppColors.error.withAlpha(120),
                        width: 1.5,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                      ),
                      backgroundColor: isDark
                          ? AppColors.error.withAlpha(20)
                          : AppColors.error.withAlpha(12),
                    ),
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

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
    required bool isDark,
    Color? trailingColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space16,
        vertical: AppDimensions.space12,
      ),
      child: Row(
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
              icon,
              size: 18,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(width: AppDimensions.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: trailingColor ??
                        (isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ').where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return 'GS';
    if (parts.length == 1) {
      final str = parts[0];
      return str.length >= 2 ? str.substring(0, 2).toUpperCase() : str.toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}
