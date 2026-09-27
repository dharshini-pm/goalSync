import 'dart:convert';

/// Represents the AI pipeline insight returned by GET /api/v1/insights.
class PipelineInsight {
  final bool available;
  final String? eventId;
  final String? transactionId;
  final String? source;
  final DateTime? processedAt;

  // Agent results
  final Map<String, dynamic>? financialState;
  final List<Map<String, dynamic>>? goals;
  final Map<String, dynamic>? conflict;
  final Map<String, dynamic>? scenario;
  final Map<String, dynamic>? explanation;

  // Metadata
  final List<String> completedStages;

  const PipelineInsight({
    required this.available,
    this.eventId,
    this.transactionId,
    this.source,
    this.processedAt,
    this.financialState,
    this.goals,
    this.conflict,
    this.scenario,
    this.explanation,
    this.completedStages = const [],
  });

  factory PipelineInsight.unavailable() =>
      const PipelineInsight(available: false);

  factory PipelineInsight.fromMap(Map<String, dynamic> map) {
    final goalsRaw = map['goal'];
    List<Map<String, dynamic>>? goalsList;
    if (goalsRaw is List) {
      goalsList = goalsRaw
          .whereType<Map<String, dynamic>>()
          .toList();
    } else if (goalsRaw is Map<String, dynamic>) {
      goalsList = [goalsRaw];
    }

    final stagesRaw = map['completed_stages'];
    final stages = stagesRaw is List
        ? stagesRaw.whereType<String>().toList()
        : <String>[];

    return PipelineInsight(
      available: (map['available'] as bool?) ?? false,
      eventId: map['event_id'] as String?,
      transactionId: map['transaction_id'] as String?,
      source: map['source'] as String?,
      processedAt: map['processed_at'] != null
          ? DateTime.tryParse(map['processed_at'].toString())?.toLocal()
          : null,
      financialState: map['financial_state'] as Map<String, dynamic>?,
      goals: goalsList,
      conflict: map['conflict'] as Map<String, dynamic>?,
      scenario: map['scenario'] as Map<String, dynamic>?,
      explanation: map['explanation'] as Map<String, dynamic>?,
      completedStages: stages,
    );
  }

  // ── Explanation helpers ────────────────────────────────────────────────
  String get headline =>
      (explanation?['headline'] as String?) ??
      (explanation?['summary'] as String?) ??
      'Analysis complete';

  String get summary =>
      (explanation?['summary'] as String?) ?? '';

  // ── Financial state helpers ────────────────────────────────────────────
  String get financialStatus =>
      (financialState?['financial_status'] as String?) ?? 'UNKNOWN';

  String get cashFlowStatus =>
      (financialState?['cash_flow_status'] as String?) ?? 'UNKNOWN';

  // ── Conflict helpers ───────────────────────────────────────────────────
  bool get hasConflict =>
      (conflict?['conflict_detected'] as bool?) ?? false;

  List<Map<String, dynamic>> get conflicts {
    final raw = conflict?['conflicts'];
    if (raw is List) return raw.whereType<Map<String, dynamic>>().toList();
    return [];
  }

  // ── Scenario helpers ───────────────────────────────────────────────────
  bool get hasScenarios =>
      (scenario?['scenario_required'] as bool?) ?? false;

  List<Map<String, dynamic>> get scenarios {
    final raw = scenario?['scenarios'];
    if (raw is List) return raw.whereType<Map<String, dynamic>>().toList();
    return [];
  }

  String toJson() => jsonEncode({
        'available': available,
        'event_id': eventId,
        'transaction_id': transactionId,
        'source': source,
        'processed_at': processedAt?.toUtc().toIso8601String(),
        'financial_state': financialState,
        'goal': goals,
        'conflict': conflict,
        'scenario': scenario,
        'explanation': explanation,
        'completed_stages': completedStages,
      });
}

/// Summary of a past pipeline execution for the history list.
class InsightHistoryItem {
  final String? eventId;
  final String? transactionId;
  final String status;
  final String? source;
  final DateTime? processedAt;
  final String? headline;

  const InsightHistoryItem({
    this.eventId,
    this.transactionId,
    required this.status,
    this.source,
    this.processedAt,
    this.headline,
  });

  factory InsightHistoryItem.fromMap(Map<String, dynamic> map) {
    return InsightHistoryItem(
      eventId: map['event_id'] as String?,
      transactionId: map['transaction_id'] as String?,
      status: (map['status'] as String?) ?? 'UNKNOWN',
      source: map['source'] as String?,
      processedAt: map['processed_at'] != null
          ? DateTime.tryParse(map['processed_at'].toString())?.toLocal()
          : null,
      headline: map['headline'] as String?,
    );
  }

  bool get isProcessed => status == 'PROCESSED';
  bool get isFailed => status == 'FAILED';
}
