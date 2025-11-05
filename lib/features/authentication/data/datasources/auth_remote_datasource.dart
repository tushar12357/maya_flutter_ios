import '../../../../core/network/api_client.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/user_model.dart';
import '../models/login_response_model.dart';
import '../../../../core/services/storage_service.dart';
import 'dart:convert';

abstract class AuthRemoteDataSource {
  Future<LoginResponseModel> login({
    required String email,
    required String password,
  });

  Future<UserModel> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone_number,
  });

  Future<void> logout();

  Future<LoginResponseModel> refreshToken(String refreshToken);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final ApiClient apiClient;
  final StorageService storageService;
  AuthRemoteDataSourceImpl(this.apiClient, this.storageService);

  @override
  Future<LoginResponseModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await apiClient.login({
        'email': email,
        'password': password,
      });
      print('🌐 API: Login response: ${response['data']['data']}');

      if (response['statusCode'] == 200) {
        final loginResponse = LoginResponseModel.fromJson(
          response['data']['data'],
        );
        print('🌐 API: Login response: ${loginResponse.user.toJson()}');
        await storageService.saveUserData(
          json.encode(loginResponse.user.toJson()),
        );
        final tokenExpiryDate = DateTime.now().add(
          Duration(seconds: loginResponse.expiryDuration),
        );
        await storageService.saveAccessToken(loginResponse.accessToken);
        await storageService.saveRefreshToken(loginResponse.refreshToken);
        await storageService.saveTokenExpiryDate(tokenExpiryDate);

        print('🌐 API: Token expiry date: $tokenExpiryDate');
        return loginResponse;
      } else {
        throw ServerException(
          message: response['message'] ?? 'Login failed',
          statusCode: response['statusCode'],
        );
      }
    } catch (e) {
      if (e is ServerException) {
        rethrow;
      }
      throw ServerException(
        message: 'Network error: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  @override
  Future<UserModel> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone_number,
  }) async {
    try {
      print('🌐 API: Attempting registration for $email');

      // Simulate API call delay
      await Future.delayed(Duration(seconds: 2));

      // Mock successful registration
      final mockUser = UserModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        email: email,
        firstName: firstName,
        lastName: lastName,
        phone_number: phone_number,
      );

      print('✅ API: Registration successful');
      return mockUser;

      // Real API call would look like this:
      /*
      final response = await apiClient.post(
        '/auth/register',
        data: {
          'email': email,
          'password': password,
          'name': name,
        },
      );
      
      if (response.statusCode == 201) {
        return UserModel.fromJson(response.data['user']);
      } else {
        throw ServerException(
          message: response.data['message'] ?? 'Registration failed',
          statusCode: response.statusCode,
        );
      }
      */
    } catch (e) {
      if (e is ServerException) {
        rethrow;
      }
      throw ServerException(
        message: 'Registration failed: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  @override
  Future<void> logout() async {
    try {
      print('🌐 API: Attempting logout');

      // Simulate API call delay
      await Future.delayed(Duration(seconds: 1));

      print('✅ API: Logout successful');

      // Real API call would look like this:
      /*
      await apiClient.post('/auth/logout');
      */
    } catch (e) {
      print('⚠️ API: Logout failed, but continuing anyway');
      // Don't throw error on logout failure
    }
  }

  @override
  Future<LoginResponseModel> refreshToken(String refreshToken) async {
    try {
      print('🌐 API: Attempting token refresh');

      final response = await getIt<ApiClient>().refreshToken(refreshToken);

      // Simulate API call delay
      await Future.delayed(Duration(seconds: 1));

      if (response['statusCode'] == 200) {
        return LoginResponseModel.fromJson(response['data']);
      } else {
        throw ServerException(
          message: response['message'] ?? 'Token refresh failed',
          statusCode: response['statusCode'],
        );
      }
    } catch (e) {
      if (e is ServerException) {
        rethrow;
      }
      throw ServerException(
        message: 'Token refresh failed: ${e.toString()}',
        statusCode: 500,
      );
    }
  }
}
