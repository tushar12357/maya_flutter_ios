import 'dart:convert';
import 'package:Maya/core/constants/colors.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:Maya/core/network/api_client.dart';

class TaskDetailPage extends StatefulWidget {
  const TaskDetailPage({super.key});

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  late final ApiClient _apiClient;
  String? _sessionId;
  String _taskQuery = 'Task Details';
  List<Map<String, dynamic>> _subtasks = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Dynamic fields
  String _title = '';
  String _description = 'No description provided.';
  String _status = 'Pending';
  String _category = 'Productivity';

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient(Dio(), Dio());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uri = GoRouterState.of(context).uri;
    _sessionId = uri.pathSegments.length > 1 ? uri.pathSegments[1] : null;
    final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
    _taskQuery = extra?['query']?.toString() ?? 'Task Details';

    if (_sessionId != null) {
      _fetchTaskDetail();
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Session ID missing';
      });
    }
  }

  // Safe JSON parser
  Map<String, dynamic> _parse(dynamic input) {
    if (input == null) return {};
    if (input is Map<String, dynamic>) return input;
    if (input is String && input.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(input);
        return decoded is Map<String, dynamic> ? decoded : {};
      } catch (_) {}
    }
    return {};
  }

  // Human readable key
  String _humanizeKey(String key) {
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  // Format timestamp
  String _formatTime(String? iso) {
    if (iso == null || iso.isEmpty) return 'Unknown time';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('hh:mm a • dd MMM yyyy').format(dt);
    } catch (_) {
      return 'Invalid time';
    }
  }

  Future<void> _fetchTaskDetail() async {
    setState(() => _isLoading = true);

    try {
      final res = await _apiClient.fetchTasksDetail(sessionId: _sessionId!);
      if (res['statusCode'] != 200 || res['data']['success'] != true) {
        throw Exception(res['message'] ?? 'Failed to load');
      }

      final List tasks = res['data']['data'] ?? [];
      if (tasks.isEmpty) throw Exception('No task found');

      final first = tasks.first as Map<String, dynamic>;

      // Real execution status from API root
      final String execStatus = (first['status']?.toString() ?? 'pending').toLowerCase();
      final String displayStatus = {
        'succeeded': 'Completed',
        'completed': 'Completed',
        'failed': 'Failed',
        'pending': 'In Progress',
        'running': 'Running',
      }[execStatus] ?? 'Unknown';

      final payload = _parse(first['user_payload']);
      final payloadData = _parse(payload['data']);
      final response = _parse(first['response']);
      final responseData = _parse(response['data']);

      final title = payloadData['title'] ?? responseData['title'] ?? 'Untitled Task';
      final description = (payloadData['description'] ?? responseData['description'] ?? '').toString().trim();

      setState(() {
        _title = title;
        _description = description.isEmpty ? 'No description provided.' : description;
        _status = displayStatus;
        _category = (payload['service']?.toString() ?? 'productivity').capitalize();
        _subtasks = tasks.cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_errorMessage != null) {
      return Scaffold(body: Center(child: Text('Error: $_errorMessage', style: const TextStyle(color: Colors.red))));
    }

    return SafeArea(
      top: false,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.balckClr),
            onPressed: () => context.go('/tasks'),
          ),
          title: const Text('Task Detail', style: TextStyle(color: AppColors.balckClr, fontSize: 18)),
          backgroundColor: AppColors.whiteClr,
          elevation: 0,
        ),
        backgroundColor: AppColors.bgColor,
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: AppColors.borderColor, borderRadius: BorderRadius.circular(5)),
                child: Text(_category, style: const TextStyle(fontSize: 14, color: AppColors.balckClr)),
              ),
              const SizedBox(height: 16),

              // Title
              Text(_title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_description, style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),

              const SizedBox(height: 20),

              // Info Rows (Priority removed)
              _buildInfoRow(Icons.calendar_today, 'Due Date', 'Today, ${DateFormat('dd MMM yyyy').format(DateTime.now())}'),
              _buildInfoRow(Icons.access_time, 'Time', DateFormat('hh:mm a').format(DateTime.now())),
              _buildInfoRow(Icons.assignment, 'Task Status', _status, isStatus: true),

              const SizedBox(height: 24),

              // Sub-tasks
              ..._subtasks.map((subtask) => SubTaskCard(subtask: subtask, sessionId: _sessionId)),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {bool isStatus = false}) {
    Color textColor = AppColors.greyColor;
    if (isStatus) {
      final lower = value.toLowerCase();
      if (lower.contains('complete')) textColor = Colors.green.shade700;
      else if (lower.contains('fail')) textColor = Colors.red.shade700;
      else if (lower.contains('progress') || lower.contains('running')) textColor = AppColors.primary;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey, size: 20),
          const SizedBox(width: 16),
          SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 16))),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 16, color: textColor, fontWeight: isStatus ? FontWeight.w600 : null),
            ),
          ),
        ],
      ),
    );
  }
}

// Fully dynamic sub-task card with working tabs
class SubTaskCard extends StatefulWidget {
  final Map<String, dynamic> subtask;
  final String? sessionId;
  const SubTaskCard({required this.subtask, this.sessionId, super.key});

  @override
  State<SubTaskCard> createState() => _SubTaskCardState();
}

class _SubTaskCardState extends State<SubTaskCard> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() => _tabIndex = _tabController.index));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _parse(dynamic input) {
    if (input == null) return {};
    if (input is Map<String, dynamic>) return input;
    if (input is String && input.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(input);
        return decoded is Map<String, dynamic> ? decoded : {};
      } catch (_) {}
    }
    return {};
  }

  String _prettyJson(dynamic data) {
    try {
      return const JsonEncoder.withIndent('  ').convert(data);
    } catch (_) {
      return data.toString();
    }
  }

  Widget _humanReadable(Map<String, dynamic> data) {
    if (data.isEmpty) {
      return const Padding(padding: EdgeInsets.all(16), child: Text('No data', style: TextStyle(color: Colors.grey)));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: data.entries.map((e) {
          final key = e.key.toString();
          final value = e.value;
          final display = value is bool
              ? (value ? 'Yes' : 'No')
              : value.toString().isEmpty
                  ? '—'
                  : value.toString();

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 140,
                  child: Text(
                    key.split('_').map((w) => w[0].toUpperCase() + w.substring(1)).join(' '),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
                const Text(': ', style: TextStyle(fontWeight: FontWeight.w600)),
                Expanded(child: Text(display, style: const TextStyle(fontSize: 14))),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final payload = _parse(widget.subtask['user_payload']);
    final payloadData = _parse(payload['data']);
    final response = _parse(widget.subtask['response']);
    final responseData = _parse(response['data']);
    final query = payload['query']?.toString() ?? 'No query';
    final time = _formatTime(widget.subtask['created_at']?.toString());

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sub-Task', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          // Tabs
          Row(
            children: ['Request Payload', 'Response Data', 'Full JSON'].asMap().entries.map((e) {
              final i = e.key;
              final title = e.value;
              final active = _tabIndex == i;
              return [
                GestureDetector(
                  onTap: () => _tabController.animateTo(i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: active ? AppColors.primary : AppColors.borderColor,
                      borderRadius: BorderRadius.circular(10),
                      border: active ? null : Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(title,
                        style: TextStyle(fontSize: 12, color: active ? Colors.white : Colors.black, fontWeight: FontWeight.w500)),
                  ),
                ),
                const SizedBox(width: 8),
              ];
            }).expand((x) => x).toList()..removeLast(),
          ),
          const SizedBox(height: 16),

          // Tab Content
          SizedBox(
            height: 300,
            child: IndexedStack(
              index: _tabIndex,
              children: [
                SingleChildScrollView(child: _humanReadable(payloadData)),
                SingleChildScrollView(child: _humanReadable(responseData)),
                SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(8)),
                    child: SelectableText(_prettyJson(widget.subtask),
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.4)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Summary
          // const Text('Summary', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          // const SizedBox(height: 8),
          // Text('At $time', style: TextStyle(color: Colors.grey.shade700)),
          // const SizedBox(height: 6),
          // Container(
          //   width: double.infinity,
          //   padding: const EdgeInsets.all(10),
          //   color: Colors.grey.shade200,
          //   child: SelectableText('/api/v1/tasks/${widget.sessionId}',
          //       style: const TextStyle(fontFamily: 'monospace', fontSize: 14)),
          // ),
          // const SizedBox(height: 12),
          // Text('"$query"', style: TextStyle(fontSize: 15, color: Colors.grey.shade700, fontStyle: FontStyle.italic)),
       
       
        ],
      ),
    );
  }

  String _formatTime(String? iso) {
    if (iso == null || iso.isEmpty) return 'Unknown time';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('hh:mm a • dd MMM yyyy').format(dt);
    } catch (_) {
      return 'Invalid time';
    }
  }
}

extension StringExt on String {
  String capitalize() => isEmpty ? this : this[0].toUpperCase() + substring(1);
}