# Call UI And Call Joining Integration

`daakia_callkit_flutter` handles signaling and incoming-call orchestration.

It does not handle the actual media session by itself.

## Your Options

1. Use the provided `DaakiaIncomingCallScreen` for the incoming call experience and then open your own call screen after accept.
2. Ignore the provided incoming call screen and open your own custom UI from `onIncomingCall`.
3. Integrate a separate call SDK for joining the actual meeting or media session.

## Optional Daakia Call SDK

If you also want Daakia's call joining SDK, see:
- https://pub.dev/packages/daakia_vc_flutter_sdk

A practical flow is:
1. Receive incoming call payload.
2. Show incoming call UI.
3. User accepts.
4. Open your actual in-call screen.
5. Join the meeting using your media SDK.

## Important Separation

Keep these concerns separate in your app:
- incoming push and ringing
- accept / reject action handling
- actual call join and media rendering

That separation makes the integration easier to maintain.
