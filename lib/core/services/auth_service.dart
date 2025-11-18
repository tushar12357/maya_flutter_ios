import 'dart:async';
import 'package:go_router/go_router.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'storage_service.dart';
import 'navigation_service.dart';
import '../../injection_container.dart';
import '../network/api_client.dart';

class AuthService {
  final StorageService _storageService = sl<StorageService>();
  Timer? _tokenExpiryTimer;
  Timer? _refreshTimer;
  final ApiClient _apiClient =
      sl<ApiClient>(); // Fixed: use sl instead of getIt

  // Add flag to prevent multiple refresh attempts
  bool _isRefreshing = false;

  void startTokenManagement(DateTime expiryDate) {
    // CRITICAL: Stop existing timers first to prevent duplicates
    stopTokenManagement();

    _startTokenExpiryCheck(expiryDate);
    _startPeriodicTokenRefresh();
  }

  void stopTokenManagement() {
    print('🔑 Stopping token management...');
    _tokenExpiryTimer?.cancel();
    _refreshTimer?.cancel();
    _tokenExpiryTimer = null;
    _refreshTimer = null;
    _isRefreshing = false; // Reset refresh flag
  }

  void _startTokenExpiryCheck(DateTime expiryDate) {
    // Validate interval
    if (expiryDate.isBefore(DateTime.now().add(Duration(seconds: 5)))) {
      print(
        '⚠️ Warning: Token expiry interval too short, using minimum 10 seconds',
      );
      expiryDate = DateTime.now().add(Duration(seconds: 10));
    } else {
      expiryDate = expiryDate.subtract(Duration(seconds: 5)); // Check 5 seconds before expiry
    }

    print('🔑 Starting token expiry check every ${expiryDate.difference(DateTime.now()).inSeconds} seconds');

    _tokenExpiryTimer = Timer.periodic(Duration(seconds: expiryDate.difference(DateTime.now()).inSeconds), (
      timer,
    ) async {
      await _checkTokenExpiry();
    });
  }

  Future<void> _checkTokenExpiry() async {
    // Prevent multiple simultaneous checks
    if (_isRefreshing) {
      print('🔄 Refresh already in progress, skipping check');
      return;
    }

    try {
      final token = await _storageService.getAccessToken();
      if (token != null && JwtDecoder.isExpired(token)) {
        print('🔑 Token expired, attempting refresh...');
        await _handleTokenExpiry();
      }
    } catch (e) {
      print('❌ Error checking token expiry: $e');
    }
  }

  void _startPeriodicTokenRefresh() {
    _refreshTimer = Timer.periodic(Duration(minutes: 10), (timer) async {
      if (!_isRefreshing) {
        await _attemptTokenRefresh();
      }
    });
  }

  Future<void> _handleTokenExpiry() async {
    if (_isRefreshing) {
      print('🔄 Token refresh already in progress');
      return;
    }

    _isRefreshing = true;

    try {
      final refreshed = await _attemptTokenRefresh();
      if (!refreshed) {
        print('❌ Token refresh failed, performing auto logout...');
        await _performAutoLogout();
        return; // Exit early, don't continue the timer
      }
    } finally {
      _isRefreshing = false;
    }
  }

  Future<bool> _attemptTokenRefresh() async {
    try {
      final refreshToken = await _storageService.getRefreshToken();

      if (refreshToken == null) {
        print('❌ No refresh token available');
        return false;
      }

      if (JwtDecoder.isExpired(refreshToken)) {
        print('❌ Refresh token is expired');
        return false;
      }

      print('🔄 Refreshing token...');

      final newToken = await _apiClient.refreshToken(refreshToken);

      // Validate response structure
      if (newToken['data'] == null ||
          newToken['data']['data'] == null) {
        print('❌ Invalid token refresh response structure');
        return false;
      }

      final tokenData = newToken['data']['data'];

      // Save new tokens
      await _storageService.saveAccessToken(tokenData['access_token']);
      await _storageService.saveRefreshToken(tokenData['refresh_token']);
      await _storageService.saveSessionId(tokenData['session_id']);
      await _storageService.saveTokenExpiryDate(DateTime.now().add(Duration(seconds: tokenData['expiry_duration'])));

      print('✅ Token refreshed successfully');

      // IMPORTANT: Restart token management with new expiry
      final newExpiryDuration = tokenData['expiry_duration'] as int?;
      if (newExpiryDuration != null) {
        stopTokenManagement();
        startTokenManagement(DateTime.now().add(Duration(seconds: newExpiryDuration)));
      }

      return true;
    } catch (e) {
      print('❌ Token refresh error: $e');
      return false;
    }
  }

  Future<void> _performAutoLogout() async {
    print('🚪 Performing auto logout...');

    // CRITICAL: Stop token management FIRST to prevent more refresh attempts
    stopTokenManagement();

    // Clear all stored data
    await _storageService.clearAll();

    // Navigate to login and show dialog
    final currentContext = NavigationService.navigatorKey.currentContext;
    if (currentContext != null) {
      currentContext.go('/login');
      await Future.delayed(Duration(milliseconds: 100));
      NavigationService.showSessionExpiredDialog();
    }
  }
}
