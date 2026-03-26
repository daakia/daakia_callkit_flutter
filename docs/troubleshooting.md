# Troubleshooting

## Incoming Calls Work Only In Foreground On Android

Most likely cause:
- missing `FirebaseMessaging.onBackgroundMessage(...)` handler in the host app

Check:
- Firebase initializes inside the background handler
- the incoming push is a data payload
- `DaakiaNotificationService().showIncomingCallNotificationFromData(...)` is called

## Android Lock-Screen UI Does Not Appear

Check:
- `USE_FULL_SCREEN_INTENT` permission is present
- activity lock-screen flags are present
- Android 14 full-screen intent access is enabled for the app
- notification permission is granted
- the device is not heavily restricting background activity

## iOS VoIP Token Is Missing

Check:
- Push Notifications capability is enabled
- Background Modes include `voip`
- the app is running on a real device
- provisioning and entitlements match the bundle ID

## FCM Token Is Missing

Check:
- Firebase is initialized successfully
- the correct Firebase config file is present
- notification permission is granted where required
- the app is registered in the correct Firebase project

## Calls Reach Android But Not iOS

Check:
- APNs / Apple credential setup
- Firebase iOS app configuration
- Apple Team ID, Key ID, and `.p8` file mapping
- sandbox vs production environment mapping
- backend uses `dev` for iOS sandbox and `prod` for iOS production

## Accept Or Reject Does Not Sync To Other Side

Check:
- whether Firestore integration is enabled
- whether your app updates local call status after accept / reject / timeout
- whether you expected backend call status sync, which is not implemented yet

## A Note On OEM Android Devices

Some OEMs can make background incoming call behavior inconsistent even with correct integration.

Devices from vendors such as Xiaomi, Oppo, Vivo, and OnePlus may require users or testers to disable battery optimization and allow background activity.
