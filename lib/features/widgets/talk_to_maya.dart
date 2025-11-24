import 'package:Maya/core/services/call_interruption_service.dart';
import 'package:Maya/core/services/thunder_service.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:Maya/core/network/api_client.dart';
import 'package:Maya/core/services/mic_service.dart';
import 'package:ultravox_client/ultravox_client.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
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
String? _profileImageUrl;

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
    _fetchUserProfile();

_setupCallInterruptionHandler();
    _setupAnimations();
    _setupListeners();
    _updateWakelock();
  }


  Future<void> _fetchUserProfile() async {
  try {
    final res = await _apiClient.getCurrentUser();
    print("USER API RESPONSE: $res");
    if (res['statusCode'] == 200) {
      final data = res['data'];
      setState(() {
        _profileImageUrl = data['data']['profile_image_url'];
      });
    }
  } catch (e) {
    print("USER API ERROR: $e");
  }
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
    WakelockPlus.disable(); // Always clean up
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
_updateWakelock();

    print('FULL RESET COMPLETE');
  }

  // ===================================================================
  // Lifecycle: Handle tab close / app background
  // ===================================================================
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
   
  }

  // ===================================================================
  // Status Handler — Only reset on disconnected
  // ===================================================================
void _onStatusChange() {
  if (!mounted || _session == null || _isResetting) return;

  final st = _session!.status;
  print('STATUS: $st');

  if (st == UltravoxSessionStatus.disconnected) {
    _resetEverything();
    _updateWakelock(); // Turn off
    return;
  }

  setState(() {
    _status = _mapStatusToSpeech(st);
    _isListening = st == UltravoxSessionStatus.listening ||
        st == UltravoxSessionStatus.speaking ||
        st == UltravoxSessionStatus.thinking;
  });

  // === UPDATE WAKELOCK BASED ON STATE ===
  _updateWakelock();

  // === Animation logic (unchanged) ===
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


void _updateWakelock() {
  final isActiveSession = _session?.status != null &&
      _session!.status != UltravoxSessionStatus.disconnected &&
      _session!.status != UltravoxSessionStatus.disconnecting;

  if (isActiveSession) {
    WakelockPlus.enable();
    print('WAKELOCK: ENABLED');
  } else {
    WakelockPlus.disable();
    print('WAKELOCK: DISABLED');
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
  final text = latest.text.trim();

  // Live partial transcript
  if (!latest.isFinal) {
    if (text.isNotEmpty && _currentTranscriptChunk != text) {
      setState(() {
        _currentTranscriptChunk = text;
        _shared.currentTranscript = text;
      });
      _scrollToBottom();
    }
    return;
  }

  // Final message
  if (text.isEmpty) return;

  final isUser = latest.speaker == Role.user;
  final speakerType = isUser ? 'user' : 'maya';

  // Block typed message echo
  if (isUser && text == _lastSentText) {
    _lastSentText = '';
    return;
  }

  // Block duplicate messages
  if (_conversation.isNotEmpty) {
    final last = _conversation.last;
    if (last['type'] == speakerType && last['text'] == text) {
      return;
    }
  }

  setState(() {
    _conversation.add({'type': speakerType, 'text': text});
    _shared.addMessage(speakerType, text);
    _currentTranscriptChunk = '';
    _shared.currentTranscript = '';
  });

  _scrollToBottom();
}// Debug Message: HangUp Detection + Typing Sound
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
        _updateWakelock();
      } else {
        throw Exception("Failed to start");
        
      }
    } catch (e) {
      setState(() {
        _isConnecting = false;
        _currentTranscriptChunk = 'Error connecting...';
      });
      _updateWakelock();
    }
  }

  Future<void> _onStop() async {
    await _resetEverything();
    _updateWakelock();
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

 

@override
Widget build(BuildContext context) {
  final screenWidth = MediaQuery.of(context).size.width;

  return Scaffold(
    backgroundColor: Colors.grey.shade50,
    resizeToAvoidBottomInset: true,
    body: SafeArea(
      child:
      Column(
        children: [
          // Top Controls: Mic + Speaker
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(
                    _isSpeakerMuted ? Icons.volume_off : Icons.volume_up,
                    color: _controlsDisabled ? Colors.grey.shade400 : Colors.black87,
                    size: 26,
                  ),
                  onPressed: _controlsDisabled ? null : _toggleSpeakerMute,
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: Icon(
                    _isMicMuted ? Icons.mic_off : Icons.mic_none,
                    color: _controlsDisabled ? Colors.grey.shade400 : Colors.black87,
                    size: 26,
                  ),
                  onPressed: _controlsDisabled ? null : _toggleMicMute,
                ),
              ],
            ),
          ),

          // Status Text
          Text(
            _status,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 32),

          // Central Image / Orb (Replace with your animation or keep static)
          GestureDetector(
            onTap: () => _isListening || _isConnecting ? _onStop() : _onStart(),
            child: AnimatedBuilder(
              animation: Listenable.merge([_orbController, _speakingPulseController]),
              builder: (_, __) => Transform.scale(
                scale: _orbScaleAnimation.value * _speakingPulseAnimation.value,
                child: Container(
                  width: screenWidth * 0.5,
                  height: screenWidth * 0.5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: 
                         Image.asset(
                            'assets/animation.png', // Replace with your actual image
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Chat Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              itemCount: _conversation.length + (_currentTranscriptChunk.isNotEmpty ? 1 : 0),
              itemBuilder: (context, i) {
                if (_currentTranscriptChunk.isNotEmpty && i == _conversation.length) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                       CircleAvatar(
  radius: 18,
  backgroundColor: Colors.transparent,
  child: ClipOval(
    child: Image.asset(
      "assets/animation.png",
      fit: BoxFit.cover,
      width: 36,
      height: 36,
    ),
  ),
),


                        const SizedBox(width: 10),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              _currentTranscriptChunk,
                              style: const TextStyle(
                                fontSize: 15,
                                color: Colors.black87,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final msg = _conversation[i];
                final isUser = msg['type'] == 'user';

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: isUser
                        ? [
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  msg['text'],
                                  style: const TextStyle(fontSize: 15),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            CircleAvatar(
  radius: 18,
  backgroundColor: Colors.grey.shade300,
  child: ClipOval(
    child: _profileImageUrl != null
        ? Image.network(
            _profileImageUrl!,
            width: 36,
            height: 36,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Image.asset(
              "assets/user.png",
              width: 36,
              height: 36,
              fit: BoxFit.cover,
            ),
          )
        : Image.asset(
            "assets/user.png",
            width: 36,
            height: 36,
            fit: BoxFit.cover,
          ),
  ),
),

                          ]
                        : [
                            CircleAvatar(
  radius: 18,
  backgroundColor: Colors.transparent,
  child: ClipOval(
    child: Image.asset(
      "assets/animation.png",
      fit: BoxFit.cover,
      width: 36,
      height: 36,
    ),
  ),
),

                            const SizedBox(width: 10),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  msg['text'],
                                  style: const TextStyle(fontSize: 15),
                                ),
                              ),
                            ),
                          ],
                  ),
                );
              },
            ),
          ),

          // Text Input + Send Button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      enabled: !_controlsDisabled,
                      style: const TextStyle(color: Colors.black87),
                      decoration: const InputDecoration(
                        hintText: "Ask maya...",
                        hintStyle: TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.only(top: 12),
                      ),
                      onSubmitted: (_) => _handleSendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _controlsDisabled ? null : _handleSendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black,
                    ),
                    child: const Icon(Icons.send, color: Colors.white, size: 17),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
}
