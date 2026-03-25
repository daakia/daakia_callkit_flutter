import 'daakia_incoming_call_payload.dart';
import 'daakia_platform.dart';
import 'daakia_voip_event.dart';

enum DaakiaCallEventType {
  incoming,
  accepted,
  declined,
  ended,
  timedOut,
  unknown,
}

class DaakiaCallEvent {
  const DaakiaCallEvent({
    required this.method,
    required this.payload,
    required this.platform,
  });

  factory DaakiaCallEvent.fromVoipEvent(DaakiaVoipEvent event) {
    return DaakiaCallEvent(
      method: event.method,
      payload: event.payload,
      platform: DaakiaPlatform.ios,
    );
  }

  final String method;
  final Map<String, dynamic> payload;
  final DaakiaPlatform platform;

  DaakiaCallEventType get type {
    switch (method) {
      case 'incomingCall':
        return DaakiaCallEventType.incoming;
      case 'callAccepted':
        return DaakiaCallEventType.accepted;
      case 'callDeclined':
        return DaakiaCallEventType.declined;
      case 'callEnded':
        return reason == 'timeout'
            ? DaakiaCallEventType.timedOut
            : DaakiaCallEventType.ended;
      default:
        return DaakiaCallEventType.unknown;
    }
  }

  String? get reason => payload['reason']?.toString();

  DaakiaIncomingCallPayload get call =>
      DaakiaIncomingCallPayload.fromMap(payload);
}
