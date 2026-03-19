import '../models/daakia_call_session.dart';
import '../models/daakia_call_status.dart';

abstract class DaakiaCallStateStore {
  Stream<DaakiaCallSession?> watchCall(String callId);

  Future<void> saveSession(DaakiaCallSession session);

  Future<void> updateStatus({
    required String callId,
    required DaakiaCallStatus status,
    String? actorId,
    String? reason,
  });
}
