// lib/features/home/widgets/voice_chat_card_interactive.dart

import 'package:flutter/material.dart';
import 'package:Maya/core/network/api_client.dart';
import 'package:Maya/core/services/thunder_service.dart';
import 'package:Maya/core/services/call_interruption_service.dart';
import 'package:Maya/core/services/mic_service.dart';
import 'package:ultravox_client/ultravox_client.dart';
import 'package:get_it/get_it.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class InteractiveVoiceChatCard extends StatefulWidget {
  const InteractiveVoiceChatCard({super.key});

  @override
  State<InteractiveVoiceChatCard> createState() => _InteractiveVoiceChatCardState();
}

class _InteractiveVoiceChatCardState extends State<InteractiveVoiceChatCard>
    with TickerProviderStateMixin, WidgetsBindingObserver {

  final ThunderSessionService _thunder = ThunderSessionService();
  final ApiClient _apiClient = GetIt.instance<ApiClient>();
  final CallInterruptionService _callService = CallInterruptionService();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _isConnecting = false;
  bool _wasMutedByCall = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupAnimations();
    _setupCallInterruption();
    _attachListeners();
    _updateWakelock();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _attachListeners() {
    _thunder.session?.statusNotifier.addListener(_onStatusChanged);
    _thunder.session?.dataMessageNotifier.addListener(_onTranscriptChanged);
  }

  void _removeListeners() {
    try {
      _thunder.session?.statusNotifier.removeListener(_onStatusChanged);
      _thunder.session?.dataMessageNotifier.removeListener(_onTranscriptChanged);
    } catch (_) {}
  }

  void _onStatusChanged() {
    if (!mounted) return;
    final status = _thunder.session?.status;

    if (status == UltravoxSessionStatus.listening) {
      _pulseController.repeat();
    } else {
      _pulseController.stop();
    }

    _updateWakelock();
    setState(() {});
  }

  void _onTranscriptChanged() => mounted ? setState(() {}) : null;

  void _updateWakelock() {
    _thunder.isSessionActive ? WakelockPlus.enable() : WakelockPlus.disable();
  }

  void _setupCallInterruption() async {
    _callService.onCallStarted = () {
      if (!mounted || _thunder.session == null || _thunder.session!.micMuted) return;
      _wasMutedByCall = true;
      _thunder.session!.micMuted = true;
      setState(() {});
    };
    _callService.onCallEnded = () {
      if (!mounted || !_wasMutedByCall) return;
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted && _wasMutedByCall) {
          _thunder.session?.micMuted = false;
          _wasMutedByCall = false;
          setState(() {});
        }
      });
    };
    await _callService.initialize();
  }

  Future<void> _toggleVoiceSession() async {
    if (_thunder.isSessionActive) {
      await _thunder.resetSession();
      _textController.clear();
      return;
    }

    final granted = await MicPermissionService.request(context);
    if (!granted) return;

    setState(() => _isConnecting = true);

    try {
      _thunder.init();
      _removeListeners();
      _attachListeners();

      final payload = _apiClient.prepareStartThunderPayload('main');
      final res = await _apiClient.startThunder(payload['agent_type']);
      if (res['statusCode'] != 200) throw Exception("Failed");

      final joinUrl = res['data']['data']['joinUrl'];
      await _thunder.session!.joinCall(joinUrl);
    } catch (e, st) {
      debugPrint("Voice card error: $e\n$st");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to connect to Maya")),
      );
      await _thunder.resetSession();
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  void _sendTextMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty || _thunder.session == null) return;

    _thunder.session!.sendText(text);
    _thunder.addMessage('user', text);
    _textController.clear();
    setState(() {});
  }

  String get _liveTranscript {
    final t = _thunder.session?.transcripts;
    if (t == null || t.isEmpty) return '';
    final last = t.last;
    return last.isFinal ? '' : last.text.trim();
  }

  String get _lastMayaMessage {
    for (final msg in _thunder.conversation.reversed) {
      if (msg['type'] == 'maya') return msg['text'];
    }
    return '';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _removeListeners();
    _pulseController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

@override
Widget build(BuildContext context) {
  final status = _thunder.session?.status ?? UltravoxSessionStatus.disconnected;
  final isDisconnected = status == UltravoxSessionStatus.disconnected ||
      status == UltravoxSessionStatus.disconnecting;

  final hasLiveTranscript = _liveTranscript.isNotEmpty;
  final lastMayaMessage = _lastMayaMessage;

  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF0062FF), Color(0xFF4C8CFF)],
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
      ),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title Row
        const Row(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: Color(0x4DFFFFFF),
              child: Icon(Icons.people, color: Colors.white, size: 20),
            ),
            SizedBox(width: 8),
            Text(
              'Voice Chat With Maya',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Transcript / Last Message / Placeholder
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: () {
            if (isDisconnected) {
              return const Text(
                'AI Voice assistants provide instant, personalised\nsupport, enhancing daily tasks effortlessly.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              );
            }

            if (hasLiveTranscript) {
              return Text(
                _liveTranscript,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              );
            }

            if (lastMayaMessage.isNotEmpty) {
              return Text(
                lastMayaMessage,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              );
            }

            // Connected but nothing to show (idle/waiting)
            return const SizedBox.shrink();
          }(),
        ),

        const SizedBox(height: 20),

        // Input Row: Text Field → Send Button (optional) → Mic Button (right)
        Row(
          children: [
            // Text Input Field (expands to fill space)
            Expanded(
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                enabled: _thunder.isSessionActive,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: _thunder.isSessionActive
                      ? 'Type a message...'
                      : 'Start voice chat first',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.15),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (_) => _sendTextMessage(),
              ),
            ),

            const SizedBox(width: 12),

            // Send Button - only visible when typing + session active
            if (_thunder.isSessionActive && _textController.text.trim().isNotEmpty)
              GestureDetector(
                onTap: _sendTextMessage,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send, color: Color(0xFF0062FF), size: 20),
                ),
              ),

            // Small gap only if send button is visible
            if (_thunder.isSessionActive && _textController.text.trim().isNotEmpty)
              const SizedBox(width: 8),

            // Mic / End Call Button - Always on the far right
            GestureDetector(
              onTap: _isConnecting ? null : _toggleVoiceSession,
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (_, __) => Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _thunder.isSessionActive ? Colors.redAccent : Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _thunder.isSessionActive ? Icons.call_end : Icons.mic,
                      color: _thunder.isSessionActive
                          ? Colors.white
                          : const Color(0xFF0062FF),
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
}