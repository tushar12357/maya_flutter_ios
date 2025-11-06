import 'package:Maya/core/network/api_client.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class GenerationsPage extends StatefulWidget {
  const GenerationsPage({super.key});

  @override
  State<GenerationsPage> createState() => _GenerationsPageState();
}

class _GenerationsPageState extends State<GenerationsPage> {
  late final Future<Map<String, dynamic>> _generationsFuture;

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

  Future<void> _updateStatus(int generationId, String action) async {
    final result = await getIt<ApiClient>().updateGenerationStatus(generationId, action);
    if (result['statusCode'] == 200 && result['data']['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Generation $action successfully')),
      );
      await _refreshGenerations();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update status')),
      );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          'Generations',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: Stack(
        children: [
          // Background color
          Container(color: const Color(0xFF111827)),
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
          // Main content
          SafeArea(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _generationsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                } else if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, color: Colors.redAccent, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading generations: ${snapshot.error}',
                          style: const TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _refreshGenerations,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2A57E8),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                } else if (snapshot.hasData && snapshot.data!['data']['success'] == true) {
                  final List<dynamic> generationsData = snapshot.data!['data']['data'] ?? [];
                  final List<dynamic> generations = List.from(generationsData);
                  // Sort by status priority (approval_pending first) then by created_at descending
                  generations.sort((a, b) {
                    final statusPriorityA = _getStatusPriority(a['status'] as String?);
                    final statusPriorityB = _getStatusPriority(b['status'] as String?);
                    if (statusPriorityA != statusPriorityB) {
                      return statusPriorityB.compareTo(statusPriorityA); // Higher priority first
                    }
                    final dateA = DateTime.tryParse(a['created_at'] as String? ?? '') ?? DateTime(1900);
                    final dateB = DateTime.tryParse(b['created_at'] as String? ?? '') ?? DateTime(1900);
                    return dateB.compareTo(dateA); // Newest first
                  });

                  if (generations.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_outlined, size: 64, color: Colors.white54),
                          SizedBox(height: 16),
                          Text(
                            'No generations yet',
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Start creating AI content to see your history here.',
                            style: TextStyle(fontSize: 14, color: Colors.white70),
                          ),
                        ],
                      ),
                    );
                  }
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        const Text(
                          'AI Generations',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'View all AI-generated content and history (${generations.length} items)',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Generations List
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: generations.length,
                          itemBuilder: (context, index) {
                            final generation = generations[index];
                            final idStr = generation['id'] as String? ?? '0';
                            final id = int.tryParse(idStr) ?? 0;
                            final title = (generation['input'] as Map<String, dynamic>?)?['message'] as String? ?? 'Untitled Generation';
                            final type = generation['type'] as String? ?? 'unknown';
                            final status = generation['status'] as String? ?? 'unknown';
                            final createdAtDate = DateTime.tryParse(generation['created_at'] as String? ?? '');
                            final createdAt = createdAtDate?.toString().split('.')[0] ?? 'Unknown';
                            final outputUrl = generation['outputUrl'] as String?;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2D4A6F).withOpacity(0.6),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withOpacity(0.1)),
                                boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black26)],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Title and Star
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          title,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.white,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const Icon(
                                        Icons.star_border,
                                        size: 20,
                                        color: Color(0xFF2A57E8),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  // Type info
                                  Text(
                                    'Type: $type',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF9CA3AF),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  // Status Badge (prominent)
                                  Chip(
                                    label: Text(
                                      status.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    backgroundColor: _getStatusColor(status),
                                  ),
                                  const SizedBox(height: 8),
                                  // Output URL (if available, e.g., for voice play)
                                  if (outputUrl != null && type == 'voice')
                                    Row(
                                      children: [
                                        const Icon(Icons.play_arrow, size: 16, color: Color(0xFF9CA3AF)),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () {
                                              // TODO: Implement audio playback, e.g., using audioplayers package
                                              // AudioPlayer().play(UrlSource(outputUrl));
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('Playing: $outputUrl')),
                                              );
                                            },
                                            child: const Text(
                                              'Play Audio',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF60A5FA),
                                                decoration: TextDecoration.underline,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Created: $createdAt',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF9CA3AF),
                                    ),
                                  ),
                                  // Action Buttons (only if approval_pending)
                                  if (status == 'approval_pending') ...[
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                        ElevatedButton(
                                          onPressed: () => _updateStatus(id, 'approve'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          child: const Text('Approve', style: TextStyle(fontSize: 12)),
                                        ),
                                        ElevatedButton(
                                          onPressed: () => _updateStatus(id, 'reject'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          child: const Text('Reject', style: TextStyle(fontSize: 12)),
                                        ),
                                        ElevatedButton(
                                          onPressed: () => _updateStatus(id, 'regenerate'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF2A57E8),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          child: const Text('Regenerate', style: TextStyle(fontSize: 12)),
                                        ),
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
                  );
                } else {
                  return const Center(
                    child: Text(
                      'Failed to load generations',
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
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
}