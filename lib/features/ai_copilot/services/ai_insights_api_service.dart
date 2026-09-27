import '../../../core/api/api_client.dart';
import '../models/pipeline_insight_model.dart';

/// HTTP service for the GoalSync AI insights API.
///
/// Calls:
///   GET /api/v1/insights           → [PipelineInsight]
///   GET /api/v1/insights/history   → List<[InsightHistoryItem]>
class AiInsightsApiService {
  final ApiClient _client;

  AiInsightsApiService({ApiClient? client})
      : _client = client ?? ApiClient.instance;

  /// Fetch the latest AI pipeline result for the authenticated user.
  Future<PipelineInsight> getLatestInsight() async {
    final response =
        await _client.get('/api/v1/insights', requiresAuth: true);
    if (response is Map<String, dynamic>) {
      return PipelineInsight.fromMap(response);
    }
    return PipelineInsight.unavailable();
  }

  /// Fetch the N most recent pipeline execution summaries.
  Future<List<InsightHistoryItem>> getInsightHistory({int limit = 10}) async {
    final response = await _client.get(
      '/api/v1/insights/history',
      requiresAuth: true,
      queryParameters: {'limit': limit},
    );
    if (response is List) {
      return response
          .whereType<Map<String, dynamic>>()
          .map(InsightHistoryItem.fromMap)
          .toList();
    }
    return [];
  }
}
