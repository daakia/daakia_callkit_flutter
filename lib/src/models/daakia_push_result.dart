class DaakiaPushResult {
  const DaakiaPushResult({
    required this.success,
    required this.message,
    required this.data,
  });

  final bool success;
  final String message;
  final Map<String, dynamic> data;

  factory DaakiaPushResult.fromJson(Map<String, dynamic> json) {
    return DaakiaPushResult(
      success: (json['success'] as num? ?? 0) == 1,
      message: json['message']?.toString() ?? '',
      data: Map<String, dynamic>.from(
        json['data'] as Map<dynamic, dynamic>? ?? const <String, dynamic>{},
      ),
    );
  }
}
