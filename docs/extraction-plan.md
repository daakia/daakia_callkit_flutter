# Extraction Plan For `daakia_callkit_flutter`

This file lives in the future package workspace and maps the SDK back to the `acetime` reference app.

## Reference Project

Source app:
- `/Users/ashif/StudioProjects/acetime`

Primary reference files:
- `/Users/ashif/StudioProjects/acetime/lib/service/call_service.dart`
- `/Users/ashif/StudioProjects/acetime/lib/service/notification_service.dart`
- `/Users/ashif/StudioProjects/acetime/lib/service/ios_voip_service.dart`
- `/Users/ashif/StudioProjects/acetime/lib/service/ringtone_service.dart`
- `/Users/ashif/StudioProjects/acetime/lib/presentation/screens/incoming_call_screen.dart`
- `/Users/ashif/StudioProjects/acetime/lib/presentation/screens/outgoing_call_screen.dart`
- `/Users/ashif/StudioProjects/acetime/ios/Runner/AppDelegate.swift`

## Package Mission

Publish a reusable Flutter package that reduces host-app implementation effort for call signaling and incoming-call handling.

The package should support:
- Android
- iOS

The package should integrate with:
- backend APIs for token registration and push triggering
- Firestore for call state tracking

## Explicit Non-Goals

- auth
- messaging/chat
- contacts sync
- server-side FCM/APNs send implementation
- app credential dashboard
- business-specific user management

## Package Modules

Suggested layout:

```text
lib/
  daakia_callkit_flutter.dart
  src/
    config/
    core/
    models/
    services/
    platform/
    ui/
```

## Source To Target Mapping

From `acetime`:

- `lib/service/call_service.dart`
  - move into package as Firestore call state service

- `lib/service/ios_voip_service.dart`
  - move into package as iOS VoIP platform service

- `lib/service/ringtone_service.dart`
  - move into package as ringtone helper

- `lib/service/notification_service.dart`
  - split into:
    - local notification orchestration
    - incoming call action handler
    - backend API client hook
  - remove:
    - direct FCM HTTP v1 client sending from app
    - service account credential loading in client

- `ios/Runner/AppDelegate.swift`
  - port logic into plugin iOS classes
  - keep method channel behavior compatible with package Dart layer

- `lib/presentation/screens/incoming_call_screen.dart`
  - either:
    - package default UI
    - or package example app only

- `lib/presentation/screens/outgoing_call_screen.dart`
  - optional example/default UI

## Required Public API

Suggested public API:

```dart
DaakiaCallkitFlutter.initialize(...)
DaakiaCallkitFlutter.registerCurrentDevice()
DaakiaCallkitFlutter.startCall(...)
DaakiaCallkitFlutter.acceptCall(callId)
DaakiaCallkitFlutter.rejectCall(callId)
DaakiaCallkitFlutter.endCall(callId)
DaakiaCallkitFlutter.watchCall(callId)
```

## Required Models

- `DaakiaCallConfig`
- `DaakiaCaller`
- `DaakiaCallee`
- `DaakiaCallSession`
- `DaakiaCallStatus`
- `DaakiaIncomingCallPayload`

## Backend Assumptions

Backend will provide APIs for:
- registering user device tokens
- storing app credentials
- triggering call pushes
- optionally mirroring call status

Backend will own:
- FCM credentials
- APNs credentials
- VoIP push credentials

## Confirmed API Inputs From Backend

Shared header for current APIs:

```http
secret: 0D16716AFADABE17F5A42C6642CF2711ED9F59F2C89C12B2
```

Header note:
- backend uses this `secret` header to identify which client credentials/configuration should be used
- `platform` values must be exactly `android` or `ios`

Current environment detail:
- backend base URL should come from team-provided environment/secret configuration

### 1. Register device token

Endpoint:
- `POST v2.0/saas/device-token/register`

Current request:

```json
{
  "username": "4jt4RS79UVPi3AayqKoiqtNmKmx2",
  "token": "fcm_or_apns_token",
  "platform": "android/ios"
}
```

Package design note:
- create a request model around `username`, `token`, and `platform`
- do not name the SDK field `fcmToken` internally at the API boundary because the backend may soon use this endpoint for VoIP too

TODO:
- extend this request model when backend adds VoIP token support in the same API
- likely backend field name will be `voip_token` or similar, but this is not finalized yet

Current response:

```json
{
  "success": 1,
  "message": "Device token updated successfully",
  "data": {
    "id": 1,
    "saas_user_id": 38315,
    "username": "4jt4RS79UVPi3AayqKoiqtNmKmx2",
    "token": "fcm_or_apns_token",
    "platform": "android"
  }
}
```

### 2. Get device token

Endpoint:
- `GET v2.0/saas/device-token/get`

Query params:

```text
username=<user_id>
platform=android|ios
```

Purpose:
- backend-managed token lookup by username

Current response:

```json
{
  "success": 1,
  "message": "Device token fetched successfully",
  "data": {
    "id": 1,
    "saas_user_id": 38315,
    "username": "4jt4RS79UVPi3AayqKoiqtNmKmx2",
    "platform": "android",
    "token": "fcm_or_apns_token"
  }
}
```

### 3. Trigger notification by token

Endpoint:
- `POST /v2.0/saas/notification/trigger/by-token`

Observed payload shape:

```json
{
  "token": "device_token",
  "platform": "android",
  "title": "Caller Name",
  "message": "Test Message",
  "config_name": "prod",
  "data": {
    "type": {
      "type": "incoming_call",
      "callId": "a0ee8560aa5570cd608dcb54",
      "sender": {
        "uid": "caller_id",
        "phone": "+919393939393",
        "userName": "Test Num",
        "fcmToken": "device_token",
        "voipToken": null,
        "createdAt": null,
        "lastLogin": null
      },
      "callerId": "caller_id",
      "receiverId": "receiver_id",
      "callTimestamp": "2026-03-19T09:11:11.197960Z",
      "body": "Incoming call",
      "title": "Caller Name"
    }
  }
}
```

Important note:
- `data.type` currently contains the actual call payload object instead of a plain string
- package parsing should remain tolerant here because the backend payload format may still settle

Important note:
- `config_name` supports APNs environment selection such as `stag` or `prod`
- this is especially relevant for iOS sandbox vs production push credentials

SDK rule for `config_name`:
- Android: always send `prod`
- iOS sandbox: send `stag`
- iOS production: send `prod`

Current response:

```json
{
  "success": 1,
  "message": "Push notification triggered",
  "data": {
    "token": "device_token",
    "platform": "android",
    "config_name": "prod",
    "sent": 1,
    "failed": 0,
    "errors": []
  }
}
```

### 4. Trigger notification by username

Endpoint:
- `POST /v2.0/saas/notification/trigger`

Purpose:
- same behavior as `trigger/by-token`
- backend resolves token using username

Current request:

```json
{
  "username": "username",
  "platform": "android",
  "title": "Ashif Airtel",
  "message": "Test Message",
  "config_name": "prod",
  "data": {}
}
```

Package implication:
- support both strategies through an abstraction so host app can choose:
  - token-driven trigger
  - username-driven trigger

SDK rule for `config_name`:
- Android: always send `prod`
- iOS sandbox: send `stag`
- iOS production: send `prod`

Current response:

```json
{
  "success": 1,
  "message": "Push notification triggered",
  "data": {
    "username": "4jt4RS79UVPi3AayqKoiqtNmKmx2",
    "config_name": "prod",
    "android": {
      "total_tokens": 1,
      "sent": 1,
      "failed": 0,
      "errors": []
    },
    "ios": {
      "total_tokens": 0,
      "sent": 0,
      "failed": 0,
      "errors": []
    },
    "overall": {
      "total_tokens": 1,
      "sent": 1,
      "failed": 0
    }
  }
}
```

## Pending API Contracts

Still under development:
- dedicated VoIP trigger API
- dedicated FCM call trigger API
- call status update API

Implementation rule:
- add TODO-backed interfaces now
- avoid final package behavior that depends on guessed response schemas
- treat call status update support as pending until backend shares final endpoint, method, and payload

## Firestore Scope

Firestore is used only for:
- call state storage
- call state listeners

Firestore is not used for:
- token storage
- user profile registry
- app credential storage

## Immediate Build Order

1. Create package skeleton.
2. Move platform-independent call models/status.
3. Move Firestore call status service.
4. Move ringtone service.
5. Move iOS VoIP bridge.
6. Rebuild notification orchestration without direct client-side FCM sending.
7. Add backend API client abstraction.
8. Add example app.
9. Add setup docs.

## Integration Requirements For Host Apps

- Firebase setup
- iOS PushKit/VoIP capability setup
- APNs setup
- Android notification permissions
- Firestore project configuration
- backend base URL and app/user identifiers

## Delivery Target

For the first publishable MVP, prioritize:
- stable initialization
- device token registration
- incoming call handling
- call accept/reject/end state sync
- example integration

Defer:
- dashboard
- rich theming/custom UI APIs
- advanced call analytics
- multi-party orchestration beyond current flow
