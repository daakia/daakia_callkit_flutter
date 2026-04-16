/// Represents the call event actions that can be reported to the Daakia backend.
///
/// These values are used by [DaakiaCallkitFlutter.sendCallEvent] and
/// [DaakiaCallkitFlutter.configureCallEventFallback].
///
/// Prefer using these typed values instead of raw strings.
enum DaakiaCallEventAction {
  /// Accept the incoming call.
  callAccept('call-accept'),

  /// Reject or decline the incoming call.
  callReject('call-reject'),

  /// The incoming call timed out or was missed.
  callTimeout('call-timeout'),

  /// The user joined the meeting.
  callJoin('call-join'),

  /// The call was ended.
  callEnd('call-end');

  const DaakiaCallEventAction(this.value);

  final String value;
}
