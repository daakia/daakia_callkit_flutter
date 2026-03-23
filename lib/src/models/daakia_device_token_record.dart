class DaakiaDeviceTokenRecord {
  const DaakiaDeviceTokenRecord({
    required this.id,
    required this.saasUserId,
    required this.username,
    required this.platform,
    required this.token,
    this.voipToken,
  });

  final int id;
  final int saasUserId;
  final String username;
  final String platform;
  final String token;
  final String? voipToken;

  factory DaakiaDeviceTokenRecord.fromJson(Map<String, dynamic> json) {
    return DaakiaDeviceTokenRecord(
      id: json['id'] as int? ?? 0,
      saasUserId: json['saas_user_id'] as int? ?? 0,
      username: json['username']?.toString() ?? '',
      platform: json['platform']?.toString() ?? '',
      token: json['token']?.toString() ?? '',
      voipToken: json['voip_token']?.toString(),
    );
  }
}
