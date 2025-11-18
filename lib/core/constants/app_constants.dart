class AppConstants {
  static const String appName = 'Flutter Auth GoRouter App';

  // API
  static const String baseUrl = 'https://maya.ravan.ai/api/';
  static const int connectionTimeout = 30000;
  static const int receiveTimeout = 30000;

  static const String protectedUrl = 'https://maya.ravan.ai/api/protected/';

  // Storage Keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userDataKey = 'user_data';
  static const String tokenExpiryDateKey = 'expiry_duration';
    static const String sessionIdKey = 'session_id';


  // Auth
  static const int tokenExpiryBufferMinutes = 5; // Refresh 5 mins before expiry
}
