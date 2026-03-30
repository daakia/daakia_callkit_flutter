# Client Handoff Checklist

Use this document during client onboarding.

It explains:
- what the client must share with Daakia
- what Daakia will set up for the client
- what Daakia will provide back for SDK integration

## What The Client Must Provide

App and project identification:
- Firebase project ID
- Android package name
- iOS bundle identifier
- Apple Team ID
- Apple `.p8` Key ID

Firebase and app setup files:
- Firebase service account `key.json`

Apple push and VoIP setup material:
- APNs `.p8` key file
- clear environment requirement: sandbox, production, or both
- VoIP certificate or VoIP push credential material for iOS incoming call delivery

## What Daakia Will Do

After receiving the required files and project details, Daakia will complete the required backend-side setup for the client.

This includes setting up the client configuration needed for:
- Firebase notification delivery
- APNs configuration
- VoIP push setup where applicable
- environment mapping for iOS sandbox and production

## What Daakia Will Provide Back

After onboarding is completed, Daakia will provide:
- Daakia backend `baseUrl`
- Daakia backend `secret`
- SDK usage authorization or license key
- confirmation that backend-side setup is completed

## Important Environment Notes

- iOS sandbox and iOS production are different environments.
- `dev` and `prod` are not interchangeable.
- a production setup cannot be used as a sandbox setup
- a sandbox setup cannot be used as a production setup

In this SDK:
- iOS sandbox resolves to `config_name: dev`
- iOS production resolves to `config_name: prod`

If a client provides only production credentials:
- production usage is possible
- sandbox testing will not work

If a client wants both sandbox testing and production use:
- both environments must be prepared correctly
- the corresponding credentials and setup details must be available

## Suggested Collection Format

Ask the client to provide these values in one structured handoff document:

```text
Project name:
Environment required: sandbox / production / both
Firebase project ID:
Android package name:
iOS bundle identifier:
Apple Team ID:
Apple Key ID:
APNs .p8 file:
Firebase service account key.json:
VoIP certificate / credential:
```

## Validation Before SDK Integration

Confirm these before SDK integration starts:
- Firebase project exists
- Android app is registered in Firebase
- iOS app is registered in Firebase
- APNs key is valid for the intended Apple account
- bundle ID matches the Apple setup
- package name matches the Firebase Android app
- required environment choice is clearly confirmed: sandbox, production, or both
- Daakia backend setup is completed
- Daakia `baseUrl` and `secret` have been issued to the client

## Keep This Separate From SDK Docs

This checklist is intentionally separate from coding setup docs so developers can skip it if onboarding is already completed.
