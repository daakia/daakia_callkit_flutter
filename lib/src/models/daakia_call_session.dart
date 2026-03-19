import 'daakia_call_status.dart';

class DaakiaCallSession {
  const DaakiaCallSession({
    required this.callId,
    required this.status,
    this.meetingId,
    this.callerId,
    this.receiverId,
    this.metadata = const <String, dynamic>{},
    this.reason,
  });

  final String callId;
  final DaakiaCallStatus status;
  final String? meetingId;
  final String? callerId;
  final String? receiverId;
  final Map<String, dynamic> metadata;
  final String? reason;
}
