import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:Maya/core/network/api_client.dart';

class TaskDetailPage extends StatefulWidget {
  const TaskDetailPage({super.key});

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  // -----------------------------------------------------------------
  //  Runtime data
  // -----------------------------------------------------------------
  late final ApiClient _apiClient;
  String? _sessionId;
  String _taskQuery = 'Task Details';

  List<Map<String, dynamic>> _subtasks = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _mainStatus;
  String? _mainCreatedAt;

  // -----------------------------------------------------------------
  @override
  void initState() {
    super.initState();

    // Initialise Dio instances exactly like TasksPage does
    final publicDio = Dio();
    final protectedDio = Dio();
    _apiClient = ApiClient(publicDio, protectedDio);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // ---- Extract route data ------------------------------------------------
    final uri = GoRouterState.of(context).uri;
    _sessionId = uri.pathSegments.length > 1 ? uri.pathSegments[1] : null;

    final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
    _taskQuery = extra?['query']?.toString() ?? 'Task Details';

    // ---- Fetch fresh data --------------------------------------------------
    if (_sessionId != null) {
      _fetchTaskDetail();
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Invalid route – session id missing.';
      });
    }
  }

  // -----------------------------------------------------------------
  Future<void> _fetchTaskDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiClient.fetchTasksDetail(
        sessionId: _sessionId!,
      );

      if (response['statusCode'] == 200 &&
          (response['data']['success'] as bool? ?? false)) {
        final List<dynamic>? dataList = response['data']['data'];

        if (dataList == null || dataList.isEmpty) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'No task details found.';
          });
          return;
        }

        final tasks = dataList.cast<Map<String, dynamic>>();
        final first = tasks.first;

        setState(() {
          _mainStatus = first['status']?.toString() ?? 'pending';
          _mainCreatedAt = first['created_at']?.toString();
          _subtasks = tasks;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage =
              response['message']?.toString() ?? 'Failed to load task.';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: ${e.toString()}';
      });
    }
  }

  // -----------------------------------------------------------------
  String _formatDate(String? timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      return DateFormat('dd MMM yyyy, hh:mm a')
          .format(DateTime.parse(timestamp).toLocal());
    } catch (_) {
      return 'N/A';
    }
  }
String _prettyPrintJson(dynamic value) {
  try {
    dynamic parsed = value;

    if (value is String) parsed = jsonDecode(value);

    if (parsed is Map) {
      return parsed.entries.map((e) {
        return "${_humanizeKey(e.key.toString())}: ${_humanizeValue(e.value)}";
      }).join("\n");
    }

    if (parsed is List) {
      return parsed.asMap().entries.map((e) {
        return "• ${_humanizeValue(e.value)}";
      }).join("\n");
    }

    return parsed.toString();
  } catch (_) {
    return value.toString();
  }
}

String _humanizeKey(String key) {
  // Convert snake_case, camelCase → Title Case
  key = key.replaceAll('_', ' ');
  key = key.replaceAllMapped(RegExp(r'[A-Z]'), (m) => " ${m.group(0)}");
  return key.trim()[0].toUpperCase() + key.trim().substring(1);
}

String _humanizeValue(dynamic value) {
  if (value == null) return "N/A";
  if (value is Map || value is List) return jsonEncode(value);
  return value.toString();
}





  // -----------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
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
                _buildHeader(context),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: Colors.white))
                      : _errorMessage != null
                          ? Center(child: _error(_errorMessage!))
                          : _content(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios,
                color: Colors.white, size: 20),
            onPressed: () => context.push('/tasks'),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 12),
          const Text(
            'Task Detail',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _error(String msg) => Text(
        msg,
        style: const TextStyle(color: Colors.white70, fontSize: 14),
        textAlign: TextAlign.center,
      );

  // -----------------------------------------------------------------
  Widget _content() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title (query)
          Text(
            _taskQuery,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          // Main status / created-at cards
          _buildSectionCard(
            title: 'Status',
            child: Text(_mainStatus ?? 'N/A',
                style: const TextStyle(color: Colors.white70)),
          ),
          const SizedBox(height: 12),
          _buildSectionCard(
            title: 'Created At',
            child: Text(_formatDate(_mainCreatedAt),
                style: const TextStyle(color: Colors.white70)),
          ),
          const SizedBox(height: 24),

          // Sub-tasks header
          Text(
            'Subtasks',
            style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 18,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),

          // Sub-tasks list
          ..._subtasks.asMap().entries.map((entry) {
            final idx = entry.key + 1;
            final sub = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildSubtaskCard(idx, sub),
            );
          }),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------
  Widget _buildSectionCard(
      {required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _sectionTitleStyle()),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  // -----------------------------------------------------------------
  Widget _buildSubtaskCard(int index, Map<String, dynamic> subtask) {
    final createdAt = subtask['created_at']?.toString();
    final status = (subtask['status']?.toString() ?? 'pending').toLowerCase();

    final payload = (subtask['user_payload'] ?? {}) as Map<String, dynamic>;
    final rawPayloadData = payload['data'];
    final responseData = subtask['response']?['data'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _subtaskHeader(index, payload['query'], status),
          const SizedBox(height: 12),
          Text(_formatDate(createdAt),
              style: TextStyle(
                  color: Colors.white.withOpacity(0.5), fontSize: 12)),
          const SizedBox(height: 16),

          // ---------- User Payload ----------
          Text('User Payload (data)', style: _jsonHeader()),
          const SizedBox(height: 8),
          _jsonBox(_prettyPrintJson(rawPayloadData)),
          const SizedBox(height: 16),

          // ---------- Response (if present) ----------
          if (responseData != null) ...[
            Text('Response (data)', style: _jsonHeader()),
            const SizedBox(height: 8),
            _jsonBox(_prettyPrintJson(responseData)),
          ],
        ],
      ),
    );
  }

  // -----------------------------------------------------------------
  Widget _subtaskHeader(int index, dynamic query, String status) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: const Color(0xFF2A57E8),
          radius: 16,
          child: Text('$index',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            query?.toString() ?? 'No query',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        _buildStatusBadge(status),
      ],
    );
  }

  // -----------------------------------------------------------------
  Widget _jsonBox(String content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: SelectableText(
        content,
        style: const TextStyle(
          fontFamily: 'Courier',
          fontSize: 11,
          color: Color(0xFF94A3B8),
          height: 1.45,
        ),
      ),
    );
  }

  TextStyle _jsonHeader() => TextStyle(
        color: Colors.white.withOpacity(0.8),
        fontSize: 13,
        fontWeight: FontWeight.w600,
      );

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      );

  TextStyle _sectionTitleStyle() => TextStyle(
        color: Colors.white.withOpacity(0.9),
        fontSize: 15,
        fontWeight: FontWeight.w600,
      );

  // -----------------------------------------------------------------
  Widget _buildStatusBadge(String status) {
    final config = {
      'succeeded': {
        'label': 'Success',
        'color': const Color(0xFF10B981)
      },
      'completed': {
        'label': 'Success',
        'color': const Color(0xFF10B981)
      },
      'pending': {
        'label': 'Pending',
        'color': const Color(0xFFF59E0B)
      },
      'failed': {
        'label': 'Failed',
        'color': const Color(0xFFEF4444)
      },
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
}