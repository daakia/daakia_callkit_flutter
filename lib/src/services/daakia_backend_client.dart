import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/daakia_callkit_config.dart';
import '../models/daakia_device_token_record.dart';
import '../models/daakia_platform.dart';
import '../models/daakia_push_result.dart';

class DaakiaBackendException implements Exception {
  const DaakiaBackendException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() =>
      'DaakiaBackendException(statusCode: $statusCode, message: $message)';
}

class DaakiaBackendClient {
  DaakiaBackendClient({
    required DaakiaCallkitConfig config,
    http.Client? httpClient,
  }) : _config = config,
       _httpClient = httpClient ?? http.Client();

  final DaakiaCallkitConfig _config;
  final http.Client _httpClient;

  Map<String, String> get _headers => <String, String>{
    'Content-Type': 'application/json',
    'secret': _config.secret,
  };

  Uri _uri(String path, [Map<String, String>? queryParameters]) {
    final base = Uri.parse(_config.baseUrl);
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return base.replace(
      path: '${base.path}$normalizedPath'.replaceAll('//', '/'),
      queryParameters: queryParameters,
    );
  }

  Future<Map<String, dynamic>> _decodeResponse(http.Response response) async {
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DaakiaBackendException(
        payload['message']?.toString() ?? 'Request failed',
        statusCode: response.statusCode,
      );
    }
    return payload;
  }

  void _throwIfBackendFailure(Map<String, dynamic> payload) {
    if ((payload['success'] as num? ?? 0) == 1) return;
    throw DaakiaBackendException(payload['message']?.toString() ?? 'Request failed');
  }

  Future<DaakiaDeviceTokenRecord> registerDeviceToken({
    required String username,
    required String token,
    required DaakiaPlatform platform,
    String? voipToken,
  }) async {
    final response = await _httpClient.post(
      _uri('/v2.0/saas/device-token/register'),
      headers: _headers,
      body: jsonEncode(<String, dynamic>{
        'username': username,
        'token': token,
        'voip_token': voipToken,
        'platform': platform.value,
      }),
    );
    final payload = await _decodeResponse(response);
    _throwIfBackendFailure(payload);
    return DaakiaDeviceTokenRecord.fromJson(
      Map<String, dynamic>.from(payload['data'] as Map<dynamic, dynamic>),
    );
  }

  Future<DaakiaDeviceTokenRecord> getDeviceToken({
    required String username,
    required DaakiaPlatform platform,
  }) async {
    final response = await _httpClient.get(
      _uri('/v2.0/saas/device-token/get', <String, String>{
        'username': username,
        'platform': platform.value,
      }),
      headers: _headers,
    );
    final payload = await _decodeResponse(response);
    _throwIfBackendFailure(payload);
    return DaakiaDeviceTokenRecord.fromJson(
      Map<String, dynamic>.from(payload['data'] as Map<dynamic, dynamic>),
    );
  }

  Future<DaakiaPushResult> triggerNotificationByToken({
    required String token,
    required DaakiaPlatform platform,
    required String title,
    required String message,
    required String configName,
    Map<String, dynamic> data = const <String, dynamic>{},
  }) async {
    final response = await _httpClient.post(
      _uri('/v2.0/saas/notification/trigger/by-token'),
      headers: _headers,
      body: jsonEncode(<String, dynamic>{
        'token': token,
        'platform': platform.value,
        'title': title,
        'message': message,
        'config_name': configName,
        'data': data,
      }),
    );
    final payload = await _decodeResponse(response);
    _throwIfBackendFailure(payload);
    return DaakiaPushResult.fromJson(payload);
  }

  Future<DaakiaPushResult> triggerNotificationByUsername({
    required String username,
    required String title,
    required String message,
    required String configName,
    Map<String, dynamic> data = const <String, dynamic>{},
  }) async {
    final response = await _httpClient.post(
      _uri('/v2.0/saas/notification/trigger'),
      headers: _headers,
      body: jsonEncode(<String, dynamic>{
        'username': username,
        'title': title,
        'message': message,
        'config_name': configName,
        'data': data,
      }),
    );
    final payload = await _decodeResponse(response);
    _throwIfBackendFailure(payload);
    return DaakiaPushResult.fromJson(payload);
  }
}
