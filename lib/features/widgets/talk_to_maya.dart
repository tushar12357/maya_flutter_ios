import 'package:Maya/core/services/call_interruption_service.dart';
import 'package:Maya/core/services/thunder_service.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:Maya/core/network/api_client.dart';
import 'package:Maya/core/services/mic_service.dart';
import 'package:ultravox_client/ultravox_client.dart';
import 'package:audioplayers/audioplayers.dart';

class TalkToMaya extends StatefulWidget {
  const TalkToMaya({super.key});

  @override
  State<TalkToMaya> createState() => _TalkToMayaState();
}

class _TalkToMayaState extends State<TalkToMaya>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // === Core State ===
  bool _isListening = false;
  bool _isConnecting = false;
  bool _isMicMuted = false;
  bool _isSpeakerMuted = false;
  String _currentTranscriptChunk = '';
  String _status = 'Talk To Maya';

  // === Guards & Flags ===
  bool _ignoreTranscripts = false;
  bool _isResetting = false;
  String _lastSentText = ''; // To prevent double typed messages

  // === Services & Session ===
  final ThunderSessionService _shared = ThunderSessionService();
  UltravoxSession? _session;
final CallInterruptionService _callService = CallInterruptionService();
bool _wasMutedByCall = false; // Track if we muted due to call
  // === UI Controllers ===
  final ScrollController _scrollController = ScrollController();
  final ApiClient _apiClient = GetIt.instance<ApiClient>();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlayingTypingSound = false;

  // === Animations ===
  late AnimationController _pulseController;
  late AnimationController _orbController;
  late AnimationController _speakingPulseController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _orbScaleAnimation;
  late Animation<double> _speakingPulseAnimation;

  List<Map<String, dynamic>> _conversation = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _shared.init();
    _session = _shared.session;

    // Restore persistent state
    _isMicMuted = _shared.isMicMuted;
    _isSpeakerMuted = _shared.isSpeakerMuted;
    _currentTranscriptChunk = _shared.currentTranscript;
    _conversation = List.from(_shared.conversation);
_setupCallInterruptionHandler();
    _setupAnimations();
    _setupListeners();
    _checkInitialPermission();
  }

  void _setupAnimations() {
    _orbController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _orbScaleAnimation = Tween<double>(begin: 1.0, end: 1.15)
        .animate(CurvedAnimation(parent: _orbController, curve: Curves.easeInOut));

    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.25)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _speakingPulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _speakingPulseAnimation = Tween<double>(begin: 1.0, end: 1.1)
        .animate(CurvedAnimation(parent: _speakingPulseController, curve: Curves.easeInOut));
  }

  void _setupListeners() {
  _session?.statusNotifier.addListener(_onStatusChange);
  _session?.dataMessageNotifier.addListener(_onDataMessage);
  _session?.experimentalMessageNotifier.addListener(_onDebugMessage);

  // 🔥 RAW ULTRAVOX TRANSCRIPT DEBUGGER
  _session?.transcripts.forEach((t) {
    print("🔻 RAW TRANSCRIPT FROM ULTRAVOX");
    print("    text: '${t.text}'");
    print("    isFinal: ${t.isFinal}");
    print("    speaker: ${t.speaker}");
    print("    timestamp: ${DateTime.now()}");
    print("    full object: $t");
    print("---------------------------------------------");
  });
}


  void _removeListeners() {
    try {
      _session?.statusNotifier.removeListener(_onStatusChange);
      _session?.dataMessageNotifier.removeListener(_onDataMessage);
      _session?.experimentalMessageNotifier.removeListener(_onDebugMessage);
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _removeListeners();
    _audioPlayer.dispose();
    _scrollController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    _pulseController.dispose();
    _orbController.dispose();
    _speakingPulseController.dispose();
    super.dispose();
  }

  void _setupCallInterruptionHandler() async {
  _callService.onCallStarted = () {
    if (!mounted || _session == null || _isMicMuted) return;

    print('CALL DETECTED → Muting Maya automatically');
    _wasMutedByCall = _isMicMuted == false; // Remember if user had mic ON

    setState(() {
      _isMicMuted = true;
      _shared.isMicMuted = true;
      _session?.micMuted = true;
    });
  };

  _callService.onCallEnded = () {
    if (!mounted || _session == null || !_wasMutedByCall) return;

    print('CALL ENDED → Unmuting Maya');
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted && _wasMutedByCall) {
        setState(() {
          _isMicMuted = false;
          _shared.isMicMuted = false;
          _session?.micMuted = false;
        });
        _wasMutedByCall = false;
      }
    });
  };

  // Start listening
  await _callService.initialize();
}

  // ===================================================================
  // ONE AND ONLY RESET FUNCTION — SOLVES ALL RACE CONDITIONS
  // ===================================================================
  Future<void> _resetEverything({bool fromHangup = false}) async {
    if (_isResetting) return;
    _isResetting = true;
    _ignoreTranscripts = true;

    print('FULL RESET STARTED (${fromHangup ? "hangUp tool" : "normal"})');

    // Stop animations
    _pulseController.stop();
    _speakingPulseController.stop();
    _orbController.stop();

    // Remove listeners immediately
    _removeListeners();

    // Mute + leave call
    try {
      _session?.micMuted = true;
      _session?.speakerMuted = true;
      _session?.leaveCall();
    } catch (_) {}

    // Reset shared state
    await _shared.resetSession();

    // UI Reset
    if (mounted) {
      setState(() {
        _conversation.clear();
        _currentTranscriptChunk = '';
        _status = 'Talk To Maya';
        _isListening = false;
        _isConnecting = false;
        _isMicMuted = false;
        _isSpeakerMuted = false;
      });
    }

    // Fresh session
    _shared.init();
    _session = _shared.session;

    // Re-attach listeners
    _setupListeners();

    _ignoreTranscripts = false;
    _isResetting = false;
    _lastSentText = '';

    print('FULL RESET COMPLETE');
  }

  // ===================================================================
  // Lifecycle: Handle tab close / app background
  // ===================================================================
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      if (_shared.isSessionActive) {
        _resetEverything();
      }
    }
  }

  // ===================================================================
  // Status Handler — Only reset on disconnected
  // ===================================================================
  void _onStatusChange() {
    if (!mounted || _session == null || _isResetting) return;

    final st = _session!.status;
    print('STATUS: $st');

    // ONLY reset when fully disconnected
    if (st == UltravoxSessionStatus.disconnected) {
      _resetEverything();
      return;
    }

    setState(() {
      _status = _mapStatusToSpeech(st);
      _isListening = st == UltravoxSessionStatus.listening ||
          st == UltravoxSessionStatus.speaking ||
          st == UltravoxSessionStatus.thinking;
    });

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

  // ===================================================================
  // Data Message: Transcripts
  // ===================================================================
void _onDataMessage() {
  if (!mounted || _ignoreTranscripts || _isResetting) return;

  final transcripts = _session!.transcripts;
  if (transcripts.isEmpty) return;

  final latest = transcripts.last;

  print("🔵 DATA MESSAGE → RAW TRANSCRIPT EVENT:");
  print("    text: '${latest.text}'");
  print("    final: ${latest.isFinal}");
  print("    speaker: ${latest.speaker}");
  print("    chunk(before filters): $_currentTranscriptChunk");
  print("    conversation(last): ${_conversation.isNotEmpty ? _conversation.last : "NONE"}");

  final text = latest.text.trim();

  // -----------------------------
  // PARTIAL TRANSCRIPT
  // -----------------------------
  if (!latest.isFinal) {
    print("🟡 PARTIAL → '$text'");

    if (text.isNotEmpty && _currentTranscriptChunk != text) {
      print("🟡 UPDATE PARTIAL CHUNK");
      setState(() {
        _currentTranscriptChunk = text;
        _shared.currentTranscript = text;
      });
      _scrollToBottom();
    } else {
      print("🟡 SKIP PARTIAL (Duplicate or Empty)");
    }

    return;
  }

  // -----------------------------
  // FINAL TRANSCRIPT
  // -----------------------------
  print("🟢 FINAL → '$text'");

  if (text.isEmpty) {
    print("⛔ FINAL EMPTY → SKIP");
    return;
  }

  final isUser = latest.speaker == Role.user;
  final speakerType = isUser ? 'user' : 'maya';

  print("🟢 Final speakerType = $speakerType");

  // Prevent typed-message echo
  if (isUser && text == _lastSentText) {
    print("⛔ BLOCK USER TYPED ECHO ($text)");
    _lastSentText = '';
    return;
  }

  // Prevent duplicates
  if (_conversation.isNotEmpty) {
    final last = _conversation.last;
    if (last['type'] == speakerType && last['text'] == text) {
      print("⛔ BLOCK DUPLICATE FINAL TRANSCRIPT");
      return;
    }
  }

  // Add message to conversation
  print("🟢 ADDING MESSAGE → $speakerType: $text");

  setState(() {
    _conversation.add({'type': speakerType, 'text': text});
    _shared.addMessage(speakerType, text);
    _currentTranscriptChunk = '';
    _shared.currentTranscript = '';
  });

  _scrollToBottom();
}
 // ===================================================================
  void _onDebugMessage() {
    if (_ignoreTranscripts || _isResetting) return;

    final msg = _session?.experimentalMessageNotifier.value;
    if (msg is! Map<String, dynamic>) return;

    final message = msg.toString();

    // HangUp Tool Call → Immediate Reset
    if (message.contains('hangUp') &&
        (message.contains('tool_calls') ||
         message.contains('FunctionCall') ||
         message.contains('"name":"hangUp"'))) {
      print('HANGUP TOOL CALL DETECTED → FORCING RESET');
      _resetEverything(fromHangup: true);
      return;
    }

    // Typing sound on search
    if ((message.contains('deep_search') || message.contains('simple_search')) &&
        !_isPlayingTypingSound) {
      _playTypingSound();
    }
  }

  // ===================================================================
  // Actions
  // ===================================================================
  Future<void> _onStart() async {
    if (_shared.isSessionActive && _session?.status != UltravoxSessionStatus.disconnected) {
      await _onStop();
      return;
    }

    final granted = await MicPermissionService.request(context);
    if (!granted) return;

    setState(() {
      _isConnecting = true;
      _isMicMuted = false;
      _isSpeakerMuted = false;
    });

    _ignoreTranscripts = false;
    _orbController.forward(from: 0);
    _pulseController.repeat();

    try {
      final payload = _apiClient.prepareStartThunderPayload('main');
      final res = await _apiClient.startThunder(payload['agent_type']);
      if (res['statusCode'] == 200) {
        final joinUrl = res['data']['data']['joinUrl'];
        _shared.init();
        _session = _shared.session;
        _removeListeners();
        _setupListeners();

        await _session!.joinCall(joinUrl);
        _session!.micMuted = _isMicMuted;
        _session!.speakerMuted = _isSpeakerMuted;

        setState(() => _isConnecting = false);
      } else {
        throw Exception("Failed to start");
      }
    } catch (e) {
      setState(() {
        _isConnecting = false;
        _currentTranscriptChunk = 'Error connecting...';
      });
    }
  }

  Future<void> _onStop() async {
    await _resetEverything();
  }

  void _toggleMicMute() {
    if (_controlsDisabled) return;
    setState(() {
      _isMicMuted = !_isMicMuted;
      _shared.isMicMuted = _isMicMuted;
      _session?.micMuted = _isMicMuted;
    });
  }

  void _toggleSpeakerMute() {
    if (_controlsDisabled) return;
    setState(() {
      _isSpeakerMuted = !_isSpeakerMuted;
      _shared.isSpeakerMuted = _isSpeakerMuted;
      _session?.speakerMuted = _isSpeakerMuted;
    });
  }

  void _handleSendMessage() {
    if (_controlsDisabled) return;
    final msg = _textController.text.trim();
    if (msg.isEmpty) return;

    _lastSentText = msg;

    try {
      _session?.sendText(msg);
    } catch (_) {}

    setState(() {
      _conversation.add({'type': 'user', 'text': msg});
      _shared.addMessage('user', msg);
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
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _playTypingSound() async {
    if (_isPlayingTypingSound) return;
    _isPlayingTypingSound = true;
    for (int i = 0; i < 5; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      await _audioPlayer.play(AssetSource('typing.mp3'));
    }
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
                  onTap: () => _isListening || _isConnecting ? _onStop() : _onStart(),
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
                            image: AssetImage('assets/maya_logo.png'),
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: _isConnecting
                            ? const Center(child: CircularProgressIndicator(color: Colors.cyan))
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
                              style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic),
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