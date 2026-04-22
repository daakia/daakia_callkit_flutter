# CHANGELOG

## 1.1.1 - (2026-04)

- Fixed Android accept-from-notification behavior on modern Android versions by removing the service-to-activity trampoline path that could block app launch when the app was fully closed.
- Updated the example app to auto-initialize from the last saved SDK config at startup so closed-state accept actions can navigate into the call flow without waiting for manual initialization.
- Added `DaakiaCallkitFlutter.dispose()` to make same-process SDK reinitialization safe when switching test credentials.

## 1.1.0 - (2026-04)

Added call event reporting features for integrations using `daakia_vc_flutter_sdk`.

Included in this release:
- `sendCallEvent()` method to report call lifecycle events (accept, reject, end, timeout) to the Daakia backend
- `configureCallEventFallback()` method to configure fallback events when the app is closed
- `clearSentCallEventCache()` method to reset the sent event cache for re-sending events
- `DaakiaCallEventAction` enum for typed call event actions
- Updated documentation in `doc/usage.md` with call event reporting examples

Notes:
- Call event methods are designed for use with `daakia_vc_flutter_sdk` for actual meeting join flow.
- Fallback events allow webhook delivery even when the app process is not running.
- Metadata in events is flexible and optional.

## 1.0.0 - (2026-03)

Initial release of `daakia_callkit_flutter`.

Included in this release:
- Daakia-backed incoming call signaling for Android and iOS
- device token registration with backend support for `token` and optional iOS `voip_token`
- incoming call trigger support by username or direct device token
- automatic backend `config_name` resolution for Android, iOS sandbox, and iOS production
- Android incoming call notifications with full-screen intent support
- iOS VoIP / CallKit bridge integration
- default incoming call screen widget
- Firebase Messaging helper integration for device registration flow
- optional experimental Firestore-based realtime call-state sync
- example app showing initialization, token registration, VoIP setup, and incoming call handling

Notes:
- Firestore support is currently experimental and not fully validated yet.
- Real iOS VoIP / CallKit validation requires a signed physical device.
- Android background incoming call delivery still requires a host-app `FirebaseMessaging.onBackgroundMessage(...)` handler.
