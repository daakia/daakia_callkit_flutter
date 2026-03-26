import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;

import 'package:daakia_callkit_flutter/daakia_callkit_flutter.dart';

void main() {
  test('resolves config_name by platform and iOS environment', () {
    const config = DaakiaCallkitConfig(
      baseUrl: 'https://stag-api.daakia.co.in',
      secret: 'secret',
    );
    final sdk = DaakiaCallkitFlutter(config: config);

    expect(sdk.resolveConfigName(platform: DaakiaPlatform.android), 'prod');
    expect(
      sdk.resolveConfigName(platform: DaakiaPlatform.ios, isIosSandbox: true),
      'dev',
    );
    expect(
      sdk.resolveConfigName(platform: DaakiaPlatform.ios, isIosSandbox: false),
      'prod',
    );
  });

  test('call event maps voip event into iOS platform event', () {
    final event = DaakiaCallEvent.fromVoipEvent(
      const DaakiaVoipEvent(
        method: 'callAccepted',
        payload: <String, dynamic>{
          'type': 'incoming_call',
          'callId': 'call_1',
          'sender': '{"uid":"caller_1","userName":"Caller"}',
          'callerId': 'caller_1',
          'receiverId': 'receiver_1',
        },
      ),
    );

    expect(event.method, 'callAccepted');
    expect(event.platform, DaakiaPlatform.ios);
    expect(event.type, DaakiaCallEventType.accepted);
    expect(event.call.callId, 'call_1');
    expect(event.call.sender.userName, 'Caller');
  });

  test('registerCurrentDevice sends expected request payload', () async {
    late Uri capturedUri;
    late Map<String, String> capturedHeaders;
    late String capturedBody;

    final mockClient = MockClient((http.Request request) async {
      capturedUri = request.url;
      capturedHeaders = request.headers;
      capturedBody = request.body;
      return http.Response(
        '''
        {
          "success": 1,
          "message": "Device token updated successfully",
          "data": {
            "id": 1,
            "saas_user_id": 38315,
            "username": "user_1",
            "token": "token_123",
            "voip_token": "voip_123",
            "platform": "android"
          }
        }
        ''',
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });

    final sdk = DaakiaCallkitFlutter(
      config: const DaakiaCallkitConfig(
        baseUrl: 'https://stag-api.daakia.co.in',
        secret: 'top-secret',
      ),
      httpClient: mockClient,
    );

    final result = await sdk.registerCurrentDevice(
      username: 'user_1',
      token: 'token_123',
      platform: DaakiaPlatform.android,
      voipToken: 'voip_123',
    );

    expect(
      capturedUri.toString(),
      contains('/v2.0/saas/device-token/register'),
    );
    expect(capturedHeaders['secret'], 'top-secret');
    expect(capturedBody, contains('"username":"user_1"'));
    expect(capturedBody, contains('"token":"token_123"'));
    expect(capturedBody, contains('"voip_token":"voip_123"'));
    expect(capturedBody, contains('"platform":"android"'));
    expect(result.username, 'user_1');
    expect(result.token, 'token_123');
    expect(result.voipToken, 'voip_123');
  });

  test('startCallByUsername sends username-based trigger payload', () async {
    late String capturedBody;

    final mockClient = MockClient((http.Request request) async {
      capturedBody = request.body;
      return http.Response(
        '''
        {
          "success": 1,
          "message": "Push notification triggered",
          "data": {
            "username": "user_2",
            "config_name": "prod",
            "android": {
              "total_tokens": 1,
              "sent": 1,
              "failed": 0,
              "errors": []
            },
            "ios": {
              "total_tokens": 0,
              "sent": 0,
              "failed": 0,
              "errors": []
            },
            "overall": {
              "total_tokens": 1,
              "sent": 1,
              "failed": 0
            }
          }
        }
        ''',
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });

    final sdk = DaakiaCallkitFlutter(
      config: const DaakiaCallkitConfig(
        baseUrl: 'https://stag-api.daakia.co.in',
        secret: 'top-secret',
      ),
      httpClient: mockClient,
    );

    final result = await sdk.startCallByUsername(
      username: 'user_2',
      title: 'Caller',
      message: 'Incoming call',
      data: const <String, dynamic>{'type': 'incoming_call', 'callId': 'abc'},
    );

    expect(capturedBody, contains('"username":"user_2"'));
    expect(capturedBody, contains('"config_name":"prod"'));
    expect(capturedBody, isNot(contains('"platform"')));
    expect(result.success, isTrue);
    expect(result.data['overall'], isA<Map<String, dynamic>>());
  });

  test('startCallByToken sends token-based trigger payload', () async {
    late String capturedBody;

    final mockClient = MockClient((http.Request request) async {
      capturedBody = request.body;
      return http.Response(
        '''
        {
          "success": 1,
          "message": "Push notification triggered",
          "data": {
            "token": "token_456",
            "platform": "ios",
            "config_name": "prod",
            "sent": 1,
            "failed": 0,
            "errors": []
          }
        }
        ''',
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });

    final sdk = DaakiaCallkitFlutter(
      config: const DaakiaCallkitConfig(
        baseUrl: 'https://stag-api.daakia.co.in',
        secret: 'top-secret',
      ),
      httpClient: mockClient,
    );

    final result = await sdk.startCallByToken(
      token: 'token_456',
      platform: DaakiaPlatform.ios,
      title: 'Ashif Airtel',
      message: 'Incoming call',
      data: const <String, dynamic>{
        'type': 'incoming_call',
        'callId': 'meeting_uid_123',
        'sender': '{"uid":"caller_1","userName":"Ashif Airtel"}',
        'callerId': 'caller_1',
        'receiverId': 'receiver_1',
      },
    );

    expect(capturedBody, contains('"token":"token_456"'));
    expect(capturedBody, contains('"platform":"ios"'));
    expect(capturedBody, contains('"config_name":"prod"'));
    expect(capturedBody, contains('"type":"incoming_call"'));
    expect(capturedBody, contains('"callId":"meeting_uid_123"'));
    expect(result.success, isTrue);
    expect(result.data['sent'], 1);
  });

  test('incoming payload parser handles direct payload with string sender', () {
    final payload = DaakiaIncomingCallPayload.fromMap(const <String, dynamic>{
      'type': 'incoming_call',
      'callId': 'abc',
      'sender': '{"uid":"caller_1","userName":"Caller"}',
      'callerId': 'caller_1',
      'receiverId': 'receiver_1',
      'title': 'Caller',
      'body': 'Incoming call',
    });

    expect(payload.type, 'incoming_call');
    expect(payload.callId, 'abc');
    expect(payload.sender.uid, 'caller_1');
    expect(payload.sender.userName, 'Caller');
  });

  test(
    'incoming payload parser still tolerates legacy nested type payload',
    () {
      final payload = DaakiaIncomingCallPayload.fromMap(const <String, dynamic>{
        'type': <String, dynamic>{
          'type': 'incoming_call',
          'callId': 'legacy_abc',
          'sender': <String, dynamic>{'uid': 'caller_2', 'userName': 'Legacy'},
        },
      });

      expect(payload.type, 'incoming_call');
      expect(payload.callId, 'legacy_abc');
      expect(payload.sender.uid, 'caller_2');
    },
  );
}
