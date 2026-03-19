class DaakiaVoipEvent {
  const DaakiaVoipEvent({required this.method, required this.payload});

  final String method;
  final Map<String, dynamic> payload;
}
