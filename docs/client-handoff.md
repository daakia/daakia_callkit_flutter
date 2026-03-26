# Client Handoff Checklist

Use this document when collecting everything needed from the client or integrating team.

This separates business-side coordination from SDK code setup.

## Required From Client

Backend and app identification:
- Daakia backend `baseUrl`
- Daakia backend `secret`
- Firebase project ID
- Android package name
- iOS bundle identifier
- Apple Team ID
- Apple `.p8` Key ID

Firebase / Google credentials:
- Firebase service account `key.json`
- `google-services.json` for Android app setup
- `GoogleService-Info.plist` for iOS app setup

Apple push credentials:
- APNs `.p8` key material and clear environment mapping for sandbox and production
- VoIP certificate or VoIP push credential material used by the backend

## Environment Notes

- If the client uses only production, sandbox credentials can be skipped.
- If the client wants both development and production iOS push delivery, keep the environments clearly separated.
- In this SDK, iOS sandbox resolves to `config_name: dev` and iOS production resolves to `config_name: prod`.

## What The Backend Team Usually Needs

To send pushes correctly, the backend side usually needs:
- Firebase service account `key.json`
- Firebase project ID
- Android package name
- iOS bundle identifier
- Apple Team ID
- `.p8` key file
- `.p8` Key ID
- APNs environment mapping for sandbox and production
- VoIP push credential setup if iOS incoming calls should use PushKit / CallKit

Depending on backend design, the same APNs auth key may be used for both iOS environments. Even in that case, the backend team still needs explicit sandbox and production mapping.

## Suggested Collection Format

Ask the client to provide these values in one structured handoff document:

```text
Project name:
Environment: dev / prod / both
Firebase project ID:
Android package name:
iOS bundle identifier:
Apple Team ID:
Apple Key ID:
APNs .p8 file:
Firebase service account key.json:
VoIP certificate / credential:
Daakia backend baseUrl:
Daakia backend secret:
```

## Validation Before Development Starts

Confirm these before implementation starts:
- Firebase project exists
- Android app is registered in Firebase
- iOS app is registered in Firebase
- APNs key is valid for the intended Apple account
- bundle ID matches the Apple setup
- package name matches the Firebase Android app
- backend team knows which environment is sandbox vs production

## Keep This Separate From SDK Docs

This checklist is intentionally separate from coding setup docs so developers can skip it if infrastructure is already prepared.
