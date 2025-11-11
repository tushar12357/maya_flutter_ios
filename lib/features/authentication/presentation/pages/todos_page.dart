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
  List<Map<String, dynamic>> filteredTodos = [];
  bool isLoadingTodos = false;
  bool isLoadingMore = false;
  int currentPage = 1;
  bool hasMore = true;
  final ScrollController _scrollController = ScrollController();
  String selectedFilter = 'all';

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
        final newTodos = List<Map<String, dynamic>>.from(response['data']['data']);
        setState(() {
          if (page == 1) {
            todos = newTodos;
          } else {
            todos.addAll(newTodos);
          }
          hasMore = newTodos.isNotEmpty;
          currentPage = page;
          _filterTodos();
        });
      } else {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('Failed to fetch todos: ${response['message'] ?? 'Unknown error'}')),
        // );
      }
    } catch (e) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Error fetching todos: $e')),
      // );
    } finally {
      setState(() {
        isLoadingTodos = false;
        isLoadingMore = false;
      });
    }
  }

  void _filterTodos() {
    List<Map<String, dynamic>> filtered = todos;
    if (selectedFilter == 'open') {
      filtered = todos.where((t) => t['status'] == 'pending').toList();
    } else if (selectedFilter == 'close') {
      filtered = todos.where((t) => t['status'] == 'completed').toList();
    } else if (selectedFilter == 'archived') {
      filtered = todos.where((t) => t['status'] == 'archived').toList();
    }
    // Filter for today's date if needed, but image shows all
    setState(() {
      filteredTodos = filtered;
    });
  }

  Future<void> updateToDo(Map<String, dynamic> todo) async {
    try {
      final payload = GetIt.I<ApiClient>().prepareUpdateToDoPayload(
        todo['ID'],
        title: todo['title'],
        description: todo['description'],
        status: todo['status'] == 'completed' ? 'pending' : 'completed',
        reminder: todo['reminder'] ?? false,
        reminder_time: todo['reminder_time'],
      );
      final response = await GetIt.I<ApiClient>().updateToDo(payload);
      if (response['statusCode'] == 200) {
        await fetchToDos(page: 1);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('To-Do updated successfully')),
        );
      } else {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('Failed to update To-Do: ${response['message'] ?? 'Unknown error'}')),
        // );
      }
    } catch (e) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Error updating To-Do: $e')),
      // );
    }
  }

  void _onFilterChanged(String filter) {
    setState(() {
      selectedFilter = filter;
    });
    _filterTodos();
  }

  void _onNewTask() {
    // Navigate to add task
    context.go('/add-task');
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
    final totalCount = todos.length;
    final openCount = todos.where((t) => t['status'] == 'pending').length;
    final closeCount = todos.where((t) => t['status'] == 'completed').length;
    final archivedCount = todos.where((t) => t['status'] == 'archived').length;

    final dateStr = DateFormat('EEEE, MMMM d, yyyy').format(today);

    return Scaffold(
      backgroundColor: Colors.transparent,
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
            child: isLoadingTodos
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : Column(
                    children: [
                      // Custom Header with Back Button
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
                              'To-Do',
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
                      // Subtitle
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: const Text(
                          'Manage personal To-Dos',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color.fromRGBO(189, 189, 189, 1),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Today's tasks header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Today's Task",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  dateStr,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color.fromRGBO(189, 189, 189, 1),
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Filter chips
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            _buildFilterChip('all', totalCount, selectedFilter == 'all'),
                            const SizedBox(width: 8),
                            _buildFilterChip('open', openCount, selectedFilter == 'open'),
                            const SizedBox(width: 8),
                            _buildFilterChip('close', closeCount, selectedFilter == 'close'),
                            const SizedBox(width: 8),
                            _buildFilterChip('archived', archivedCount, selectedFilter == 'archived'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Todos List
                      Expanded(
                        child: filteredTodos.isEmpty
                            ? const Center(
                                child: Text(
                                  'No to-dos available',
                                  style: TextStyle(fontSize: 16, color: Colors.white),
                                ),
                              )
                            : ListView.separated(
                                controller: _scrollController,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: filteredTodos.length + (isLoadingMore ? 1 : 0),
                                separatorBuilder: (context, index) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  if (index == filteredTodos.length) {
                                    return const Center(child: CircularProgressIndicator(color: Color(0xFF2A57E8)));
                                  }
                                  final todo = filteredTodos[index];
                                  final isCompleted = todo['status'] == 'completed';
                                  final checkboxColor = isCompleted ? Colors.white.withOpacity(0.5) : const Color(0xFF2A57E8);
                                  final textColor = isCompleted ? Colors.white.withOpacity(0.5) : Colors.white;

                                  return Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2D4A6F).withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white.withOpacity(0.1)),
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
                                              border: Border.all(color: checkboxColor),
                                              color: isCompleted ? checkboxColor : Colors.transparent,
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
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                todo['title'] ?? 'Untitled Task',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: textColor,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                todo['description'] ?? '',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Color.fromRGBO(189, 189, 189, 1),
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF2A57E8).withOpacity(0.2),
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Text(
                                                      'Today, 20 Sep 2025', // From image, dynamic based on todo['due_date']
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: const Color(0xFF2A57E8),
                                                      ),
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  // Icons
                                                  
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

  Widget _buildFilterChip(String filter, int count, bool isSelected) {
    return GestureDetector(
      onTap: () => _onFilterChanged(filter),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2A57E8).withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF2A57E8) : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              filter.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? const Color(0xFF2A57E8) : Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '($count)',
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? const Color(0xFF2A57E8) : Colors.white.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}