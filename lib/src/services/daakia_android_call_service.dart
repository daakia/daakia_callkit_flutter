import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

typedef DaakiaAndroidCallEventHandler =
    FutureOr<void> Function(String method, Map<String, dynamic> payload);

class DaakiaAndroidCallService {
  DaakiaAndroidCallService._internal();

  static final DaakiaAndroidCallService _instance =
      DaakiaAndroidCallService._internal();

  factory DaakiaAndroidCallService() => _instance;

  static const MethodChannel _channel = MethodChannel(
    'daakia_callkit_flutter/android_call',
  );

  bool _initialized = false;
  DaakiaAndroidCallEventHandler? _onEvent;

  Future<void> initialize({DaakiaAndroidCallEventHandler? onEvent}) async {
    if (!Platform.isAndroid) return;

    _onEvent = onEvent;
    if (_initialized) {
      await _channel.invokeMethod<void>('register');
      return;
    }

    _channel.setMethodCallHandler(_handleNativeCall);
    _initialized = true;
    await _channel.invokeMethod<void>('register');
  }

  Future<void> showIncomingCall(
    Map<String, dynamic> payload, {
    int timeoutSeconds = 30,
  }) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('showIncomingCall', <String, dynamic>{
      'payload': jsonEncode(payload),
      'timeoutSeconds': timeoutSeconds,
    });
  }

  Future<void> endCall(String? callId) async {
    if (!Platform.isAndroid || callId == null || callId.isEmpty) return;
    await _channel.invokeMethod<void>('endCall', <String, dynamic>{
      'callId': callId,
    });
  }

  Future<void> setCallConnected(String? callId) async {
    if (!Platform.isAndroid || callId == null || callId.isEmpty) return;
    await _channel.invokeMethod<void>('setCallConnected', <String, dynamic>{
      'callId': callId,
    });
  }

  Future<bool> canUseFullScreenIntent() async {
    if (!Platform.isAndroid) return true;
    final result = await _channel.invokeMethod<bool>('canUseFullScreenIntent');
    return result ?? true;
  }

  Future<bool> openFullScreenIntentSettings() async {
    if (!Platform.isAndroid) return false;
    final result = await _channel.invokeMethod<bool>(
      'openFullScreenIntentSettings',
    );
    return result ?? false;
  }

  Future<void> configureCallEventFallback({
    required String baseUrl,
    required String secret,
    required Set<String> actions,
    Map<String, dynamic>? metadata,
  }) async {
    if (!Platform.isAndroid) return;
    await _channel
        .invokeMethod<void>('configureCallEventFallback', <String, dynamic>{
          'baseUrl': baseUrl,
          'secret': secret,
          'actions': actions.toList(),
          'metadata': metadata ?? <String, dynamic>{},
        });
  }

  Future<void> clearCallEventFallback() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('clearCallEventFallback');
  }

  Future<bool> wasCallEventSent({
    required String meetingUid,
    required String action,
  }) async {
    if (!Platform.isAndroid) return false;
    final result = await _channel.invokeMethod<bool>(
      'wasCallEventSent',
      <String, dynamic>{'meetingUid': meetingUid, 'action': action},
    );
    return result ?? false;
  }

  Future<void> markCallEventSent({
    required String meetingUid,
    required String action,
  }) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('markCallEventSent', <String, dynamic>{
      'meetingUid': meetingUid,
      'action': action,
    });
  }

  Future<void> clearSentCallEventCache() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('clearSentCallEventCache');
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    if (call.arguments is! Map) return;
    final payload = Map<String, dynamic>.from(
      call.arguments as Map<dynamic, dynamic>,
    );
    await _onEvent?.call(call.method, payload);
  }
}
