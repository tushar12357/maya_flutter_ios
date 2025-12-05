import 'package:Maya/core/network/api_client.dart';
import 'package:Maya/features/authentication/presentation/pages/tasks_page.dart';

class TasksRepository {
  List<TaskDetail> cachedTasks = [];
  bool hasLoaded = false;

  Future<List<TaskDetail>> preloadTasks(ApiClient apiClient) async {
    if (hasLoaded) return cachedTasks;

    final response = await apiClient.fetchTasks(page: 1);
    final data = response["data"]["data"]["sessions"] as List<dynamic>;
    cachedTasks = data.map((json) => TaskDetail.fromJson(json)).toList();

    hasLoaded = true;
    return cachedTasks;
  }
}
