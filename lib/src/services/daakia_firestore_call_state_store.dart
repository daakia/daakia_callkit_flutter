import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/daakia_call_session.dart';
import '../models/daakia_call_status.dart';
import 'daakia_call_state_store.dart';

class DaakiaFirestoreCallStateStore implements DaakiaCallStateStore {
  DaakiaFirestoreCallStateStore({
    FirebaseFirestore? firestore,
    this.collectionPath = 'calls',
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final String collectionPath;

  DocumentReference<Map<String, dynamic>> _callRef(String callId) {
    return _firestore.collection(collectionPath).doc(callId);
  }

  @override
  Future<void> saveSession(DaakiaCallSession session) async {
    await _callRef(session.callId).set(<String, dynamic>{
      'callId': session.callId,
      'meetingId': session.meetingId ?? session.callId,
      'status': session.status.value,
      'callerId': session.callerId,
      'receiverId': session.receiverId,
      'metadata': session.metadata,
      'reason': session.reason,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      if (session.status == DaakiaCallStatus.accepted)
        'acceptedAt': FieldValue.serverTimestamp(),
      if (session.status == DaakiaCallStatus.ended)
        'endedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> updateStatus({
    required String callId,
    required DaakiaCallStatus status,
    String? actorId,
    String? reason,
  }) async {
    await _callRef(callId).set(<String, dynamic>{
      'status': status.value,
      'actorId': actorId,
      'reason': reason,
      'updatedAt': FieldValue.serverTimestamp(),
      if (status == DaakiaCallStatus.accepted)
        'acceptedAt': FieldValue.serverTimestamp(),
      if (status == DaakiaCallStatus.ended)
        'endedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Stream<DaakiaCallSession?> watchCall(String callId) {
    return _callRef(callId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      final data = snapshot.data();
      if (data == null) return null;
      return _sessionFromMap(data);
    });
  }

  DaakiaCallSession _sessionFromMap(Map<String, dynamic> data) {
    return DaakiaCallSession(
      callId: data['callId']?.toString() ?? '',
      meetingId: data['meetingId']?.toString(),
      status: _statusFromValue(data['status']?.toString()),
      callerId: data['callerId']?.toString(),
      receiverId: data['receiverId']?.toString(),
      metadata: Map<String, dynamic>.from(
        data['metadata'] as Map<dynamic, dynamic>? ?? const <String, dynamic>{},
      ),
      reason: data['reason']?.toString(),
    );
  }

  DaakiaCallStatus _statusFromValue(String? value) {
    return DaakiaCallStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => DaakiaCallStatus.ringing,
    );
  }
}
