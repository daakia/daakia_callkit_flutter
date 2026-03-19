enum DaakiaCallStatus {
  ringing,
  accepted,
  rejected,
  missed,
  cancelled,
  ended;

  String get value => name;
}
