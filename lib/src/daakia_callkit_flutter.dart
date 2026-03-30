import 'dart:async';

import 'package:http/http.dart' as http;

import 'models/daakia_call_event.dart';
import 'models/daakia_call_session.dart';
import 'models/daakia_call_status.dart';
import 'models/daakia_callkit_config.dart';
import 'models/daakia_device_token_record.dart';
import 'models/daakia_platform.dart';
import 'models/daakia_push_result.dart';
import 'services/daakia_backend_client.dart';
import 'services/daakia_call_state_store.dart';
import 'services/daakia_fcm_service.dart';
import 'services/daakia_ios_voip_service.dart';
import 'services/daakia_notification_service.dart';
import 'services/daakia_ringtone_service.dart';

typedef DaakiaCallEventHandler = FutureOr<void> Function(DaakiaCallEvent event);

class DaakiaCallkitFlutter {
  DaakiaCallkitFlutter({
    required DaakiaCallkitConfig config,
    DaakiaCallStateStore? callStateStore,
    http.Client? httpClient,
  }) : _config = config,
       _callStateStore = callStateStore,
       _backendClient = DaakiaBackendClient(
         config: config,
         httpClient: httpClient,
       );

  final DaakiaCallkitConfig _config;
  final DaakiaCallStateStore? _callStateStore;
  final DaakiaBackendClient _backendClient;
  StreamSubscription<DaakiaCallEvent>? _callEventSubscription;

  DaakiaFcmService get fcm => DaakiaFcmService();

  DaakiaIosVoipService get voip => DaakiaIosVoipService();

  DaakiaNotificationService get notifications => DaakiaNotificationService();

  DaakiaRingtoneService get ringtone => DaakiaRingtoneService();

  Stream<DaakiaCallEvent> get events => Stream<DaakiaCallEvent>.multi((
    StreamController<DaakiaCallEvent> controller,
  ) {
    final notificationSubscription = notifications.events.listen(
      controller.add,
      onError: controller.addError,
    );
    final voipSubscription = voip.events
        .map(DaakiaCallEvent.fromVoipEvent)
        .listen(
          controller.add,
          onError: controller.addError,
        );

    controller.onCancel = () async {
      await notificationSubscription.cancel();
      await voipSubscription.cancel();
    };
  });

  bool get supportsRealtimeCallState => _callStateStore != null;

  Future<void> initialize({
    DaakiaIncomingCallHandler? onIncomingCall,
    DaakiaCallEventHandler? onCallEvent,
    DaakiaIncomingCallHandler? onCallAccepted,
    DaakiaIncomingCallHandler? onCallDeclined,
    DaakiaIncomingCallHandler? onCallEnded,
    DaakiaIncomingCallHandler? onCallTimedOut,
  }) async {
    await notifications.initialize(
      onIncomingCall: onIncomingCall,
    );

    await _callEventSubscription?.cancel();
    if (onCallEvent == null &&
        onCallAccepted == null &&
        onCallDeclined == null &&
        onCallEnded == null &&
        onCallTimedOut == null) {
      return;
    }

    _callEventSubscription = events.listen((DaakiaCallEvent event) async {
      await onCallEvent?.call(event);

      switch (event.type) {
        case DaakiaCallEventType.accepted:
          await onCallAccepted?.call(event.call);
          return;
        case DaakiaCallEventType.declined:
          await onCallDeclined?.call(event.call);
          return;
        case DaakiaCallEventType.ended:
          await onCallEnded?.call(event.call);
          return;
        case DaakiaCallEventType.timedOut:
          await onCallTimedOut?.call(event.call);
          return;
        case DaakiaCallEventType.incoming:
        case DaakiaCallEventType.unknown:
          return;
      }
    });
  }

  String resolveConfigName({
    required DaakiaPlatform platform,
    bool? isIosSandbox,
  }) {
    return _config.resolveConfigName(
      platform: platform,
      isIosSandbox: isIosSandbox,
    );
  }

  Future<DaakiaDeviceTokenRecord> registerCurrentDevice({
    required String username,
    required String token,
    required DaakiaPlatform platform,
    String? voipToken,
  }) {
    return _backendClient.registerDeviceToken(
      username: username,
      token: token,
      platform: platform,
      voipToken: voipToken,
    );
  }

  Future<DaakiaDeviceTokenRecord?> registerCurrentPushDevice({
    required String username,
    required DaakiaPlatform platform,
    String? voipToken,
    bool requestApplePermission = true,
  }) async {
    final token = await fcm.getFcmToken(
      requestApplePermission: requestApplePermission,
    );
    if (token == null || token.isEmpty) return null;

    return registerCurrentDevice(
      username: username,
      token: token,
      platform: platform,
      voipToken: voipToken,
    );
  }

  @Deprecated(
    'Use registerCurrentPushDevice(...) instead. '
    'This method still fetches the current FCM token and can optionally attach the iOS VoIP token.',
  )
  Future<DaakiaDeviceTokenRecord?> registerCurrentFcmDevice({
    required String username,
    required DaakiaPlatform platform,
    String? voipToken,
    bool requestApplePermission = true,
  }) {
    return registerCurrentPushDevice(
      username: username,
      platform: platform,
      voipToken: voipToken,
      requestApplePermission: requestApplePermission,
    );
  }

  Future<DaakiaDeviceTokenRecord> getRegisteredDeviceToken({
    required String username,
    required DaakiaPlatform platform,
  }) {
    return _backendClient.getDeviceToken(
      username: username,
      platform: platform,
    );
  }

  Future<DaakiaPushResult> startCallByToken({
    required String token,
    required DaakiaPlatform platform,
    required String title,
    required String message,
    required Map<String, dynamic> data,
    bool? isIosSandbox,
  }) {
    return _backendClient.triggerNotificationByToken(
      token: token,
      platform: platform,
      title: title,
      message: message,
      configName: resolveConfigName(
        platform: platform,
        isIosSandbox: isIosSandbox,
      ),
      data: data,
    );
  }

  Future<DaakiaPushResult> startCallByUsername({
    required String username,
    required String title,
    required String message,
    required Map<String, dynamic> data,
    String? configName,
    bool? isIosSandbox,
  }) {
    return _backendClient.triggerNotificationByUsername(
      username: username,
      title: title,
      message: message,
      configName:
          configName ??
          resolveConfigName(
            platform: DaakiaPlatform.ios,
            isIosSandbox: isIosSandbox,
          ),
      data: data,
    );
  }

  Future<String?> initializeVoip({
    Future<void> Function(String token)? onVoipTokenUpdated,
  }) {
    return voip.initialize(onVoipTokenUpdated: onVoipTokenUpdated);
  }

  Stream<DaakiaCallSession?> watchCall(String callId) {
    final store = _callStateStore;
    if (store == null) {
      return Stream<DaakiaCallSession?>.value(null);
    }
    return store.watchCall(callId);
  }

  Future<void> saveCallSession(DaakiaCallSession session) async {
    final store = _callStateStore;
    if (store == null) return;
    await store.saveSession(session);
  }

  Future<void> updateLocalCallStatus({
    required String callId,
    required DaakiaCallStatus status,
    String? actorId,
    String? reason,
  }) async {
    final store = _callStateStore;
    if (store == null) return;
    await store.updateStatus(
      callId: callId,
      status: status,
      actorId: actorId,
      reason: reason,
    );
  }

  Future<void> updateBackendCallStatus({
    required String callId,
    required DaakiaCallStatus status,
    String? actorId,
    String? reason,
  }) {
    throw UnimplementedError(
      'Backend call status API is not available yet. '
      'Pending backend endpoint for callId=$callId status=${status.value} actorId=$actorId reason=$reason.',
    );
  }
}
