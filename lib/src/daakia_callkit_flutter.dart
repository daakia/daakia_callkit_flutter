import 'package:http/http.dart' as http;

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

  DaakiaFcmService get fcm => DaakiaFcmService();

  DaakiaIosVoipService get voip => DaakiaIosVoipService();

  DaakiaNotificationService get notifications => DaakiaNotificationService();

  DaakiaRingtoneService get ringtone => DaakiaRingtoneService();

  bool get supportsRealtimeCallState => _callStateStore != null;

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

  Future<DaakiaDeviceTokenRecord?> registerCurrentFcmDevice({
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
