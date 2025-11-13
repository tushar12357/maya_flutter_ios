// lib/core/services/call_interruption_service.dart

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';

class CallInterruptionService {
  static final CallInterruptionService _instance = CallInterruptionService._internal();
  factory CallInterruptionService() => _instance;
  CallInterruptionService._internal();

  AudioSession? _session; // ← Now stores the actual instance, not a Future

  VoidCallback? onCallStarted;   // → Mute Maya
  VoidCallback? onCallEnded;     // → Unmute Maya

  bool _isCallActive = false;

  Future<void> initialize() async {
    try {
      _session = await AudioSession.instance;

      // Critical: Configure for voice chat (iOS + Android)
      await _session!.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.allowBluetooth | AVAudioSessionCategoryOptions.defaultToSpeaker,
        avAudioSessionMode: AVAudioSessionMode.voiceChat,
        avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: AndroidAudioUsage.voiceCommunication,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientExclusive,
        androidWillPauseWhenDucked: true,
      ));

      // Listen to interruptions (phone calls, Siri, alarms)
      _session!.interruptionEventStream.listen((event) {
        if (kDebugMode) {
          print('Interruption: ${event.begin ? "BEGIN" : "END"} | Type: ${event.type}');
        }

        if (event.begin) {
          // Call started or audio interrupted
          if (!_isCallActive) {
            _isCallActive = true;
            onCallStarted?.call(); // ← MUTE MAYA
          }
        } else {
          // Interruption ended
          if (_isCallActive) {
            _isCallActive = false;
            Future.delayed(const Duration(milliseconds: 800), () {
              if (!_isCallActive) {
                onCallEnded?.call(); // ← UNMUTE MAYA
              }
            });
          }
        }
      });

      // Optional: headset unplug
      _session!.becomingNoisyEventStream.listen((_) {
        if (kDebugMode) print('Headphones unplugged');
        // Optional: mute mic
      });

      if (kDebugMode) print('CallInterruptionService initialized successfully');
    } catch (e) {
      if (kDebugMode) print('Failed to initialize CallInterruptionService: $e');
    }
  }

  void dispose() {
    // Streams are auto-closed by plugin
  }
}