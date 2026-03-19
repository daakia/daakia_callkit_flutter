import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/daakia_incoming_call_payload.dart';
import '../services/daakia_ringtone_service.dart';

class DaakiaIncomingCallScreen extends StatefulWidget {
  const DaakiaIncomingCallScreen({
    super.key,
    required this.payload,
    required this.onAccept,
    required this.onReject,
    this.onTimeout,
    this.timeout = const Duration(seconds: 30),
    this.ringtoneAssetPath = 'ringtone.mp3',
    this.autoStartRinging = true,
  });

  final DaakiaIncomingCallPayload payload;
  final Future<void> Function(DaakiaIncomingCallPayload payload) onAccept;
  final Future<void> Function(DaakiaIncomingCallPayload payload) onReject;
  final Future<void> Function(DaakiaIncomingCallPayload payload)? onTimeout;
  final Duration timeout;
  final String ringtoneAssetPath;
  final bool autoStartRinging;

  @override
  State<DaakiaIncomingCallScreen> createState() =>
      _DaakiaIncomingCallScreenState();
}

class _DaakiaIncomingCallScreenState extends State<DaakiaIncomingCallScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(WakelockPlus.enable());
    if (widget.autoStartRinging) {
      unawaited(
        DaakiaRingtoneService().startRinging(
          assetPath: widget.ringtoneAssetPath,
        ),
      );
    }
    DaakiaRingtoneService().startAutoTimeout(() async {
      if (widget.onTimeout != null) {
        await widget.onTimeout!.call(widget.payload);
      }
      await DaakiaRingtoneService().stopRinging();
    }, widget.timeout);
  }

  @override
  void dispose() {
    unawaited(WakelockPlus.disable());
    DaakiaRingtoneService().cancelAutoTimeout();
    unawaited(DaakiaRingtoneService().stopRinging());
    super.dispose();
  }

  Future<void> _handleAccept() async {
    if (_busy) return;
    _busy = true;
    try {
      await DaakiaRingtoneService().stopRinging();
      await widget.onAccept(widget.payload);
    } finally {
      _busy = false;
    }
  }

  Future<void> _handleReject() async {
    if (_busy) return;
    _busy = true;
    try {
      await DaakiaRingtoneService().stopRinging();
      await widget.onReject(widget.payload);
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final caller = widget.payload.sender;
    final callerName = caller.userName?.trim().isNotEmpty == true
        ? caller.userName!.trim()
        : 'Unknown';

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF121212), Color(0xFF0A2A43)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: <Widget>[
                const Spacer(),
                Container(
                  width: 128,
                  height: 128,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24, width: 2),
                    color: Colors.blueGrey.shade700,
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Colors.black45,
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Text(
                    callerName.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 44,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  callerName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 32,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.payload.title ?? 'Incoming Call',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  widget.payload.body ?? 'Respond to join or decline the call',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white60, fontSize: 14),
                ),
                const SizedBox(height: 20),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          FloatingActionButton(
                            heroTag: 'daakia_reject',
                            onPressed: _handleReject,
                            backgroundColor: const Color(0xFFE53935),
                            elevation: 6,
                            child: const Icon(
                              Icons.call_end,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Decline',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          FloatingActionButton(
                            heroTag: 'daakia_accept',
                            onPressed: _handleAccept,
                            backgroundColor: const Color(0xFF43A047),
                            elevation: 6,
                            child: const Icon(Icons.call, color: Colors.white),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Accept',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
