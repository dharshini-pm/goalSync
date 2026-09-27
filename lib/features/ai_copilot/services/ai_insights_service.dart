import 'package:flutter/foundation.dart';
import '../../../core/api/api_client.dart';
import '../models/pipeline_insight_model.dart';
import 'ai_insights_api_service.dart';

/// State management service for the AI Copilot feature.
///
/// Fetches and caches the latest pipeline insight and execution history
/// from the GoalSync backend. Notifies listeners on state changes.
class AiInsightsService extends ChangeNotifier {
  static AiInsightsService? _instance;
  static AiInsightsService get instance =>
      _instance ??= AiInsightsService._();

  AiInsightsService._({AiInsightsApiService? api})
      : _api = api ?? AiInsightsApiService();

  @visibleForTesting
  static void resetForTesting() {
    _instance = null;
  }

  final AiInsightsApiService _api;

  PipelineInsight? _latestInsight;
  List<InsightHistoryItem> _history = [];
  bool _isLoading = false;
  String? _error;
  DateTime? _lastFetched;

  // ── Public getters ───────────────────────────────────────────────────────

  /// The most recent pipeline insight, or `null` if not yet loaded.
  PipelineInsight? get latestInsight => _latestInsight;

  /// Whether a pipeline insight is available.
  bool get hasInsight => _latestInsight?.available ?? false;

  /// Execution history (most recent first).
  List<InsightHistoryItem> get history => List.unmodifiable(_history);

  bool get isLoading => _isLoading;
  String? get error => _error;

  /// True when data has been fetched at least once.
  bool get hasData => _latestInsight != null || _history.isNotEmpty;

  // ── API calls ────────────────────────────────────────────────────────────

  /// Refresh both the latest insight and the history from the backend.
  Future<void> refresh({bool force = false}) async {
    // Debounce: skip if we fetched within the last 30 seconds, unless forced.
    if (!force && _lastFetched != null) {
      final elapsed = DateTime.now().difference(_lastFetched!);
      if (elapsed.inSeconds < 30) return;
    }

    if (ApiClient.instance.authToken == null) {
      _setError('Not authenticated');
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _api.getLatestInsight(),
        _api.getInsightHistory(limit: 10),
      ]);

      _latestInsight = results[0] as PipelineInsight;
      _history = results[1] as List<InsightHistoryItem>;
      _lastFetched = DateTime.now();
    } catch (e) {
      _error = _parseError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch only the latest insight (lighter call for polling).
  Future<void> refreshLatest() async {
    if (ApiClient.instance.authToken == null) return;
    try {
      _latestInsight = await _api.getLatestInsight();
      _lastFetched = DateTime.now();
      notifyListeners();
    } catch (_) {
      // Silently ignore polling errors
    }
  }

  void _setError(String message) {
    _error = message;
    _isLoading = false;
    notifyListeners();
  }

  String _parseError(Object e) {
    final msg = e.toString();
    if (msg.contains('401') || msg.contains('403')) {
      return 'Session expired. Please log in again.';
    }
    if (msg.contains('Connection') || msg.contains('timeout')) {
      return 'Cannot reach GoalSync server. Check your connection.';
    }
    return 'Failed to load AI insights. Try again.';
  }

  /// Clear all cached data (e.g. on logout).
  void clear() {
    _latestInsight = null;
    _history = [];
    _error = null;
    _isLoading = false;
    _lastFetched = null;
    notifyListeners();
  }
}
