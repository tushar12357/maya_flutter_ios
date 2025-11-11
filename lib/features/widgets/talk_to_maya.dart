import 'package:Maya/core/services/thunder_service.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:Maya/core/network/api_client.dart';
import 'package:Maya/core/services/mic_service.dart';
import 'package:ultravox_client/ultravox_client.dart';
import 'package:audioplayers/audioplayers.dart'; // Add this import for audio playback

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
  // 🔒 new: block late transcripts after stop/disconnect
  bool _ignoreTranscripts = false;
  final ThunderSessionService _shared = ThunderSessionService();
  UltravoxSession? _session;
  final ScrollController _scrollController = ScrollController();
  final ApiClient _apiClient = GetIt.instance<ApiClient>();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late final AnimationController _pulseController;
  late final AnimationController _orbController;
  late final AnimationController _speakingPulseController;
  late final Animation<double> _pulseAnimation;
  late final Animation<double> _orbScaleAnimation;
  late final Animation<double> _speakingPulseAnimation;
  List<Map<String, dynamic>> _conversation = [];

  // Add AudioPlayer for typing sounds
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlayingTypingSound = false; // Prevent overlapping sounds

  @override
  void initState() {
    super.initState();
    _shared.init();
    _session = _shared.session;
    _isMicMuted = _shared.isMicMuted;
    _isSpeakerMuted = _shared.isSpeakerMuted;
    _currentTranscriptChunk = _shared.currentTranscript;
    _conversation.addAll(_shared.conversation);
    _session?.statusNotifier.addListener(_onStatusChange);
    _session?.dataMessageNotifier.addListener(_onDataMessage);
    _session?.experimentalMessageNotifier.addListener(_onDebugMessage);
    _checkInitialPermission();
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _orbScaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _orbController, curve: Curves.easeInOut),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.25).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    _speakingPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _speakingPulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(CurvedAnimation(
      parent: _speakingPulseController,
      curve: Curves.easeInOut,
    ));

    // Preload typing sound (add 'assets/sounds/typing_key.mp3' to pubspec.yaml under assets)
    _audioPlayer.setReleaseMode(ReleaseMode.stop);
  }

  @override
  void dispose() {
    _session?.statusNotifier.removeListener(_onStatusChange);
    _session?.dataMessageNotifier.removeListener(_onDataMessage);
    _session?.experimentalMessageNotifier.removeListener(_onDebugMessage);
    _scrollController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    _pulseController.dispose();
    _orbController.dispose();
    _speakingPulseController.dispose();
    _audioPlayer.dispose(); // Dispose audio player
    super.dispose();
  }

  void _onStatusChange() {
    if (!mounted) return;
    final st = _session!.status;
    setState(() {
      _status = _mapStatusToSpeech(st);
      _isListening = st == UltravoxSessionStatus.listening ||
          st == UltravoxSessionStatus.speaking ||
          st == UltravoxSessionStatus.thinking;
    });
    // 🔒 When disconnecting/disconnected: block/clear live text *and* ignore any late packets
    if (st == UltravoxSessionStatus.disconnecting ||
        st == UltravoxSessionStatus.disconnected) {
      _ignoreTranscripts = true;
      if (_currentTranscriptChunk.isNotEmpty) {
        setState(() => _currentTranscriptChunk = '');
      }
      // double-clear next frame to kill any stragglers rendered after status flip
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_currentTranscriptChunk.isNotEmpty) {
          setState(() => _currentTranscriptChunk = '');
        }
      });
    }
    if (st == UltravoxSessionStatus.speaking) {
      _pulseController.stop();
      _speakingPulseController.repeat();
    } else if (st == UltravoxSessionStatus.listening) {
      _speakingPulseController.stop();
      _pulseController.repeat();
    } else {
      _pulseController.stop();
      _speakingPulseController.stop();
    }
  }

  void _onDataMessage() {
    if (!mounted) return;
    // 🔒 hard gate for ghost packets during/after teardown
    final s = _session?.status;
    if (_ignoreTranscripts ||
        s == UltravoxSessionStatus.disconnecting ||
        s == UltravoxSessionStatus.disconnected) {
      if (_currentTranscriptChunk.isNotEmpty) {
        setState(() => _currentTranscriptChunk = '');
      }
      return;
    }
    final transcripts = _session!.transcripts;
    if (transcripts.isEmpty) return;
    final latest = transcripts.last;
    // Live chunk → show as typing bubble and scroll
    if (!latest.isFinal) {
      setState(() {
        _currentTranscriptChunk = latest.text;
      });
      _scrollToBottom();
      return;
    }
    // ignore empty final
    final finalText = latest.text.trim();
    if (finalText.isEmpty) return;
    final speaker = latest.speaker == Role.user ? 'user' : 'maya';
    // prevent duplicates
    if (_conversation.isNotEmpty) {
      final last = _conversation.last;
      if (last['type'] == speaker && last['text'] == finalText) {
        setState(() => _currentTranscriptChunk = '');
        return;
      }
    }
    setState(() {
      _conversation.add({'type': speaker, 'text': finalText});
      _currentTranscriptChunk = '';
    });
    _scrollToBottom();
  }

  void _onDebugMessage() {
    final msg = _session!.experimentalMessageNotifier.value;
    print('Got a debug message: ${msg.toString()}');

    // Check for search tool calls and play typing sound
    if (msg is Map<String, dynamic> && msg['type'] == 'debug') {
      final message = msg['message'].toString();
      if ((message.contains('"type": "deep_search"') || message.contains('"type": "simple_search"')) &&
          !_isPlayingTypingSound) {
        _playTypingSound();
      }
    }
  }

  // Play a sequence of quick typing key sounds to simulate searching/typing
  Future<void> _playTypingSound() async {
    if (_isPlayingTypingSound) return;
    _isPlayingTypingSound = true;

    // Play 5 quick keypress sounds with slight delays
    for (int i = 0; i < 5; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      await _audioPlayer.play(AssetSource('assets/typing.mp3')); // Adjust path as needed
    }

    // Reset flag after a short delay
    await Future.delayed(const Duration(milliseconds: 500));
    _isPlayingTypingSound = false;
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
        return 'Ending Conversation...';
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
    if (!granted) {
      setState(() {
        _currentTranscriptChunk = 'Tap to grant microphone access';
      });
    }
  }

  Future<void> _onStart() async {
    if (_shared.isSessionActive) return;
    final granted = await MicPermissionService.request(context);
    if (!granted) return;
    setState(() {
      _isConnecting = true;
      _isMicMuted = false;
      _isSpeakerMuted = false;
    });
    _ignoreTranscripts = false; // ✅ allow new transcripts
    _orbController.forward(from: 0);
    _pulseController.repeat();
    try {
      final payload = _apiClient.prepareStartThunderPayload('main');
      final res = await _apiClient.startThunder(payload['agent_type']);
      if (res['statusCode'] == 200) {
        final joinUrl = res['data']['data']['joinUrl'];
        await _session!.joinCall(joinUrl);
        _session!.micMuted = _isMicMuted;
        _session!.speakerMuted = _isSpeakerMuted;
        setState(() {
          _isConnecting = false;
        });
      }
    } catch (e) {
      setState(() {
        _isConnecting = false;
        _currentTranscriptChunk = 'Error: $e';
      });
    }
  }

  void _onStop() {
    // 🔒 block late packets immediately
    _ignoreTranscripts = true;
    _session?.micMuted = true;
    _session?.speakerMuted = true;
    _session?.leaveCall();
    setState(() {
      _isListening = false;
      _isConnecting = false;
      _currentTranscriptChunk = '';
    });
    // Post-frame double-clear for absolute safety
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_currentTranscriptChunk.isNotEmpty) {
        setState(() => _currentTranscriptChunk = '');
      }
    });
    _pulseController.stop();
    _speakingPulseController.stop();
    _orbController.reverse(from: 1.0);
  }

  void _toggleMicMute() {
    if (_controlsDisabled) return;
    setState(() {
      _isMicMuted = !_isMicMuted;
      _session?.micMuted = _isMicMuted;
    });
  }

  void _toggleSpeakerMute() {
    if (_controlsDisabled) return;
    setState(() {
      _isSpeakerMuted = !_isSpeakerMuted;
      _session?.speakerMuted = _isSpeakerMuted;
    });
  }

  void _handleSendMessage() {
    if (_controlsDisabled) return;
    final msg = _textController.text.trim();
    if (msg.isEmpty) return;
    _session?.sendText(msg);
    setState(() {
      _conversation.add({'type': 'user', 'text': msg});
      _textController.clear();
    });
    _scrollToBottom();
  }

  bool get _controlsDisabled {
    final s = _session?.status;
    return s == UltravoxSessionStatus.disconnected ||
        s == UltravoxSessionStatus.disconnecting ||
        s == UltravoxSessionStatus.connecting;
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 250), () {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0x992A57E8), Colors.transparent],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: Icon(
                          _isMicMuted ? Icons.mic_off : Icons.mic,
                          color: _controlsDisabled
                              ? Colors.grey
                              : (_isMicMuted ? Colors.grey : Colors.white),
                        ),
                        onPressed: _controlsDisabled ? null : _toggleMicMute,
                      ),
                      IconButton(
                        icon: Icon(
                          _isSpeakerMuted ? Icons.volume_off : Icons.volume_up,
                          color: _controlsDisabled
                              ? Colors.grey
                              : (_isSpeakerMuted ? Colors.grey : Colors.white),
                        ),
                        onPressed: _controlsDisabled ? null : _toggleSpeakerMute,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(_status, style: const TextStyle(color: Colors.white70, fontSize: 17)),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () {
                    _isListening || _isConnecting ? _onStop() : _onStart();
                  },
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_orbController, _speakingPulseController]),
                    builder: (_, __) => Transform.scale(
                      scale: _orbScaleAnimation.value * _speakingPulseAnimation.value,
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          image: DecorationImage(
                            image: AssetImage('assets/Layer_1.png'),
                            fit: BoxFit.contain,
                          ),
                        ),
                        child: _isConnecting
                            ? const Center(
                                child: CircularProgressIndicator(color: Colors.cyan),
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    itemCount: _conversation.length + (_currentTranscriptChunk.isNotEmpty ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (_currentTranscriptChunk.isNotEmpty && i == _conversation.length) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.09),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(
                              _currentTranscriptChunk,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        );
                      }
                      final msg = _conversation[i];
                      final isUser = msg['type'] == 'user';
                      return Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(isUser ? 0.22 : 0.12),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(msg['text'], style: const TextStyle(color: Colors.white)),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          focusNode: _focusNode,
                          enabled: !_controlsDisabled,
                          decoration: InputDecoration(
                            hintText: 'Type here...',
                            hintStyle: const TextStyle(color: Colors.grey),
                            filled: true,
                            fillColor: const Color(0xFF1E293B),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          style: const TextStyle(color: Colors.white),
                          onSubmitted: (_) => _handleSendMessage(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _controlsDisabled ? null : _handleSendMessage,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFF2A57E8), Color(0xFF6A0DAD)],
                            ),
                          ),
                          child: const Icon(Icons.send, color: Colors.white),
                        ),
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