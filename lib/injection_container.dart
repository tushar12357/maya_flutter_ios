import 'package:Maya/features/authentication/domain/repositories/tasks_repository.dart';
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'core/network/api_client.dart';
import 'core/network/network_info.dart';
import 'core/services/auth_service.dart';
import 'core/services/navigation_service.dart';
import 'core/services/token_service.dart';
import 'core/services/storage_service.dart';
import 'features/authentication/data/datasources/auth_remote_datasource.dart';
import 'features/authentication/data/datasources/auth_local_datasource.dart';
import 'features/authentication/data/repositories/auth_repository_impl.dart';
import 'features/authentication/domain/repositories/auth_repository.dart';
import 'features/authentication/domain/usecases/login_usecase.dart';
import 'features/authentication/domain/usecases/logout_usecase.dart';
import 'features/authentication/domain/usecases/check_auth_usecase.dart';
import 'features/authentication/presentation/bloc/auth_bloc.dart';
import 'core/services/deep_link_service.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // External
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPreferences);
  sl.registerLazySingleton(() => const FlutterSecureStorage());
  sl.registerLazySingleton(() => Dio(), instanceName: 'publicDio');
  sl.registerLazySingleton(() => Dio(), instanceName: 'protectedDio');
  sl.registerLazySingleton(() => Connectivity());

  // Core
  sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl(sl()));
  sl.registerLazySingleton<ApiClient>(
    () => ApiClient(
      sl(instanceName: 'publicDio'),
      sl(instanceName: 'protectedDio'),
    ),
  );
  sl.registerLazySingleton<TasksRepository>(() => TasksRepository());
  sl.registerLazySingleton<StorageService>(
    () => StorageServiceImpl(sl(), sl()),
  );
  sl.registerLazySingleton<TokenService>(() => TokenService(sl()));
  sl.registerLazySingleton<AuthService>(() => AuthService());
  sl.registerLazySingleton<DeepLinkService>(() => DeepLinkService());
  sl.registerLazySingleton<NavigationService>(() => NavigationService());

  // Authentication Feature
  _initAuth();
}

void _initAuth() {
  // CRITICAL FIX: Change to registerLazySingleton for single AuthBloc instance
  sl.registerLazySingleton(
    // Changed from registerFactory to registerLazySingleton
    () => AuthBloc(
      loginUseCase: sl(),
      logoutUseCase: sl(),
      checkAuthUseCase: sl(),
      authService: sl(),
    ),
  );

  // Use cases
  sl.registerLazySingleton(() => LoginUseCase(sl()));
  sl.registerLazySingleton(() => LogoutUseCase(sl()));
  sl.registerLazySingleton(() => CheckAuthUseCase(sl()));

  // Repository
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
      networkInfo: sl(),
    ),
  );

  // Data sources
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(sl(), sl()),
  );
  sl.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSourceImpl(sl()),
  );
}
