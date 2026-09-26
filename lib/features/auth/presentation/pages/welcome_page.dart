import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import 'login_page.dart';
import 'sign_up_page.dart';

/// Welcome Page for GoalSync.
///
/// Features:
/// - Brand header and bold typography
/// - Responsive layout (split desktop/tablet vs stacked mobile)
/// - Animated Financial Intelligence visual pipeline:
///   Income -> Transactions -> Financial State -> Goals -> Conflicts -> Scenarios
/// - Dual CTAs: [ Get Started ] and [ I already have an account ]
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.sizeOf(context);
    final isWide = size.width >= 900;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      body: SafeArea(
        child: isWide
            ? _buildWideLayout(context, isDark)
            : _buildMobileLayout(context, isDark),
      ),
    );
  }

  Widget _buildWideLayout(BuildContext context, bool isDark) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.space40,
            vertical: AppDimensions.space32,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left Column: Brand & Actions
              Expanded(
                flex: 5,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.only(right: AppDimensions.space40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildBrandHeader(isDark),
                        const SizedBox(height: AppDimensions.space32),
                        _buildHeadline(context, isDark),
                        const SizedBox(height: AppDimensions.space20),
                        _buildDescription(isDark),
                        const SizedBox(height: AppDimensions.space40),
                        _buildActionButtons(context, isDark),
                      ],
                    ),
                  ),
                ),
              ),

              // Right Column: Financial Intelligence Visual
              Expanded(
                flex: 5,
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 700),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurface.withAlpha(160)
                          : AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radius2xl,
                      ),
                      border: Border.all(
                        color: isDark
                            ? AppColors.navyBorder
                            : AppColors.lightSurfaceVariant,
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withAlpha(80)
                              : Colors.black.withAlpha(15),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(AppDimensions.space24),
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, _) {
                        return _FinancialIntelligenceVisual(
                          progress: _pulseController.value,
                          isDark: isDark,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.pagePaddingH,
        vertical: AppDimensions.space20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBrandHeader(isDark),
          const SizedBox(height: AppDimensions.space28),
          _buildHeadline(context, isDark),
          const SizedBox(height: AppDimensions.space16),
          _buildDescription(isDark),
          const SizedBox(height: AppDimensions.space28),

          // Visual Node Container
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkSurface.withAlpha(160)
                  : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
              border: Border.all(
                color: isDark
                    ? AppColors.navyBorder
                    : AppColors.lightSurfaceVariant,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withAlpha(60)
                      : Colors.black.withAlpha(12),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.space16,
              vertical: AppDimensions.space20,
            ),
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) {
                return _FinancialIntelligenceVisual(
                  progress: _pulseController.value,
                  isDark: isDark,
                  isCompact: true,
                );
              },
            ),
          ),

          const SizedBox(height: AppDimensions.space32),
          _buildActionButtons(context, isDark),
          const SizedBox(height: AppDimensions.space24),
        ],
      ),
    );
  }

  Widget _buildBrandHeader(bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: AppColors.gradientAccent,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            boxShadow: [
              BoxShadow(
                color: AppColors.electricCyan.withAlpha(80),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.hub_rounded,
            color: AppColors.deepNavy,
            size: 24,
          ),
        ),
        const SizedBox(width: AppDimensions.space12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'GoalSync',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            Text(
              'FINANCIAL INTELLIGENCE',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: AppColors.electricCyan,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeadline(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your money changes.',
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.0,
            height: 1.15,
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
          ),
        ),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: AppColors.gradientAccent,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ).createShader(bounds),
          child: const Text(
            'Your goals should adapt.',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.0,
              height: 1.15,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDescription(bool isDark) {
    return Text(
      'GoalSync continuously understands your financial activity, '
      'detects goal conflicts, and helps you explore what-if scenarios.',
      style: TextStyle(
        fontSize: 16,
        height: 1.5,
        color: isDark
            ? AppColors.textSecondaryDark
            : AppColors.textSecondaryLight,
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Primary CTA: Get Started -> Sign Up
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: AppColors.gradientAccent,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            boxShadow: [
              BoxShadow(
                color: AppColors.electricCyan.withAlpha(90),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SignUpPage()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Get Started',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.deepNavy,
                    letterSpacing: 0.2,
                  ),
                ),
                SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: AppColors.deepNavy,
                  size: 20,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppDimensions.space12),

        // Secondary CTA: I already have an account -> Login
        OutlinedButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LoginPage()),
            );
          },
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            side: BorderSide(
              color: isDark ? AppColors.navyBorder : const Color(0xFFCCE4F5),
              width: 1.5,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            ),
            backgroundColor: isDark
                ? AppColors.darkSurface.withAlpha(80)
                : Colors.white.withAlpha(120),
          ),
          child: Text(
            'I already have an account',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
        ),
      ],
    );
  }
}

/// Visual representation of GoalSync's intelligence pipeline.
class _FinancialIntelligenceVisual extends StatelessWidget {
  final double progress;
  final bool isDark;
  final bool isCompact;

  const _FinancialIntelligenceVisual({
    required this.progress,
    required this.isDark,
    this.isCompact = false,
  });

  static const List<_PipelineStep> _steps = [
    _PipelineStep(
      title: 'Income',
      subtitle: 'Continuous cash-inflow tracking',
      icon: Icons.trending_up_rounded,
    ),
    _PipelineStep(
      title: 'Transactions',
      subtitle: 'Real-time financial activity streams',
      icon: Icons.receipt_long_rounded,
    ),
    _PipelineStep(
      title: 'Financial State',
      subtitle: 'Live liquidity and net position',
      icon: Icons.account_balance_wallet_rounded,
    ),
    _PipelineStep(
      title: 'Goals',
      subtitle: 'Dynamic priority & timeline modeling',
      icon: Icons.flag_rounded,
    ),
    _PipelineStep(
      title: 'Conflicts',
      subtitle: 'Early cross-goal collision detection',
      icon: Icons.sync_problem_rounded,
    ),
    _PipelineStep(
      title: 'Scenarios',
      subtitle: 'AI what-if simulations & trade-offs',
      icon: Icons.alt_route_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.mint,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'FINANCIAL INTELLIGENCE ENGINE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.cyanGlow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.electricCyan.withAlpha(60),
                ),
              ),
              child: const Text(
                'LIVE SYNC',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: AppColors.electricCyan,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.space16),

        // Steps with connecting lines
        for (int i = 0; i < _steps.length; i++) ...[
          _buildNodeCard(i),
          if (i < _steps.length - 1) _buildConnector(i),
        ],
      ],
    );
  }

  Widget _buildNodeCard(int index) {
    final step = _steps[index];
    final stepProgress = (progress * _steps.length) % _steps.length;
    final isActive = (stepProgress >= index && stepProgress < index + 1);

    final borderColor = isActive
        ? AppColors.electricCyan
        : (isDark ? AppColors.navyBorder : const Color(0xFFD6E4F0));

    final nodeBg = isDark
        ? (isActive ? AppColors.navyMid : AppColors.darkSurface)
        : (isActive ? const Color(0xFFF0F9FF) : Colors.white);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: EdgeInsets.symmetric(
        horizontal: AppDimensions.space16,
        vertical: isCompact ? AppDimensions.space10 : AppDimensions.space12,
      ),
      decoration: BoxDecoration(
        color: nodeBg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(
          color: borderColor,
          width: isActive ? 1.5 : 1.0,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppColors.electricCyan.withAlpha(35),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // Step Icon
          Container(
            width: isCompact ? 32 : 38,
            height: isCompact ? 32 : 38,
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.electricCyan.withAlpha(35)
                  : (isDark
                      ? AppColors.navyBorder.withAlpha(90)
                      : AppColors.lightSurfaceVariant),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            ),
            child: Icon(
              step.icon,
              size: isCompact ? 18 : 20,
              color: isActive
                  ? AppColors.electricCyan
                  : (isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight),
            ),
          ),
          const SizedBox(width: AppDimensions.space12),

          // Title & Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  step.title,
                  style: TextStyle(
                    fontSize: isCompact ? 13 : 14,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                Text(
                  step.subtitle,
                  style: TextStyle(
                    fontSize: isCompact ? 11 : 12,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),

          // Flow indicator dot
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? AppColors.mint
                  : (isDark ? AppColors.navyBorder : const Color(0xFFBACFD8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnector(int index) {
    return SizedBox(
      height: isCompact ? 12 : 16,
      child: Center(
        child: CustomPaint(
          size: Size(16, isCompact ? 12 : 16),
          painter: _FlowConnectorPainter(
            progress: progress,
            stepIndex: index,
            totalSteps: _steps.length,
          ),
        ),
      ),
    );
  }
}

class _PipelineStep {
  final String title;
  final String subtitle;
  final IconData icon;

  const _PipelineStep({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

class _FlowConnectorPainter extends CustomPainter {
  final double progress;
  final int stepIndex;
  final int totalSteps;

  _FlowConnectorPainter({
    required this.progress,
    required this.stepIndex,
    required this.totalSteps,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final startX = size.width / 2;
    final linePaint = Paint()
      ..color = AppColors.electricCyan.withAlpha(50)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(startX, 0),
      Offset(startX, size.height),
      linePaint,
    );

    // Arrow indicator
    final arrowPaint = Paint()
      ..color = AppColors.electricCyan.withAlpha(120)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(startX - 3, size.height - 3)
      ..lineTo(startX + 3, size.height - 3)
      ..lineTo(startX, size.height)
      ..close();

    canvas.drawPath(path, arrowPaint);

    // Animated glow particle
    final stepPhase = ((progress * totalSteps) - stepIndex).clamp(0.0, 1.0);
    if (stepPhase > 0.0 && stepPhase < 1.0) {
      final particleY = size.height * stepPhase;
      final glowPaint = Paint()
        ..color = AppColors.mint
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3);
      canvas.drawCircle(Offset(startX, particleY), 2.5, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FlowConnectorPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
