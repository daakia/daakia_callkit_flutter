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
      'stag',
    );
    expect(
      sdk.resolveConfigName(platform: DaakiaPlatform.ios, isIosSandbox: false),
      'prod',
    );
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
      additionalFields: const <String, dynamic>{'upcoming_token': 'todo'},
    );

    expect(
      capturedUri.toString(),
      contains('/v2.0/saas/device-token/register'),
    );
    expect(capturedHeaders['secret'], 'top-secret');
    expect(capturedBody, contains('"username":"user_1"'));
    expect(capturedBody, contains('"token":"token_123"'));
    expect(capturedBody, contains('"platform":"android"'));
    expect(capturedBody, contains('"upcoming_token":"todo"'));
    expect(result.username, 'user_1');
    expect(result.token, 'token_123');
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
      platform: DaakiaPlatform.android,
      title: 'Caller',
      message: 'Incoming call',
      data: const <String, dynamic>{
        'type': <String, dynamic>{'type': 'incoming_call', 'callId': 'abc'},
      },
    );

    expect(capturedBody, contains('"username":"user_2"'));
    expect(capturedBody, contains('"config_name":"prod"'));
    expect(result.success, isTrue);
    expect(result.data['overall'], isA<Map<String, dynamic>>());
  });

  test('incoming payload parser handles backend nested type object', () {
    final payload = DaakiaIncomingCallPayload.fromMap(const <String, dynamic>{
      'type': <String, dynamic>{
        'type': 'incoming_call',
        'callId': 'abc',
        'sender': <String, dynamic>{'uid': 'caller_1', 'userName': 'Caller'},
        'callerId': 'caller_1',
        'receiverId': 'receiver_1',
        'title': 'Caller',
        'body': 'Incoming call',
      },
    });

    expect(payload.type, 'incoming_call');
    expect(payload.callId, 'abc');
    expect(payload.sender.uid, 'caller_1');
    expect(payload.sender.userName, 'Caller');
  });
}
