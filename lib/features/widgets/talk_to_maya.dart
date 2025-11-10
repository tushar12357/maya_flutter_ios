import 'package:flutter/material.dart';
import 'package:flutter/animation.dart';
import 'package:get_it/get_it.dart';
import 'package:Maya/core/network/api_client.dart';
import 'package:Maya/core/services/mic_service.dart';
import 'package:ultravox_client/ultravox_client.dart';

class TalkToMaya extends StatefulWidget {
  const TalkToMaya({super.key});

  @override
  State<TalkToMaya> createState() => _TalkToMayaState();
}

class _TalkToMayaState extends State<TalkToMaya> with TickerProviderStateMixin {
  bool _isListening = false;
  bool _isConnecting = false;
  bool _isMicMuted = false;
  bool _isSpeakerMuted = false;
  String _currentTranscriptChunk = '';
  String _status = 'Talk To Maya';
  final List<Map<String, dynamic>> _conversation = [];
  final String _inputValue = '';
  UltravoxSession? _session;
  String _previousStatus = '';
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  AnimationController? _orbController;
  late final Animation<double> _orbScaleAnimation;

  late final AnimationController _speakingPulseController;
  late final Animation<double> _speakingPulseAnimation;

  final ApiClient _apiClient = GetIt.instance<ApiClient>();
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkInitialPermission();
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _orbScaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _orbController!, curve: Curves.easeInOut),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController!, curve: Curves.easeInOut),
    );
     _speakingPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _speakingPulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _speakingPulseController,
        curve: Curves.easeInOut,
      ),
    );
    _session = UltravoxSession.create();
    _session!.statusNotifier.addListener(_onStatusChange);
    _session!.dataMessageNotifier.addListener(_onDataMessage);
    _session!.experimentalMessageNotifier.addListener(_onDebugMessage);
  }

  @override
  void dispose() {
    _session?.leaveCall();
    _session?.statusNotifier.removeListener(_onStatusChange);
    _session?.dataMessageNotifier.removeListener(_onDataMessage);
    _session?.experimentalMessageNotifier.removeListener(_onDebugMessage);
    _pulseController?.dispose();
    _orbController?.dispose();

    _speakingPulseController.dispose();
    _focusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

 void _onStatusChange() {
    final current = _session!.status;
    setState(() {
      _status = _mapStatusToSpeech(current);
      _isListening =
          current == UltravoxSessionStatus.listening ||
          current == UltravoxSessionStatus.speaking ||
          current == UltravoxSessionStatus.thinking;
    });

    // Animation logic (unchanged)
    if (current == UltravoxSessionStatus.speaking) {
      _pulseController.stop();
      _speakingPulseController.repeat();
    } else if (current == UltravoxSessionStatus.listening) {
      _speakingPulseController.stop();
      _pulseController.repeat();
    } else {
      _pulseController.stop();
      _speakingPulseController.stop();
    }

    // Clear live transcript when idle
    if (current == UltravoxSessionStatus.idle &&
        _previousStatus.contains('speaking')) {
      Future.delayed(const Duration(seconds: 1), () {
        if (!mounted) return;
        setState(() {
          _currentTranscriptChunk = '';
        });
      });
    }

    _previousStatus = current.toString();
  }

  void _onDataMessage() {
    final transcripts = _session!.transcripts;

    if (transcripts.isEmpty) return;

    // Get the latest transcript (could be partial or final)
    final latestTranscript = transcripts.last;

    // Update live streaming chunk (even if not final)
    setState(() {
      _currentTranscriptChunk = latestTranscript.text;
    });

    // Only add to conversation when it's final AND not already added
    if (latestTranscript.isFinal) {
      final text = latestTranscript.text.trim();
      if (text.isNotEmpty) {
        // Avoid duplicates
        final lastMsg = _conversation.isNotEmpty
            ? _conversation.last['text']
            : null;
        final speakerType = latestTranscript.speaker == Role.user
            ? 'user'
            : 'maya';

        if (lastMsg != text ||
            _conversation.isEmpty ||
            _conversation.last['type'] != speakerType) {
          setState(() {
            _conversation.add({'type': speakerType, 'text': text});
            // Keep only last 10 messages
            if (_conversation.length > 10) {
              _conversation.removeAt(0);
            }
          });
        }
      }

      // Clear live chunk after final
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _session!.transcripts.last == latestTranscript) {
          setState(() => _currentTranscriptChunk = '');
        }
      });
    }
  }
  void _onDebugMessage() {
    final message = _session!.lastExperimentalMessage;
    if (mounted) {
      print('Got a debug message: $message');
    }
  }

  String _mapStatusToSpeech(UltravoxSessionStatus status) {
    switch (status) {
      case UltravoxSessionStatus.disconnected:
        return 'Talk To Maya';
      case UltravoxSessionStatus.connecting:
        return 'Connecting To Maya';
      case UltravoxSessionStatus.speaking:
        return 'Maya is Speaking';
      case UltravoxSessionStatus.disconnecting:
        return 'Ending Conversation With Maya';
      case UltravoxSessionStatus.listening:
        return 'Maya is Listening';
      case UltravoxSessionStatus.thinking:
        return 'Maya is Thinking';
      case UltravoxSessionStatus.idle:
        return 'Maya is Ready';
      default:
        return 'Talk To Maya';
    }
  }

Future<void> _checkInitialPermission() async {
  final granted = await MicPermissionService.isGranted();
  if (mounted && !granted) {
    setState(() {
      _currentTranscriptChunk = 'Tap to grant microphone access';
    });
  }
}

Future<void> _onStart() async {
  // -------------------------------------------------------------
  // 1. Ask for mic permission (new logic)
  // -------------------------------------------------------------
  final granted = await MicPermissionService.request(context);
  if (!granted) {
    if (mounted) {
      setState(() {
        _currentTranscriptChunk = 'Microphone permission required';
      });
    }
    return;
  }

  // -------------------------------------------------------------
  // 2. Permission OK → continue with the existing flow
  // -------------------------------------------------------------
  if (mounted) {
    setState(() {
      _isConnecting = true;
      _currentTranscriptChunk = '';
      _isMicMuted = false;
      _isSpeakerMuted = false;
    });
  }

  _orbController?.forward(from: 0.0);
  _pulseController?.repeat();

  try {
    final payload = _apiClient.prepareStartThunderPayload('main');
    final response = await _apiClient.startThunder(payload['agent_type']);

    if (response['statusCode'] == 200) {
      final joinUrl = response['data']['data']['joinUrl'];
      await _session!.joinCall(joinUrl);
      _session!.micMuted = _isMicMuted;
      _session!.speakerMuted = _isSpeakerMuted;

      if (mounted) {
        setState(() {
          _isListening = true;
          _isConnecting = false;
        });
      }
    } else {
      _handleError('Error starting session: ${response['statusCode']}');
    }
  } catch (e) {
    _handleError('Error: $e');
  }
}

void _handleError(String msg) {
  if (mounted) {
    setState(() {
      _currentTranscriptChunk = msg;
      _isConnecting = false;
    });
  }
  _onStop();
}
  void _onStop() {
    if (_session != null) {
      _session!.micMuted = true;
      _session!.speakerMuted = true;
      _session!.leaveCall();
    }
    if (mounted) {
      setState(() {
        _isListening = false;
        _isConnecting = false;
        _currentTranscriptChunk = '';
        _conversation.clear();
      });
    }
    _pulseController.stop();
        _speakingPulseController.stop();

    _orbController?.reverse(from: 1.0);
  }

  void _toggleMicMute() {
    if (mounted) {
      setState(() {
        _isMicMuted = !_isMicMuted;
        _session?.micMuted = _isMicMuted;
      });
    }
  }

  void _toggleSpeakerMute() {
    if (mounted) {
      setState(() {
        _isSpeakerMuted = !_isSpeakerMuted;
        _session?.speakerMuted = _isSpeakerMuted;
      });
    }
  }

  void _handleSendMessage() {
    final msg = _textController.text.trim();
    if (msg.isEmpty) return;

    _session?.sendText(msg);

    if (mounted) {
      setState(() {
        _conversation.add({'type': 'user', 'text': msg});
        _textController.clear();
      });
      FocusScope.of(context).requestFocus(_focusNode);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      body: Stack(
        children: [
          // Gradient overlay
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x992A57E8), Colors.transparent],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Mic + Speaker buttons row
                // ── Mic + Speaker buttons row + NEW STATUS TEXT ──
                // ── Mic + Speaker buttons row + NEW STATUS TEXT ──
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Column(
                    children: [
                      // Mic & Speaker buttons (right-aligned)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: Icon(
                              _isMicMuted ? Icons.mic_off : Icons.mic,
                              color: _isMicMuted ? Colors.grey : Colors.white,
                              size: 28,
                            ),
                            onPressed: _toggleMicMute,
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: Icon(
                              _isSpeakerMuted
                                  ? Icons.volume_off
                                  : Icons.volume_up,
                              color: _isSpeakerMuted
                                  ? Colors.grey
                                  : Colors.white,
                              size: 28,
                            ),
                            onPressed: _toggleSpeakerMute,
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // ── NEW: Voice-wave + Status in a tight row ──
                     Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    // Left spacer (mirrors right spacer)
    const SizedBox(width: 16), // Half of 24 + 8 = 32 → use 16 on each side

    // Voice-wave – visible only when connected
    if (_isListening && !_isConnecting)
      const AnimatedVoiceWave(
        isActive: true,
        duration: Duration(milliseconds: 1200),
      )
    else
      const SizedBox(width: 24), // same size as wave

    const SizedBox(width: 8),

    // Status text
    Expanded(
      child: Text(
        _status,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.4,
        ),
        textAlign: TextAlign.center,
      ),
    ),

    // Right spacer to balance
    const SizedBox(width: 16),
  ],
),],
                  ),
                ),
                  Expanded(
                  flex: 2,
                  child: Center(
                    child: GestureDetector(
                      onTap: _isListening || _isConnecting ? _onStop : _onStart,
                      child: AnimatedBuilder(
                        animation: Listenable.merge([
                          _orbController,
                          _speakingPulseController,
                        ]),
                        builder: (_, __) => Transform.scale(
                          scale:
                              _orbScaleAnimation.value *
                              _speakingPulseAnimation.value,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Listening pulse ring (outer)
                              if (_isListening && !_isConnecting)
                                AnimatedBuilder(
                                  animation: _pulseAnimation,
                                  builder: (_, __) => Container(
                                    width: 280 * _pulseAnimation.value,
                                    height: 280 * _pulseAnimation.value,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.cyan.withOpacity(0.2),
                                    ),
                                  ),
                                ),

                              // Orb Image
                              Container(
                                width: 180,
                                height: 180,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  image: const DecorationImage(
                                    image: AssetImage(
                                      'assets/LAYER_1.png',
                                    ),
                                    fit: BoxFit.contain,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.5),
                                      blurRadius: 30,
                                      spreadRadius: 8,
                                    ),
                                  ],
                                ),
                                child: _isConnecting
                                    ? const Center(
                                        child: CircularProgressIndicator(
                                          color: Colors.cyan,
                                          strokeWidth: 4,
                                        ),
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Conversation ──
                Expanded(
                  flex: 3,
                  child: _conversation.isEmpty
                      ? const Center(
                          child: Text(
                            'Start a conversation...',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 17,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          itemCount: _conversation.length,
                          itemBuilder: (_, i) {
                            final msg = _conversation[i];
                            final isUser = msg['type'] == 'user';
                            return Align(
                              alignment: isUser
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.75,
                                ),
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  color: isUser
                                      ? const Color(0xFF2A57E8)
                                      : const Color(0xFF6A0DAD),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  msg['text'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // ── Bottom Input ──
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFF111827),
                    border: Border(
                      top: BorderSide(color: Color(0x332A57E8), width: 1),
                    ),
                  ),
                  child: Column(
                    children: [
                     if (_currentTranscriptChunk.isNotEmpty)
  Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0x332A57E8)),
    ),
    child: Row(
      children: [
        if (_session!.transcripts.isNotEmpty)
          Icon(
            _session!.transcripts.last.speaker == Role.user
                ? Icons.person
                : Icons.smart_toy,
            color: const Color(0xFF2A57E8),
            size: 20,
          )
        else
          const Icon(
            Icons.person,
            color: Color(0xFF2A57E8),
            size: 20,
          ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _currentTranscriptChunk,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ),

        if (_session!.transcripts.isNotEmpty &&
            !_session!.transcripts.last.isFinal)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(Colors.cyan),
            ),
          ),
      ],
    ),
  ),

                        Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(
                                  color: const Color(0x332A57E8),
                                ),
                              ),
                              child: TextField(
                                controller: _textController,
                                focusNode: _focusNode,
                                onSubmitted: (_) => _handleSendMessage(),
                                decoration: const InputDecoration(
                                  hintText: 'Type your message...',
                                  hintStyle: TextStyle(color: Colors.grey),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 14,
                                  ),
                                ),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: _handleSendMessage,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF2A57E8),
                                    Color(0xFF6A0DAD),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 8,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.send,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Sound Wave Painter (matches screenshot)
class _SoundWavePainter extends CustomPainter {
  final bool isActive;

  _SoundWavePainter({required this.isActive});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isActive ? Colors.cyan : Colors.white54
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final path = Path();

    if (isActive) {
      // Animated sound waves
      path.moveTo(center.dx - 8, center.dy + 8);
      path.lineTo(center.dx - 8, center.dy - 8);
      path.moveTo(center.dx - 4, center.dy + 6);
      path.lineTo(center.dx - 4, center.dy - 6);
      path.moveTo(center.dx, center.dy + 4);
      path.lineTo(center.dx, center.dy - 4);
      path.moveTo(center.dx + 4, center.dy + 2);
      path.lineTo(center.dx + 4, center.dy - 2);
    } else {
      // Static small wave
      path.moveTo(center.dx - 2, center.dy + 4);
      path.lineTo(center.dx - 2, center.dy - 4);
      path.moveTo(center.dx + 2, center.dy + 2);
      path.lineTo(center.dx + 2, center.dy - 2);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class AnimatedVoiceWave extends StatefulWidget {
  final bool isActive;
  final Duration duration;

  const AnimatedVoiceWave({
    Key? key,
    required this.isActive,
    this.duration = const Duration(milliseconds: 1200),
  }) : super(key: key);

  @override
  State<AnimatedVoiceWave> createState() => _AnimatedVoiceWaveState();
}

class _AnimatedVoiceWaveState extends State<AnimatedVoiceWave>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<double>> _waveAnimations;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this)
      ..repeat();

    // Create 5 staggered wave animations
    _waveAnimations = List.generate(5, (index) {
      return Tween<double>(begin: 0.2, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(
            (0.1 * index).clamp(0.0, 1.0),
            1.0,
            curve: Curves.elasticOut,
          ),
        ),
      );
    });
  }

  @override
  void didUpdateWidget(AnimatedVoiceWave oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _controller.repeat();
      } else {
        _controller.stop();
        _controller.reset();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: widget.isActive
          ? Row(
              key: const ValueKey('active'),
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (index) {
                return AnimatedBuilder(
                  animation: _waveAnimations[index],
                  builder: (context, child) {
                    return Container(
                      margin: const EdgeInsets.only(right: 2),
                      width: 3,
                      height: 20 * _waveAnimations[index].value,
                      decoration: BoxDecoration(
                        color: Colors.cyanAccent.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    );
                  },
                );
              }),
            )
          : Row(
              key: const ValueKey('inactive'),
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (index) {
                return Container(
                  margin: const EdgeInsets.only(right: 2),
                  width: 3,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                );
              }),
            ),
    );
  }
}
