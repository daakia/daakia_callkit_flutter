import 'dart:async';

import 'package:http/http.dart' as http;

import 'models/daakia_call_event.dart';
import 'models/daakia_call_event_action.dart';
import 'models/daakia_call_session.dart';
import 'models/daakia_call_status.dart';
import 'models/daakia_callkit_config.dart';
import 'models/daakia_device_token_record.dart';
import 'models/daakia_platform.dart';
import 'models/daakia_push_result.dart';
import 'services/daakia_backend_client.dart';
import 'services/daakia_android_call_service.dart';
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
        .listen(controller.add, onError: controller.addError);

    controller.onCancel = () async {
      await notificationSubscription.cancel();
      await voipSubscription.cancel();
    };
  });

  bool get supportsRealtimeCallState => _callStateStore != null;

  /// Initializes the SDK listeners for incoming-call notifications and call events.
  ///
  /// Call this once during app startup before handling incoming calls.
  ///
  /// [onIncomingCall] is invoked when the SDK receives an incoming-call payload.
  /// [onCallEvent] provides typed lifecycle updates such as accepted, declined,
  /// ended, and timed out.
  ///
  /// The more specific callbacks remain available for integrations that prefer
  /// separate handlers for each call state.
  Future<void> initialize({
    DaakiaIncomingCallHandler? onIncomingCall,
    DaakiaCallEventHandler? onCallEvent,
    DaakiaIncomingCallHandler? onCallAccepted,
    DaakiaIncomingCallHandler? onCallDeclined,
    DaakiaIncomingCallHandler? onCallEnded,
    DaakiaIncomingCallHandler? onCallTimedOut,
  }) async {
    await notifications.initialize(onIncomingCall: onIncomingCall);

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

  /// Resolves the backend `config_name` value for the target platform.
  ///
  /// Current behavior:
  /// - Android returns `prod`
  /// - iOS sandbox returns `dev`
  /// - iOS production returns `prod`
  String resolveConfigName({
    required DaakiaPlatform platform,
    bool? isIosSandbox,
  }) {
    return _config.resolveConfigName(
      platform: platform,
      isIosSandbox: isIosSandbox,
    );
  }

  /// Registers a device token with the Daakia backend.
  ///
  /// Use this when you already have the push token and want full control over
  /// the registration flow.
  ///
  /// On iOS, [voipToken] can also be provided so the backend stores both the
  /// standard push token and the VoIP token together.
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

  /// Fetches the current FCM token and registers the current push device.
  ///
  /// This is the recommended high-level registration helper for most apps.
  ///
  /// The method always fetches the current Firebase Messaging token first.
  /// On iOS, [voipToken] can optionally be attached in the same backend request.
  /// On Android, [voipToken] should be omitted or left `null`.
  ///
  /// Returns `null` when the FCM token is unavailable.
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

  /// Fetches the currently registered device token record for a user and platform.
  Future<DaakiaDeviceTokenRecord> getRegisteredDeviceToken({
    required String username,
    required DaakiaPlatform platform,
  }) {
    return _backendClient.getDeviceToken(
      username: username,
      platform: platform,
    );
  }

  /// Triggers an incoming-call notification directly to a specific device token.
  ///
  /// Use this when you already know the destination device token.
  ///
  /// The backend `config_name` is resolved automatically from [platform] and
  /// the optional iOS sandbox flag.
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

  /// Triggers an incoming-call notification by backend username lookup.
  ///
  /// Use this when the backend should resolve the target device tokens for the
  /// destination user.
  ///
  /// If [configName] is not provided, the SDK resolves it automatically.
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

  /// Initializes the iOS VoIP bridge and returns the current VoIP token if available.
  ///
  /// This is only relevant for iOS PushKit / CallKit integrations.
  Future<String?> initializeVoip({
    Future<void> Function(String token)? onVoipTokenUpdated,
  }) {
    return voip.initialize(onVoipTokenUpdated: onVoipTokenUpdated);
  }

  /// Sends a call lifecycle event to the Daakia backend.
  ///
  /// This method is intended for use when the app is managing the actual
  /// call join flow, for example via `daakia_vc_flutter_sdk`, and needs to
  /// report a user action such as accept, reject, join, end, or timeout.
  ///
  /// [meetingUid] identifies the call session, and [action] specifies which
  /// webhook event should be delivered.
  ///
  /// Optional [metadata] is forwarded to the backend with the event payload.
  ///
  /// The event is only sent once per call action; duplicate deliveries are
  /// prevented by the platform-specific sent-event cache.
  Future<void> sendCallEvent({
    required String meetingUid,
    required DaakiaCallEventAction action,
    Map<String, dynamic>? metadata,
  }) async {
    if (meetingUid.isEmpty) {
      throw const DaakiaBackendException('meetingUid is required');
    }

    final alreadySent = await _wasCallEventSent(
      meetingUid: meetingUid,
      action: action,
    );
    if (alreadySent) return;

    await _backendClient.sendCallEvent(
      meetingUid: meetingUid,
      action: action,
      metadata: metadata,
    );
    await _markCallEventSent(meetingUid: meetingUid, action: action);
  }

  /// Configures fallback call event actions for when the app is closed.
  ///
  /// This stores the selected [actions] and optional [metadata] so the
  /// underlying Android or iOS bridge can emit call events later without the
  /// app being active.
  ///
  /// Fallback metadata is captured at configuration time and cannot be
  /// updated later while the app is closed. Use this when you need the call
  /// event to be available even if the application process is not running.
  ///
  /// Pass an empty [actions] set to clear any previously configured fallback.
  Future<void> configureCallEventFallback({
    required Set<DaakiaCallEventAction> actions,
    Map<String, dynamic>? metadata,
  }) async {
    final actionValues = actions
        .map((DaakiaCallEventAction item) => item.value)
        .toSet();
    if (actionValues.isEmpty) {
      await clearCallEventFallback();
      return;
    }

    if (DaakiaPlatform.current == DaakiaPlatform.android) {
      await DaakiaAndroidCallService().configureCallEventFallback(
        baseUrl: _config.baseUrl,
        secret: _config.secret,
        actions: actionValues,
        metadata: metadata,
      );
      return;
    }

    if (DaakiaPlatform.current == DaakiaPlatform.ios) {
      await voip.configureCallEventFallback(
        baseUrl: _config.baseUrl,
        secret: _config.secret,
        actions: actionValues,
        metadata: metadata,
      );
    }
  }

  Future<void> clearCallEventFallback() async {
    if (DaakiaPlatform.current == DaakiaPlatform.android) {
      await DaakiaAndroidCallService().clearCallEventFallback();
      return;
    }

    if (DaakiaPlatform.current == DaakiaPlatform.ios) {
      await voip.clearCallEventFallback();
    }
  }

  /// Clears the platform-local cache of already sent call events.
  ///
  /// This should be used when you want to reset the sent-event state so that
  /// `sendCallEvent` may be allowed to send the same action again for the
  /// same meeting UID.
  Future<void> clearSentCallEventCache() async {
    if (DaakiaPlatform.current == DaakiaPlatform.android) {
      await DaakiaAndroidCallService().clearSentCallEventCache();
      return;
    }

    if (DaakiaPlatform.current == DaakiaPlatform.ios) {
      await voip.clearSentCallEventCache();
    }
  }

  /// Watches realtime state updates for a call when a call-state store is configured.
  ///
  /// When no store is configured, this returns a stream containing a single `null`.
  Stream<DaakiaCallSession?> watchCall(String callId) {
    final store = _callStateStore;
    if (store == null) {
      return Stream<DaakiaCallSession?>.value(null);
    }
    return store.watchCall(callId);
  }

  /// Saves the initial call session into the configured realtime call-state store.
  ///
  /// Does nothing when no call-state store is configured.
  Future<void> saveCallSession(DaakiaCallSession session) async {
    final store = _callStateStore;
    if (store == null) return;
    await store.saveSession(session);
  }

  /// Updates the local realtime call status in the configured call-state store.
  ///
  /// This is useful for accept, reject, missed, or ended transitions when using
  /// Firestore or another realtime state adapter.
  ///
  /// Does nothing when no call-state store is configured.
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

  Future<bool> _wasCallEventSent({
    required String meetingUid,
    required DaakiaCallEventAction action,
  }) async {
    if (DaakiaPlatform.current == DaakiaPlatform.android) {
      return DaakiaAndroidCallService().wasCallEventSent(
        meetingUid: meetingUid,
        action: action.value,
      );
    }

    if (DaakiaPlatform.current == DaakiaPlatform.ios) {
      return voip.wasCallEventSent(
        meetingUid: meetingUid,
        action: action.value,
      );
    }

    return false;
  }

  Future<void> _markCallEventSent({
    required String meetingUid,
    required DaakiaCallEventAction action,
  }) async {
    if (DaakiaPlatform.current == DaakiaPlatform.android) {
      await DaakiaAndroidCallService().markCallEventSent(
        meetingUid: meetingUid,
        action: action.value,
      );
      return;
    }

    if (DaakiaPlatform.current == DaakiaPlatform.ios) {
      await voip.markCallEventSent(
        meetingUid: meetingUid,
        action: action.value,
      );
    }
  }
}
