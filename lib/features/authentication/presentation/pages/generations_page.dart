import 'dart:async';

import 'package:Maya/core/constants/colors.dart';
import 'package:Maya/core/network/api_client.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class GenerationsPage extends StatefulWidget {
  const GenerationsPage({super.key});

  @override
  State<GenerationsPage> createState() => _GenerationsPageState();
}

class _GenerationsPageState extends State<GenerationsPage> {
  late Future<Map<String, dynamic>> _generationsFuture;

  @override
  void initState() {
    super.initState();
    _generationsFuture = getIt<ApiClient>().getGenerations();
  }

  Future<void> _refresh() async {
    setState(() {
      _generationsFuture = getIt<ApiClient>().getGenerations();
    });
  }

  Future<void> _updateStatus(String id, String action) async {
    final result = await getIt<ApiClient>().updateGenerationStatus(id, action);
    if (result['statusCode'] == 200 && result['data']['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Generation ${action}ed successfully')),
      );
      _refresh();
    }
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {
      return 'Unknown date';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: InkWell(
          onTap: () => context.go('/other'),
          child: const Icon(Icons.arrow_back, color: Colors.black),
        ),
        title: const Text(
          "Generations",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<Map<String, dynamic>>(
          future: _generationsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!['data']?['success'] != true) {
              return const Center(child: Text("Failed to load generations"));
            }

            final generations = (snapshot.data!['data']['data'] as List<dynamic>)
                .where((g) => g['status'] == 'approval_pending')
                .toList();

            if (generations.isEmpty) {
              return const Center(
                child: Text("No pending generations", style: TextStyle(fontSize: 16, color: Colors.grey)),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: generations.length,
              separatorBuilder: (_, __) => const SizedBox(height: 30),
              itemBuilder: (context, index) {
                final g = generations[index];
                final id = g['id'].toString();
                final title = g['input']?['message'] ?? "Meeting with client";
                final date = "Today, ${_formatDate(g['created_at'] ?? '')}";
                final audioUrl = g['outputUrl'] as String?;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _titleRow(title, date),
                    const SizedBox(height: 16),
                    if (audioUrl != null && audioUrl.isNotEmpty)
                      _audioCard(audioUrl),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _actionBtn("Approve", Colors.green.shade50, Colors.green, () => _updateStatus(id, 'approve')),
                        _actionBtn("Reject", Colors.red.shade50, Colors.red, () => _updateStatus(id, 'reject')),
                        _actionBtn("Regenerate", Colors.purple.shade50, Colors.purple, () => _updateStatus(id, 'regenerate')),
                      ],
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _titleRow(String title, String date) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
            const SizedBox(width: 6),
            Text(date, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ],
    );
  }

  Widget _actionBtn(String text, Color bg, Color border, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Text(
          text,
          style: TextStyle(color: border, fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  // EXACT SAME AUDIO CARD FROM YOUR VoiceUIExample (now with real audio)
  Widget _audioCard(String url) {
    return AudioCardPlayer(url: url);
  }
}

// EXACT COPY OF YOUR AUDIO CARD + REAL AUDIO PLAYBACK


class AudioCardPlayer extends StatefulWidget {
  final String url;
  const AudioCardPlayer({super.key, required this.url});

  @override
  State<AudioCardPlayer> createState() => _AudioCardPlayerState();
}

class _AudioCardPlayerState extends State<AudioCardPlayer> with TickerProviderStateMixin {
  late final AudioPlayer _audioPlayer;
  Duration? duration;
  Duration position = Duration.zero;
  bool isPlaying = false;
  PlayerState playerState = PlayerState.stopped;
bool _sourceReady = false;
final Duration _seekTimeout = const Duration(seconds: 5);


  final int _numberOfBars = 50;
  late final List<double> _dummyAmplitudes;

  @override
  void initState() {
    super.initState();

    // Generate static dummy waveform (looks nice even when not playing)
    final random = Random(42); // fixed seed = same waveform every time
    _dummyAmplitudes = List.generate(_numberOfBars, (i) {
      double base = 0.1 + (i % 8) * 0.08 + (i % 3) * 0.05;
      double noise = random.nextDouble() * 0.1;
      double taper = i > 30 ? (1 - (i - 30) / 20) * 0.5 : 1.0;
      return (base + noise) * taper;
    });

    _audioPlayer = AudioPlayer();

    // Set source (URL)
    _audioPlayer.setSource(UrlSource(widget.url));

    // Listeners
    _audioPlayer.onDurationChanged.listen((d) {
  setState(() {
    duration = d;
    _sourceReady = d != null && d.inMilliseconds > 0;
  });
});


    _audioPlayer.onPositionChanged.listen((p) {
      setState(() => position = p);
    });

    _audioPlayer.onPlayerStateChanged.listen((state) async {
      setState(() {
        playerState = state;
        isPlaying = state == PlayerState.playing;
      });

      // When audio completes → reset to beginning and show play button
      if (state == PlayerState.completed) {
  _audioPlayer.stop(); // important! forces a clean reset
  await _audioPlayer.setSource(UrlSource(widget.url));

  setState(() {
    position = Duration.zero;
    isPlaying = false;
    playerState = PlayerState.stopped;
    _sourceReady = false; // will flip to true once onDurationChanged fires again
  });

  // Ensure UI & waveform refresh correctly
  Future.microtask(() {
    _safeSeek(Duration.zero);
  });
}

    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }


  Future<void> _shareAudioFile() async {
  try {
    final uri = Uri.parse(widget.url);

    // Download audio bytes
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception("Failed to download audio");
    }

    // Save to temp storage
    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/shared_audio_${DateTime.now().millisecondsSinceEpoch}.mp3';
    final file = File(filePath);
    await file.writeAsBytes(response.bodyBytes);

    // Share actual file
    await Share.shareXFiles([XFile(filePath)], text: "Here's the voice note");

  } catch (e) {
    debugPrint("Share failed: $e");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to share audio")),
      );
    }
  }
}

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  double get progress => duration != null && duration!.inSeconds > 0
      ? (position.inSeconds / duration!.inSeconds).clamp(0.0, 1.0)
      : 0.0;

Future<void> _togglePlayPause() async {
  // If audio completed or position is at end → restart fresh
  if (playerState == PlayerState.completed ||
      (playerState == PlayerState.stopped && position == Duration.zero)) {

    if (_sourceReady) {
      await _safeSeek(Duration.zero);
      await _audioPlayer.resume();
    } else {
      // fallback: try resume — if source isn't ready, resume will start once loaded
      try {
        await _audioPlayer.resume();
      } catch (e) {
        debugPrint('resume fallback failed: $e');
      }
    }

    setState(() => isPlaying = true);
    return;
  }

  // Normal toggle play/pause
  if (isPlaying) {
    await _audioPlayer.pause();
    setState(() => isPlaying = false);
  } else {
    await _audioPlayer.resume();
    setState(() => isPlaying = true);
  }
}

Future<void> _safeSeek(Duration target) async {
  // don't attempt seek if source isn't ready
  if (!_sourceReady) return;

  try {
    // limit how long we wait for the internal seek
    await _audioPlayer.seek(target).timeout(_seekTimeout);
  } on TimeoutException catch (e) {
    // swallow timeout and log — player wasn't ready to seek
    // optionally try a fallback: pause/resume or re-set source
    debugPrint('seek timeout: $e');
  } catch (e) {
    debugPrint('seek error: $e');
  }
}

 Future<void> _seekRelative(Duration delta) async {
  // Don't attempt to seek if we don't know the duration yet
  if (duration == null || duration!.inMilliseconds == 0) return;

  final int targetMs = (position.inMilliseconds + delta.inMilliseconds)
      .clamp(0, duration!.inMilliseconds);
  final target = Duration(milliseconds: targetMs);
await _safeSeek(target);

}

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffB2B2B2), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.grey.shade100, offset: const Offset(0, 4), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Voice record chat", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
                child:  GestureDetector(
  onTap: _shareAudioFile,
  child: Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
    child: const Icon(Icons.share_outlined, size: 20, color: Colors.black54),
  ),
),

              ),
            ],
          ),
          const SizedBox(height: 30),

          // Waveform
          SizedBox(
            height: 80,
            width: double.infinity,
            child: CustomPaint(
              painter: AudioWaveformPainter(amplitudes: _dummyAmplitudes, progress: progress),
            ),
          ),
          const SizedBox(height: 10),

          // Slider
         SliderTheme(
  data: SliderTheme.of(context).copyWith(
    trackHeight: 2.5,
    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
    overlayShape: const RoundSliderOverlayShape(overlayRadius: 10.0),
    activeTrackColor: AppColors.primary,
    inactiveTrackColor: AppColors.borderColor,
    thumbColor: AppColors.primary,
  ),
  child: Slider(
    value: position.inMilliseconds.toDouble().clamp(0.0, (duration?.inMilliseconds.toDouble() ?? 1.0)),
    min: 0.0,
    max: (duration?.inMilliseconds.toDouble() ?? 1.0),
    onChanged: (duration == null || (duration?.inMilliseconds ?? 0) == 0)
    ? null
    : (v) => _safeSeek(Duration(milliseconds: v.toInt())),

  ),
),

          // Time labels
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDuration(position), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                Text(_formatDuration(duration ?? Duration.zero), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Control buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _controlBtn(Icons.fast_rewind_rounded, () => _seekRelative(const Duration(seconds: -10))),
              const SizedBox(width: 20),
              _controlBtn(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                _togglePlayPause,
                isLarge: true,
              ),
              const SizedBox(width: 20),
              _controlBtn(Icons.fast_forward_rounded, () => _seekRelative(const Duration(seconds: 10))),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _controlBtn(IconData icon, VoidCallback onTap, {bool isLarge = false}) {
    final double size = isLarge ? 28.0 : 22.0;
    final double padding = isLarge ? 20.0 : 14.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: const Color(0xffECB48D), // AppColors.secondary
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.blue.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Icon(icon, color: Colors.black, size: size),
      ),
    );
  }
}
// EXACT SAME PAINTER FROM YOUR ORIGINAL CODE
class AudioWaveformPainter extends CustomPainter {
  final List<double> amplitudes;
  final double progress;

  AudioWaveformPainter({required this.amplitudes, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final double halfHeight = size.height / 2;
    final double barWidth = 3.0;
    final double spacing = 1.5;
    final double step = barWidth + spacing;
    final int activeBarCount = (amplitudes.length * progress).round();

    final Paint activePaint = Paint()
      ..color = AppColors.secondary
      ..strokeWidth = barWidth
      ..strokeCap = StrokeCap.round;

    final Paint inactivePaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = barWidth
      ..strokeCap = StrokeCap.round;

    final double startX = (size.width - (amplitudes.length * step) + spacing) / 2;

    for (int i = 0; i < amplitudes.length; i++) {
      double normalizedAmplitude = amplitudes[i].clamp(0.0, 0.9);
      double barHeight = normalizedAmplitude * halfHeight;

      double x = startX + i * step;
      Offset p1 = Offset(x, halfHeight - barHeight);
      Offset p2 = Offset(x, halfHeight + barHeight);

      canvas.drawLine(p1, p2, i < activeBarCount ? activePaint : inactivePaint);
    }
  }

  @override
  bool shouldRepaint(covariant AudioWaveformPainter old) => old.progress != progress;
}