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
  AnimationController? _pulseController;
  Animation<double>? _pulseAnimation;
  AnimationController? _orbController;
  Animation<double>? _orbScaleAnimation;

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
    _focusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _onStatusChange() {
    UltravoxSessionStatus current = _session!.status;
    setState(() {
      _status = _mapStatusToSpeech(current);
    });
    if (current == 'idle' && _previousStatus == 'speaking') {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _currentTranscriptChunk = '';
            _isListening = false;
            _isConnecting = false;
          });
        }
      });
    }
    _previousStatus = current as String;
    if (mounted) setState(() {});
  }

  void _onDataMessage() {
    final message = _session!.lastDataMessage;
    if (message['type'] == 'transcript') {
      final lastTranscript = _session!.transcripts.last;
      if (mounted && lastTranscript.isFinal) {
        setState(() {
          _currentTranscriptChunk = lastTranscript.text;
          _conversation.add({
            'type': lastTranscript.speaker == Role.user ? 'user' : 'maya',
            'text': _currentTranscriptChunk,
          });
          _currentTranscriptChunk = '';
          if (_conversation.length > 10) {
            _conversation.removeAt(0);
          }
        });
      }
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
        return 'Ravan is Speaking';
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
    _pulseController?.stop();
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
      body: Container(
        height: MediaQuery.of(context).size.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue.shade50, Colors.purple.shade50],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Status Bar
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isListening ? Icons.mic : Icons.mic_off,
                      color: Colors.blue.shade700,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _status,
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (_isConnecting)
                      const Padding(
                        padding: EdgeInsets.only(left: 12),
                        child: CircularProgressIndicator(
                          color: Colors.blue,
                          strokeWidth: 3,
                        ),
                      ),
                  ],
                ),
              ),
              // Interactive Orb
              Expanded(
                flex: 2,
                child: Center(
                  child: GestureDetector(
                    onTap: _isListening || _isConnecting ? _onStop : _onStart,
                    child: AnimatedBuilder(
                      animation: _orbController!,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _orbScaleAnimation!.value,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (_isListening)
                                AnimatedBuilder(
                                  animation: _pulseAnimation!,
                                  builder: (context, child) {
                                    return Container(
                                      width: 250 * _pulseAnimation!.value,
                                      height: 250 * _pulseAnimation!.value,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.blue.shade200.withOpacity(0.3),
                                      ),
                                    );
                                  },
                                ),
                              Container(
                                width: 160,
                                height: 160,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: _isListening || _isConnecting
                                        ? [
                                            Colors.blue.shade600,
                                            Colors.purple.shade600,
                                          ]
                                        : [
                                            Colors.blue.shade300,
                                            Colors.purple.shade300,
                                          ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.15),
                                      blurRadius: 25,
                                      spreadRadius: 5,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: _isConnecting
                                    ? const Center(
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 4,
                                        ),
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              // Conversation Area
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _conversation.isNotEmpty
                      ? ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          itemCount: _conversation.length,
                          itemBuilder: (context, index) {
                            final msg = _conversation[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Align(
                                alignment: msg['type'] == 'user'
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  constraints: BoxConstraints(
                                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    color: msg['type'] == 'user'
                                        ? Colors.blue.shade100
                                        : Colors.purple.shade100,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    msg['text'],
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.black87,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        )
                      : Center(
                          child: Text(
                            'Start a conversation...',
                            style: TextStyle(
                              color: Colors.blue.shade700.withOpacity(0.7),
                              fontSize: 18,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                ),
              ),
              // Transcript and Input
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  border: Border(
                    top: BorderSide(color: Colors.blue.shade200.withOpacity(0.2)),
                  ),
                ),
                child: Column(
                  children: [
                    if (_currentTranscriptChunk.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.white.withOpacity(0.1),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.record_voice_over,
                              color: Colors.blue.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _currentTranscriptChunk,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.blue.shade700,
                                  height: 1.4,
                                ),
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
                              borderRadius: BorderRadius.circular(25),
                              color: Colors.white.withOpacity(0.1),
                              border: Border.all(color: Colors.white.withOpacity(0.2)),
                            ),
                            child: TextField(
                              controller: _textController,
                              focusNode: _focusNode,
                              enabled: true, // Fixed: Always enable TextField
                              onSubmitted: (_) => _handleSendMessage(),
                              decoration: InputDecoration(
                                hintText: 'Type your message...',
                                hintStyle: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 16,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 14,
                                ),
                              ),
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: _handleSendMessage,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: _textController.text.trim().isEmpty
                                    ? [
                                        Colors.grey.shade300,
                                        Colors.grey.shade400,
                                      ]
                                    : [
                                        Colors.blue.shade400,
                                        Colors.purple.shade500,
                                      ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.send,
                              size: 24,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_isListening)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: Icon(
                                _isMicMuted ? Icons.mic_off : Icons.mic,
                                color: _isMicMuted ? Colors.grey : Colors.blue,
                                size: 28,
                              ),
                              onPressed: _toggleMicMute,
                            ),
                            const SizedBox(width: 16),
                            IconButton(
                              icon: Icon(
                                _isSpeakerMuted ? Icons.volume_off : Icons.volume_up,
                                color: _isSpeakerMuted ? Colors.grey : Colors.blue,
                                size: 28,
                              ),
                              onPressed: _toggleSpeakerMute,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}