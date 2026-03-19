import 'dart:async';
import 'dart:developer';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class DaakiaRingtoneService {
  DaakiaRingtoneService._internal();

  static final DaakiaRingtoneService _instance =
      DaakiaRingtoneService._internal();

  factory DaakiaRingtoneService() => _instance;

  final AudioPlayer _player = AudioPlayer();
  Timer? _timeoutTimer;
  Timer? _vibrationTimer;
  bool _configured = false;
  bool _isRinging = false;

  Future<void> _configureAudio() async {
    if (_configured) return;

    await _player.setAudioContext(
      AudioContext(
        android: AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: true,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.notificationRingtone,
          audioFocus: AndroidAudioFocus.gain,
        ),
      ),
    );
    await _player.setPlayerMode(PlayerMode.mediaPlayer);
    await _player.setReleaseMode(ReleaseMode.loop);
    _configured = true;
  }

  Future<void> startRinging({String assetPath = 'ringtone.mp3'}) async {
    try {
      _isRinging = true;
      await _configureAudio();
      await _player.stop();
      await _player.setSource(AssetSource(assetPath));
      await _player.setVolume(1.0);
      await _player.resume();
      _startVibrationLoop();
    } catch (error) {
      log('[DaakiaRingtoneService] startRinging failed: $error');
    }
  }

  Future<void> stopRinging() async {
    _isRinging = false;
    _vibrationTimer?.cancel();
    _timeoutTimer?.cancel();
    await _player.stop();
  }

  void startAutoTimeout(void Function() onTimeout, Duration duration) {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(duration, onTimeout);
  }

  void cancelAutoTimeout() {
    _timeoutTimer?.cancel();
  }

  void _startVibrationLoop() {
    _vibrationTimer?.cancel();
    HapticFeedback.vibrate();
    _vibrationTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) {
      if (!_isRinging) return;
      HapticFeedback.vibrate();
    });
  }
}
