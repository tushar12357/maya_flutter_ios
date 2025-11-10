import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:Maya/core/network/api_client.dart';

class TaskDetailPage extends StatefulWidget {
  final String sessionId;
  final String taskQuery;
  final ApiClient apiClient;

  const TaskDetailPage({
    super.key,
    required this.sessionId,
    required this.taskQuery,
    required this.apiClient,
  });

  @override
  _TaskDetailPageState createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  List<Map<String, dynamic>> subtasks = [];
  String mainDescription = 'No description available.';
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchTaskDetail();
  }

  Future<void> fetchTaskDetail() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await widget.apiClient.fetchTasksDetail(
        sessionId: widget.sessionId,
      );

      if (response['statusCode'] == 200 && (response['data']['success'] as bool? ?? false)) {
        final dataList = response['data']['data'] as List<dynamic>?;

        if (dataList == null || dataList.isEmpty) {
          setState(() {
            isLoading = false;
            errorMessage = 'No task details found.';
          });
          return;
        }

        final List<Map<String, dynamic>> tasks = dataList.cast<Map<String, dynamic>>();

        // Extract description from first subtask
        final firstPayload = tasks.first['user_payload'] as Map<String, dynamic>?;
        final dataStr = firstPayload?['data']?.toString();
        if (dataStr != null) {
          try {
            final payloadJson = jsonDecode(dataStr) as Map<String, dynamic>;
            mainDescription = payloadJson['description']?.toString() ?? 'No description.';
          } catch (_) {
            mainDescription = 'No description.';
          }
        }

        setState(() {
          subtasks = tasks;
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
          errorMessage = response['message']?.toString() ?? 'Failed to load task.';
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Error: ${e.toString()}';
      });
    }
  }

  String _formatDate(String? timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      return DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(timestamp).toLocal());
    } catch (_) {
      return 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    final routeData = GoRouterState.of(context).extra as Map<String, dynamic>?;
    final taskQuery = widget.taskQuery.isNotEmpty
        ? widget.taskQuery
        : (routeData?['query']?.toString() ?? 'Task Details');

    return Scaffold(
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
            child: Column(
              children: [
                // AppBar
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                        onPressed: () => context.push('/tasks'),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Task Detail',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),

                // Main Content
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator(color: Colors.white))
                      : errorMessage != null
                          ? Center(
                              child: Text(
                                errorMessage!,
                                style: const TextStyle(color: Colors.white70, fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Task Title
                                  Text(
                                    taskQuery,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Description Section
                                  _buildSectionCard(
                                    title: 'Description',
                                    child: Text(
                                      mainDescription,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: 14,
                                        height: 1.6,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  // Subtasks Section
                                  Text(
                                    'Subtasks',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Subtask Cards with JSON
                                  ...subtasks.asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final subtask = entry.value;
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 16),
                                      child: _buildSubtaskCard(
                                        index: index + 1,
                                        subtask: subtask,
                                      ),
                                    );
                                  }).toList(),

                                  const SizedBox(height: 24),
                                ],
                              ),
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildSubtaskCard({required int index, required Map<String, dynamic> subtask}) {
    final createdAt = subtask['created_at']?.toString();
    final status = subtask['status']?.toString().toLowerCase() ?? 'pending';
    final query = (subtask['user_payload'] as Map<String, dynamic>?)?['query']?.toString() ?? 'No query';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFF2A57E8),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$index',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  query,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _buildStatusBadge(status),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _formatDate(createdAt),
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),

          // Full JSON Display
          Text(
            'Full JSON',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: SelectableText(
              _prettyJson(subtask),
              style: const TextStyle(
                fontFamily: 'Courier',
                fontSize: 11,
                color: Color(0xFF94A3B8),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final config = {
      'succeeded': {'label': 'Success', 'color': const Color(0xFF10B981)},
      'completed': {'label': 'Success', 'color': const Color(0xFF10B981)},
      'pending': {'label': 'Pending', 'color': const Color(0xFFF59E0B)},
      'failed': {'label': 'Failed', 'color': const Color(0xFFEF4444)},
    };

    final cfg = config[status] ?? config['pending']!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (cfg['color'] as Color).withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        cfg['label'] as String,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: cfg['color'] as Color,
        ),
      ),
    );
  }

  String _prettyJson(Map<String, dynamic> json) {
    try {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(json);
    } catch (e) {
      return json.toString();
    }
  }
}