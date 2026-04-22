# Example App Setup

This example app is a local integration demo for `daakia_callkit_flutter`.

It is not expected to run immediately after cloning the repository.

Some files and credentials are intentionally excluded from git, so you must add your own local setup before running the example.

## What You Need To Add Locally

The example app depends on local, uncommitted configuration for:
- Firebase Android config: `example/android/app/google-services.json`
- Firebase iOS config: `example/ios/Runner/GoogleService-Info.plist`
- FlutterFire generated options: `example/lib/firebase_options.dart`
- SDK credentials: `example/lib/secret/secret_credential.dart`

These files are intentionally ignored by git so secrets and client-specific configuration are not committed.

## Quick Setup

1. Create a Firebase project for your own test app.
2. Register the Android app in Firebase.
3. Register the iOS app in Firebase.
4. Add the Firebase config files to the example app.
5. Generate `firebase_options.dart` for the example app.
6. Create `example/lib/secret/secret_credential.dart` using the template below.
7. If needed, update the Android package name and iOS bundle identifier to match your Firebase app registration.
8. Run the example on real devices for push and call testing.

## Credential File

Create `example/lib/secret/secret_credential.dart` with this shape:

```dart
class SecretCredential {
  static const String baseUrl = 'https://your-daakia-base-url';
  static const String secretKey = 'your-daakia-secret';
  static const String daakiaVcSecretKey = 'your-daakia-vc-secret';
}
```

Notes:
- `baseUrl` and `secretKey` are used by the example app to initialize `daakia_callkit_flutter`.
- `daakiaVcSecretKey` is only relevant if you also want to test the optional `daakia_vc_flutter_sdk` flow from the example app.
- If you are not testing `daakia_vc_flutter_sdk`, you should still provide a placeholder value unless you remove that integration code locally.

## Firebase Setup

Android:
- place `google-services.json` in `example/android/app/`

iOS:
- place `GoogleService-Info.plist` in `example/ios/Runner/`
- ensure the file is added to the Runner target in Xcode

Generate FlutterFire options for the example app so `example/lib/firebase_options.dart` exists and matches your Firebase project.

## Package Name And Bundle Identifier

You have two valid options:

1. Keep the current example app identifiers and create matching Firebase apps for them.
2. Change the example app identifiers to match your own app naming.

If you change identifiers, make sure they stay consistent across:
- Firebase app registration
- Android package name
- iOS bundle identifier

## Important Notes

- The example app is only a demo shell for SDK integration.
- Push delivery and VoIP / CallKit validation should be tested on real devices.
- Firestore support in the SDK is currently experimental.
- The bundled example flow also includes optional `daakia_vc_flutter_sdk` usage. That part is not required if you only want to test call signaling and incoming call UI.

## Recommended First Test

For the first successful run, keep the scope small:
- initialize Firebase
- let the app auto-initialize the SDK from the saved config
- fetch and register the current push token
- test one incoming call

After that, add VoIP, Firestore, or call joining flows as needed.

The example app now persists the last initialized `baseUrl` and `secret`, then
boots the SDK from those saved values on startup. That keeps closed-state accept
navigation working while still allowing you to change credentials in the UI and
reinitialize for testing.
