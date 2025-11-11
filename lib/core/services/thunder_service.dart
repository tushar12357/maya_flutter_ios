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
void init() {
if (session == null) {
session = UltravoxSession.create(experimentalMessages: {"debug"});
    }
  }
bool get isSessionActive {
final s = session?.status;
return s != UltravoxSessionStatus.disconnected &&
s != UltravoxSessionStatus.disconnecting &&
s != UltravoxSessionStatus.connecting &&
s != null;
  }
}