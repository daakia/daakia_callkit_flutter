import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/services.dart';

import '../models/daakia_voip_event.dart';

class DaakiaIosVoipService {
  DaakiaIosVoipService._internal();

  static final DaakiaIosVoipService _instance =
      DaakiaIosVoipService._internal();

  factory DaakiaIosVoipService() => _instance;

  static const MethodChannel _channel = MethodChannel(
    'daakia_callkit_flutter/voip',
  );

  final StreamController<DaakiaVoipEvent> _events =
      StreamController<DaakiaVoipEvent>.broadcast();
  bool _initialized = false;

  Stream<DaakiaVoipEvent> get events => _events.stream;

  Future<String?> initialize({
    FutureOr<void> Function(String token)? onVoipTokenUpdated,
  }) async {
    if (!Platform.isIOS || _initialized) return null;

    _channel.setMethodCallHandler((MethodCall call) {
      return _handleNativeCall(call, onVoipTokenUpdated: onVoipTokenUpdated);
    });
    _initialized = true;

    try {
      await _channel.invokeMethod<void>('register');
      final token = await _channel.invokeMethod<String>('getVoipToken');
      if (token != null && token.isNotEmpty) {
        await onVoipTokenUpdated?.call(token);
      }
      return token;
    } catch (error) {
      log('[DaakiaIosVoipService] Failed to initialize: $error');
      return null;
    }
  }

  Future<void> endCall(String? callId) async {
    if (!Platform.isIOS || callId == null || callId.isEmpty) return;

    try {
      await _channel.invokeMethod<void>('endCall', <String, dynamic>{
        'callId': callId,
      });
    } catch (error) {
      log('[DaakiaIosVoipService] Failed to end CallKit call: $error');
    }
  }

  Future<void> setCallConnected(String? callId) async {
    if (!Platform.isIOS || callId == null || callId.isEmpty) return;

    try {
      await _channel.invokeMethod<void>('setCallConnected', <String, dynamic>{
        'callId': callId,
      });
    } catch (error) {
      log(
        '[DaakiaIosVoipService] Failed to mark CallKit call connected: $error',
      );
    }
  }

  Future<dynamic> _handleNativeCall(
    MethodCall call, {
    FutureOr<void> Function(String token)? onVoipTokenUpdated,
  }) async {
    switch (call.method) {
      case 'voipTokenUpdated':
        final token = call.arguments?.toString();
        if (token != null && token.isNotEmpty) {
          await onVoipTokenUpdated?.call(token);
        }
        return null;
      case 'incomingCall':
      case 'callAccepted':
      case 'callDeclined':
      case 'callEnded':
        if (call.arguments is Map) {
          _events.add(
            DaakiaVoipEvent(
              method: call.method,
              payload: Map<String, dynamic>.from(
                call.arguments as Map<dynamic, dynamic>,
              ),
            ),
          );
        }
        return null;
      default:
        return null;
    }
  }
}
