`daakia_callkit_flutter` is a Flutter package for Daakia-backed call signaling and incoming-call orchestration.

## Features

- register device tokens with Daakia backend
- trigger incoming call notifications by `username` or direct `token`
- resolve `config_name` automatically for Android vs iOS sandbox/production
- show local full-screen incoming call notifications
- expose a default incoming call screen widget
- provide FCM token helper, ringtone helper, and iOS VoIP method-channel bridge
- support optional realtime call-state storage through an adapter
- keep Firestore optional instead of mandatory

## Getting started

Current backend-backed MVP requires:
- Daakia backend base URL
- shared `secret` header
- host app user identity
- platform value as `android` or `ios`

Notes:
- Android always uses `config_name: prod`
- iOS sandbox uses `config_name: dev`
- iOS production uses `config_name: prod`
- backend call status API is still pending, so status sync to backend is not implemented yet

### Android setup

Add these permissions in `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT" />
<uses-permission android:name="android.permission.VIBRATE" />
```

For better lock-screen behavior, configure your main activity similar to:

```xml
<activity
    android:name=".MainActivity"
    android:exported="true"
    android:launchMode="singleTop"
    android:showOnLockScreen="true"
    android:turnScreenOn="true"
    android:showWhenLocked="true" />
```

How lock-screen incoming call works on Android in this package:
- package shows a `flutter_local_notifications` notification with `fullScreenIntent: true`
- Android uses that as the call alert entry point
- your host app should open its incoming call UI when the notification action or payload is handled
- the provided `DaakiaIncomingCallScreen` keeps the screen awake while visible with `wakelock_plus`
- Android call notifications in the package use the system ringtone URI by default instead of a bundled custom ringtone asset
- the package-provided incoming call screen does not auto-start a custom ringtone on Android by default

Important for Android background / lock-screen delivery:
- foreground handling alone is not enough
- if you use FCM data messages for incoming calls, the host app must register a top-level `FirebaseMessaging.onBackgroundMessage(...)` handler
- that background handler should initialize Firebase if needed, initialize `DaakiaNotificationService`, and call `showIncomingCallNotificationFromData(...)`
- without this, incoming calls may work only while the app is foregrounded
- this cannot be fully hidden by the package because `firebase_messaging` requires the background handler entrypoint to live in the host app

Minimal Android background handler shape:

```dart
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
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
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  runApp(const MyApp());
}
```

For better UX after notification taps:
- also handle `FirebaseMessaging.onMessageOpenedApp`
- also check `FirebaseMessaging.instance.getInitialMessage()`

Android 14+ full-screen intent note:
- a manifest declaration alone is not always enough for lock-screen full-screen incoming call UI
- on Android 14 and newer, full-screen intent access can be disabled in system settings for the app
- the package exposes helpers through `sdk.notifications.canUseFullScreenIntent()` and `sdk.notifications.openFullScreenIntentSettings()`
- if full-screen intent access is disabled, the app should explain the requirement and route the user to settings

Backend note:
- Android background wake-up is much more reliable when the backend sends a high-priority FCM data message for `incoming_call`
- `flutter_local_notifications` can present a call-style full-screen notification, but it is still not identical to a native Android telecom/dialer integration; exact ringing behavior may vary by device/OEM

OEM/device note:
- some Android OEMs such as OnePlus, Xiaomi, Oppo, and Vivo can make lock-screen or background incoming-call behavior intermittent even when the package integration is correct
- for these devices, ask users/testers to disable battery optimization for the app and allow background activity / auto-launch / lock-screen notifications where the ROM exposes those controls
- if lock-screen incoming calls are inconsistent, verify notification permission is still granted and confirm the backend is sending `incoming_call` as a high-priority data-only FCM payload

### iOS setup

Current package state:
- Dart-side VoIP bridge is present
- package now includes iOS plugin-side PushKit/CallKit bridge
- backend `config_name` should be `dev` for sandbox and `prod` for production

Required capabilities and settings in the host iOS app:
- Push Notifications capability
- Background Modes:
  - `voip`
  - `remote-notification`
  - `audio`
- APNs entitlement with correct environment

Add these background modes to `Info.plist`:

```xml
<key>UIBackgroundModes</key>
<array>
  <string>remote-notification</string>
  <string>voip</string>
  <string>audio</string>
</array>
```

Add APNs entitlement in your entitlements file:

```xml
<key>aps-environment</key>
<string>development</string>
```

Use `production` for release provisioning when appropriate.

### Firestore setup

Firestore is optional.

If enabled:
- you can plug in a realtime `DaakiaCallStateStore`
- package includes `DaakiaFirestoreCallStateStore` for Firestore-backed sync
- caller/callee status sync becomes much better

If disabled:
- incoming call trigger still works
- users can still receive and answer calls
- realtime cancel/reject/missed/end synchronization becomes best-effort only

## Usage

Preferred integration pattern:

```dart
final sdk = DaakiaCallkitFlutter(
  config: const DaakiaCallkitConfig(
    baseUrl: 'https://your-daakia-base-url',
    secret: 'your-shared-secret',
  ),
);

await sdk.initialize(
  onIncomingCall: (payload) async {
    // Open your incoming-call UI if your app needs a Flutter screen.
  },
  onCallEvent: (event) async {
    switch (event.type) {
      case DaakiaCallEventType.incoming:
        break;
      case DaakiaCallEventType.accepted:
        break;
      case DaakiaCallEventType.declined:
        break;
      case DaakiaCallEventType.ended:
        break;
      case DaakiaCallEventType.timedOut:
        break;
      case DaakiaCallEventType.unknown:
        break;
    }
  },
);
```

Notes:
- `sdk.initialize(...)` is the recommended app-facing setup entrypoint
- `event.type` is the preferred typed lifecycle signal
- `event.call` gives you the parsed `DaakiaIncomingCallPayload`
- `event.platform` is available if you need platform-specific behavior
- older lower-level APIs such as `sdk.events`, `sdk.voip.events`, and `sdk.notifications.initialize(...)` are still available for backward compatibility

Example Android 14+ check:

```dart
if (Platform.isAndroid &&
    !await sdk.notifications.canUseFullScreenIntent()) {
  await sdk.notifications.openFullScreenIntentSettings();
}
```

Basic setup and backend calls:

```dart
final sdk = DaakiaCallkitFlutter(
  config: const DaakiaCallkitConfig(
    baseUrl: 'https://your-daakia-base-url',
    secret: 'your-shared-secret',
  ),
);

await sdk.registerCurrentDevice(
  username: 'current_user_id',
  token: 'fcm_or_apns_token',
  voipToken: 'optional_ios_voip_token',
  platform: DaakiaPlatform.android,
);

await sdk.startCallByUsername(
  username: 'target_user_id',
  title: 'Ashif Airtel',
  message: 'Incoming call',
  data: {
    'type': 'incoming_call',
    'callId': 'meeting_uid_123',
    'sender': '{"uid":"current_user_id","userName":"Ashif Airtel"}',
    'callerId': 'current_user_id',
    'receiverId': 'target_user_id',
  },
);
```

Trigger directly by device token:

```dart
await sdk.startCallByToken(
  token: 'device_token',
  platform: DaakiaPlatform.ios,
  title: 'Ashif Airtel',
  message: 'Incoming call',
  data: {
    'type': 'incoming_call',
    'callId': 'meeting_uid_123',
    'sender': '{"uid":"current_user_id","userName":"Ashif Airtel"}',
    'callerId': 'current_user_id',
    'receiverId': 'target_user_id',
  },
);
```

Use Firestore for realtime call state:

```dart
final sdk = DaakiaCallkitFlutter(
  config: const DaakiaCallkitConfig(
    baseUrl: 'https://your-daakia-base-url',
    secret: 'your-shared-secret',
  ),
  callStateStore: DaakiaFirestoreCallStateStore(),
);
```

Register current FCM token directly:

```dart
await sdk.registerCurrentFcmDevice(
  username: 'current_user_id',
  platform: DaakiaPlatform.android,
  voipToken: 'optional_ios_voip_token',
);
```

Initialize iOS VoIP token registration:

```dart
await sdk.initializeVoip(
  onVoipTokenUpdated: (token) async {
    // Save or register the updated VoIP token.
  },
);
```

If you need the lower-level notification setup explicitly:

```dart
await sdk.notifications.initialize(
  onIncomingCall: (payload) async {
    // Open your incoming call UI here.
  },
);

await sdk.notifications.showIncomingCallNotificationFromData(payloadMap);
```

Use the package-provided Flutter incoming call screen:

```dart
Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => DaakiaIncomingCallScreen(
      payload: payload,
      onAccept: (payload) async {
        // open your meeting/call screen
      },
      onReject: (payload) async {
        // update local/backend status
      },
      onTimeout: (payload) async {
        // optional timeout handling
      },
    ),
  ),
);
```

## Additional information

Current status of the package:
- backend token registration and trigger APIs are wired
- local incoming call notification handling is available
- default incoming call screen is available
- FCM helper and VoIP bridge are available on Dart side
- iOS plugin-side PushKit/CallKit bridge is included
- backend call status API is still pending

Firestore is optional. Without a realtime call-state store, signaling still works, but callers and callees lose realtime cancel/reject/missed/end synchronization. The package exposes an adapter interface for call-state storage so Firestore support can be plugged in without making it a hard dependency.
