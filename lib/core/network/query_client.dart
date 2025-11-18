// lib/core/network/query_client.dart
import 'package:flutter_tanstack_query/flutter_tanstack_query.dart';

final queryClient = QueryClient(
  cache: QueryCache.instance,
  networkPolicy: NetworkPolicy.instance,
);