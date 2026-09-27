import 'dart:async';
import 'package:flutter/services.dart';
import 'device_identity.dart';
import 'n8n_webhook_client.dart';

/// Callback signature when an SMS is processed.
typedef SmsEventCallback = void Function(Map<String, dynamic> event);

/// Service managing the Android SMS receiver bridge, permissions, and event dispatch.
///
/// Ensures:
/// - Only newly broadcasted SMS are received (no full inbox polling).
/// - Fails gracefully if permissions are denied or platform channel is unavailable.
/// - Privacy-first pre-filter drops OTPs and non-financial SMS.
/// - Safe development test simulation mode without real bank SMS.
class SmsReceiverService {
  static const MethodChannel _channel =
      MethodChannel('com.goalsync.goalsync/sms_receiver');

  final N8nWebhookClient? webhookClient;
  final SmsEventCallback? onTransactionDispatched;
  final bool enableSimulationMode;

  bool _isListening = false;

  SmsReceiverService({
    this.webhookClient,
    this.onTransactionDispatched,
    this.enableSimulationMode = false,
  });

  /// Starts listening to incoming SMS broadcasts from native Android.
  void initialize() {
    if (_isListening) return;
    _isListening = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onSmsReceived') {
        final raw = call.arguments;
        if (raw is Map) {
          final data = Map<String, dynamic>.from(raw);
          await processIncomingSms(
            body: data['body'] as String? ?? '',
            sender: data['sender'] as String?,
            timestamp: (data['timestamp'] as num?)?.toInt(),
          );
        }
      }
    });
  }

  /// Checks if the Android SMS permission is currently granted.
  Future<bool> checkPermission() async {
    try {
      final granted = await _channel.invokeMethod<bool>('checkPermission');
      return granted ?? false;
    } catch (e) {
      // Graceful fallback on non-Android platforms or test environments
      return false;
    }
  }

  /// Requests the necessary Android SMS permissions.
  Future<bool> requestPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestPermission');
      return result ?? false;
    } catch (e) {
      // Graceful failure: never crash the UI
      return false;
    }
  }

  /// Lightweight Dart-side pre-filter matching the Android native filter.
  static bool isPotentialFinancialSms(String body) {
    final lower = body.toLowerCase();

    // Drop OTP and verification codes immediately
    if (lower.contains('otp') ||
        lower.contains('verification code') ||
        lower.contains('security code') ||
        lower.contains('secret code')) {
      return false;
    }

    // Must contain basic financial/banking signals
    final signals = [
      'debited',
      'debit',
      'credited',
      'credit',
      'paid',
      'payment',
      'spent',
      'withdrawn',
      'purchase',
      'transferred',
      'upi',
      'vpa',
      'atm',
      'imps',
      'neft',
      'a/c',
      'acct',
      'avl bal',
    ];

    for (final s in signals) {
      if (lower.contains(s)) {
        return true;
      }
    }

    return false;
  }

  /// Processes an incoming SMS message.
  Future<WebhookDeliveryResult?> processIncomingSms({
    required String body,
    String? sender,
    int? timestamp,
  }) async {
    if (body.isEmpty) {
      return null;
    }

    // Step 1: Privacy pre-filter — discard non-financial messages
    if (!isPotentialFinancialSms(body)) {
      return null;
    }

    // Step 2: Attach secure user / device identity
    final deviceId = await DeviceIdentity.getDeviceId();
    final userId = await DeviceIdentity.getUserId();

    // Step 3: Construct structured event
    // The authoritative classification and parsing happens at the backend/ingestion boundary
    final event = <String, dynamic>{
      'event_type': 'financial_transaction',
      'source': 'android_sms',
      'sender': sender ?? 'UNKNOWN',
      'raw_content': body,
      'timestamp': timestamp ?? DateTime.now().millisecondsSinceEpoch,
      'device_id': deviceId,
      'user_id': ?userId,
    };

    onTransactionDispatched?.call(event);

    if (webhookClient != null) {
      return await webhookClient!.sendTransactionEvent(event);
    }

    return null;
  }

  /// Development / test simulation method to verify ingestion flow without real SMS.
  Future<WebhookDeliveryResult?> simulateIncomingSms(
    String body, {
    String sender = 'SIM-BANK',
    int? timestamp,
  }) async {
    return await processIncomingSms(
      body: body,
      sender: sender,
      timestamp: timestamp,
    );
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
    _isListening = false;
  }
}
