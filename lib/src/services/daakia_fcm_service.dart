import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class DaakiaFcmService {
  DaakiaFcmService({FirebaseMessaging? messaging}) : _messaging = messaging;

  final FirebaseMessaging? _messaging;
  String? _cachedToken;

  FirebaseMessaging get _resolvedMessaging =>
      _messaging ?? FirebaseMessaging.instance;

  String? get cachedToken => _cachedToken;

  Future<String?> getFcmToken({
    bool requestApplePermission = true,
    bool provisionalPermission = true,
  }) async {
    try {
      if (Platform.isIOS && requestApplePermission) {
        final settings = await _resolvedMessaging.requestPermission(
          provisional: provisionalPermission,
        );

        if (settings.authorizationStatus == AuthorizationStatus.denied) {
          debugPrint('[DaakiaFcmService] iOS notification permission denied');
          return null;
        }

        String? apnsToken = await _resolvedMessaging.getAPNSToken();
        if (apnsToken == null) {
          await Future<void>.delayed(const Duration(seconds: 3));
          apnsToken = await _resolvedMessaging.getAPNSToken();
        }
      }

      final token = await _resolvedMessaging.getToken();
      _cachedToken = token;
      return token;
    } catch (error) {
      debugPrint('[DaakiaFcmService] Failed to get token: $error');
      return null;
    }
  }

  StreamSubscription<String> listenForTokenRefresh({
    FutureOr<void> Function(String newToken)? onRefresh,
  }) {
    return _resolvedMessaging.onTokenRefresh.listen((String newToken) async {
      _cachedToken = newToken;
      await onRefresh?.call(newToken);
    });
  }
}
