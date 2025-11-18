import 'dart:convert';
import '../../../../core/services/storage_service.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/user_model.dart';

abstract class AuthLocalDataSource {
  Future<void> cacheUser(UserModel user);
  Future<void> cacheTokens({
    required String accessToken,
    required String refreshToken,
    required String sessionId,
  });
  Future<UserModel?> getCachedUser();
  Future<String?> getAccessToken();
  Future<String?> getRefreshToken();
  Future<String?> getSessionId();
  Future<void> clearCache();
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  final StorageService storageService;
  
  AuthLocalDataSourceImpl(this.storageService);
  
  @override
  Future<void> cacheUser(UserModel user) async {
    try {
      print('💾 Local: Caching user data for ${user.firstName} ${user.lastName}');
      await storageService.saveUserData(json.encode(user.toJson()));
      print('✅ Local: User data cached successfully');
    } catch (e) {
      print('❌ Local: Failed to cache user data - ${e.toString()}');
      throw CacheException('Failed to cache user data: ${e.toString()}');
    }
  }
  
  @override
  Future<void> cacheTokens({
    required String accessToken,
    required String refreshToken,
    required String sessionId,
  }) async {
    try {
      print('💾 Local: Caching authentication tokens');
      await Future.wait([
        storageService.saveAccessToken(accessToken),
        storageService.saveRefreshToken(refreshToken),
        storageService.saveSessionId(sessionId),
      ]);
      print('✅ Local: Tokens cached successfully');
    } catch (e) {
      print('❌ Local: Failed to cache tokens - ${e.toString()}');
      throw CacheException('Failed to cache tokens: ${e.toString()}');
    }
  }
  
  @override
  Future<UserModel?> getCachedUser() async {
    try {
      print('📱 Local: Retrieving cached user data');
      final userJson = await storageService.getUserData();
      if (userJson != null && userJson.isNotEmpty) {
        final user = UserModel.fromJson(json.decode(userJson));
        print('✅ Local: User found in cache - ${user.firstName} ${user.lastName}');
        return user;
      }
      print('ℹ️ Local: No user found in cache');
      return null;
    } catch (e) {
      print('❌ Local: Failed to get cached user - ${e.toString()}');
      throw CacheException('Failed to get cached user: ${e.toString()}');
    }
  }
  
  @override
  Future<String?> getAccessToken() async {
    try {
      final token = await storageService.getAccessToken();
      if (token != null && token.isNotEmpty) {
        print('✅ Local: Access token found');
        return token;
      } else {
        print('ℹ️ Local: No access token found');
        return null;
      }
    } catch (e) {
      print('❌ Local: Failed to get access token - ${e.toString()}');
      throw CacheException('Failed to get access token: ${e.toString()}');
    }
  }
  
  @override
  Future<String?> getRefreshToken() async {
    try {
      final token = await storageService.getRefreshToken();
      if (token != null && token.isNotEmpty) {
        print('✅ Local: Refresh token found');
        return token;
      } else {
        print('ℹ️ Local: No refresh token found');
        return null;
      }
    } catch (e) {
      print('❌ Local: Failed to get refresh token - ${e.toString()}');
      throw CacheException('Failed to get refresh token: ${e.toString()}');
    }
  }


   @override
  Future<String?> getSessionId() async{
 try {
      final sessionId = await storageService.getSessionId();
      if (sessionId != null && sessionId.isNotEmpty) {
        print('✅ Local: session id found');
        return sessionId;
      } else {
        print('ℹ️ Local: No session id found');
        return null;
      }
    } catch (e) {
      print('❌ Local: Failed to get session id - ${e.toString()}');
      throw CacheException('Failed to get session id: ${e.toString()}');
    }    
  }
  
  @override
  Future<void> clearCache() async {
    try {
      print('🗑️ Local: Clearing all cached authentication data');
      await storageService.clearAll();
      print('✅ Local: Cache cleared successfully');
    } catch (e) {
      print('❌ Local: Failed to clear cache - ${e.toString()}');
      throw CacheException('Failed to clear cache: ${e.toString()}');
    }
  }
}