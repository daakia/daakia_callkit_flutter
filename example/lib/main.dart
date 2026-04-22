import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:callkit/secret/secret_credential.dart';
import 'package:daakia_callkit_flutter/daakia_callkit_flutter.dart';
import 'package:daakia_vc_flutter_sdk/daakia_vc_flutter_sdk.dart';
import 'package:daakia_vc_flutter_sdk/model/daakia_meeting_configuration.dart';
import 'package:daakia_vc_flutter_sdk/model/participant_config.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
const String _sdkBaseUrlPreferenceKey = 'example_sdk_base_url';
const String _sdkSecretPreferenceKey = 'example_sdk_secret';

class ExampleSdkBootstrapConfig {
  const ExampleSdkBootstrapConfig({
    required this.baseUrl,
    required this.secret,
  });

  final String baseUrl;
  final String secret;

  bool get isComplete => baseUrl.trim().isNotEmpty && secret.trim().isNotEmpty;
}

Future<ExampleSdkBootstrapConfig> _loadInitialSdkConfig() async {
  final preferences = await SharedPreferences.getInstance();
  return ExampleSdkBootstrapConfig(
    baseUrl:
        preferences.getString(_sdkBaseUrlPreferenceKey) ??
        SecretCredential.baseUrl,
    secret:
        preferences.getString(_sdkSecretPreferenceKey) ??
        SecretCredential.secretKey,
  );
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  if (message.data.isEmpty) return;

  final notifications = DaakiaNotificationService();
  await notifications.initialize();
  await notifications.showIncomingCallNotificationFromData(
    Map<String, dynamic>.from(message.data),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseInitResult firebaseState = const FirebaseInitResult.notInitialized();
  final initialSdkConfig = await _loadInitialSdkConfig();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseState = const FirebaseInitResult.success();
  } catch (error) {
    firebaseState = FirebaseInitResult.failed(error.toString());
  }

  runApp(
    MyApp(firebaseState: firebaseState, initialSdkConfig: initialSdkConfig),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.firebaseState,
    required this.initialSdkConfig,
  });

  final FirebaseInitResult firebaseState;
  final ExampleSdkBootstrapConfig initialSdkConfig;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Daakia SDK Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF005F73)),
      ),
      home: DemoHomePage(
        firebaseState: firebaseState,
        initialSdkConfig: initialSdkConfig,
      ),
    );
  }
}

class FirebaseInitResult {
  const FirebaseInitResult._({required this.initialized, this.error});

  const FirebaseInitResult.success() : this._(initialized: true);

  const FirebaseInitResult.failed(String error)
    : this._(initialized: false, error: error);

  const FirebaseInitResult.notInitialized() : this._(initialized: false);

  final bool initialized;
  final String? error;
}

class DemoHomePage extends StatefulWidget {
  const DemoHomePage({
    super.key,
    required this.firebaseState,
    required this.initialSdkConfig,
  });

  final FirebaseInitResult firebaseState;
  final ExampleSdkBootstrapConfig initialSdkConfig;

  @override
  State<DemoHomePage> createState() => _DemoHomePageState();
}

class _DemoHomePageState extends State<DemoHomePage> {
  late final TextEditingController _baseUrlController;
  late final TextEditingController _secretController;
  late final TextEditingController _currentUsernameController;
  late final TextEditingController _targetUsernameController;
  late final TextEditingController _directTokenController;
  late final TextEditingController _callIdController;
  late final TextEditingController _callerNameController;
  late final TextEditingController _callEventMetadataController;
  late final TextEditingController _phoneController;

  bool _firestoreEnabled = false;
  bool _sendRejectEventManually = true;
  bool _enableRejectFallback = false;
  bool _sdkReady = false;
  bool _didAttemptAutoInitialization = false;
  bool _isInitializingSdk = false;
  bool _checkedInitialMessage = false;
  String _log = '';
  String? _latestFcmToken;
  String? _latestVoipToken;

  DaakiaCallkitFlutter? _sdk;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedAppSubscription;

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController(
      text: widget.initialSdkConfig.baseUrl,
    );
    _secretController = TextEditingController(
      text: widget.initialSdkConfig.secret,
    );
    _currentUsernameController = TextEditingController();
    _targetUsernameController = TextEditingController();
    _directTokenController = TextEditingController();
    _callIdController = TextEditingController(
      text: DateTime.now().millisecondsSinceEpoch.toString(),
    );
    _callerNameController = TextEditingController(text: 'Daakia Demo Caller');
    _callEventMetadataController = TextEditingController(
      text: '{"source":"example_app"}',
    );
    _phoneController = TextEditingController(text: '+910000000000');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_bootstrapSdkOnLaunch());
    });
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _secretController.dispose();
    _currentUsernameController.dispose();
    _targetUsernameController.dispose();
    _directTokenController.dispose();
    _callIdController.dispose();
    _callerNameController.dispose();
    _callEventMetadataController.dispose();
    _phoneController.dispose();
    _foregroundMessageSubscription?.cancel();
    _messageOpenedAppSubscription?.cancel();
    unawaited(_sdk?.dispose() ?? Future<void>.value());
    super.dispose();
  }

  void _appendLog(String value) {
    setState(() {
      _log = '[${DateTime.now().toIso8601String()}] $value\n$_log';
    });
  }

  void _clearLog() {
    setState(() {
      _log = '';
    });
  }

  String _describeSdkError(Object error) {
    if (error.runtimeType.toString() == 'DaakiaBackendException') {
      return error.toString();
    }
    return '$error';
  }

  ExampleSdkBootstrapConfig _currentSdkConfig() {
    return ExampleSdkBootstrapConfig(
      baseUrl: _baseUrlController.text.trim(),
      secret: _secretController.text.trim(),
    );
  }

  Future<void> _persistSdkConfig(ExampleSdkBootstrapConfig config) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_sdkBaseUrlPreferenceKey, config.baseUrl);
    await preferences.setString(_sdkSecretPreferenceKey, config.secret);
  }

  Future<void> _bootstrapSdkOnLaunch() async {
    if (_didAttemptAutoInitialization) return;
    _didAttemptAutoInitialization = true;

    if (!widget.initialSdkConfig.isComplete) {
      _appendLog(
        'Startup SDK bootstrap skipped because the saved config is incomplete.',
      );
      return;
    }

    _appendLog('Bootstrapping SDK from the last saved config.');
    await _initializeSdk(automatic: true);
  }

  Map<String, dynamic> _callEventMetadata({
    Map<String, dynamic> extra = const <String, dynamic>{},
  }) {
    final raw = _callEventMetadataController.text.trim();
    final metadata = <String, dynamic>{};
    if (raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw const FormatException('Metadata JSON must be an object.');
      }
      metadata.addAll(Map<String, dynamic>.from(decoded));
    }
    metadata.addAll(extra);
    return metadata;
  }

  Future<void> _copyToken(String label, String? value) async {
    if (value == null || value.isEmpty) {
      _appendLog('$label is not available to copy.');
      return;
    }

    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label copied')));
  }

  DaakiaCallkitFlutter _buildSdk() {
    final config = DaakiaCallkitConfig(
      baseUrl: _baseUrlController.text.trim(),
      secret: _secretController.text.trim(),
    );

    return DaakiaCallkitFlutter(
      config: config,
      callStateStore: _firestoreEnabled
          ? DaakiaFirestoreCallStateStore()
          : null,
    );
  }

  Map<String, dynamic> _incomingPayloadMap() {
    return <String, dynamic>{
      'type': 'incoming_call',
      'callId': _callIdController.text.trim(),
      'sender': jsonEncode(<String, dynamic>{
        'uid': _currentUsernameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'userName': _callerNameController.text.trim(),
        'fcmToken': null,
        'voipToken': null,
        'createdAt': null,
        'lastLogin': null,
      }),
      'callerId': _currentUsernameController.text.trim(),
      'receiverId': _targetUsernameController.text.trim(),
      'callTimestamp': DateTime.now().toUtc().toIso8601String(),
      'body': 'Incoming call',
      'title': _callerNameController.text.trim(),
    };
  }

  Future<void> _bindIncomingHandlers(DaakiaCallkitFlutter sdk) async {
    await _foregroundMessageSubscription?.cancel();
    _foregroundMessageSubscription = FirebaseMessaging.onMessage.listen((
      RemoteMessage message,
    ) async {
      if (message.data.isEmpty) {
        _appendLog('Received foreground push without data payload.');
        return;
      }

      final payload = Map<String, dynamic>.from(message.data);
      _appendLog('Received foreground FCM payload: ${jsonEncode(payload)}');
      await sdk.notifications.showIncomingCallNotificationFromData(payload);
    });

    await _messageOpenedAppSubscription?.cancel();
    _messageOpenedAppSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      (RemoteMessage message) async {
        if (message.data.isEmpty) {
          _appendLog('Opened app from push without data payload.');
          return;
        }

        final payload = DaakiaIncomingCallPayload.fromMap(
          Map<String, dynamic>.from(message.data),
        );
        _appendLog('Opened app from push for call ${payload.callId}');
        await _openIncomingCallFromPayload(payload);
      },
    );
  }

  Future<void> _handleCallEvent(DaakiaCallEvent event) async {
    _appendLog(
      'Call event [${event.platform.name}]: '
      '${event.method} ${jsonEncode(event.payload)}',
    );

    final payload = event.call;
    final sdk = _sdk;

    switch (event.type) {
      case DaakiaCallEventType.accepted:
        unawaited(_joinCall(payload.callId, payload.title));
        if (sdk != null && sdk.supportsRealtimeCallState) {
          await sdk.updateLocalCallStatus(
            callId: payload.callId,
            status: DaakiaCallStatus.accepted,
            actorId: payload.receiverId,
          );
        }
        return;
      case DaakiaCallEventType.declined:
        if (_sendRejectEventManually) {
          await _sendRejectCallEvent(
            meetingUid: payload.callId,
            source: 'call_event_declined',
          );
        }
        if (sdk != null && sdk.supportsRealtimeCallState) {
          await sdk.updateLocalCallStatus(
            callId: payload.callId,
            status: DaakiaCallStatus.rejected,
            actorId: payload.receiverId,
          );
        }
        return;
      case DaakiaCallEventType.timedOut:
        if (sdk != null && sdk.supportsRealtimeCallState) {
          await sdk.updateLocalCallStatus(
            callId: payload.callId,
            status: DaakiaCallStatus.missed,
            actorId: payload.receiverId,
          );
        }
        return;
      case DaakiaCallEventType.incoming:
        return;
      case DaakiaCallEventType.ended:
        return;
      case DaakiaCallEventType.unknown:
        return;
    }
  }

  Future<void> _runWithNavigator(
    Future<void> Function(NavigatorState navigator) action,
  ) async {
    final navigator = navigatorKey.currentState;
    if (navigator != null) {
      await action(navigator);
      return;
    }
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_runWithNavigator(action));
    });
  }

  Future<void> _joinCall(String? callUid, String? callerName) async {
    if (callUid == null) return;
    await _runWithNavigator((NavigatorState navigator) async {
      await navigator.push<void>(
        MaterialPageRoute(
          builder: (_) => DaakiaVideoConferenceWidget(
            meetingId: callUid,
            secretKey: SecretCredential.daakiaVcSecretKey,
            isHost: false,
            configuration: DaakiaMeetingConfiguration(
              participantNameConfig: ParticipantNameConfig(
                name: callerName ?? "Unknown",
                isEditable: false,
              ),
              skipPreJoinPage: true,
              enableCameraByDefault: true,
              enableMicrophoneByDefault: true,
            ),
          ),
        ),
      );
    });
    await _sdk?.voip.endCall(callUid);
  }

  Future<void> _fetchFcmToken() async {
    final sdk = _sdk;
    if (sdk == null) {
      _appendLog('Initialize SDK first.');
      return;
    }
    if (!widget.firebaseState.initialized) {
      _appendLog(
        'Firebase is not initialized. Add GoogleService-Info.plist / google-services.json first.',
      );
      return;
    }

    final token = await sdk.fcm.getFcmToken();
    setState(() {
      _latestFcmToken = token;
    });

    if (token == null || token.isEmpty) {
      _appendLog('FCM token is not available.');
      return;
    }

    _appendLog('Fetched FCM token: $token');
  }

  Future<void> _requestAndroidNotificationPermission() async {
    if (!Platform.isAndroid) return;
    if (!widget.firebaseState.initialized) return;

    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    _appendLog(
      'Android notification permission: '
      '${settings.authorizationStatus.name}',
    );
  }

  Future<void> _ensureAndroidFullScreenIntentAccess(
    DaakiaCallkitFlutter sdk, {
    bool promptToOpenSettings = true,
  }) async {
    if (!Platform.isAndroid) return;

    final canUseFullScreenIntent = await sdk.notifications
        .canUseFullScreenIntent();
    _appendLog(
      'Android full-screen intent access: '
      '${canUseFullScreenIntent ? 'allowed' : 'disabled'}',
    );
    if (canUseFullScreenIntent || !mounted || !promptToOpenSettings) return;

    final openSettings = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Enable Full-Screen Calls'),
          content: const Text(
            'Lock-screen incoming call UI may not appear until full-screen '
            'notifications are enabled for this app.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );

    if (openSettings == true) {
      final opened = await sdk.notifications.openFullScreenIntentSettings();
      _appendLog(
        opened
            ? 'Opened full-screen intent settings.'
            : 'Could not open full-screen intent settings.',
      );
    }
  }

  Future<void> _handleInitialMessageIfNeeded() async {
    if (_checkedInitialMessage || !widget.firebaseState.initialized) return;
    _checkedInitialMessage = true;

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage == null || initialMessage.data.isEmpty) return;

    final payload = DaakiaIncomingCallPayload.fromMap(
      Map<String, dynamic>.from(initialMessage.data),
    );
    _appendLog('Launched from push for call ${payload.callId}');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_openIncomingCallFromPayload(payload));
    });
  }

  Future<String?> _initializeVoipBridge(
    DaakiaCallkitFlutter sdk, {
    bool automatic = false,
  }) async {
    final token = await sdk.initializeVoip(
      onVoipTokenUpdated: (String token) async {
        if (!mounted) return;
        setState(() {
          _latestVoipToken = token;
        });
        _appendLog('VoIP token updated: $token');
      },
    );

    if (mounted && token != null && token.isNotEmpty) {
      setState(() {
        _latestVoipToken = token;
      });
    }
    _appendLog(
      automatic
          ? 'VoIP bridge initialized at startup. '
                'token=${token ?? _latestVoipToken ?? 'null'}'
          : 'VoIP initialization finished. '
                'token=${token ?? _latestVoipToken ?? 'null'}',
    );
    return token;
  }

  Future<void> _initializeSdk({bool automatic = false}) async {
    final config = _currentSdkConfig();
    if (!config.isComplete) {
      _appendLog('Base URL and secret are required.');
      return;
    }
    if (_isInitializingSdk) {
      if (!automatic) {
        _appendLog('SDK initialization is already in progress.');
      }
      return;
    }

    _isInitializingSdk = true;
    try {
      await _sdk?.dispose();
      final sdk = _buildSdk();
      _sdk = sdk;

      await _requestAndroidNotificationPermission();
      await sdk.initialize(
        onIncomingCall: _openIncomingCallFromPayload,
        onCallEvent: _handleCallEvent,
      );
      await _persistSdkConfig(config);
      if (Platform.isIOS) {
        await _initializeVoipBridge(sdk, automatic: automatic);
      }
      await _ensureAndroidFullScreenIntentAccess(
        sdk,
        promptToOpenSettings: !automatic,
      );
      await _bindIncomingHandlers(sdk);
      await _handleInitialMessageIfNeeded();

      if (!mounted) return;
      setState(() {
        _sdkReady = true;
      });
      await _applyRejectFallbackConfig();
      _appendLog(
        automatic
            ? 'SDK initialized from saved config. Firestore adapter: '
                  '${_firestoreEnabled ? 'enabled' : 'disabled'}'
            : 'SDK initialized. Firestore adapter: '
                  '${_firestoreEnabled ? 'enabled' : 'disabled'}',
      );
    } catch (error) {
      _sdk = null;
      if (mounted) {
        setState(() {
          _sdkReady = false;
        });
      }
      _appendLog('SDK initialization failed: ${_describeSdkError(error)}');
    } finally {
      _isInitializingSdk = false;
    }
  }

  Future<void> _sendRejectCallEvent({
    String? meetingUid,
    required String source,
  }) async {
    final sdk = _sdk;
    final resolvedMeetingUid = meetingUid ?? _callIdController.text.trim();
    if (sdk == null) {
      _appendLog('Initialize SDK first.');
      return;
    }
    if (resolvedMeetingUid.isEmpty) {
      _appendLog('Meeting UID / Call ID is required.');
      return;
    }

    try {
      await sdk.sendCallEvent(
        meetingUid: resolvedMeetingUid,
        action: DaakiaCallEventAction.callReject,
        metadata: _callEventMetadata(
          extra: <String, dynamic>{'source': source},
        ),
      );
      _appendLog(
        'Sent call-reject event for $resolvedMeetingUid from $source.',
      );
    } catch (error) {
      _appendLog('Send call-reject failed: ${_describeSdkError(error)}');
    }
  }

  Future<void> _applyRejectFallbackConfig() async {
    final sdk = _sdk;
    if (sdk == null) {
      _appendLog('Initialize SDK first.');
      return;
    }

    try {
      if (_enableRejectFallback) {
        await sdk.configureCallEventFallback(
          actions: <DaakiaCallEventAction>{DaakiaCallEventAction.callReject},
          metadata: _callEventMetadata(
            extra: <String, dynamic>{'source': 'fallback_config'},
          ),
        );
        _appendLog(
          'Configured call event fallback for call-reject. '
          'This is the more reliable path when the app is backgrounded or closed.',
        );
      } else {
        await sdk.clearCallEventFallback();
        _appendLog('Cleared call event fallback config.');
      }
    } catch (error) {
      _appendLog(
        'Configure call event fallback failed: ${_describeSdkError(error)}',
      );
    }
  }

  Future<void> _clearSentCallEventCache() async {
    final sdk = _sdk;
    if (sdk == null) {
      _appendLog('Initialize SDK first.');
      return;
    }

    try {
      await sdk.clearSentCallEventCache();
      _appendLog('Cleared sent call event cache.');
    } catch (error) {
      _appendLog(
        'Clear sent call event cache failed: ${_describeSdkError(error)}',
      );
    }
  }

  Future<void> _initializeVoip() async {
    final sdk = _sdk;
    if (sdk == null) {
      _appendLog('Initialize SDK first.');
      return;
    }
    await _initializeVoipBridge(sdk);
  }

  Future<void> _registerFcm() async {
    final sdk = _sdk;
    if (sdk == null) {
      _appendLog('Initialize SDK first.');
      return;
    }
    if (!widget.firebaseState.initialized) {
      _appendLog(
        'Firebase is not initialized. Add GoogleService-Info.plist / google-services.json first.',
      );
      return;
    }
    if (_currentUsernameController.text.trim().isEmpty) {
      _appendLog('Current username is required.');
      return;
    }

    try {
      final result = await sdk.registerCurrentPushDevice(
        username: _currentUsernameController.text.trim(),
        platform: Theme.of(context).platform == TargetPlatform.iOS
            ? DaakiaPlatform.ios
            : DaakiaPlatform.android,
        voipToken: _latestVoipToken,
      );

      if (result == null) {
        _appendLog('FCM token was not available.');
        return;
      }

      setState(() {
        _latestFcmToken = result.token;
        _latestVoipToken = result.voipToken ?? _latestVoipToken;
      });
      _appendLog('Registered push device for ${result.username}.');
    } catch (error) {
      _appendLog('Register push device failed: ${_describeSdkError(error)}');
    }
  }

  Future<void> _triggerByUsername() async {
    final sdk = _sdk;
    if (sdk == null) {
      _appendLog('Initialize SDK first.');
      return;
    }
    if (_targetUsernameController.text.trim().isEmpty) {
      _appendLog('Target username is required.');
      return;
    }

    try {
      final result = await sdk.startCallByUsername(
        username: _targetUsernameController.text.trim(),
        title: _callerNameController.text.trim(),
        message: 'Incoming call',
        data: _incomingPayloadMap(),
      );

      _appendLog('Triggered by username: ${jsonEncode(result.data)}');
    } catch (error) {
      _appendLog('Trigger by username failed: ${_describeSdkError(error)}');
    }
  }

  Future<void> _triggerByToken() async {
    final sdk = _sdk;
    if (sdk == null) {
      _appendLog('Initialize SDK first.');
      return;
    }
    if (_directTokenController.text.trim().isEmpty) {
      _appendLog('Direct token is required.');
      return;
    }

    try {
      final result = await sdk.startCallByToken(
        token: _directTokenController.text.trim(),
        platform: Theme.of(context).platform == TargetPlatform.iOS
            ? DaakiaPlatform.ios
            : DaakiaPlatform.android,
        title: _callerNameController.text.trim(),
        message: 'Incoming call',
        data: _incomingPayloadMap(),
      );

      _appendLog('Triggered by token: ${jsonEncode(result.data)}');
    } catch (error) {
      _appendLog('Trigger by token failed: ${_describeSdkError(error)}');
    }
  }

  Future<void> _simulateIncomingCall() async {
    final payload = DaakiaIncomingCallPayload.fromMap(_incomingPayloadMap());
    await _openIncomingCallFromPayload(payload);
  }

  Future<void> _openIncomingCallFromPayload(
    DaakiaIncomingCallPayload payload,
  ) async {
    _appendLog('Opening incoming call UI for ${payload.callId}');
    await _runWithNavigator((NavigatorState navigator) async {
      await navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => DaakiaIncomingCallScreen(
            payload: payload,
            onAccept: (DaakiaIncomingCallPayload payload) async {
              _appendLog('Incoming screen accept: ${payload.callId}');
              unawaited(_joinCall(payload.callId, payload.title));
              final sdk = _sdk;
              if (sdk != null && sdk.supportsRealtimeCallState) {
                await sdk.updateLocalCallStatus(
                  callId: payload.callId,
                  status: DaakiaCallStatus.accepted,
                  actorId: payload.receiverId,
                );
              }
              navigator.pop();
            },
            onReject: (DaakiaIncomingCallPayload payload) async {
              _appendLog('Incoming screen reject: ${payload.callId}');
              if (_sendRejectEventManually) {
                await _sendRejectCallEvent(
                  meetingUid: payload.callId,
                  source: 'incoming_screen_reject',
                );
              }
              final sdk = _sdk;
              if (sdk != null && sdk.supportsRealtimeCallState) {
                await sdk.updateLocalCallStatus(
                  callId: payload.callId,
                  status: DaakiaCallStatus.rejected,
                  actorId: payload.receiverId,
                );
              }
              navigator.pop();
            },
            onTimeout: (DaakiaIncomingCallPayload payload) async {
              _appendLog('Incoming screen timeout: ${payload.callId}');
              final sdk = _sdk;
              if (sdk != null && sdk.supportsRealtimeCallState) {
                await sdk.updateLocalCallStatus(
                  callId: payload.callId,
                  status: DaakiaCallStatus.missed,
                  actorId: payload.receiverId,
                );
              }
            },
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daakia SDK Example')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _StatusCard(
            firebaseState: widget.firebaseState,
            sdkReady: _sdkReady,
            firestoreEnabled: _firestoreEnabled,
          ),
          const SizedBox(height: 16),
          _TokenCard(
            label: 'Current FCM Token',
            value: _latestFcmToken,
            onCopy: () => _copyToken('FCM token', _latestFcmToken),
          ),
          const SizedBox(height: 12),
          _TokenCard(
            label: 'Current iOS VoIP Token',
            value: _latestVoipToken,
            onCopy: () => _copyToken('VoIP token', _latestVoipToken),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _baseUrlController,
            decoration: const InputDecoration(
              labelText: 'Base URL',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _secretController,
            decoration: const InputDecoration(
              labelText: 'Secret',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: _firestoreEnabled,
            onChanged: (bool value) {
              setState(() {
                _firestoreEnabled = value;
              });
            },
            title: const Text('Enable Firestore adapter'),
            subtitle: const Text(
              'Experimental realtime call-state sync for accept/reject/cancel/missed.',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _currentUsernameController,
            decoration: const InputDecoration(
              labelText: 'Current username',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _targetUsernameController,
            decoration: const InputDecoration(
              labelText: 'Target username',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _directTokenController,
            decoration: const InputDecoration(
              labelText: 'Direct device / VoIP token',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _callIdController,
            decoration: const InputDecoration(
              labelText: 'Meeting UID / Call ID',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _callerNameController,
            decoration: const InputDecoration(
              labelText: 'Caller name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Caller phone',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Call Event Webhook',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This example focuses on call-reject. Join-related events only make sense when the meeting is opened through daakia_vc_flutter_sdk.',
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _sendRejectEventManually,
                    onChanged: (bool value) {
                      setState(() {
                        _sendRejectEventManually = value;
                      });
                    },
                    title: const Text('Manually send call-reject from Dart'),
                    subtitle: const Text(
                      'Useful while the app is open. Metadata can be dynamic.',
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _enableRejectFallback,
                    onChanged: (bool value) {
                      setState(() {
                        _enableRejectFallback = value;
                      });
                    },
                    title: const Text('Enable native fallback for call-reject'),
                    subtitle: const Text(
                      'More reliable for background or closed-app reject actions. Metadata must be predefined.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _callEventMetadataController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Call event metadata JSON',
                      hintText: '{"source":"example_app"}',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: <Widget>[
                      FilledButton(
                        onPressed: () {
                          _sendRejectCallEvent(source: 'manual_button');
                        },
                        child: const Text('Send Reject Event'),
                      ),
                      OutlinedButton(
                        onPressed: _applyRejectFallbackConfig,
                        child: const Text('Apply Fallback Config'),
                      ),
                      OutlinedButton(
                        onPressed: _clearSentCallEventCache,
                        child: const Text('Clear Event Cache'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              FilledButton(
                onPressed: _initializeSdk,
                child: const Text('Initialize SDK'),
              ),
              FilledButton(
                onPressed: _initializeVoip,
                child: const Text('Initialize VoIP'),
              ),
              FilledButton(
                onPressed: _fetchFcmToken,
                child: const Text('Fetch FCM Token'),
              ),
              FilledButton(
                onPressed: _registerFcm,
                child: const Text('Register Push Device'),
              ),
              FilledButton(
                onPressed: _triggerByUsername,
                child: const Text('Trigger by Username'),
              ),
              FilledButton(
                onPressed: _triggerByToken,
                child: const Text('Trigger by Token'),
              ),
              OutlinedButton(
                onPressed: _simulateIncomingCall,
                child: const Text('Simulate Incoming UI'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  'Event Log',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(onPressed: _clearLog, child: const Text('Clear Log')),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(
              _log.isEmpty ? 'No events yet.' : _log,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.firebaseState,
    required this.sdkReady,
    required this.firestoreEnabled,
  });

  final FirebaseInitResult firebaseState;
  final bool sdkReady;
  final bool firestoreEnabled;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Setup Status',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('Firebase initialized: ${firebaseState.initialized}'),
            Text('SDK initialized: $sdkReady'),
            Text('Firestore adapter enabled: $firestoreEnabled'),
            if (firebaseState.error != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                firebaseState.error!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TokenCard extends StatelessWidget {
  const _TokenCard({
    required this.label,
    required this.value,
    required this.onCopy,
  });

  final String label;
  final String? value;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: onCopy,
                  tooltip: 'Copy',
                  icon: const Icon(Icons.copy_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(
              value == null || value!.isEmpty ? 'Not available yet.' : value!,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ],
        ),
      ),
    );
  }
}
