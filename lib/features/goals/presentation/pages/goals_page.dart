import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../auth/services/auth_service.dart';
import '../../models/goal_model.dart';
import '../../services/goal_service.dart';
import '../widgets/goal_card.dart';
import 'create_goal_page.dart';
import 'goal_detail_page.dart';

/// Full Goals tab page.
class GoalsPage extends StatefulWidget {
  const GoalsPage({super.key});

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  @override
  void initState() {
    super.initState();
    GoalService.instance.addListener(_onGoalsChanged);
  }

  @override
  void dispose() {
    GoalService.instance.removeListener(_onGoalsChanged);
    super.dispose();
  }

  void _onGoalsChanged() => setState(() {});

  Future<void> _openCreateGoal() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreateGoalPage()),
    );
    setState(() {});
  }

  Future<void> _openGoalDetail(GoalModel goal) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GoalDetailPage(goal: goal)),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userId = AuthService.instance.currentUser?.id ?? '';
    final goals = GoalService.instance.getGoalsForUser(userId);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
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
                  // ── Header ─────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your Goals',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'GoalSync tracks your progress and adapts goals as your financial conditions change.',
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (goals.isNotEmpty)
                        _AddGoalFAB(onTap: _openCreateGoal, compact: true),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.space24),

                  // ── Content ────────────────────────────────────
                  if (goals.isEmpty)
                    _EmptyGoalsState(onCreateGoal: _openCreateGoal)
                  else ...[
                    // Summary chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.electricCyan.withAlpha(20),
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusMd),
                        border: Border.all(
                            color: AppColors.electricCyan.withAlpha(60)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.flag_rounded,
                              size: 14, color: AppColors.electricCyan),
                          const SizedBox(width: 6),
                          Text(
                            '${goals.length} ${goals.length == 1 ? "goal" : "goals"} active',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.electricCyan,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${goals.where((g) => g.isCompleted).length} completed',
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
                    const SizedBox(height: AppDimensions.space16),

                    // Goal cards
                    ...goals.map(
                      (g) => GoalCard(
                        goal: g,
                        onTap: () => _openGoalDetail(g),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.space16),

                    // Bottom add button
                    _AddGoalFAB(onTap: _openCreateGoal, compact: false),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyGoalsState extends StatelessWidget {
  final VoidCallback onCreateGoal;
  const _EmptyGoalsState({required this.onCreateGoal});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        const SizedBox(height: AppDimensions.space40),
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
            Icons.flag_rounded,
            size: 40,
            color: AppColors.deepNavy,
          ),
        ),
        const SizedBox(height: AppDimensions.space24),
        Text(
          'No Goals Yet',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: AppDimensions.space12),
        Text(
          "Goals are the foundation of GoalSync's financial conflict analysis. Create your first goal so the system can begin tracking your progress and detecting future conflicts.",
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
            onPressed: onCreateGoal,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Create Your First Goal'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.electricCyan,
              foregroundColor: AppColors.deepNavy,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.space40),
      ],
    );
  }
}

class _AddGoalFAB extends StatelessWidget {
  final VoidCallback onTap;
  final bool compact;
  const _AddGoalFAB({required this.onTap, required this.compact});

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: AppColors.gradientAccent),
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
          child: const Icon(Icons.add_rounded,
              size: 20, color: AppColors.deepNavy),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('Add Another Goal'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.electricCyan,
          side: const BorderSide(color: AppColors.electricCyan),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
    );
  }
}
