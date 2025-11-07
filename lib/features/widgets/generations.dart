import 'package:flutter/material.dart';
import 'package:Maya/core/network/api_client.dart';

class Generations extends StatefulWidget {
  const Generations({super.key});

  @override
  State<Generations> createState() => _GenerationsState();
}

class _GenerationsState extends State<Generations> {
  List<Map<String, dynamic>> generations = [];
  bool isLoading = false;
  bool isCreating = false;
  final TextEditingController _typeController = TextEditingController();
  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _createdByController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchGenerations();
  }

  Future<void> fetchGenerations() async {
    setState(() => isLoading = true);
    try {
      // Since we don't have a list endpoint, we'll fetch a sample generation
      // In a real app, you might want to add a list endpoint or modify this
      final response = await getIt<ApiClient>().getGeneration('2a443278-fab0-4e51-9e6f-f8160b03683e');
      if (response['statusCode'] == 200) {
        setState(() {
          generations = [response['data']];
        });
      }
    } catch (e) {
      // ScaffoldMessenger.of(
      //   context,
      // ).showSnackBar(SnackBar(content: Text('Error fetching generations: $e')));
    }
    setState(() => isLoading = false);
  }

  Future<void> createGeneration() async {
    setState(() => isCreating = true);
    try {
      final payload = getIt<ApiClient>().prepareCreateGenerationPayload(
        _typeController.text,
        {'content': _inputController.text},
        _createdByController.text,
      );
      final response = await getIt<ApiClient>().createGeneration(payload);
      if (response['statusCode'] == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Generation created successfully')),
        );
        _typeController.clear();
        _inputController.clear();
        _createdByController.clear();
        fetchGenerations();
      } else {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text('Failed to create generation: ${response['data']}'),
        //   ),
        // );
      }
    } catch (e) {
      // ScaffoldMessenger.of(
      //   context,
      // ).showSnackBar(SnackBar(content: Text('Error creating generation: $e')));
    }
    setState(() => isCreating = false);
  }

  Future<void> approveGeneration(String id) async {
    try {
      final response = await getIt<ApiClient>().approveGeneration(id);
      if (response['statusCode'] == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Generation approved successfully')),
        );
        fetchGenerations();
      } else {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text('Failed to approve generation: ${response['data']}'),
        //   ),
        // );
      }
    } catch (e) {
      // ScaffoldMessenger.of(
      //   context,
      // ).showSnackBar(SnackBar(content: Text('Error approving generation: $e')));
    }
  }

  Future<void> regenerateGeneration(String id) async {
    try {
      final response = await getIt<ApiClient>().regenerateGeneration(id);
      if (response['statusCode'] == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Generation regenerated successfully')),
        );
        fetchGenerations();
      } else {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text(
        //       'Failed to regenerate generation: ${response['data']}',
        //     ),
        //   ),
        // );
      }
    } catch (e) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Error regenerating generation: $e')),
      // );
    }
  }

  void _showCreateGenerationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Generation'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _typeController,
                decoration: const InputDecoration(labelText: 'Type'),
              ),
              TextField(
                controller: _inputController,
                decoration: const InputDecoration(labelText: 'Input Content'),
              ),
              TextField(
                controller: _createdByController,
                decoration: const InputDecoration(labelText: 'Created By'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: isCreating
                ? null
                : () {
                    Navigator.of(context).pop();
                    createGeneration();
                  },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Generations',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: _showCreateGenerationDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Generation'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            generations.isEmpty
                ? const Text('No generations available')
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: generations.length,
                    itemBuilder: (context, index) {
                      final generation = generations[index];
                      return ListTile(
                        title: Text(generation['type'] ?? 'Untitled'),
                        subtitle: Text(generation['input']?['content'] ?? ''),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check_circle_outline),
                              onPressed: () =>
                                  approveGeneration(generation['id'] ?? ''),
                              tooltip: 'Approve',
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh),
                              onPressed: () =>
                                  regenerateGeneration(generation['id'] ?? ''),
                              tooltip: 'Regenerate',
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _typeController.dispose();
    _inputController.dispose();
    _createdByController.dispose();
    super.dispose();
  }
}
