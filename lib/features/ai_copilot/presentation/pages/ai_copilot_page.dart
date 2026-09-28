import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../models/pipeline_insight_model.dart';
import '../../services/ai_insights_service.dart';

/// AI Copilot tab — surfaces real LangGraph multi-agent results.
///
/// Displays the latest AI pipeline analysis driven by SMS-detected transactions:
/// - Headline & summary from the Explanation Agent
/// - Financial state from the Financial State Agent
/// - Goal impact from the Goal Agent
/// - Conflicts from the Conflict Agent
/// - Scenarios from the Scenario Agent
/// - Execution history of all past analyses
class AiCopilotPage extends StatefulWidget {
  const AiCopilotPage({super.key});

  @override
  State<AiCopilotPage> createState() => _AiCopilotPageState();
}

class _AiCopilotPageState extends State<AiCopilotPage> {
  @override
  void initState() {
    super.initState();
    AiInsightsService.instance.addListener(_onUpdate);
    AiInsightsService.instance.refresh();
  }

  @override
  void dispose() {
    AiInsightsService.instance.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final svc = AiInsightsService.instance;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.electricCyan,
          onRefresh: () => svc.refresh(force: true),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ─── Header ────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.pagePaddingH,
                    vertical: AppDimensions.space20,
                  ),
                  child: _buildHeader(isDark, svc),
                ),
              ),

              // ─── Content ───────────────────────────────────────────────
              if (svc.isLoading && !svc.hasData)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.electricCyan,
                      strokeWidth: 2,
                    ),
                  ),
                )
              else if (svc.error != null && !svc.hasData)
                SliverFillRemaining(
                  child: _buildErrorState(svc.error!, isDark, svc),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.pagePaddingH,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildBody(isDark, svc),
                      const SizedBox(height: AppDimensions.space32),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────

  Widget _buildHeader(bool isDark, AiInsightsService svc) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: AppColors.gradientAccent),
            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          ),
          child: const Icon(Icons.auto_awesome_rounded,
              size: 18, color: AppColors.deepNavy),
        ),
        const SizedBox(width: AppDimensions.space10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI Copilot',
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
              'MULTI-AGENT FINANCIAL INTELLIGENCE',
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: AppColors.electricCyan,
              ),
            ),
          ],
        ),
        const Spacer(),
        if (svc.isLoading)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              color: AppColors.electricCyan,
              strokeWidth: 2,
            ),
          )
        else
          GestureDetector(
            onTap: () => svc.refresh(force: true),
            child: const Icon(Icons.refresh_rounded,
                size: 20, color: AppColors.electricCyan),
          ),
      ],
    );
  }

  // ── Body ────────────────────────────────────────────────────────────────

  Widget _buildBody(bool isDark, AiInsightsService svc) {
    if (!svc.hasInsight) {
      return _buildNoInsightYet(isDark);
    }

    final insight = svc.latestInsight!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // AI Analysis Badge
        _buildAiBadge(insight, isDark),
        const SizedBox(height: AppDimensions.space16),

        // Headline Card
        _buildHeadlineCard(insight, isDark),
        const SizedBox(height: AppDimensions.space16),

        // Financial State
        if (insight.financialState != null)
          _buildFinancialStateCard(insight, isDark),
        if (insight.financialState != null)
          const SizedBox(height: AppDimensions.space16),

        // Goal Impact
        if (insight.goals != null && insight.goals!.isNotEmpty)
          _buildGoalImpactCard(insight, isDark),
        if (insight.goals != null && insight.goals!.isNotEmpty)
          const SizedBox(height: AppDimensions.space16),

        // Conflicts
        _buildConflictCard(insight, isDark),
        const SizedBox(height: AppDimensions.space16),

        // Scenarios
        if (insight.hasScenarios)
          _buildScenariosCard(insight, isDark),
        if (insight.hasScenarios)
          const SizedBox(height: AppDimensions.space16),

        // Agent Pipeline Status
        _buildPipelineStatusCard(insight, isDark),
        const SizedBox(height: AppDimensions.space24),

        // History
        _buildHistorySection(svc.history, isDark),
      ],
    );
  }

  // ── No insight state ────────────────────────────────────────────────────

  Widget _buildNoInsightYet(bool isDark) {
    return Column(
      children: [
        const SizedBox(height: AppDimensions.space32),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.electricCyan.withAlpha(20),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.electricCyan.withAlpha(60)),
          ),
          child: const Icon(Icons.auto_awesome_rounded,
              size: 36, color: AppColors.electricCyan),
        ),
        const SizedBox(height: AppDimensions.space20),
        Text(
          'No AI Analysis Yet',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: AppDimensions.space8),
        Text(
          'GoalSync AI will analyse your financial transactions in real-time as transactions are recorded.\n\nOnce a transaction is processed through the 6-agent pipeline, the full analysis will appear here.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            height: 1.6,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: AppDimensions.space24),
        _AgentChip(label: 'Transaction Agent', color: AppColors.electricCyan),
        const SizedBox(height: 8),
        _AgentChip(label: 'Financial State Agent', color: AppColors.mint),
        const SizedBox(height: 8),
        _AgentChip(label: 'Goal Agent', color: const Color(0xFF64B5F6)),
        const SizedBox(height: 8),
        _AgentChip(label: 'Conflict Agent', color: AppColors.warning),
        const SizedBox(height: 8),
        _AgentChip(label: 'Scenario Agent', color: const Color(0xFFBA68C8)),
        const SizedBox(height: 8),
        _AgentChip(label: 'Explanation Agent', color: AppColors.electricCyan),
      ],
    );
  }

  // ── AI Badge ────────────────────────────────────────────────────────────

  Widget _buildAiBadge(PipelineInsight insight, bool isDark) {
    final stages = insight.completedStages.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.electricCyan.withAlpha(25),
            AppColors.mint.withAlpha(15),
          ],
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.electricCyan.withAlpha(70)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded,
              size: 14, color: AppColors.electricCyan),
          const SizedBox(width: 6),
          Text(
            '$stages/6 AGENTS COMPLETE',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: AppColors.electricCyan,
            ),
          ),
          const Spacer(),
          if (insight.processedAt != null)
            Text(
              _formatTime(insight.processedAt!),
              style: TextStyle(
                fontSize: 10,
                color: isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textTertiaryLight,
              ),
            ),
        ],
      ),
    );
  }

  // ── Headline Card ───────────────────────────────────────────────────────

  Widget _buildHeadlineCard(PipelineInsight insight, bool isDark) {
    return _InsightCard(
      isDark: isDark,
      accentColor: AppColors.electricCyan,
      headerTag: 'AI ANALYSIS',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            insight.headline,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          if (insight.summary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              insight.summary,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Financial State Card ────────────────────────────────────────────────

  Widget _buildFinancialStateCard(PipelineInsight insight, bool isDark) {
    final fs = insight.financialState!;
    final status = insight.financialStatus;
    final cfStatus = insight.cashFlowStatus;
    final statusColor = _statusColor(status);
    final cfColor = _cashFlowColor(cfStatus);

    return _InsightCard(
      isDark: isDark,
      accentColor: AppColors.mint,
      headerTag: 'FINANCIAL STATE AGENT',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusBadge(label: status, color: statusColor),
              const SizedBox(width: 8),
              _StatusBadge(label: cfStatus, color: cfColor),
            ],
          ),
          const SizedBox(height: AppDimensions.space12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (fs['monthly_income'] != null)
                _FinTile(
                  label: 'Income',
                  value: _fmtAmount(fs['monthly_income']),
                  color: AppColors.mint,
                ),
              if (fs['monthly_expenses'] != null)
                _FinTile(
                  label: 'Expenses',
                  value: _fmtAmount(fs['monthly_expenses']),
                  color: AppColors.error,
                ),
              if (fs['monthly_surplus'] != null)
                _FinTile(
                  label: 'Surplus',
                  value: _fmtAmount(fs['monthly_surplus']),
                  color: AppColors.electricCyan,
                ),
              if (fs['savings_rate'] != null)
                _FinTile(
                  label: 'Savings %',
                  value: '${(fs['savings_rate'] as num).toStringAsFixed(1)}%',
                  color: const Color(0xFF64B5F6),
                ),
            ],
          ),
          if (fs['recommendation'] != null) ...[
            const SizedBox(height: AppDimensions.space12),
            _QuoteBox(text: fs['recommendation'].toString(), isDark: isDark),
          ],
        ],
      ),
    );
  }

  // ── Goal Impact Card ────────────────────────────────────────────────────

  Widget _buildGoalImpactCard(PipelineInsight insight, bool isDark) {
    final goals = insight.goals!;
    return _InsightCard(
      isDark: isDark,
      accentColor: const Color(0xFF64B5F6),
      headerTag: 'GOAL AGENT',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: goals.take(3).map((g) {
          final name = (g['goal_name'] as String?) ?? 'Goal';
          final goalStatus = (g['goal_status'] as String?) ?? '';
          final color = _goalStatusColor(goalStatus);
          final score = (g['feasibility_score'] as num?)?.toDouble();
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
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
                      if (score != null) ...[
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (score / 100.0).clamp(0.0, 1.0),
                            backgroundColor:
                                isDark ? AppColors.navyMid : const Color(0xFFE8EEF4),
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _StatusBadge(label: goalStatus, color: color),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Conflict Card ───────────────────────────────────────────────────────

  Widget _buildConflictCard(PipelineInsight insight, bool isDark) {
    final hasConflict = insight.hasConflict;
    final conflicts = insight.conflicts;

    return _InsightCard(
      isDark: isDark,
      accentColor: hasConflict ? AppColors.warning : AppColors.mint,
      headerTag: 'CONFLICT AGENT',
      child: hasConflict && conflicts.isNotEmpty
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 16, color: AppColors.warning),
                    const SizedBox(width: 6),
                    Text(
                      '${conflicts.length} Conflict${conflicts.length == 1 ? '' : 's'} Detected',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.warning,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.space12),
                ...conflicts.take(3).map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _QuoteBox(
                          text: (c['description'] as String?) ??
                              (c['message'] as String?) ??
                              c.toString(),
                          isDark: isDark,
                          color: AppColors.warning,
                        ),
                      ),
                    ),
              ],
            )
          : Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    size: 16, color: AppColors.mint),
                const SizedBox(width: 8),
                Text(
                  'No conflicts detected — your goals align.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
    );
  }

  // ── Scenarios Card ──────────────────────────────────────────────────────

  Widget _buildScenariosCard(PipelineInsight insight, bool isDark) {
    final scenarios = insight.scenarios;
    return _InsightCard(
      isDark: isDark,
      accentColor: const Color(0xFFBA68C8),
      headerTag: 'SCENARIO AGENT',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: scenarios.take(2).map((s) {
          final title = (s['scenario_name'] as String?) ??
              (s['title'] as String?) ??
              'Scenario';
          final desc = (s['description'] as String?) ?? '';
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFBA68C8),
                  ),
                ),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Pipeline Status Card ────────────────────────────────────────────────

  Widget _buildPipelineStatusCard(PipelineInsight insight, bool isDark) {
    const allAgents = [
      ('transaction_agent', 'Transaction Agent', AppColors.electricCyan),
      ('financial_state_agent', 'Financial State Agent', AppColors.mint),
      ('goal_agent', 'Goal Agent', Color(0xFF64B5F6)),
      ('conflict_agent', 'Conflict Agent', AppColors.warning),
      ('scenario_agent', 'Scenario Agent', Color(0xFFBA68C8)),
      ('explanation_agent', 'Explanation Agent', AppColors.electricCyan),
    ];

    return _InsightCard(
      isDark: isDark,
      accentColor: AppColors.electricCyan,
      headerTag: 'PIPELINE EXECUTION',
      child: Column(
        children: allAgents.map((agent) {
          final isComplete = insight.completedStages.contains(agent.$1);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(
                  isComplete
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked,
                  size: 14,
                  color: isComplete ? agent.$3 : (isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight),
                ),
                const SizedBox(width: 8),
                Text(
                  agent.$2,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isComplete ? FontWeight.w700 : FontWeight.w400,
                    color: isComplete
                        ? (isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight)
                        : (isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight),
                  ),
                ),
                const Spacer(),
                if (isComplete)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: agent.$3.withAlpha(25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'DONE',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: agent.$3,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── History Section ─────────────────────────────────────────────────────

  Widget _buildHistorySection(
      List<InsightHistoryItem> history, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ANALYSIS HISTORY',
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
        if (history.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppDimensions.space16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              border: Border.all(
                  color: isDark
                      ? AppColors.navyBorder
                      : const Color(0xFFD6E4F0)),
            ),
            child: Text(
              'No analysis history yet.',
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          )
        else
          Column(
            children: history.map((item) {
              final color =
                  item.isProcessed ? AppColors.mint : AppColors.error;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(AppDimensions.space12),
                  decoration: BoxDecoration(
                    color:
                        isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusMd),
                    border: Border.all(
                      color: isDark
                          ? AppColors.navyBorder
                          : const Color(0xFFD6E4F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        item.isProcessed
                            ? Icons.check_circle_rounded
                            : Icons.error_outline_rounded,
                        size: 14,
                        color: color,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.headline ??
                                  (item.isProcessed ? 'Analysis complete' : 'Processing failed'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (item.processedAt != null)
                              Text(
                                _formatTime(item.processedAt!),
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
                      _StatusBadge(label: item.status, color: color),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  // ── Error state ─────────────────────────────────────────────────────────

  Widget _buildErrorState(
      String error, bool isDark, AiInsightsService svc) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.space32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 48,
                color: isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textTertiaryLight),
            const SizedBox(height: AppDimensions.space16),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: AppDimensions.space16),
            ElevatedButton.icon(
              onPressed: () => svc.refresh(force: true),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.electricCyan,
                foregroundColor: AppColors.deepNavy,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Utilities ───────────────────────────────────────────────────────────

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'STABLE':
      case 'STRONG':
        return AppColors.mint;
      case 'MODERATE':
        return AppColors.warning;
      case 'AT_RISK':
      case 'CRITICAL':
        return AppColors.error;
      default:
        return AppColors.electricCyan;
    }
  }

  Color _cashFlowColor(String status) {
    switch (status.toUpperCase()) {
      case 'POSITIVE':
        return AppColors.mint;
      case 'NEUTRAL':
        return AppColors.electricCyan;
      case 'NEGATIVE':
        return AppColors.error;
      default:
        return AppColors.electricCyan;
    }
  }

  Color _goalStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'ON_TRACK':
      case 'AHEAD':
        return AppColors.mint;
      case 'AT_RISK':
      case 'BEHIND':
        return AppColors.warning;
      case 'INFEASIBLE':
        return AppColors.error;
      default:
        return AppColors.electricCyan;
    }
  }

  String _fmtAmount(dynamic value) {
    if (value == null) return '—';
    final v = (value as num).toDouble();
    if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(2)}Cr';
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(2)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}K';
    return '₹${v.toStringAsFixed(0)}';
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable widgets
// ─────────────────────────────────────────────────────────────────────────────

class _InsightCard extends StatelessWidget {
  final bool isDark;
  final Color accentColor;
  final String headerTag;
  final Widget child;

  const _InsightCard({
    required this.isDark,
    required this.accentColor,
    required this.headerTag,
    required this.child,
  });

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 5,
                height: 5,
                decoration:
                    BoxDecoration(shape: BoxShape.circle, color: accentColor),
              ),
              const SizedBox(width: 7),
              Text(
                headerTag,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.space12),
          child,
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Text(
        label.replaceAll('_', ' '),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _FinTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _FinTile(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
                fontSize: 9,
                color: color.withAlpha(180)),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }
}

class _QuoteBox extends StatelessWidget {
  final String text;
  final bool isDark;
  final Color color;

  const _QuoteBox({
    required this.text,
    required this.isDark,
    this.color = AppColors.electricCyan,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          height: 1.5,
          color: isDark
              ? AppColors.textSecondaryDark
              : AppColors.textSecondaryLight,
        ),
      ),
    );
  }
}

class _AgentChip extends StatelessWidget {
  final String label;
  final Color color;

  const _AgentChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.smart_toy_outlined, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
