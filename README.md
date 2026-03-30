# daakia_callkit_flutter

`daakia_callkit_flutter` helps Flutter apps integrate Daakia-backed incoming call signaling for Android and iOS.

It covers:
- device token registration with the Daakia backend
- incoming call push handling
- Android full-screen incoming call notifications
- iOS VoIP / CallKit bridge
- a default incoming call screen
- optional Firestore-based call state sync (experimental)

It does not cover:
- authentication
- backend implementation
- call media / RTC itself
- app-specific navigation or user management

## What You Need

Required:
- Daakia backend `baseUrl`
- Daakia backend `secret`
- Firebase project configured for your app
- Android package name
- iOS bundle identifier

Optional:
- Firestore for experimental realtime call status sync
- `daakia_vc_flutter_sdk` if you also want Daakia's call joining SDK

## Quick Start

Add the package:

```yaml
dependencies:
  daakia_callkit_flutter: ^1.0.0
```

Initialize the SDK:

```dart
final sdk = DaakiaCallkitFlutter(
  config: const DaakiaCallkitConfig(
    baseUrl: 'https://your-daakia-base-url',
    secret: 'your-shared-secret',
  ),
);

await sdk.initialize(
  onIncomingCall: (payload) async {
    // Open your call UI.
  },
  onCallEvent: (event) async {
    switch (event.type) {
      case DaakiaCallEventType.accepted:
      case DaakiaCallEventType.declined:
      case DaakiaCallEventType.ended:
      case DaakiaCallEventType.timedOut:
      case DaakiaCallEventType.incoming:
      case DaakiaCallEventType.unknown:
        break;
    }
  },
);
```

Register the current device:

```dart
await sdk.registerCurrentDevice(
  username: 'current_user_id',
  token: 'fcm_or_apns_token',
  voipToken: 'optional_ios_voip_token',
  platform: DaakiaPlatform.android, // or DaakiaPlatform.ios
);
```

Trigger an incoming call:

```dart
await sdk.startCallByUsername(
  username: 'target_user_id',
  title: 'Caller Name',
  message: 'Incoming call',
  data: {
    'type': 'incoming_call',
    'callId': 'meeting_uid_123',
    'sender': '{"uid":"current_user_id","userName":"Caller Name"}',
    'callerId': 'current_user_id',
    'receiverId': 'target_user_id',
  },
);
```

## Integration Order

1. Complete Firebase setup.
2. Complete Android or iOS platform setup.
3. Initialize the SDK.
4. Register the current device token.
5. Handle incoming call events.
6. Optionally add Firestore-based call state sync.
7. Optionally integrate your call media SDK.

## Documentation

Start here:
- [Getting started](doc/getting-started.md)
- [Client handoff checklist](doc/client-handoff.md)

Platform setup:
- [Firebase setup](doc/firebase-setup.md)
- [Android setup](doc/android-setup.md)
- [iOS setup](doc/ios-setup.md)
- [APNs and Firebase linking](doc/ios-apns-firebase-linking.md)

SDK usage:
- [SDK usage](doc/usage.md)
- [Optional Firestore integration](doc/firestore-optional.md)
- [Optional call UI / call joining integration](doc/call-ui-integration.md)
- [Troubleshooting](doc/troubleshooting.md)

## Important Notes

- Android always uses `config_name: prod`.
- iOS sandbox uses `config_name: dev`.
- iOS production uses `config_name: prod`.
- Firestore support is optional and currently experimental.
- Android background call delivery still requires a top-level `FirebaseMessaging.onBackgroundMessage(...)` handler in the host app.
- Real iOS VoIP / CallKit validation still requires a signed physical device.

## Example App

See the example flow in [example/lib/main.dart](example/lib/main.dart).

The example shows:
- SDK initialization
- Android background FCM handling
- optional VoIP initialization
- token registration
- trigger by username or token
- optional Firestore adapter usage
- opening the provided incoming call screen

## Optional Call SDK

This package handles signaling and incoming-call orchestration. Joining the actual call is app-defined.

If you want to use Daakia's call SDK as well, see:
- https://pub.dev/packages/daakia_vc_flutter_sdk
