import 'package:Maya/core/constants/colors.dart';
import 'package:Maya/utils/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:Maya/core/network/api_client.dart';

class TaskDetail {
  final String id;
  final String query;
  final String status;
  final String error;
  final String timestamp;

  TaskDetail({
    required this.id,
    required this.query,
    required this.status,
    required this.error,
    required this.timestamp,
  });

  factory TaskDetail.fromJson(Map<String, dynamic> json) {
    final toolCall = json['current_tool_call'] as Map<String, dynamic>? ?? {};
    final status =
        toolCall['status']?.toString() ?? json['status']?.toString() ?? '';
    final success =
        json['success'] as bool? ?? toolCall['success'] as bool? ?? false;
    final error =
        json['error']?.toString() ?? toolCall['error']?.toString() ?? '';

    String formattedTimestamp = 'No timestamp';
    try {
      final createdAt = DateTime.parse(json['created_at']?.toString() ?? '');
      formattedTimestamp = DateFormat('MMM dd, yyyy HH:mm').format(createdAt);
    } catch (e) {
      // Keep default if parsing fails
    }

    return TaskDetail(
      id: json['id']?.toString() ?? 'Unknown',
      query: json['user_payload']?['task']?.toString() ??
          json['query']?.toString() ??
          'No query',
      status: status.isNotEmpty
          ? status
          : (success
              ? 'complete'
              : (error.isNotEmpty ? 'failed' : 'pending')),
      error: error.isNotEmpty ? error : 'None',
      timestamp: formattedTimestamp,
    );
  }
}

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  _TasksPageState createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  String selectedFilter = 'all';
  List<TaskDetail> tasks = [];
  bool isLoading = true;
  bool isLoadingMore = false;
  String? errorMessage;
  late ApiClient apiClient;
  int currentPage = 1;
  bool hasMore = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final publicDio = Dio();
    final protectedDio = Dio();
    apiClient = ApiClient(publicDio, protectedDio);
    fetchTasks();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String? _mapFilterToStatus(String filter) {
    switch (filter) {
      case 'succeeded':
        return 'succeeded';
      case 'failed':
        return 'failed';
      case 'pending':
        return 'pending';
      case 'approval-pending':
        return 'approval-pending';
      case 'scheduled':
        return 'scheduled';
      case 'all':
      default:
        return null;
    }
  }

  Future<void> fetchTasks({int page = 1}) async {
    if (page == 1) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    } else {
      setState(() {
        isLoadingMore = true;
      });
    }

    try {
      final statusFilter = _mapFilterToStatus(selectedFilter);
      final response = await apiClient.fetchTasks(
        page: page,
        status: statusFilter,
      );

      final data = response['data'];
      if (response['statusCode'] == 200 && data['success'] == true) {
        final List<dynamic> taskList =
            data['data']?['sessions'] as List<dynamic>? ?? [];

        setState(() {
          final newTasks =
              taskList.map((json) => TaskDetail.fromJson(json)).toList();
          if (page == 1) {
            tasks = newTasks;
          } else {
            tasks.addAll(newTasks);
          }
          hasMore = newTasks.isNotEmpty && taskList.length >= 20;
          currentPage = page;
          isLoading = false;
          isLoadingMore = false;
        });
      } else {
        setState(() {
          isLoading = false;
          isLoadingMore = false;
          errorMessage =
              'Failed to load tasks: ${data['message'] ?? 'Unknown error'}';
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        isLoadingMore = false;
        errorMessage = 'Error fetching tasks: $e';
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !isLoadingMore &&
        hasMore) {
      fetchTasks(page: currentPage + 1);
    }
  }

  String _getFilterStatus(String status) {
    final lower = status.toLowerCase();
    if (lower == 'succeeded') return 'succeeded';
    if (lower == 'failed') return 'failed';
    if (lower == 'pending') return 'pending';
    if (lower == 'approval-pending') return 'approval-pending';
    if (lower == 'scheduled') return 'scheduled';
    return 'pending';
  }

  @override
  Widget build(BuildContext context) {
    final filteredTasks = tasks.where((task) {
      if (selectedFilter == 'all') return true;
      return _getFilterStatus(task.status) == selectedFilter;
    }).toList();

    // Background color from the design
    const Color scaffoldBg = Color(0xffF6F8FC);

    return Scaffold(
      backgroundColor: AppColors.bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              const SizedBox(height: 24),

              // Tasks Header
              const Text(
                "Tasks",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.balckClr,
                ),
              ),
              const SizedBox(height: 12),

              // Filter Tabs
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _tabButton("All Tasks", selectedFilter == 'all'),
                    const SizedBox(width: 10),
                    _tabButton("Completed", selectedFilter == 'succeeded'),
                    const SizedBox(width: 10),
                    _tabButton("Pending", selectedFilter == 'pending'),
                    const SizedBox(width: 10),
                    _tabButton("In Progress", selectedFilter == 'approval-pending'),
                    const SizedBox(width: 10),
                    _tabButton("Failed", selectedFilter == 'failed'),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Loading / Error / Empty / List
              isLoading
                  ? ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 5,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (_, __) => const SkeletonItem(),
                    )
                  : errorMessage != null
                      ? Center(
                          child: Text(
                            errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        )
                      : filteredTasks.isEmpty
                          ? const Center(
                              child: Text(
                                "No tasks found",
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : Column(
                              children: [
                                ...filteredTasks.map((task) => Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 14),
                                      child: _buildTaskCard(task),
                                    )),
                                if (isLoadingMore)
                                  const Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: CircularProgressIndicator(),
                                  ),
                              ],
                            ),

              const SizedBox(height: 100), // Bottom padding
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // UI Widgets (exact copy from your design)
  // ──────────────────────────────────────────────


Widget _tabButton(String title, bool active) {
  return GestureDetector(
    onTap: () {
      String newFilter;
      switch (title) {
        case "All Tasks": newFilter = 'all'; break;
        case "Completed": newFilter = 'succeeded'; break;
        case "Pending": newFilter = 'pending'; break;
        case "In Progress": newFilter = 'approval-pending'; break;
        case "Failed": newFilter = 'failed'; break;
        default: newFilter = 'all';
      }
      if (selectedFilter != newFilter) {
        setState(() {
          selectedFilter = newFilter;
          tasks.clear();
          currentPage = 1;
          hasMore = true;
        });
        fetchTasks();
      }
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: active ? AppColors.primary.withOpacity(0.12) : AppColors.whiteClr,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? AppColors.primary : AppColors.borderColor,
          width: active ? 2 : 1,
        ),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          color: active ? AppColors.primary : AppColors.balckClr,
          fontWeight: active ? FontWeight.bold : FontWeight.w500,
        ),
      ),
    ),
  );
}
  Widget _buildTaskCard(TaskDetail task) {
    Color tagColor;
    String statusText;

    switch (task.status.toLowerCase()) {
      case 'succeeded':
        tagColor = Colors.green;
        statusText = "Completed";
        break;
      case 'failed':
        tagColor = Colors.red;
        statusText = "Failed";
        break;
      case 'approval-pending':
        tagColor = Colors.blue;
        statusText = "In Progress";
        break;
      default:
        tagColor = Colors.orange;
        statusText = "Pending";
    }

    return InkWell(
      onTap: () {
        context.go('/tasks/${task.id}', extra: {'query': task.query});
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.whiteClr,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.borderColor),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: Offset(0, 6)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _statusTagWidget(statusText, tagColor),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              task.query.isNotEmpty ? task.query : "No query provided",
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                const Text("Created at", style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(width: 6),
                Text(
                  task.timestamp,
                  style: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tagWidget(String text,
      {Color bg = AppColors.secondary, Color color = AppColors.primary}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _statusTagWidget(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}