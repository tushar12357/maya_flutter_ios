import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
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

class _TaskDetailPageState extends State<TaskDetailPage>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? task;
  List<Map<String, dynamic>> subtasks = [];
  bool isLoading = true;
  String? errorMessage;

  late TabController _tabController;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
    ); // Only 3 tabs for bottom section
    _tabController.addListener(() {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    });
    fetchTaskDetail();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
      final data = response['data']['data'];
      if (response['statusCode'] == 200 &&
          (response['data']['success'] as bool? ?? false)) {
        if (data == null || (data is List && data.isEmpty)) {
          setState(() {
            isLoading = false;
            errorMessage =
                'No task details found for session ${widget.sessionId}';
          });
        } else {
          setState(() {
            task = (data is List ? data.first : data) as Map<String, dynamic>;
            subtasks =
                (task?['subtasks'] as List<dynamic>?)
                    ?.cast<Map<String, dynamic>>() ??
                [];
            isLoading = false;
          });
        }
      } else {
        setState(() {
          isLoading = false;
          errorMessage =
              'Failed to load task details: ${response['message']?.toString() ?? 'Unknown error'}';
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Error fetching task details: ${e.toString()}';
      });
    }
  }

  Widget getStatusBadge(String status) {
    final statusConfig = {
      'succeeded': {
        'label': 'Completed',
        'icon': Icons.check_circle,
        'color': const Color(0xFF10B981),
      },
      'completed': {
        'label': 'Completed',
        'icon': Icons.check_circle,
        'color': const Color(0xFF10B981),
      },
      'pending': {
        'label': 'In Progress',
        'icon': Icons.access_time,
        'color': const Color(0xFFF59E0B),
      },
      'failed': {
        'label': 'Failed',
        'icon': Icons.error_outline,
        'color': const Color(0xFFEF4444),
      },
      'approval_pending': {
        'label': 'Approval Pending',
        'icon': Icons.warning_amber,
        'color': const Color(0xFF3B82F6),
      },
    };

    final config =
        statusConfig[status.toLowerCase()] ?? statusConfig['pending']!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: (config['color'] as Color).withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            config['icon'] as IconData,
            size: 12,
            color: config['color'] as Color,
          ),
          const SizedBox(width: 4),
          Text(
            config['label'] as String,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: config['color'] as Color,
            ),
          ),
        ],
      ),
    );
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
                // Custom AppBar
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios,
                          color: Colors.white,
                          size: 20,
                        ),
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
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Text(
                              errorMessage!,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Task Header Info
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    
                                    const SizedBox(height: 12),
                                    Text(
                                      taskQuery,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    if (task != null) ...[
                                      _buildInfoRow(
                                        icon: Icons.person_outline,
                                        label: 'Meeting with Client',
                                        value:
                                            task?['client_name']?.toString() ??
                                            'Unknown Client',
                                      ),
                                      const SizedBox(height: 10),
                                      _buildInfoRow(
                                        icon: Icons.calendar_today,
                                        label: 'Due Date',
                                        value: _formatDate(task?['created_at']),
                                      ),
                                      const SizedBox(height: 10),
                                      _buildInfoRow(
                                        icon: Icons.access_time,
                                        label: 'Time',
                                        value: _formatTime(task?['created_at']),
                                      ),
                                      const SizedBox(height: 10),
                                      _buildInfoRow(
                                        icon: Icons.event_note,
                                        label: 'Task Status',
                                        badge: getStatusBadge(
                                          task?['status']?.toString() ??
                                              'pending',
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              const SizedBox(height: 8),
                              Divider(
                                color: Colors.white.withOpacity(0.1),
                                height: 1,
                              ),
                              const SizedBox(height: 20),

                              // Description Section
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Description',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      task?['description']?.toString() ??
                                          task?['user_payload']?['query']
                                              ?.toString() ??
                                          'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.6),
                                        fontSize: 13,
                                        height: 1.6,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Sub Task Section
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Sub Task',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    ...subtasks.asMap().entries.map((entry) {
                                      return _buildSubtaskCheckbox(
                                        entry.value,
                                        entry.key,
                                      );
                                    }).toList(),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Attachment Section
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Attachment',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    ..._getAttachments().map((attachment) {
                                      return _buildAttachmentItem(attachment);
                                    }).toList(),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 24),
                              Divider(
                                color: Colors.white.withOpacity(0.1),
                                height: 1,
                              ),
                              const SizedBox(height: 8),

                              // Bottom Tabs for JSON/Payload/Response
                              Container(
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Colors.white.withOpacity(0.1),
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: TabBar(
                                  controller: _tabController,
                                  indicatorColor: const Color(0xFF2A57E8),
                                  indicatorWeight: 3,
                                  labelColor: Colors.white,
                                  unselectedLabelColor: Colors.white
                                      .withOpacity(0.5),
                                  labelStyle: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  unselectedLabelStyle: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  tabs: const [
                                    Tab(text: 'Request Payload'),
                                    Tab(text: 'Response Data'),
                                    Tab(text: 'Full JSON'),
                                  ],
                                ),
                              ),

                              // Tab Content
                              SizedBox(
                                height: 400,
                                child: TabBarView(
                                  controller: _tabController,
                                  children: [
                                    _buildRequestPayloadTab(),
                                    _buildResponseDataTab(),
                                    _buildForJsonTab(),
                                  ],
                                ),
                              ),

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

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    String? value,
    Widget? badge,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white.withOpacity(0.6)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        if (badge != null)
          badge
        else if (value != null)
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
      ],
    );
  }

  Widget _buildSubtaskCheckbox(Map<String, dynamic> subtask, int index) {
    final status = subtask['status']?.toString().toLowerCase() ?? 'pending';
    final isCompleted = status == 'completed' || status == 'succeeded';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: isCompleted ? const Color(0xFF10B981) : Colors.transparent,
              border: Border.all(
                color: isCompleted
                    ? const Color(0xFF10B981)
                    : Colors.white.withOpacity(0.3),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: isCompleted
                ? const Icon(Icons.check, size: 12, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              subtask['user_payload']?['query']?.toString() ??
                  subtask['name']?.toString() ??
                  'Unnamed Subtask',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 13,
                height: 1.5,
                decoration: isCompleted ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getAttachments() {
    List<Map<String, dynamic>> attachments = [];

    // Check main task for attachments
    if (task?['attachments'] != null) {
      attachments.addAll(
        (task!['attachments'] as List).cast<Map<String, dynamic>>(),
      );
    }

    // Check subtasks for attachments or audio files
    for (var subtask in subtasks) {
      if (subtask['response'] != null) {
        final response = subtask['response'];
        if (response is Map<String, dynamic>) {
          // Check for direct s3_url
          if (response['s3_url'] != null &&
              response['s3_url'].toString().isNotEmpty) {
            final url = response['s3_url'].toString();
            String fileName = url.split('/').last;
            String fileType = fileName.split('.').last.toUpperCase();

            attachments.add({
              'name': fileName,
              'url': url,
              'type': fileType,
              'size': response['size']?.toString() ?? '2.3 MB',
              'created_at': subtask['created_at'],
            });
          }
          // Check nested data
          if (response['data'] is String) {
            try {
              final inner =
                  jsonDecode(response['data']) as Map<String, dynamic>;
              if (inner['s3_url'] != null &&
                  inner['s3_url'].toString().isNotEmpty) {
                final url = inner['s3_url'].toString();
                String fileName = url.split('/').last;
                String fileType = fileName.split('.').last.toUpperCase();

                attachments.add({
                  'name': fileName,
                  'url': url,
                  'type': fileType,
                  'size': inner['size']?.toString() ?? '2.3 MB',
                  'created_at': subtask['created_at'],
                });
              }
            } catch (_) {}
          }
        }
      }
    }

    return attachments;
  }

  Widget _buildAttachmentItem(Map<String, dynamic> attachment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF2A57E8).withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                attachment['type']?.toString().toUpperCase() ?? 'FILE',
                style: const TextStyle(
                  color: Color(0xFF2A57E8),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment['name']?.toString() ?? 'Attachment',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  attachment['size']?.toString() ?? '2.3 MB',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white70, size: 20),
            onPressed: () {
              // Handle download
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  // Bottom Tab Contents
  Widget _buildRequestPayloadTab() {
    if (task?['user_payload'] == null) {
      return _buildEmptyState('No request payload available');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: JsonDisplay(data: task!['user_payload'], label: ''),
    );
  }

  Widget _buildResponseDataTab() {
    if (task?['response'] == null &&
        (task?['subtasks'] == null || (task!['subtasks'] as List).isEmpty)) {
      return _buildEmptyState('No response data available');
    }

    // Try to get response from task or first completed subtask
    dynamic responseData = task?['response'];

    if (responseData == null && subtasks.isNotEmpty) {
      for (var subtask in subtasks) {
        if (subtask['response'] != null) {
          responseData = subtask['response'];
          break;
        }
      }
    }

    if (responseData == null) {
      return _buildEmptyState('No response data available');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: _buildResponseWidget(responseData),
    );
  }

  Widget _buildForJsonTab() {
    if (task == null) return _buildEmptyState('No JSON data available');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: JsonDisplay(data: task, label: ''),
    );
  }

  Widget _buildCollapsibleSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.white.withOpacity(0.5)),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ],
        ),
        child,
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 48,
              color: Colors.white.withOpacity(0.2),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(String? timestamp) {
    try {
      if (timestamp == null || timestamp.isEmpty) return 'N/A';
      final dateTime = DateTime.parse(timestamp).toLocal();
      return DateFormat('MMM d, yyyy h:mm a').format(dateTime);
    } catch (e) {
      return timestamp ?? 'N/A';
    }
  }

  String _formatDate(String? timestamp) {
    try {
      if (timestamp == null || timestamp.isEmpty) return 'N/A';
      final dateTime = DateTime.parse(timestamp).toLocal();
      return DateFormat('EEEE, dd MMM yyyy').format(dateTime);
    } catch (e) {
      return timestamp ?? 'N/A';
    }
  }

  String _formatTime(String? timestamp) {
    try {
      if (timestamp == null || timestamp.isEmpty) return 'N/A';
      final dateTime = DateTime.parse(timestamp).toLocal();
      return DateFormat('hh:mm a').format(dateTime);
    } catch (e) {
      return timestamp ?? 'N/A';
    }
  }

  Widget _buildResponseWidget(dynamic response) {
    if (response == null) return const SizedBox.shrink();

    if (response is Map<String, dynamic> &&
        response.containsKey('s3_url') &&
        response['s3_url'] is String &&
        (response['s3_url'] as String).endsWith('.mp3')) {
      return _audioColumn(response['s3_url'] as String);
    }

    Map<String, dynamic>? inner;
    if (response is Map<String, dynamic> &&
        response.containsKey('data') &&
        response['data'] is String) {
      try {
        inner = jsonDecode(response['data']) as Map<String, dynamic>;

        if (inner.containsKey('s3_url') &&
            inner['s3_url'] is String &&
            (inner['s3_url'] as String).endsWith('.mp3')) {
          return _audioColumn(inner['s3_url'] as String);
        }
      } catch (_) {}
    }

    return _fullResponseDisplay(
      outer: response as Map<String, dynamic>,
      inner: inner,
    );
  }

  Widget _audioColumn(String url) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'AUDIO',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.white.withOpacity(0.5),
          letterSpacing: 0.5,
        ),
      ),
      const SizedBox(height: 8),
      AudioPlayerWidget(url: url),
    ],
  );

  Widget _fullResponseDisplay({
    required Map<String, dynamic> outer,
    required Map<String, dynamic>? inner,
  }) {
    final outerCopy = Map<String, dynamic>.from(outer);

    if (inner != null) outerCopy.remove('data');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (outerCopy.isNotEmpty) ...[
          Text(
            'RESPONSE META',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.5),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          JsonDisplay(data: outerCopy, label: ''),
        ],

        if (inner != null) ...[
          const SizedBox(height: 12),
          Text(
            'RESPONSE PAYLOAD',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.5),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          JsonDisplay(data: inner, label: ''),
        ],

        if (inner == null && outer.containsKey('data')) ...[
          Text(
            'RAW DATA',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.5),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          JsonDisplay(data: outer['data'], label: ''),
        ],
      ],
    );
  }
}

class JsonDisplay extends StatelessWidget {
  final dynamic data;
  final String label;

  const JsonDisplay({super.key, required this.data, required this.label});

  @override
  Widget build(BuildContext context) {
    if (data == null) return const SizedBox.shrink();

    dynamic displayData = data;
    if (data is String) {
      try {
        displayData = jsonDecode(data);
      } catch (e) {
        // If decoding fails, use the raw string
      }
    }

    String formattedData;
    try {
      formattedData = const JsonEncoder.withIndent('  ').convert(displayData);
    } catch (e) {
      formattedData = displayData.toString();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: SelectableText(
        formattedData,
        style: TextStyle(
          fontSize: 10,
          color: Colors.white.withOpacity(0.6),
          fontFamily: 'Courier',
          height: 1.5,
        ),
      ),
    );
  }
}

class AudioPlayerWidget extends StatefulWidget {
  final String url;

  const AudioPlayerWidget({super.key, required this.url});

  @override
  _AudioPlayerWidgetState createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  late AudioPlayer _audioPlayer;
  bool isPlaying = false;
  Duration duration = Duration.zero;
  Duration position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          isPlaying = state == PlayerState.playing;
        });
      }
    });

    _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) {
        setState(() {
          duration = newDuration;
        });
      }
    });

    _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) {
        setState(() {
          position = newPosition;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                  icon: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: const Color(0xFF2A57E8),
                    size: 18,
                  ),
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
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 5,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 10,
                        ),
                        activeTrackColor: const Color(0xFF2A57E8),
                        inactiveTrackColor: Colors.white.withOpacity(0.1),
                        thumbColor: const Color(0xFF2A57E8),
                      ),
                      child: Slider(
                        min: 0,
                        max: duration.inSeconds.toDouble(),
                        value: position.inSeconds.toDouble(),
                        onChanged: (value) async {
                          final position = Duration(seconds: value.toInt());
                          await _audioPlayer.seek(position);
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(position),
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.white.withOpacity(0.4),
                            ),
                          ),
                          Text(
                            _formatDuration(duration),
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.white.withOpacity(0.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
