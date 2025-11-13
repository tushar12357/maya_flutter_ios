import 'package:Maya/core/network/api_client.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';

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

  final DateTime today = DateTime(2025, 9, 11); // Based on image

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

  Future<void> fetchToDos({int page = 1}) async {
  if (page == 1) {
    setState(() => isLoadingTodos = true);
  } else {
    setState(() => isLoadingMore = true);
  }

  try {
    final response = await GetIt.I<ApiClient>().getToDo(page: page);

    if (response['statusCode'] == 200) {
      final newTodos = List<Map<String, dynamic>>.from(
        response['data']['data'],
      );

      setState(() {
        if (page == 1) {
          todos = newTodos;
        } else {
          todos.addAll(newTodos);
        }

        // ❌ Your API has no pagination meta
        // So disable infinite scroll
        hasMore = false;

        currentPage = page;
      });
    } else {
      _showSnackBar(
        'Failed to fetch todos: ${response['message'] ?? 'Unknown error'}',
      );
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> updateToDo(Map<String, dynamic> todo) async {
    try {
      final currentStatus = (todo['status']?.toString().toLowerCase() ?? '');
      final newStatus = currentStatus == 'completed' ? 'pending' : 'completed';

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
          'Failed to update: ${response['message'] ?? 'Unknown error'}',
        );
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

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEEE, MMMM d, yyyy').format(today);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background
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
            child: isLoadingTodos
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : Column(
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: () => context.push('/other'),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF111827,
                                  ).withOpacity(0.8),
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
                              'Todo List',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const Spacer(),
                            // (Optional) Add Button or Action Icon can go here later
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Todos List
                      Expanded(
                        child: todos.isEmpty
                            ? const Center(
                                child: Text(
                                  'No to-dos available',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                controller: _scrollController,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                itemCount:
                                    todos.length + (isLoadingMore ? 1 : 0),
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  if (index == todos.length) {
                                    return const Center(
                                      child: CircularProgressIndicator(
                                        color: Color(0xFF2A57E8),
                                      ),
                                    );
                                  }

                                  final todo = todos[index];
                                  final String status =
                                      (todo['status']
                                          ?.toString()
                                          .toLowerCase() ??
                                      '');
                                  final bool isCompleted =
                                      status == 'completed';

                                  final Color checkboxColor = isCompleted
                                      ? Colors.white.withOpacity(0.5)
                                      : const Color(0xFF2A57E8);
                                  final Color textColor = isCompleted
                                      ? Colors.white.withOpacity(0.5)
                                      : Colors.white;
                                  final Color descColor = const Color.fromRGBO(
                                    189,
                                    189,
                                    189,
                                    1,
                                  );

                                  return Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF2D4A6F,
                                      ).withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.1),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // Checkbox
                                        GestureDetector(
                                          onTap: () => updateToDo(todo),
                                          child: Container(
                                            width: 20,
                                            height: 20,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: checkboxColor,
                                              ),
                                              color: isCompleted
                                                  ? checkboxColor
                                                  : Colors.transparent,
                                            ),
                                            child: isCompleted
                                                ? const Icon(
                                                    Icons.check,
                                                    color: Colors.white,
                                                    size: 16,
                                                  )
                                                : null,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        // Content
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // Title with strikethrough
                                              Text(
                                                todo['title'] ??
                                                    'Untitled Task',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: textColor,
                                                  decoration: isCompleted
                                                      ? TextDecoration
                                                            .lineThrough
                                                      : TextDecoration.none,
                                                  decorationColor: textColor,
                                                  decorationThickness: 1.5,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              // Description with strikethrough
                                              Text(
                                                todo['description'] ?? '',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: descColor,
                                                  decoration: isCompleted
                                                      ? TextDecoration
                                                            .lineThrough
                                                      : TextDecoration.none,
                                                  decorationColor: descColor,
                                                  decorationThickness: 1.5,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              // Due Date Chip
                                              Row(
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                        0xFF2A57E8,
                                                      ).withOpacity(0.2),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      _formatDueDate(todo),
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: Color.fromARGB(255, 255, 255, 255),
                                                      ),
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // Format CreatedAt as fallback for due date
  String _formatDueDate(Map<String, dynamic> todo) {
    final createdAt = todo['CreatedAt'];
    if (createdAt == null || createdAt is! String) return 'No date';

    try {
      final date = DateTime.parse(createdAt).toLocal();
      return DateFormat('MMM d, yyyy').format(date);
    } catch (e) {
      return 'No date';
    }
  }
}