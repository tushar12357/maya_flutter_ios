import 'package:Maya/core/constants/colors.dart';
import 'package:Maya/core/network/api_client.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';

// ──────────────────────── Your Colors ────────────────────────

// ──────────────────────── TodosPage ────────────────────────
class TodosPage extends StatefulWidget {
  const TodosPage({super.key});

  @override
  _TodosPageState createState() => _TodosPageState();
}

class _TodosPageState extends State<TodosPage> {
  List<Map<String, dynamic>> todos = [];
  bool isLoadingTodos = false;
  bool isLoadingMore = false;
  int currentPage = 1;
  bool hasMore = true;
  final ScrollController _scrollController = ScrollController();

  // Filter state
  int _selectedFilterIndex = 0; // 0-All, 1-Open, 2-Close, 3-Archived

  final DateTime today = DateTime(2025, 9, 11); // as in the design

  @override
  void initState() {
    super.initState();
    fetchToDos();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ────── API & Pagination (unchanged) ──────
  Future<void> fetchToDos({int page = 1}) async {
    if (page == 1) {
      setState(() => isLoadingTodos = true);
    } else {
      setState(() => isLoadingMore = true);
    }
    try {
      final response = await GetIt.I<ApiClient>().getToDo(page: page);
      
if (response['statusCode'] == 200 && response['data']['success'] == true) {
        final newTodos = List<Map<String, dynamic>>.from(
          response['data']['data'],
        );
        setState(() {
          if (page == 1) {
            todos = newTodos;
          } else {
            todos.addAll(newTodos);
          }
          // Your API currently has no pagination meta → disable infinite scroll
          hasMore = false;
          currentPage = page;
        });
      } 
    } catch (e) {
      _showSnackBar('Error fetching todos: $e');
    } finally {
      setState(() {
        isLoadingTodos = false;
        isLoadingMore = false;
      });
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> updateToDo(Map<String, dynamic> todo) async {
    try {
      final currentStatus =
          (todo['status']?.toString().toLowerCase() ?? '');
      final newStatus =
          currentStatus == 'completed' ? 'pending' : 'completed';
      final payload = GetIt.I<ApiClient>().prepareUpdateToDoPayload(
        todo['ID'],
        title: todo['title'],
        description: todo['description'],
        status: newStatus,
        reminder: todo['reminder'] ?? false,
        reminder_time: todo['reminder_time'],
      );
      final response = await GetIt.I<ApiClient>().updateToDo(payload);
      if (response['statusCode'] == 200) {
        await fetchToDos(page: 1);
        _showSnackBar('To-Do updated successfully');
      } else {
        _showSnackBar(
            'Failed to update: ${response['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      _showSnackBar('Error updating To-Do: $e');
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !isLoadingMore &&
        hasMore) {
      fetchToDos(page: currentPage + 1);
    }
  }

  // ────── Filter Button Widget ──────
  Widget _buildFilterButton(String text, int count, int index) {
    final bool isSelected = _selectedFilterIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilterIndex = index;
        });
        // TODO: filter logic when you have status field
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.secondary.withOpacity(0.2)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.secondary.withOpacity(0.2)
                : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: TextStyle(
                color: isSelected ? AppColors.secondary : Colors.black,
                fontWeight: FontWeight.w500,
                fontSize: 10,
              ),
            ),
            const SizedBox(width: 3),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.3)
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString().padLeft(2, '0'),
                style: TextStyle(
                  color: isSelected ? AppColors.secondary : Colors.black,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEEE, d MMM yyyy').format(today);

    return Scaffold(
      backgroundColor: Colors.grey[100],
   appBar: AppBar(
  backgroundColor: Colors.white,
  elevation: 0,
  leading: IconButton(
    icon: const Icon(Icons.arrow_back, color: Colors.black),
    onPressed: () => context.go('/other'),
  ),
  // ← Add this line
  titleSpacing: 0, // removes default extra spacing

  title: Align(
    alignment: Alignment.centerLeft, // ← forces left alignment
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'To-Do',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        Text(
          'Manage personal To-Do\'s',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    ),
  ),
),   body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Today's Task Header + New Task button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Todo List",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color.fromRGBO(0, 0, 0, 0.867),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateStr,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
         
            // Loading or List
            Expanded(
              child: isLoadingTodos
                  ? const Center(child: CircularProgressIndicator())
                  : todos.isEmpty
                      ? const Center(
                          child: Text(
                            'No to-dos available',
                            style: TextStyle(fontSize: 16),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          itemCount:
                              todos.length + (isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == todos.length) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }
                            final todo = todos[index];
                            final String status = (todo['status']
                                    ?.toString()
                                    .toLowerCase() ??
                                '');
                            final bool isCompleted = status == 'completed';

                            // Fake progress for demo – replace with real data later
                            final double progress = isCompleted
                                ? 1.0
                                : (index % 4 == 0
                                    ? 0.0
                                    : index % 4 == 1
                                        ? 0.75
                                        : 0.20);

                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 5),
                              child: TaskCard(
                                title: todo['title'] ?? 'Untitled Task',
                                subtitle:
                                    todo['description'] ?? 'No description',
                                date: _formatDueDate(todo),
                                progress: progress,
                                isCompleted: isCompleted,
                                onToggle: () => updateToDo(todo),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDueDate(Map<String, dynamic> todo) {
    final createdAt = todo['CreatedAt'];
    if (createdAt == null || createdAt is! String) return 'No date';
    try {
      final date = DateTime.parse(createdAt).toLocal();
      return DateFormat('d MMM yyyy').format(date);
    } catch (e) {
      return 'No date';
    }
  }
}

// ──────────────────────── TaskCard Widget (exact design) ────────────────────────
class TaskCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String date;
  final double progress;
  final bool isCompleted;
  final VoidCallback onToggle;

  const TaskCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.date,
    this.progress = 0,
    required this.isCompleted,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Icon container
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.people, color: Colors.grey[700]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          decoration:
                              isCompleted ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          decoration:
                              isCompleted ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ],
                  ),
                ),
                // Checkbox
                GestureDetector(
                  onTap: onToggle,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCompleted
                          ? AppColors.primary
                          : Colors.transparent,
                      border: Border.all(
                        color: isCompleted
                            ? AppColors.primary
                            : Colors.grey,
                        width: 2,
                      ),
                    ),
                    child: isCompleted
                        ? const Icon(Icons.check,
                            color: Colors.white, size: 16)
                        : null,
                  ),
                ),
              ],
            ),
            const Divider(color: Color(0xffB2B2B2)),

            // Progress bar (only when progress > 0)
            // if (progress > 0) ...[
            //   const SizedBox(height: 16),
            //   LinearProgressIndicator(
            //     value: progress,
            //     backgroundColor: Colors.grey[200],
            //     valueColor: AlwaysStoppedAnimation<Color>(
            //       progress < 0.5 ? AppColors.redColor : AppColors.primary,
            //     ),
            //     minHeight: 6,
            //     borderRadius: BorderRadius.circular(10),
            //   ),
            //   const SizedBox(height: 8),
            //   Align(
            //     alignment: Alignment.bottomRight,
            //     child: Text(
            //       '${(progress * 100).toInt()}%',
            //       style: TextStyle(
            //         fontSize: 12,
            //         color:
            //             progress < 0.5 ? AppColors.redColor : AppColors.primary,
            //         fontWeight: FontWeight.bold,
            //       ),
            //     ),
            //   ),
            // ],

            // Date row
            Row(
              children: [
                Icon(Icons.access_time,
                    color: Colors.grey[500], size: 16),
                const SizedBox(width: 8),
                Text(
                  date,
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}