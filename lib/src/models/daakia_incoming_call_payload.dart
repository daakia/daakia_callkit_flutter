import 'dart:convert';

import 'daakia_caller.dart';

class DaakiaIncomingCallPayload {
  const DaakiaIncomingCallPayload({
    required this.type,
    required this.callId,
    required this.sender,
    this.callerId,
    this.receiverId,
    this.callTimestamp,
    this.body,
    this.title,
    this.raw = const <String, dynamic>{},
  });

  final String type;
  final String callId;
  final DaakiaCaller sender;
  final String? callerId;
  final String? receiverId;
  final DateTime? callTimestamp;
  final String? body;
  final String? title;
  final Map<String, dynamic> raw;

  factory DaakiaIncomingCallPayload.fromMap(Map<String, dynamic> source) {
    final payload = _normalizeSource(source);
    final senderRaw = payload['sender'];
    final senderMap = senderRaw is String
        ? Map<String, dynamic>.from(
            jsonDecode(senderRaw) as Map<String, dynamic>,
          )
        : Map<String, dynamic>.from(
            senderRaw as Map<dynamic, dynamic>? ?? const <String, dynamic>{},
          );

    return DaakiaIncomingCallPayload(
      type: payload['type']?.toString() ?? 'incoming_call',
      callId: payload['callId']?.toString() ?? '',
      sender: DaakiaCaller.fromJson(senderMap),
      callerId: payload['callerId']?.toString(),
      receiverId: payload['receiverId']?.toString(),
      callTimestamp: payload['callTimestamp'] == null
          ? null
          : DateTime.tryParse(payload['callTimestamp'].toString()),
      body: payload['body']?.toString(),
      title: payload['title']?.toString(),
      raw: payload,
    );
  }

  static Map<String, dynamic> _normalizeSource(Map<String, dynamic> source) {
    final nestedType = source['type'];
    if (nestedType is Map &&
        source['callId'] == null &&
        source['sender'] == null &&
        source['callerId'] == null) {
      return Map<String, dynamic>.from(nestedType);
    }
    return Map<String, dynamic>.from(source);
  }
}
