import 'user_model.dart';

class LoginResponseModel {
  final UserModel user;
  final String accessToken;
  final String refreshToken;
  final String sessionId;
  final int expiryDuration;
  const LoginResponseModel({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
    required this.sessionId,
    required this.expiryDuration,
  });

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) {
    return LoginResponseModel(
      user: UserModel.fromJson(
        json['user'] ??
            {
              'id': json['id'],
              'email': json['email'],
              'first_name': json['first_name'],
              'last_name': json['last_name'],
            },
      ),
      accessToken: json['access_token'] ?? '',
      refreshToken: json['refresh_token'] ?? '',
      sessionId: json['session_id'] ?? '',
      expiryDuration: json['expiry_duration'] ?? 0,
    );
  }
}
