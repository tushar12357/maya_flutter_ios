import 'package:Maya/core/network/api_client.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background
          Container(color: const Color(0xFF111827)),
          // Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x992A57E8), Colors.transparent],
              ),
            ),
          ),

          /// MAIN CONTENT
          SafeArea(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _generationsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }

                if (snapshot.hasError) {
                  return _errorView();
                }

                if (!snapshot.hasData ||
                    snapshot.data!['data'] == null ||
                    snapshot.data!['data']['success'] != true) {
                  return _failedView();
                }

                final generationsData = snapshot.data!['data']['data'] ?? [];
                final List<dynamic> generations = List.from(generationsData);

                // Sorting
                generations.sort((a, b) {
                  final statusPriorityA = _getStatusPriority(a['status'] as String?);
                  final statusPriorityB = _getStatusPriority(b['status'] as String?);

                  if (statusPriorityA != statusPriorityB) {
                    return statusPriorityB.compareTo(statusPriorityA);
                  }

                  final dateA = DateTime.tryParse(a['created_at'] as String? ?? '') ?? DateTime(1900);
                  final dateB = DateTime.tryParse(b['created_at'] as String? ?? '') ?? DateTime(1900);

                  return dateB.compareTo(dateA);
                });

                return Column(
                  children: [
                    /// ✅ Custom Top Header (same as ProfilePage)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => context.push('/other'),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF111827).withOpacity(0.8),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                ),
                              ),
                              child: const Icon(
                                Icons.arrow_back,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Generations',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const Spacer(),
                        ],
                      ),
                    ),

                    Expanded(
                      child: generations.isEmpty
                          ? _emptyView()
                          : SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'AI Generations',
                                    style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'View AI history (${generations.length})',
                                    style: const TextStyle(fontSize: 15, color: Color(0xFF9CA3AF)),
                                  ),
                                  const SizedBox(height: 20),

                                  /// LIST
                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: generations.length,
                                    itemBuilder: (context, index) {
                                      final g = generations[index];

                                      final id = g['id']?.toString() ?? '';
                                      final title = g['input']?['message'] ?? 'Untitled';
                                      final type = g['type'] ?? 'unknown';
                                      final status = g['status'] ?? 'unknown';
                                      final createdAt =
                                          (DateTime.tryParse(g['created_at'] ?? '') ?? DateTime(1900))
                                              .toString()
                                              .split('.')[0];
                                      final outputUrl = g['outputUrl'];

                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 12),
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2D4A6F).withOpacity(0.6),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    title,
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.white,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const Icon(Icons.star_border,
                                                    color: Color(0xFF2A57E8), size: 20),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              'Type: $type',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: Color(0xFF9CA3AF),
                                              ),
                                            ),
                                            const SizedBox(height: 6),
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
                                            const SizedBox(height: 6),
                                            Text(
                                              'Created: $createdAt',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF9CA3AF),
                                              ),
                                            ),

                                            /// Action buttons
                                            if (status == 'approval_pending') ...[
                                              const SizedBox(height: 10),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.spaceBetween,
                                                children: [
                                                  _actionBtn('Approve', Colors.green,
                                                      () => _updateStatus(id, 'approve')),
                                                  _actionBtn('Reject', Colors.red,
                                                      () => _updateStatus(id, 'reject')),
                                                  _actionBtn('Regenerate',
                                                      const Color(0xFF2A57E8),
                                                      () => _updateStatus(id, 'regenerate')),
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

  /// REUSABLE UI PARTS

  Widget _actionBtn(String label, Color color, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _emptyView() => const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 100),
          child: Column(
            children: [
              Icon(Icons.inbox_outlined, size: 64, color: Colors.white54),
              SizedBox(height: 16),
              Text('No generations found',
                  style: TextStyle(fontSize: 18, color: Colors.white)),
            ],
          ),
        ),
      );

  Widget _failedView() => const Center(
        child: Text('Failed to load generations', style: TextStyle(color: Colors.white)),
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
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
}