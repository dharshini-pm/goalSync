import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:goalsync/core/sms_ingestion/device_identity.dart';
import 'package:goalsync/core/sms_ingestion/n8n_webhook_client.dart';
import 'package:goalsync/core/sms_ingestion/sms_receiver_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('N8nWebhookClient Tests', () {
    test('HMAC-SHA256 signature matches expected digest', () {
      const payload = '{"amount":450.0,"merchant":"SWIGGY"}';
      const secret = 'my-secret-key-123';

      final sig1 = N8nWebhookClient.computeSignature(payload, secret);
      final sig2 = N8nWebhookClient.computeSignature(payload, secret);

      expect(sig1.length, 64);
      expect(sig1, equals(sig2));
      // Different payload yields different signature
      final sigDiff = N8nWebhookClient.computeSignature('diff', secret);
      expect(sig1, isNot(equals(sigDiff)));
    });

    test('Missing webhook URL handled gracefully', () async {
      final client = N8nWebhookClient(webhookUrl: '');
      final res = await client.sendTransactionEvent({
        'amount': 500.0,
      });

      expect(res.success, isFalse);
      expect(res.message, contains('Missing GOALSYNC_N8N_WEBHOOK_URL'));
    });

    test('Successful delivery sends correct headers and signature', () async {
      String? capturedSignature;
      String? capturedBody;

      final mockClient = MockClient((request) async {
        capturedSignature = request.headers['X-GoalSync-Signature'];
        capturedBody = request.body;
        return http.Response('{"status":"ok"}', 200);
      });

      final client = N8nWebhookClient(
        webhookUrl: 'https://n8n.example.com/webhook/transaction',
        webhookSecret: 'test-secret',
        httpClient: mockClient,
      );

      final event = {
        'event_type': 'financial_transaction',
        'amount': 450.0,
        'merchant': 'SWIGGY',
        'fingerprint': 'fp_12345',
      };

      final res = await client.sendTransactionEvent(event);

      expect(res.success, isTrue);
      expect(res.statusCode, 200);
      expect(capturedSignature, isNotNull);
      expect(capturedBody, isNotNull);
      expect(jsonDecode(capturedBody!)['merchant'], equals('SWIGGY'));
    });

    test('Duplicate fingerprint is skipped', () async {
      int callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        return http.Response('{"status":"ok"}', 200);
      });

      final client = N8nWebhookClient(
        webhookUrl: 'https://n8n.example.com/webhook',
        httpClient: mockClient,
      );

      final event = {
        'amount': 100.0,
        'fingerprint': 'unique_fp_999',
      };

      final res1 = await client.sendTransactionEvent(event);
      expect(res1.success, isTrue);
      expect(res1.isDuplicate, isFalse);
      expect(callCount, 1);

      // Second attempt with same fingerprint
      final res2 = await client.sendTransactionEvent(event);
      expect(res2.success, isTrue);
      expect(res2.isDuplicate, isTrue);
      expect(callCount, 1); // No second HTTP request made
    });

    test('Network failure triggers offline queueing with bounded retries', () async {
      int callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        throw Exception('Network unreachable');
      });

      final client = N8nWebhookClient(
        webhookUrl: 'https://n8n.example.com/webhook',
        maxRetries: 3,
        httpClient: mockClient,
      );

      final event = {
        'amount': 250.0,
        'fingerprint': 'offline_fp_001',
      };

      final res = await client.sendTransactionEvent(event);

      expect(res.success, isFalse);
      expect(res.isQueued, isTrue);
      expect(callCount, 3); // Exactly 3 bounded attempts

      final queueCount = await client.getPendingQueueCount();
      expect(queueCount, 1);
    });

    test('Flushing offline queue delivers pending events when network restored', () async {
      // Step 1: fail and queue
      final failClient = MockClient((request) async {
        throw Exception('Offline');
      });

      final client1 = N8nWebhookClient(
        webhookUrl: 'https://n8n.example.com/webhook',
        maxRetries: 1,
        httpClient: failClient,
      );

      await client1.sendTransactionEvent({
        'amount': 300.0,
        'fingerprint': 'flush_fp_1',
      });

      expect(await client1.getPendingQueueCount(), 1);

      // Step 2: network restored
      final successClient = MockClient((request) async {
        return http.Response('{"status":"ok"}', 200);
      });

      final client2 = N8nWebhookClient(
        webhookUrl: 'https://n8n.example.com/webhook',
        httpClient: successClient,
      );

      final flushed = await client2.flushPendingQueue();
      expect(flushed, 1);
      expect(await client2.getPendingQueueCount(), 0);
    });
  });

  group('DeviceIdentity Tests', () {
    test('Generates stable anonymous device ID', () async {
      final devId1 = await DeviceIdentity.getDeviceId();
      final devId2 = await DeviceIdentity.getDeviceId();

      expect(devId1, startsWith('dev_'));
      expect(devId1, equals(devId2));
    });

    test('Sets and retrieves authenticated user ID', () async {
      expect(await DeviceIdentity.getUserId(), isNull);

      await DeviceIdentity.setUserId('user_abc_123');
      expect(await DeviceIdentity.getUserId(), equals('user_abc_123'));

      await DeviceIdentity.clear();
      expect(await DeviceIdentity.getUserId(), isNull);
    });
  });

  group('SmsReceiverService Pre-filter & Simulation Tests', () {
    test('Pre-filter accepts banking SMS and rejects OTP/promo', () {
      expect(
        SmsReceiverService.isPotentialFinancialSms('Your A/c is debited by Rs.450 at SWIGGY'),
        isTrue,
      );
      expect(
        SmsReceiverService.isPotentialFinancialSms('Rs 500 credited to account via UPI'),
        isTrue,
      );
      expect(
        SmsReceiverService.isPotentialFinancialSms('Your OTP for transaction is 123456'),
        isFalse,
      );
      expect(
        SmsReceiverService.isPotentialFinancialSms('Happy birthday to you!'),
        isFalse,
      );
    });

    test('Simulation mode dispatches valid transaction', () async {
      Map<String, dynamic>? dispatchedEvent;

      final service = SmsReceiverService(
        onTransactionDispatched: (event) {
          dispatchedEvent = event;
        },
      );

      await service.simulateIncomingSms(
        'Your A/c XX1234 is debited by Rs.450.00 at SWIGGY. Avl Bal Rs.12,450.00',
        sender: 'TEST-HDFCBK',
      );

      expect(dispatchedEvent, isNotNull);
      expect(dispatchedEvent!['event_type'], equals('financial_transaction'));
      expect(dispatchedEvent!['sender'], equals('TEST-HDFCBK'));
      expect(dispatchedEvent!['device_id'], isNotNull);
    });
  });
}
