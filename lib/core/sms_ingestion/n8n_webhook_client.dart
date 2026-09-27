import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Result status of delivering an event to the n8n webhook.
class WebhookDeliveryResult {
  final bool success;
  final bool isDuplicate;
  final bool isQueued;
  final int statusCode;
  final String message;
  final String? signature;

  const WebhookDeliveryResult({
    required this.success,
    this.isDuplicate = false,
    this.isQueued = false,
    this.statusCode = 0,
    required this.message,
    this.signature,
  });

  @override
  String toString() =>
      'WebhookDeliveryResult(success: $success, duplicate: $isDuplicate, queued: $isQueued, code: $statusCode, message: $message)';
}

/// Secure client for transmitting structured financial transaction events to the n8n webhook.
///
/// Features:
/// - HMAC-SHA256 request signing (`X-GoalSync-Signature`)
/// - Bounded retries (max 3 attempts) with timeout
/// - Duplicate suppression via deterministic fingerprints
/// - Offline resilience via local SharedPreferences queue
/// - Strict privacy: never logs secrets or full raw SMS text
class N8nWebhookClient {
  static const String _prefPendingQueueKey = 'goalsync_n8n_pending_queue';
  static const String _prefFingerprintsKey = 'goalsync_processed_fingerprints';

  final String webhookUrl;
  final String? webhookSecret;
  final http.Client _httpClient;
  final Duration timeout;
  final int maxRetries;

  // In-memory cache of delivered fingerprints to prevent duplicate forwarding
  final Set<String> _processedFingerprints = <String>{};

  N8nWebhookClient({
    required this.webhookUrl,
    this.webhookSecret,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 10),
    this.maxRetries = 3,
  }) : _httpClient = httpClient ?? http.Client();

  /// Computes HMAC-SHA256 signature over the UTF-8 payload.
  static String computeSignature(String payload, String secret) {
    final keyBytes = utf8.encode(secret);
    final payloadBytes = utf8.encode(payload);
    final hmac = Hmac(sha256, keyBytes);
    return hmac.convert(payloadBytes).toString();
  }

  /// Checks if a fingerprint has already been processed.
  Future<bool> isDuplicate(String fingerprint) async {
    if (_processedFingerprints.contains(fingerprint)) {
      return true;
    }
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_prefFingerprintsKey) ?? [];
    return stored.contains(fingerprint);
  }

  /// Records a fingerprint as delivered.
  Future<void> _recordFingerprint(String fingerprint) async {
    _processedFingerprints.add(fingerprint);
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_prefFingerprintsKey) ?? [];
    if (!stored.contains(fingerprint)) {
      stored.add(fingerprint);
      // Keep only last 500 fingerprints to bound local storage
      if (stored.length > 500) {
        stored.removeRange(0, stored.length - 500);
      }
      await prefs.setStringList(_prefFingerprintsKey, stored);
    }
  }

  /// Sends a structured financial transaction event to the n8n webhook.
  Future<WebhookDeliveryResult> sendTransactionEvent(
    Map<String, dynamic> event,
  ) async {
    if (webhookUrl.isEmpty) {
      return const WebhookDeliveryResult(
        success: false,
        message: 'Missing GOALSYNC_N8N_WEBHOOK_URL configuration',
      );
    }

    final fingerprint = event['fingerprint'] as String? ?? '';
    if (fingerprint.isNotEmpty && await isDuplicate(fingerprint)) {
      return const WebhookDeliveryResult(
        success: true,
        isDuplicate: true,
        message: 'Duplicate event skipped (fingerprint already delivered)',
      );
    }

    final payloadJson = jsonEncode(event);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'X-GoalSync-Source': 'android_sms',
    };

    String? signature;
    if (webhookSecret != null && webhookSecret!.isNotEmpty) {
      signature = computeSignature(payloadJson, webhookSecret!);
      headers['X-GoalSync-Signature'] = signature;
    }

    // Bounded retry loop
    int attempt = 0;
    while (attempt < maxRetries) {
      attempt++;
      try {
        final uri = Uri.parse(webhookUrl);
        final response = await _httpClient
            .post(
              uri,
              headers: headers,
              body: payloadJson,
            )
            .timeout(timeout);

        if (response.statusCode >= 200 && response.statusCode < 300) {
          if (fingerprint.isNotEmpty) {
            await _recordFingerprint(fingerprint);
          }
          return WebhookDeliveryResult(
            success: true,
            statusCode: response.statusCode,
            message: 'Delivered to n8n successfully',
            signature: signature,
          );
        } else {
          // If server error (5xx), retry; if client error (4xx), do not retry
          if (response.statusCode >= 400 && response.statusCode < 500) {
            return WebhookDeliveryResult(
              success: false,
              statusCode: response.statusCode,
              message: 'n8n webhook rejected request with status ${response.statusCode}',
              signature: signature,
            );
          }
        }
      } catch (e) {
        // Network or timeout failure on this attempt
        if (attempt >= maxRetries) {
          // All retries exhausted: enqueue locally for offline sync
          await _enqueueOfflineEvent(event);
          return WebhookDeliveryResult(
            success: false,
            isQueued: true,
            message: 'Webhook unreachable after $maxRetries attempts; queued for offline retry',
            signature: signature,
          );
        }
        // Brief exponential backoff
        await Future.delayed(Duration(milliseconds: 100 * attempt));
      }
    }

    await _enqueueOfflineEvent(event);
    return WebhookDeliveryResult(
      success: false,
      isQueued: true,
      message: 'Failed to deliver event; queued locally',
      signature: signature,
    );
  }

  /// Enqueues an unsent event into local SharedPreferences queue.
  Future<void> _enqueueOfflineEvent(Map<String, dynamic> event) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queue = prefs.getStringList(_prefPendingQueueKey) ?? [];
      queue.add(jsonEncode(event));
      // Cap offline queue at 100 events to prevent memory/storage bloat
      if (queue.length > 100) {
        queue.removeAt(0);
      }
      await prefs.setStringList(_prefPendingQueueKey, queue);
    } catch (_) {
      // Graceful degradation: never crash on storage error
    }
  }

  /// Flushes pending offline events when network is restored.
  Future<int> flushPendingQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList(_prefPendingQueueKey) ?? [];
    if (queue.isEmpty) {
      return 0;
    }

    int deliveredCount = 0;
    final remaining = <String>[];

    for (final rawEvent in queue) {
      try {
        final event = jsonDecode(rawEvent) as Map<String, dynamic>;
        final res = await sendTransactionEvent(event);
        if (res.success) {
          deliveredCount++;
        } else {
          remaining.add(rawEvent);
        }
      } catch (_) {
        remaining.add(rawEvent);
      }
    }

    await prefs.setStringList(_prefPendingQueueKey, remaining);
    return deliveredCount;
  }

  /// Retrieves the current count of queued offline events.
  Future<int> getPendingQueueCount() async {
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList(_prefPendingQueueKey) ?? [];
    return queue.length;
  }

  /// Clears the pending offline queue (useful for testing).
  @visibleForTesting
  Future<void> clearQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefPendingQueueKey);
  }

  /// Clears cached fingerprints (useful for testing).
  @visibleForTesting
  Future<void> clearFingerprints() async {
    _processedFingerprints.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefFingerprintsKey);
  }

  void dispose() {
    _httpClient.close();
  }
}
