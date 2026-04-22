# SDK Usage

Use this guide after Firebase and platform setup are already complete.

## Create The SDK

```dart
final sdk = DaakiaCallkitFlutter(
  config: const DaakiaCallkitConfig(
    baseUrl: 'https://your-daakia-base-url',
    secret: 'your-shared-secret',
  ),
);
```

## Initialize The SDK

```dart
await sdk.initialize(
  onIncomingCall: (payload) async {
    // Open your incoming call UI.
  },
  onCallEvent: (event) async {
    switch (event.type) {
      case DaakiaCallEventType.accepted:
        break;
      case DaakiaCallEventType.declined:
        break;
      case DaakiaCallEventType.ended:
        break;
      case DaakiaCallEventType.timedOut:
        break;
      case DaakiaCallEventType.incoming:
      case DaakiaCallEventType.unknown:
        break;
    }
  },
);
```

Call `initialize()` as part of app startup. Do not wait until the user opens a
debug, settings, or onboarding screen if you need accept actions from a closed
state to immediately continue into your app flow.

## Initialize iOS VoIP

Call this on iOS once the SDK is initialized, ideally in the same startup flow:

```dart
final voipToken = await sdk.initializeVoip(
  onVoipTokenUpdated: (token) async {
    // Persist or register updated token.
  },
);
```

## Register The Current Device

If you want the SDK to fetch the current FCM token and register the current push device:

```dart
await sdk.registerCurrentPushDevice(
  username: 'current_user_id',
  platform: DaakiaPlatform.android, // or DaakiaPlatform.ios
  voipToken: latestVoipToken,
);
```

`voipToken` is only relevant on iOS. On Android, leave it `null` or omit it.

If you already have the token yourself:

```dart
await sdk.registerCurrentDevice(
  username: 'current_user_id',
  token: 'fcm_or_apns_token',
  voipToken: 'optional_ios_voip_token',
  platform: DaakiaPlatform.android, // or DaakiaPlatform.ios
);
```

## Trigger A Call By Username

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
    'callTimestamp': DateTime.now().toUtc().toIso8601String(),
    'body': 'Incoming call',
    'title': 'Caller Name',
  },
);
```

## Trigger A Call By Token

```dart
await sdk.startCallByToken(
  token: 'device_token',
  platform: DaakiaPlatform.ios,
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

## Payload Shape To Keep Stable

For the current integration, keep these fields in the incoming call payload:
- `type`
- `callId`
- `sender`
- `callerId`
- `receiverId`
- `callTimestamp`
- `body`
- `title`

`sender` may be sent as a JSON string or an object. The SDK currently tolerates both.

## Event Handling

The main event types are:
- `incoming`
- `accepted`
- `declined`
- `ended`
- `timedOut`
- `unknown`

Use `event.call` for the parsed `DaakiaIncomingCallPayload`.

## Call Event Reporting

When using `daakia_vc_flutter_sdk` for the actual meeting join, report call lifecycle events to the Daakia backend.

### Send Call Event

Report user actions like accept, reject, end, or timeout:

```dart
await sdk.sendCallEvent(
  meetingUid: 'meeting_uid_123',
  action: DaakiaCallEventAction.callAccept,
  metadata: {'userId': 'current_user_id'},
);
```

The event is sent only once per action per meeting UID. Use `clearSentCallEventCache()` to reset if needed.

Metadata is optional and can be any key-value pairs you want to include.

### Configure Call Event Fallback

Set up fallback events for when the app is closed:

```dart
await sdk.configureCallEventFallback(
  actions: {DaakiaCallEventAction.callAccept, DaakiaCallEventAction.callReject},
  metadata: {'fallback': true},
);
```

This allows events to be sent even if the app process is not running. Metadata is fixed at setup time.

Metadata is optional and can be any key-value pairs you want to include.

### Clear Sent Call Event Cache

Reset the cache to allow re-sending the same event:

```dart
await sdk.clearSentCallEventCache();
```

Use this sparingly, as it bypasses duplicate prevention.

## Default Incoming Call Screen

If you want to use the built-in Flutter screen:

```dart
await Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => DaakiaIncomingCallScreen(
      payload: payload,
      onAccept: (payload) async {},
      onReject: (payload) async {},
      onTimeout: (payload) async {},
    ),
  ),
);
```

## Android Full-Screen Intent Check

```dart
if (!await sdk.notifications.canUseFullScreenIntent()) {
  await sdk.notifications.openFullScreenIntentSettings();
}
```

## What This Package Does Not Do

This package does not join the media call for you. Use your own RTC flow or see [call-ui-integration.md](call-ui-integration.md).
