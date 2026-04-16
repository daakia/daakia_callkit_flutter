enum DaakiaCallEventAction {
  callAccept('call-accept'),
  callReject('call-reject'),
  callTimeout('call-timeout'),
  callJoin('call-join'),
  callEnd('call-end');

  const DaakiaCallEventAction(this.value);

  final String value;
}
