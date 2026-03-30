# Firestore Optional Integration

Use this guide only if you want realtime call state sync between caller and callee.

Skip this if basic incoming call delivery is enough for your first version.

## Stability Note

The Firestore adapter is currently experimental.

It is available for teams that want to try realtime call-state sync, but it is not fully validated yet. Do not treat it as a stable, production-proven part of the SDK at this stage.

## What Firestore Improves

When Firestore is enabled, it can improve:
- accepted state sync
- rejected state sync
- missed / timeout state sync
- caller-side awareness of call progress
- auto-closing or state-driven UI behavior

## What Happens Without Firestore

Without Firestore:
- token registration still works
- incoming call delivery still works
- call answer / reject UI can still work locally
- cross-device status sync becomes best-effort only

## Enable The Adapter

```dart
final sdk = DaakiaCallkitFlutter(
  config: const DaakiaCallkitConfig(
    baseUrl: 'https://your-daakia-base-url',
    secret: 'your-shared-secret',
  ),
  callStateStore: DaakiaFirestoreCallStateStore(),
);
```

## Update Local Call Status

```dart
await sdk.updateLocalCallStatus(
  callId: payload.callId,
  status: DaakiaCallStatus.accepted,
  actorId: payload.receiverId,
);
```

## Practical Recommendation

Do not block your first integration on Firestore.

Get this working first:
- push arrives
- incoming call screen opens
- accept or reject callbacks fire

Then add Firestore only if you need better multi-device state sync and are comfortable using an experimental feature.
