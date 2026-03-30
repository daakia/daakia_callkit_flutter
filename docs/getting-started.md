# Getting Started

Use this guide when you want the shortest correct integration path.

Skip sections you already completed in your app.

## What You Will Finish With

After this guide, your app should be able to:
- initialize `daakia_callkit_flutter`
- register device tokens with the Daakia backend
- receive incoming call pushes
- show incoming call UI on Android and iOS

## Before You Start

You need:
- Flutter app with Android and/or iOS targets
- Daakia backend `baseUrl`
- Daakia backend `secret`
- Firebase project for the app
- Android package name
- iOS bundle identifier

For server-side setup, also review [client-handoff.md](client-handoff.md).

## Recommended Integration Order

1. Complete [Firebase setup](firebase-setup.md).
2. Complete [Android setup](android-setup.md) if your app supports Android.
3. Complete [iOS setup](ios-setup.md) if your app supports iOS.
4. Complete [APNs and Firebase linking](ios-apns-firebase-linking.md) if your iOS app will receive pushes.
5. Add the SDK and initialize it as shown in [usage.md](usage.md).
6. Register the current device token.
7. Test with a real incoming call payload.
8. Add optional pieces only if you need them:
   - [Firestore realtime sync](firestore-optional.md)
   - [Call joining / custom call UI](call-ui-integration.md)

## Required Vs Optional

Required for basic incoming call flow:
- Firebase setup
- SDK initialization
- token registration
- Android background message handler for Android
- iOS VoIP / APNs setup for iOS

Optional:
- Firestore call state sync
- custom ringtone behavior
- your own incoming call UI
- `daakia_vc_flutter_sdk` or any other media SDK

## Minimal Integration Checklist

1. Add the package to `pubspec.yaml`.
2. Initialize Firebase in `main()`.
3. Register `FirebaseMessaging.onBackgroundMessage(...)`.
4. Create `DaakiaCallkitFlutter` with `baseUrl` and `secret`.
5. Call `sdk.initialize(...)`.
6. On iOS, call `sdk.initializeVoip(...)`.
7. Call `sdk.registerCurrentPushDevice(...)` after login or user identification.
8. Trigger a test call from your backend or test app.

## Keep The Root Flow Simple

A common mistake is trying to implement every optional feature on day one.

For the first pass, aim for this sequence only:
- setup Firebase
- setup Android or iOS platform requirements
- initialize SDK
- register token
- receive one incoming call successfully

Once this works, add optional Firestore sync or your call media SDK.
