import 'package:Maya/core/network/api_client.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// ---------------------------------------------------------------
///  Audio-player widget (copied from TaskDetailPage)
/// ---------------------------------------------------------------
class AudioPlayerWidget extends StatefulWidget {
  final String url;
  const AudioPlayerWidget({super.key, required this.url});

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  late final AudioPlayer _audioPlayer;
  bool isPlaying = false;
  Duration duration = Duration.zero;
  Duration position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => isPlaying = state == PlayerState.playing);
    });
    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => duration = d);
    });
    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => position = p);
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF2A57E8).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow,
                  color: const Color(0xFF2A57E8), size: 18),
              onPressed: () async {
                if (isPlaying) {
                  await _audioPlayer.pause();
                } else {
                  await _audioPlayer.play(UrlSource(widget.url));
                }
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 5),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 10),
                    activeTrackColor: const Color(0xFF2A57E8),
                    inactiveTrackColor: Colors.white.withOpacity(0.1),
                    thumbColor: const Color(0xFF2A57E8),
                  ),
                  child: Slider(
                    min: 0,
                    max: duration.inSeconds.toDouble(),
                    value: position.inSeconds.toDouble().clamp(
                        0, duration.inSeconds.toDouble()),
                    onChanged: (v) => _audioPlayer.seek(
                        Duration(seconds: v.toInt())),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_format(position),
                          style: TextStyle(
                              fontSize: 9,
                              color: Colors.white.withOpacity(0.4))),
                      Text(_format(duration),
                          style: TextStyle(
                              fontSize: 9,
                              color: Colors.white.withOpacity(0.4))),
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

/// ---------------------------------------------------------------
///  GenerationsPage (updated)
/// ---------------------------------------------------------------
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

  Future<void> _refreshGenerations() async {
    setState(() {
      _generationsFuture = getIt<ApiClient>().getGenerations();
    });
  }

  Future<void> _updateStatus(String generationId, String action) async {
    final result = await getIt<ApiClient>()
        .updateGenerationStatus(generationId, action);
    if (result['statusCode'] == 200 && result['data']['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Generation $action successfully')),
      );
      await _refreshGenerations();
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approval_pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  int _getStatusPriority(String? status) {
    final s = status ?? 'unknown';
    switch (s) {
      case 'approval_pending':
        return 3;
      case 'approved':
        return 2;
      case 'rejected':
        return 1;
      default:
        return 0;
    }
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('dd MMM yyyy, HH:mm').format(dt);
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Container(color: const Color(0xFF111827)),
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
            child: FutureBuilder<Map<String, dynamic>>(
              future: _generationsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: Colors.white));
                }
                if (snapshot.hasError) return _errorView();
                if (!snapshot.hasData ||
                    snapshot.data!['data'] == null ||
                    snapshot.data!['data']['success'] != true) {
                  return _failedView();
                }

                final List<dynamic> generations =
                    List.from(snapshot.data!['data']['data'] ?? []);

                // ---- sorting -------------------------------------------------
                generations.sort((a, b) {
                  final prioA = _getStatusPriority(a['status'] as String?);
                  final prioB = _getStatusPriority(b['status'] as String?);
                  if (prioA != prioB) return prioB.compareTo(prioA);

                  final dA = DateTime.tryParse(a['created_at'] ?? '') ??
                      DateTime(1900);
                  final dB = DateTime.tryParse(b['created_at'] ?? '') ??
                      DateTime(1900);
                  return dB.compareTo(dA);
                });

                // ---------------------------------------------------------------
                return Column(
                  children: [
                    // ---- Header ------------------------------------------------
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => context.push('/other'),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color:
                                    const Color(0xFF111827).withOpacity(0.8),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.1)),
                              ),
                              child: const Icon(Icons.arrow_back,
                                  color: Colors.white, size: 20),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text('Generations',
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          const Spacer(),
                        ],
                      ),
                    ),

                    // ---- List --------------------------------------------------
                    Expanded(
                      child: generations.isEmpty
                          ? _emptyView()
                          : SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('AI Generations',
                                      style: TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white)),
                                  const SizedBox(height: 6),
                                  Text(
                                      'View AI history (${generations.length})',
                                      style: const TextStyle(
                                          fontSize: 15,
                                          color: Color(0xFF9CA3AF))),
                                  const SizedBox(height: 20),

                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: generations.length,
                                    itemBuilder: (context, index) {
                                      final g = generations[index];

                                      final id = g['id']?.toString() ?? '';
                                      final title =
                                          g['input']?['message'] ?? 'Untitled';
                                      final type = g['type'] ?? 'unknown';
                                      final status =
                                          g['status'] ?? 'unknown';
                                      final createdAt = _formatDate(
                                          g['created_at'] ?? '');
                                      final outputUrl = g['outputUrl'] as String?;

                                      return Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 12),
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2D4A6F)
                                              .withOpacity(0.6),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                              color:
                                                  Colors.white.withOpacity(0.1)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // ---- Title & Star -------------------------
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(title,
                                                      style: const TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: Colors.white),
                                                      overflow:
                                                          TextOverflow.ellipsis),
                                                ),
                                                const Icon(Icons.star_border,
                                                    color: Color(0xFF2A57E8),
                                                    size: 20),
                                              ],
                                            ),
                                            const SizedBox(height: 6),

                                            // ---- Type ---------------------------------
                                            Text('Type: $type',
                                                style: const TextStyle(
                                                    fontSize: 13,
                                                    color: Color(0xFF9CA3AF))),
                                            const SizedBox(height: 6),

                                            // ---- Status Chip -------------------------
                                            Chip(
                                              label: Text(status.toUpperCase(),
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.white)),
                                              backgroundColor:
                                                  _getStatusColor(status),
                                            ),
                                            const SizedBox(height: 6),

                                            // ---- Created At -------------------------
                                            Text('Created: $createdAt',
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFF9CA3AF))),
                                            const SizedBox(height: 8),

                                            // ---- OUTPUT URL (always shown) ----------
                                            if (outputUrl != null &&
                                                outputUrl.isNotEmpty) ...[
                                              const Text('Output',
                                                  style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.white70)),
                                              const SizedBox(height: 6),
                                              AudioPlayerWidget(url: outputUrl),
                                              const SizedBox(height: 12),
                                            ],

                                            // ---- Action buttons (only for pending) --
                                            if (status == 'approval_pending') ...[
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  _actionBtn(
                                                      'Approve',
                                                      Colors.green,
                                                      () => _updateStatus(
                                                          id, 'approve')),
                                                  _actionBtn(
                                                      'Reject',
                                                      Colors.red,
                                                      () => _updateStatus(
                                                          id, 'reject')),
                                                  _actionBtn(
                                                      'Regenerate',
                                                      const Color(0xFF2A57E8),
                                                      () => _updateStatus(
                                                          id, 'regenerate')),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------
  //  Re-usable UI helpers
  // -----------------------------------------------------------------
  Widget _actionBtn(String label, Color color, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _emptyView() => const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 100),
          child: Column(
            children: [
              Icon(Icons.inbox_outlined,
                  size: 64, color: Colors.white54),
              SizedBox(height: 16),
              Text('No generations found',
                  style: TextStyle(fontSize: 18, color: Colors.white)),
            ],
          ),
        ),
      );

  Widget _failedView() => const Center(
        child: Text('Failed to load generations',
            style: TextStyle(color: Colors.white)),
      );

  Widget _errorView() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            const Text('Error loading generations',
                style: TextStyle(color: Colors.white)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshGenerations,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2A57E8),
                  foregroundColor: Colors.white),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
}