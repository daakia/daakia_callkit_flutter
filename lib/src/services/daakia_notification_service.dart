import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/daakia_call_event.dart';
import '../models/daakia_incoming_call_payload.dart';
import '../models/daakia_platform.dart';
import 'daakia_android_call_service.dart';

typedef DaakiaIncomingCallHandler =
    Future<void> Function(DaakiaIncomingCallPayload payload);

@pragma('vm:entry-point')
Future<void> onDaakiaNotificationResponseBackground(
  NotificationResponse response,
) async {
  await DaakiaNotificationService.instance.handleNotificationResponse(
    response,
    fromBackground: true,
  );
}

class DaakiaNotificationService {
  DaakiaNotificationService._internal();

  static final DaakiaNotificationService instance =
      DaakiaNotificationService._internal();

  factory DaakiaNotificationService() => instance;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final StreamController<DaakiaCallEvent> _events =
      StreamController<DaakiaCallEvent>.broadcast();

  bool _initialized = false;
  DaakiaIncomingCallHandler? _onIncomingCall;
  DaakiaIncomingCallHandler? _onAcceptCall;
  DaakiaIncomingCallHandler? _onRejectCall;

  static const String _defaultChannelId = 'daakia_default_channel';
  static const String _callChannelId = 'daakia_call_channel_system_ringtone';
  static const String _acceptCallActionId = 'accept_call';
  static const String _rejectCallActionId = 'reject_call';
  static const UriAndroidNotificationSound _androidSystemRingtoneSound =
      UriAndroidNotificationSound('content://settings/system/ringtone');
  static final Int64List _callVibrationPattern = Int64List.fromList(<int>[
    0,
    700,
    500,
    900,
  ]);

  Stream<DaakiaCallEvent> get events => _events.stream;

  Future<void> initialize({
    DaakiaIncomingCallHandler? onIncomingCall,
    DaakiaIncomingCallHandler? onAcceptCall,
    DaakiaIncomingCallHandler? onRejectCall,
  }) async {
    _onIncomingCall = onIncomingCall;
    _onAcceptCall = onAcceptCall;
    _onRejectCall = onRejectCall;
    if (_initialized) {
      if (_hasAndroidEventHandlers) {
        await DaakiaAndroidCallService().initialize(
          onEvent: _handleAndroidCallEvent,
        );
      }
      return;
    }

    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final DarwinInitializationSettings darwinInit =
        DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          notificationCategories: <DarwinNotificationCategory>[
            DarwinNotificationCategory(
              _callChannelId,
              actions: <DarwinNotificationAction>[
                DarwinNotificationAction.plain(
                  _rejectCallActionId,
                  'Reject',
                  options: <DarwinNotificationActionOption>{
                    DarwinNotificationActionOption.destructive,
                  },
                ),
                DarwinNotificationAction.plain(
                  _acceptCallActionId,
                  'Accept',
                  options: <DarwinNotificationActionOption>{
                    DarwinNotificationActionOption.foreground,
                  },
                ),
              ],
              options: <DarwinNotificationCategoryOption>{
                DarwinNotificationCategoryOption.customDismissAction,
              },
            ),
          ],
        );

    final InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          onDaakiaNotificationResponseBackground,
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _defaultChannelId,
        'General Notifications',
        description: 'General notifications',
        importance: Importance.high,
      ),
    );
    await androidPlugin?.createNotificationChannel(
      AndroidNotificationChannel(
        _callChannelId,
        'Calls',
        description: 'Incoming call notifications',
        importance: Importance.max,
        playSound: true,
        sound: _androidSystemRingtoneSound,
        enableVibration: true,
        vibrationPattern: _callVibrationPattern,
      ),
    );

    if (_hasAndroidEventHandlers) {
      await DaakiaAndroidCallService().initialize(
        onEvent: _handleAndroidCallEvent,
      );
    }

    _initialized = true;
  }

  bool get _hasAndroidEventHandlers =>
      Platform.isAndroid &&
      (_onIncomingCall != null ||
          _onAcceptCall != null ||
          _onRejectCall != null);

  Future<void> handleNotificationResponse(
    NotificationResponse response, {
    bool fromBackground = false,
  }) async {
    if (response.payload == null) return;

    final source = jsonDecode(response.payload!) as Map<String, dynamic>;
    final payload = DaakiaIncomingCallPayload.fromMap(source);
    final actionId = response.actionId;

    if (actionId == _rejectCallActionId) {
      _emitEvent('callDeclined', source);
      await _onRejectCall?.call(payload);
      await dismissIncomingCallNotification(payload.callId);
      return;
    }

    if (actionId == _acceptCallActionId) {
      _emitEvent('callAccepted', source);
      await _onAcceptCall?.call(payload);
      await dismissIncomingCallNotification(payload.callId);
      return;
    }

    _emitEvent('incomingCall', source);
    await _onIncomingCall?.call(payload);
    if (!fromBackground) {
      await dismissIncomingCallNotification(payload.callId);
    }
  }

  Future<void> showIncomingCallNotificationFromData(
    Map<String, dynamic> data,
  ) async {
    if (Platform.isAndroid) {
      await DaakiaAndroidCallService().showIncomingCall(data);
      return;
    }

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          _callChannelId,
          'Calls',
          channelDescription: 'Incoming calls',
          importance: Importance.max,
          priority: Priority.max,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.call,
          visibility: NotificationVisibility.public,
          playSound: true,
          sound: _androidSystemRingtoneSound,
          audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
          enableVibration: true,
          vibrationPattern: _callVibrationPattern,
          ongoing: true,
          autoCancel: false,
          ticker: 'Incoming call',
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction(
              _rejectCallActionId,
              'Reject',
              showsUserInterface: true,
              cancelNotification: true,
              titleColor: Colors.red,
            ),
            AndroidNotificationAction(
              _acceptCallActionId,
              'Accept',
              showsUserInterface: true,
              cancelNotification: true,
              titleColor: Colors.green,
            ),
          ],
        );

    const DarwinNotificationDetails darwinDetails = DarwinNotificationDetails(
      categoryIdentifier: _callChannelId,
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _localNotifications.show(
      _callNotificationIdFromData(data),
      data['title']?.toString() ?? 'Incoming Call',
      data['body']?.toString() ?? 'Tap to answer',
      details,
      payload: jsonEncode(data),
    );
  }

  Future<void> dismissIncomingCallNotification(String? callId) async {
    if (callId == null || callId.isEmpty) return;
    if (Platform.isAndroid) {
      await DaakiaAndroidCallService().endCall(callId);
      return;
    }
    await _localNotifications.cancel(callId.hashCode);
  }

  Future<void> showMissedCallNotification({
    required String callId,
    String title = 'Missed call',
    String body = 'You missed a call',
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          _defaultChannelId,
          'General Notifications',
          channelDescription: 'General notifications',
          importance: Importance.high,
          priority: Priority.high,
        );

    const DarwinNotificationDetails darwinDetails = DarwinNotificationDetails();

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _localNotifications.show(
      '${callId}_missed'.hashCode,
      title,
      body,
      details,
    );
  }

  Future<bool> canUseFullScreenIntent() {
    return DaakiaAndroidCallService().canUseFullScreenIntent();
  }

  Future<bool> openFullScreenIntentSettings() {
    return DaakiaAndroidCallService().openFullScreenIntentSettings();
  }

  int _callNotificationIdFromData(Map<String, dynamic> data) {
    final callId = data['callId']?.toString();
    if (callId != null && callId.isNotEmpty) {
      return callId.hashCode;
    }
    return data.hashCode;
  }

  Future<void> _handleAndroidCallEvent(
    String method,
    Map<String, dynamic> payload,
  ) async {
    _emitEvent(method, payload);
    final callPayload = DaakiaIncomingCallPayload.fromMap(payload);

    switch (method) {
      case 'incomingCall':
        return;
      case 'callAccepted':
        await _onAcceptCall?.call(callPayload);
        return;
      case 'callDeclined':
        await _onRejectCall?.call(callPayload);
        return;
      case 'callEnded':
        await DaakiaAndroidCallService().endCall(callPayload.callId);
        return;
      default:
        return;
    }
  }

  void _emitEvent(String method, Map<String, dynamic> payload) {
    _events.add(
      DaakiaCallEvent(
        method: method,
        payload: payload,
        platform: Platform.isIOS ? DaakiaPlatform.ios : DaakiaPlatform.android,
      ),
    );
  }
}
