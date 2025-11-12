import 'package:ultravox_client/ultravox_client.dart';

class ThunderSessionService {
  static final ThunderSessionService _instance = ThunderSessionService._internal();
  factory ThunderSessionService() => _instance;
  ThunderSessionService._internal();

  UltravoxSession? session;

  // Persistent UI data
  List<Map<String, dynamic>> conversation = [];
  String currentTranscript = '';
  bool isMicMuted = false;
  bool isSpeakerMuted = false;

  /// Initialize Ultravox session if none exists or previous is disconnected
  void init() {
    if (session == null ||
        session!.status == UltravoxSessionStatus.disconnected ||
        session!.status == UltravoxSessionStatus.disconnecting) {
      session = UltravoxSession.create(experimentalMessages: {"debug"});
    }
  }

  bool get isSessionActive {
    final s = session?.status;
    return s != null &&
        s != UltravoxSessionStatus.disconnected &&
        s != UltravoxSessionStatus.disconnecting;
  }

  void addMessage(String type, String text) {
    conversation.add({'type': type, 'text': text});
  }

  void updateTranscript(String chunk) {
    currentTranscript = chunk;
  }

  void clearTranscript() {
    currentTranscript = '';
  }

  void clearConversation() {
    conversation.clear();
    currentTranscript = '';
  }

  /// Cleanly leave call and reset session so a fresh session can be created later.
  Future<void> resetSession() async {
    try {
      await session?.leaveCall();
    } catch (_) {
      // ignore errors from leave
    }
    session = null;
    clearConversation();
    isMicMuted = false;
    isSpeakerMuted = false;
  }
}
