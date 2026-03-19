class DaakiaCaller {
  const DaakiaCaller({
    required this.uid,
    this.phone,
    this.userName,
    this.fcmToken,
    this.voipToken,
    this.createdAt,
    this.lastLogin,
  });

  final String uid;
  final String? phone;
  final String? userName;
  final String? fcmToken;
  final String? voipToken;
  final DateTime? createdAt;
  final DateTime? lastLogin;

  factory DaakiaCaller.fromJson(Map<String, dynamic> json) {
    return DaakiaCaller(
      uid: json['uid']?.toString() ?? '',
      phone: json['phone']?.toString(),
      userName: json['userName']?.toString(),
      fcmToken: json['fcmToken']?.toString(),
      voipToken: json['voipToken']?.toString(),
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.tryParse(json['createdAt'].toString()),
      lastLogin: json['lastLogin'] == null
          ? null
          : DateTime.tryParse(json['lastLogin'].toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'uid': uid,
      'phone': phone,
      'userName': userName,
      'fcmToken': fcmToken,
      'voipToken': voipToken,
      'createdAt': createdAt?.toIso8601String(),
      'lastLogin': lastLogin?.toIso8601String(),
    };
  }
}
