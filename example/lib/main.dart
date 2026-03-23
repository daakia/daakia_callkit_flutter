import 'dart:convert';

import 'package:daakia_callkit_flutter/daakia_callkit_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseInitResult firebaseState = const FirebaseInitResult.notInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseState = const FirebaseInitResult.success();
  } catch (error) {
    firebaseState = FirebaseInitResult.failed(error.toString());
  }

  runApp(MyApp(firebaseState: firebaseState));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.firebaseState});

  final FirebaseInitResult firebaseState;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Daakia SDK Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF005F73)),
      ),
      home: DemoHomePage(firebaseState: firebaseState),
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
  const DemoHomePage({super.key, required this.firebaseState});

  final FirebaseInitResult firebaseState;

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
  late final TextEditingController _phoneController;

  bool _firestoreEnabled = false;
  bool _sdkReady = false;
  String _log = '';

  DaakiaCallkitFlutter? _sdk;

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController(
      text: 'https://stag-api.daakia.co.in',
    );
    _secretController = TextEditingController();
    _currentUsernameController = TextEditingController();
    _targetUsernameController = TextEditingController();
    _directTokenController = TextEditingController();
    _callIdController = TextEditingController(
      text: DateTime.now().millisecondsSinceEpoch.toString(),
    );
    _callerNameController = TextEditingController(text: 'Daakia Demo Caller');
    _phoneController = TextEditingController(text: '+910000000000');
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
    _phoneController.dispose();
    super.dispose();
  }

  void _appendLog(String value) {
    setState(() {
      _log = '[${DateTime.now().toIso8601String()}] $value\n$_log';
    });
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

  Future<void> _initializeSdk() async {
    if (_baseUrlController.text.trim().isEmpty ||
        _secretController.text.trim().isEmpty) {
      _appendLog('Base URL and secret are required.');
      return;
    }

    final sdk = _buildSdk();
    await sdk.notifications.initialize(
      onIncomingCall: _openIncomingCallFromPayload,
      onAcceptCall: (payload) async {
        _appendLog('Accepted call ${payload.callId}');
      },
      onRejectCall: (payload) async {
        _appendLog('Rejected call ${payload.callId}');
      },
    );

    _sdk = sdk;
    setState(() {
      _sdkReady = true;
    });
    _appendLog(
      'SDK initialized. Firestore adapter: ${_firestoreEnabled ? 'enabled' : 'disabled'}',
    );
  }

  Future<void> _initializeVoip() async {
    final sdk = _sdk;
    if (sdk == null) {
      _appendLog('Initialize SDK first.');
      return;
    }

    final token = await sdk.initializeVoip(
      onVoipTokenUpdated: (String token) async {
        _appendLog('VoIP token updated: $token');
      },
    );

    _appendLog('VoIP initialization finished. token=${token ?? 'null'}');
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

    final result = await sdk.registerCurrentFcmDevice(
      username: _currentUsernameController.text.trim(),
      platform: Theme.of(context).platform == TargetPlatform.iOS
          ? DaakiaPlatform.ios
          : DaakiaPlatform.android,
    );

    if (result == null) {
      _appendLog('FCM token was not available.');
      return;
    }

    _appendLog('Registered FCM token for ${result.username}.');
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

    final result = await sdk.startCallByUsername(
      username: _targetUsernameController.text.trim(),
      title: _callerNameController.text.trim(),
      message: 'Incoming call',
      data: _incomingPayloadMap(),
    );

    _appendLog('Triggered by username: ${jsonEncode(result.data)}');
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
  }

  Future<void> _simulateIncomingCall() async {
    final payload = DaakiaIncomingCallPayload.fromMap(_incomingPayloadMap());
    await _openIncomingCallFromPayload(payload);
  }

  Future<void> _openIncomingCallFromPayload(
    DaakiaIncomingCallPayload payload,
  ) async {
    _appendLog('Opening incoming call UI for ${payload.callId}');
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    await navigator.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DaakiaIncomingCallScreen(
          payload: payload,
          onAccept: (DaakiaIncomingCallPayload payload) async {
            _appendLog('Incoming screen accept: ${payload.callId}');
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
              'Optional realtime call-state sync for accept/reject/cancel/missed.',
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
              labelText: 'Direct device token',
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
                onPressed: _registerFcm,
                child: const Text('Register FCM'),
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
          const Text(
            'Event Log',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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
