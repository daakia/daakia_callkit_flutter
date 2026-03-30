# CHANGELOG

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
