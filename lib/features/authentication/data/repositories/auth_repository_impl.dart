import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;
  final NetworkInfo networkInfo;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, User>> login({
    required String email,
    required String password,
  }) async {
    if (await networkInfo.isConnected) {
      try {

        // Call remote API for authentication
        final loginResponse = await remoteDataSource.login(
          email: email,
          password: password,
        );

        // Cache user data and tokens locally for offline access
        await localDataSource.cacheUser(loginResponse.user);
        await localDataSource.cacheTokens(
          accessToken: loginResponse.accessToken,
          refreshToken: loginResponse.refreshToken,
          sessionId: loginResponse.sessionId,
        );
        print('🔐 Repository: Login successful, user and tokens cached');
        return Right(loginResponse.user);
      } on ServerException catch (e) {
        print('❌ Repository: Server error during login - ${e.message}');
        return Left(ServerFailure(e.message));
      } on CacheException catch (e) {
        print('⚠️ Repository: Cache error during login - ${e.message}');
        // Login succeeded but caching failed - still return success
        // but log the issue for monitoring
        return Left(CacheFailure(e.message));
      } catch (e) {
        print('❌ Repository: Unexpected error during login - ${e.toString()}');
        return Left(ServerFailure('Login failed: ${e.toString()}'));
      }
    } else {
      print('❌ Repository: No internet connection available');
      return Left(
        NetworkFailure(
          'No internet connection. Please check your network and try again.',
        ),
      );
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      print('🚪 Repository: Starting logout process');

      // Try to notify server about logout (don't fail if this fails)
      if (await networkInfo.isConnected) {
        try {
          await remoteDataSource.logout();
          print('✅ Repository: Server logout successful');
        } catch (e) {
          print(
            '⚠️ Repository: Server logout failed, continuing with local logout - ${e.toString()}',
          );
          // Continue with local logout even if server logout fails
        }
      } else {
        print(
          'ℹ️ Repository: No internet connection, performing local logout only',
        );
      }

      // Always clear local cache regardless of server logout result
      await localDataSource.clearCache();

      print('✅ Repository: Logout completed successfully');
      return Right(null);
    } on CacheException catch (e) {
      print('❌ Repository: Cache error during logout - ${e.message}');
      return Left(CacheFailure(e.message));
    } catch (e) {
      print('❌ Repository: Unexpected error during logout - ${e.toString()}');
      return Left(ServerFailure('Logout failed: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, User?>> getCurrentUser() async {
    try {
      print('👤 Repository: Retrieving current user information');

      // First check if we have a valid access token
      final accessToken = await localDataSource.getAccessToken();
      if (accessToken == null) {
        print('ℹ️ Repository: No access token found - user not logged in');
        return Right(null);
      }

      // Get cached user data
      final user = await localDataSource.getCachedUser();
      if (user != null) {
        print(
          '✅ Repository: Current user retrieved - ${user.firstName} ${user.lastName}',
        );
        return Right(user);
      } else {
        print('ℹ️ Repository: No cached user data found despite having token');
        // Token exists but no user data - clear token and return null
        await localDataSource.clearCache();
        return Right(null);
      }
    } on CacheException catch (e) {
      print('❌ Repository: Cache error retrieving current user - ${e.message}');
      return Left(CacheFailure(e.message));
    } catch (e) {
      print(
        '❌ Repository: Unexpected error retrieving current user - ${e.toString()}',
      );
      return Left(CacheFailure('Failed to get current user: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> isLoggedIn() async {
    try {
      print('🔍 Repository: Checking user login status');

      // Check for access token presence
      final accessToken = await localDataSource.getAccessToken();
      final hasToken = accessToken != null && accessToken.isNotEmpty;

      // Check for user data presence
      final user = await localDataSource.getCachedUser();
      final hasUser = user != null;

      // User is logged in if both token and user data exist
      final isLoggedIn = hasToken && hasUser;

      print(
        'ℹ️ Repository: Login status check - Token: $hasToken, User: $hasUser, Result: $isLoggedIn',
      );

      // If we have token but no user data, clear everything
      if (hasToken && !hasUser) {
        print('⚠️ Repository: Inconsistent state detected, clearing cache');
        await localDataSource.clearCache();
        return Right(false);
      }

      return Right(isLoggedIn);
    } on CacheException catch (e) {
      print('❌ Repository: Cache error checking login status - ${e.message}');
      return Left(CacheFailure(e.message));
    } catch (e) {
      print(
        '❌ Repository: Unexpected error checking login status - ${e.toString()}',
      );
      return Left(
        CacheFailure('Failed to check login status: ${e.toString()}'),
      );
    }
  }
}
