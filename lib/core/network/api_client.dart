import 'dart:io';

import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:Maya/core/services/storage_service.dart';
import 'package:intl/intl.dart';
import '../constants/app_constants.dart';

import 'package:http_parser/http_parser.dart';
final getIt = GetIt.instance;

class ApiClient {
  late final Dio _publicDio;
  late final Dio _protectedDio;
  late final Dio _multipartDio;

  ApiClient(Dio publicDio, Dio protectedDio) {
    _publicDio = publicDio;
    _protectedDio = protectedDio;
    
    // ✅ CRITICAL: Multipart Dio with NO Content-Type preset
    _multipartDio = Dio(
      BaseOptions(
        baseUrl: AppConstants.protectedUrl,
        connectTimeout: Duration(milliseconds: AppConstants.connectionTimeout),
        receiveTimeout: Duration(milliseconds: AppConstants.receiveTimeout),
        headers: {
          'Accept': 'application/json',
          // ❌ DO NOT SET Content-Type here - Dio will auto-generate with boundary
        },
      ),
    );

    // Configure public Dio instance
    _publicDio.options.baseUrl = AppConstants.baseUrl;
    _publicDio.options.connectTimeout = Duration(
      milliseconds: AppConstants.connectionTimeout,
    );
    _publicDio.options.receiveTimeout = Duration(
      milliseconds: AppConstants.receiveTimeout,
    );
    _publicDio.options.headers['Content-Type'] = 'application/json';

    // Configure protected Dio instance
    _protectedDio.options.baseUrl = AppConstants.protectedUrl;
    _protectedDio.options.connectTimeout = Duration(
      milliseconds: AppConstants.connectionTimeout,
    );
    _protectedDio.options.receiveTimeout = Duration(
      milliseconds: AppConstants.receiveTimeout,
    );
    _protectedDio.options.headers['Content-Type'] = 'application/json';

    // ✅ Multipart interceptor - ONLY adds Authorization, NO Content-Type
    _multipartDio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await getIt<StorageService>().getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          
          // ✅ Ensure Dio auto-generates Content-Type with boundary
          // Remove any preset Content-Type so FormData can set it properly
          if (options.data is FormData) {
            options.headers.remove('Content-Type');
          }
          
          return handler.next(options);
        },
        onError: (DioException error, ErrorInterceptorHandler handler) async {
          // ❌ NEVER retry multipart uploads - they break on retry
          

          if (error.response?.statusCode == 401) {
            final encodedRefreshToken =
                await getIt<StorageService>().getRefreshToken();

            if (encodedRefreshToken != null) {
              final response = await refreshToken(encodedRefreshToken);

              if (response['statusCode'] == 200) {
                final tokenData = response['data']['data'];

                await getIt<StorageService>().saveAccessToken(tokenData['access_token']);
                await getIt<StorageService>().saveRefreshToken(tokenData['refresh_token']);
                await getIt<StorageService>().saveTokenExpiryDate(tokenData['expiry_duration']);

                final RequestOptions requestOptions = error.requestOptions;
                requestOptions.headers['Authorization'] =
                    'Bearer ${tokenData['access_token']}';

                final cloned = await _multipartDio.fetch(requestOptions);
                return handler.resolve(cloned);
              }
            }
          }

          return handler.next(error);
        },
      ),
    );

    // Debug logs optional
    _multipartDio.interceptors.add(
      LogInterceptor(requestBody: true, responseBody: true),
    );

    // Add interceptors for both instances
    _publicDio.interceptors.add(
      LogInterceptor(requestBody: true, responseBody: true),
    );
    _protectedDio.interceptors.add(
      LogInterceptor(requestBody: true, responseBody: true),
    );

    // Add authorization interceptor for protected Dio
    _protectedDio.interceptors.add(
      InterceptorsWrapper(
        onRequest:
            (RequestOptions options, RequestInterceptorHandler handler) async {
              final token = await getIt<StorageService>().getAccessToken();
              if (token != null) {
                options.headers['Authorization'] = 'Bearer $token';
              }
              return handler.next(options);
            },
        onError: (DioException error, ErrorInterceptorHandler handler) async {
          // ❌ Do NOT retry profile update endpoint
         

          if (error.response?.statusCode == 401) {
            final encodedRefreshToken =
                await getIt<StorageService>().getRefreshToken();

            if (encodedRefreshToken != null) {
              final response = await refreshToken(encodedRefreshToken);

              if (response['statusCode'] == 200) {
                final tokenData = response['data']['data'];

                await getIt<StorageService>().saveAccessToken(tokenData['access_token']);
                await getIt<StorageService>().saveRefreshToken(tokenData['refresh_token']);
                await getIt<StorageService>().saveTokenExpiryDate(tokenData['expiry_duration']);

                final RequestOptions requestOptions = error.requestOptions;
                requestOptions.headers['Authorization'] =
                    'Bearer ${tokenData['access_token']}';

                final cloned = await _protectedDio.fetch(requestOptions);
                return handler.resolve(cloned);
              }
            }
          }

          return handler.next(error);
        },
      ),
    );
  }

  Future<Response> get(
    Dio dio,
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return await dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> post(Dio dio, String path, {dynamic data}) async {
    return await dio.post(path, data: data);
  }

  Future<Response> put(Dio dio, String path, {dynamic data}) async {
    return await dio.put(path, data: data);
  }

  Future<Response> patch(Dio dio, String path, {dynamic data}) async {
    return await dio.patch(path, data: data);
  }

  Future<Response> delete(Dio dio, String path, {dynamic data}) async {
    return await dio.delete(path, data: data);
  }

  // Login API
  Future<Map<String, dynamic>> login(Map<String, dynamic> payload) async {
    final response = await post(_publicDio, '/auth/login', data: payload);
    return {'statusCode': response.statusCode, 'data': response.data};
  }

  Map<String, dynamic> prepareLoginPayload(String email, String password) {
    return {'email': email, 'password': password};
  }

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    final response = await post(_publicDio, '/auth/forgot-password', data: {'email': email});
    return {'statusCode': response.statusCode, 'data': response.data};
  }

  Future<Map<String, dynamic>> resetPassword(String email, String otp, String newPassword, String confirmPassword) async {
    final response = await post(_publicDio, '/auth/reset-password', data: {'email': email, 'new_password': newPassword, 'confirm_password': confirmPassword});
    return {'statusCode': response.statusCode, 'data': response.data};
  }

  Future<Map<String, dynamic>> verifyOTP(String email, String otp) async {
    final response = await post(_publicDio, '/auth/verify-otp', data: {'email': email, 'otp': otp});
    return {'statusCode': response.statusCode, 'data': response.data};
  }

  // ✅ For text-only updates (no file)
  Future<Map<String, dynamic>> updateUserProfilePartial(
    Map<String, dynamic> fieldsToUpdate,
  ) async {
    final response = await _protectedDio.patch(
      '/auth/users/update',
      data: fieldsToUpdate,
    );
    return {'statusCode': response.statusCode, 'data': response.data};
  }

  Future<Map<String, dynamic>> getIntegrationStatus() async {
    final response = await _protectedDio.get('/auth/integrations/status');
    print('getCurrentUser response: ${response.data}');
    print('getCurrentUser statusCode: ${response.statusCode}');
    return {'statusCode': response.statusCode, 'data': response.data};
  }

  // Google Sign-In API
  Future<Map<String, dynamic>> googleLogin(Map<String, dynamic> payload) async {
    final response = await post(_publicDio, '/auth/google/', data: payload);
    return {'statusCode': response.statusCode, 'data': response.data};
  }

  Map<String, dynamic> prepareGoogleLoginPayload(String accessToken) {
    return {'access_token': accessToken};
  }

  // Refresh Token API
  Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    final response = await post(
      _publicDio,
      '/auth/refresh',
      data: {'refresh_token': refreshToken},
    );
    print('refreshToken response: ${response.data}');
    print('refreshToken statusCode: ${response.statusCode}');
    return {'statusCode': response.statusCode, 'data': response.data};
  }

  // Google Access Token Mobile API
  Future<Map<String, dynamic>> googleAccessTokenMobile({
    required int userId,
    required String authCode,
  }) async {
    final response = await get(
      _publicDio,
      '/productivity/google/oauth/callback',
      queryParameters: {'code':authCode,'state':userId}
    );

    return {'statusCode': response.statusCode, 'data': response.data};
  }

  // Fetch Tasks API
  Future<Map<String, dynamic>> fetchTasks({int page=1, String? status}) async {
    final response = await get(
      _protectedDio,
      '/thunder/get-tool-call-sessions?page=$page',
      queryParameters: {'status': status},
    );
    print('fetchTasks response: ${response.data}');
    print('fetchTasks statusCode: ${response.statusCode}');
    return {'statusCode': response.statusCode, 'data': response.data};
  }

  // Fetch Tasks Detail API
  Future<Map<String, dynamic>> fetchTasksDetail({
    required String sessionId,
  }) async {
    final response = await get(
      _protectedDio,
      '/thunder/get-tool-calls/$sessionId',
    );
    print('fetchTasksDetail response: ${response.data}');
    print('fetchTasksDetail statusCode: ${response.statusCode}');
    return {'statusCode': response.statusCode, 'data': response.data};
  }

  // Sync Contacts API
  Future<Map<String, dynamic>> syncContacts(
    List<Map<String, String>> payload,
  ) async {
    final response = await post(
      _protectedDio,
      '/communication/sync-contacts',
      data: payload,
    );
    return {'statusCode': response.statusCode, 'data': response.data};
  }

  List<Map<String, String>> prepareSyncContactsPayload(
    List<Map<String, String>> contactList,
  ) {
    return contactList;
  }

  // Start Thunder API
  Future<Map<String, dynamic>> startThunder(String agentType) async {
    final response = await post(
      _protectedDio,
      '/thunder/start-thunder',
      data: {'agent_type': agentType},
    );
    return {'statusCode': response.statusCode, 'data': response.data};
  }

  Map<String, dynamic> prepareStartThunderPayload(String agentType) {
    return {'agent_type': agentType};
  }

  // Fetch Call Sessions API
  Future<Map<String, dynamic>> fetchCallSessions({int page = 1}) async {
    final response = await get(
      _protectedDio,
      '/thunder/get-sessions',
      queryParameters: {'page': page.toString()},
    );
    return {'statusCode': response.statusCode, 'data': response.data};
  }

  // Create To-Do API
  Future<Map<String, dynamic>> createToDo(Map<String, dynamic> payload) async {
    final response = await post(
      _protectedDio,
      '/crm/todo/create',
      data: payload,
    );
    return {'statusCode': response.statusCode, 'data': response.data};
  }

  Map<String, dynamic> prepareCreateToDoPayload(
    String title,
    String description,
    String? reminderTime,
  ) {
    return {
      'title': title,
      'description': description,
      'reminder': reminderTime != null && reminderTime.isNotEmpty,
      'reminder_time': reminderTime,
    };
  }

  // Get To-Do API
  Future<Map<String, dynamic>> getToDo({int page=1}) async {
    print('getToDo');
    final response = await get(_protectedDio, '/productivity/todo/get?page=$page');
    print('getToDo response: ${response.data}');
    print('getToDo statusCode: ${response.statusCode}');
    return {'statusCode': response.statusCode, 'data': response.data};
  }

  // Update To-Do API
  Future<Map<String, dynamic>> updateToDo(Map<String, dynamic> payload) async {
    final response = await patch(
      _protectedDio,
      '/productivity/todo/update',
      data: payload,
    );
    return {'statusCode': response.statusCode, 'data': response.data};
  }

  Map<String, dynamic> prepareUpdateToDoPayload(
    int id, {
    required String title,
    required String description,
    required String status,
    required bool reminder,
    String? reminder_time,
  }) {
    return {
      'ID': id,
      'title': title,
      'description': description,
      'status': status,
      'reminder': reminder,
      'reminder_time': reminder_time,
    };
  }

  // Delete To-Do API
  Future<Map<String, dynamic>> deleteToDo(int id) async {
    final response = await delete(
      _protectedDio,
      '/productivity/todo/delete',
      data: {'ID': id},
    );
    return {'statusCode': response.statusCode, 'data': response.data};
  }

  // Fetch Notifications API
  Future<Map<String, dynamic>> sendFcmToken(String fcmToken) async {
    final response = await post(
      _protectedDio,
      '/auth/save-fcm-token',
      data: {'fcm_token': fcmToken},
    );
    return {'statusCode': response.statusCode, 'data': response.data};
  }

  Future<Map<String, dynamic>> getReminders({
    int page = 1,
    DateTime? startDate,
    DateTime? endDate,
    String? timeFilter,
  }) async {
    final Map<String, dynamic> query = {};
    if (startDate != null) {
      query['start_date'] = DateFormat('yyyy-MM-dd').format(startDate);
    }
    if (endDate != null) {
      query['end_date'] = DateFormat('yyyy-MM-dd').format(endDate);
    }
    if (timeFilter != null && timeFilter != 'All') {
      query['time_filter'] = timeFilter.toLowerCase();
    }

    final response = await get(
      _protectedDio,
      '/productivity/reminder/get',
      queryParameters: query,
    );

    return {'success': response.statusCode == 200, 'data': response.data};
  }

  Future<Map<String, dynamic>> saveLocation(
    double latitude,
    double longitude,
    String timezone,
  ) async {
    final payload = {
      'latitude': latitude,
      'longitude': longitude,
      'timezone': timezone,
    };
    final response = await post(
      _protectedDio,
      '/auth/save-location',
      data: payload,
    );
    return {'statusCode': response.statusCode, 'data': response.data};
  }

  Map<String, dynamic> prepareDeleteToDoPayload(int id) {
    return {'ID': id};
  }

  // Google Search API
  Future<Map<String, dynamic>> googleSearch(
    String question, {
    String? mode,
  }) async {
    final payload = prepareGoogleSearchPayload(question, mode: mode);
    final response = await post(
      _protectedDio,
      '/productivity/google/search',
      data: payload,
    );
    print('googleSearch response: ${response.data}');
    print('googleSearch statusCode: ${response.statusCode}');
    return {'statusCode': response.statusCode, 'data': response.data};
  }

  Map<String, dynamic> prepareGoogleSearchPayload(
    String question, {
    String? mode,
  }) {
    final payload = {'question': question};
    if (mode != null) {
      payload['mode'] = mode;
    }
    return payload;
  }

  Future<Map<String, dynamic>> createGeneration(
    Map<String, dynamic> payload,
  ) async {
    final response = await post(
      _protectedDio,
      '/productivity/generations',
      data: payload,
    );
    print('createGeneration response: ${response.data}');
    print('createGeneration statusCode: ${response.statusCode}');
    return {'statusCode': response.statusCode, 'data': response.data};
  }

  Map<String, dynamic> prepareCreateGenerationPayload(
    String type,
    Map<String, dynamic> input,
    String createdBy,
  ) {
    return {'type': type, 'input': input, 'createdBy': createdBy};
  }

  // Get Generation API
  Future<Map<String, dynamic>> getGeneration(String id) async {
    final response = await get(_protectedDio, '/productivity/generations/$id');
    print('getGeneration response: ${response.data}');
    print('getGeneration statusCode: ${response.statusCode}');
    return {'statusCode': response.statusCode, 'data': response.data};
  }

  // Approve Generation API
  Future<Map<String, dynamic>> approveGeneration(String id) async {
    final response = await post(
      _protectedDio,
      '/productivity/generations/$id/approve',
    );
    print('approveGeneration response: ${response.data}');
    print('approveGeneration statusCode: ${response.statusCode}');
    return {'statusCode': response.statusCode, 'data': response.data};
  }

  // Regenerate Generation API
  Future<Map<String, dynamic>> regenerateGeneration(String id) async {
    final response = await post(
      _protectedDio,
      '/productivity/generations/$id/regenerate',
    );
    print('regenerateGeneration response: ${response.data}');
    print('regenerateGeneration statusCode: ${response.statusCode}');
    return {'statusCode': response.statusCode, 'data': response.data};
  }

  // Publish MQTT Message API
  Future<Map<String, dynamic>> publishMqttMessage({
    required String message,
    int qos = 2,
    bool retain = false,
  }) async {
    final payload = prepareMqttPublishPayload(message, qos, retain);
    final response =
        await post(_publicDio, '/device/mqtt/publish', data: payload).then((
          response,
        ) {
          print('publishMqttMessage response: ${response.data}');
          print('publishMqttMessage statusCode: ${response.statusCode}');
          return {'statusCode': response.statusCode, 'data': response.data};
        });

    return response;
  }

  // Set Volume API
  Future<Map<String, dynamic>> setVolume(int level) async {
    final payload = prepareSetVolumePayload(level);
    final options = Options(headers: {'X-Device-ID': 'maya-india-26b'});
    final response = await _publicDio.post(
      '/device/mqtt/publish',
      data: payload,
      options: options,
    );
    print('setVolume response: ${response.data}');
    print('setVolume statusCode: ${response.statusCode}');
    return {'statusCode': response.statusCode, 'data': response.data};
  }

  // Get Volume API
  Future<Map<String, dynamic>> getVolume() async {
    final payload = prepareGetVolumePayload();
    final options = Options(headers: {'X-Device-ID': 'maya-india-26b'});
    final response = await _publicDio.post(
      '/device/mqtt/publish',
      data: payload,
      options: options,
    );
    print('getVolume response: ${response.data}');
    print('getVolume statusCode: ${response.statusCode}');
    return {'statusCode': response.statusCode, 'data': response.data};
  }

  Future<Map<String, dynamic>> setMicVolume(int level) async {
    final payload = prepareSetMicVolumePayload(level);
    final options = Options(headers: {'X-Device-ID': 'maya-india-26b'});
    final response = await _publicDio.post(
      '/device/mqtt/publish',
      data: payload,
      options: options,
    );
    print('setMicVolume response: ${response.data}');
    print('setMicVolume statusCode: ${response.statusCode}');
    return {'statusCode': response.statusCode, 'data': response.data};
  }

  // Get Microphone Volume API
  Future<Map<String, dynamic>> getMicVolume() async {
    final payload = prepareGetMicVolumePayload();
    final options = Options(headers: {'X-Device-ID': 'maya-india-26b'});
    final response = await _publicDio.post(
      '/device/mqtt/publish',
      data: payload,
      options: options,
    );
    print('getMicVolume response: ${response.data}');
    print('getMicVolume statusCode: ${response.statusCode}');
    return {'statusCode': response.statusCode, 'data': response.data};
  }

  // Prepare MQTT Publish Payload
  Map<String, dynamic> prepareMqttPublishPayload(
    String message, [
    int qos = 2,
    bool retain = false,
  ]) {
    return {'message': message, 'qos': qos, 'retain': retain};
  }

  // Prepare Set Volume Payload
  Map<String, dynamic> prepareSetVolumePayload(int level) {
    return prepareMqttPublishPayload(
      '{"action":"set_speaker_volume","level":$level}',
      2,
      false,
    );
  }

  // Prepare Get Volume Payload
  Map<String, dynamic> prepareGetVolumePayload() {
    return prepareMqttPublishPayload('{"action":"get_speaker_volume"}', 2, false);
  }

  Map<String, dynamic> prepareSetMicVolumePayload(int level) {
    return prepareMqttPublishPayload(
      '{"action":"set_mic_volume","level":$level}',
      2,
      false,
    );
  }

  // Prepare Get Microphone Volume Payload
  Map<String, dynamic> prepareGetMicVolumePayload() {
    return prepareMqttPublishPayload(
      '{"action":"get_mic_volume"}',
      2,
      false,
    );
  }

  Future<Map<String, dynamic>> rebootDevice() async {
    final payload = prepareRebootPayload();
    final options = Options(headers: {'X-Device-ID': 'maya-india-26b'});
    final response = await _publicDio.post(
      '/device/mqtt/publish',
      data: payload,
      options: options,
    );
    print('rebootDevice response: ${response.data}');
    print('rebootDevice statusCode: ${response.statusCode}');
    return {'statusCode': response.statusCode, 'data': response.data};
  }

  // Shutdown Device API
  Future<Map<String, dynamic>> shutdownDevice() async {
    final payload = prepareShutdownPayload();
    final options = Options(headers: {'X-Device-ID': 'maya-india-26b'});
    final response = await _publicDio.post(
      '/device/mqtt/publish',
      data: payload,
      options: options,
    );
    print('shutdownDevice response: ${response.data}');
    print('shutdownDevice statusCode: ${response.statusCode}');
    return {'statusCode': response.statusCode, 'data': response.data};
  }

  Map<String, dynamic> prepareRebootPayload() {
    return prepareMqttPublishPayload(
      '{"action":"reboot"}',
      2,
      false,
    );
  }

  // Prepare Shutdown Payload
  Map<String, dynamic> prepareShutdownPayload() {
    return prepareMqttPublishPayload(
      '{"action":"shutdown"}',
      2,
      false,
    );
  }

  // Set Wake Word API
  Future<Map<String, dynamic>> setWakeWord(String mode) async {
    final payload = prepareSetWakeWordPayload(mode);
    final options = Options(headers: {'X-Device-ID': 'maya-india-26b'});
    final response = await _publicDio.post(
      '/device/mqtt/publish',
      data: payload,
      options: options,
    );
    print('setWakeWord response: ${response.data}');
    print('setWakeWord statusCode: ${response.statusCode}');
    return {'statusCode': response.statusCode, 'data': response.data};
  }

  // Get Wake Word API
  Future<Map<String, dynamic>> getWakeWord() async {
    final payload = prepareGetWakeWordPayload();
    final options = Options(headers: {'X-Device-ID': 'maya-india-26b'});
    final response = await _publicDio.post(
      '/device/mqtt/publish',
      data: payload,
      options: options,
    );
    print('getWakeWord response: ${response.data}');
    print('getWakeWord statusCode: ${response.statusCode}');
    return {'statusCode': response.statusCode, 'data': response.data};
  }

  // Wake Maya API
  Future<Map<String, dynamic>> wakeMaya() async {
    final payload = prepareWakeMayaPayload();
    final options = Options(headers: {'X-Device-ID': 'maya-india-26b'});
    final response = await _publicDio.post(
      '/device/mqtt/publish',
      data: payload,
      options: options,
    );
    print('wakeMaya response: ${response.data}');
    print('wakeMaya statusCode: ${response.statusCode}');
    return {'statusCode': response.statusCode, 'data': response.data};
  }

  // Prepare Set Wake Word Payload
  Map<String, dynamic> prepareSetWakeWordPayload(String mode) {
    if (mode != 'on' && mode != 'off') {
      throw ArgumentError('Mode must be either "on" or "off"');
    }
    return prepareMqttPublishPayload(
      '{"action":"set_wake_word","mode":"$mode"}',
      2,
      false,
    );
  }

  // Prepare Get Wake Word Payload
  Map<String, dynamic> prepareGetWakeWordPayload() {
    return prepareMqttPublishPayload(
      '{"action":"get_wake_word"}',
      2,
      false,
    );
  }

  // Prepare Wake Maya Payload
  Map<String, dynamic> prepareWakeMayaPayload() {
    return prepareMqttPublishPayload(
      '{"action":"wake_maya"}',
      2,
      false,
    );
  }

  Future<Map<String, dynamic>> getCurrentUser() async {
    final response = await _protectedDio.get('/auth/users/me');
    print('getCurrentUser response: ${response.data}');
    print('getCurrentUser statusCode: ${response.statusCode}');
    return {'statusCode': response.statusCode, 'data': response.data};
  }

  Future<Map<String, dynamic>> updateNotificationPreferences({
    required bool emailNotifications,
    required bool pushNotifications,
    required bool smsNotifications,
    required bool deviceNotifications,
    required bool callNotifications,
  }) async {
    final payload = _buildNotificationPayload(
      email: emailNotifications,
      push: pushNotifications,
      sms: smsNotifications,
      device: deviceNotifications,
      call: callNotifications,
    );

    final response = await _protectedDio.patch(
      '/auth/users/notification-preferences',
      data: payload,
    );

    return {'statusCode': response.statusCode, 'data': response.data};
  }

  Map<String, bool> _buildNotificationPayload({
    required bool email,
    required bool push,
    required bool sms,
    required bool device,
    required bool call,
  }) {
    return {
      'email_notifications': email,
      'push_notifications': push,
      'sms_notifications': sms,
      'device_notifications': device,
      'call_notifications': call,
    };
  }

  Map<String, dynamic> prepareSaveLocationPayload(
    double latitude,
    double longitude,
    String timezone,
  ) {
    return {
      "latitude": latitude,
      "longitude": longitude,
      "timezone": timezone,
    };
  }

  Map<String, dynamic> prepareUpdateUserProfilePayload({
    required String firstName,
    required String lastName,
    required String fcmToken,
    required double latitude,
    required double longitude,
    required String timezone,
    required String phoneNumber,
  }) {
    return {
      "first_name": firstName,
      "last_name": lastName,
      "fcm_token": fcmToken,
      "latitude": latitude,
      "longitude": longitude,
      "timezone": timezone,
      "phone_number": phoneNumber,
    };
  }

  Future<Map<String,dynamic>> getGenerations() async {
    final response = await _protectedDio.get('/productivity/generations');
    return {'statusCode': response.statusCode, 'data': response.data};
  }

  Future<Map<String,dynamic>> updateGenerationStatus(String generationId, String action)async{
    final response= await _protectedDio.patch('/productivity/generations/status',
    data:{'generation_id': generationId, 'action': action});
    return {'statusCode': response.statusCode, 'data': response.data};
  }

  Future<Map<String, dynamic>> saveFirefliesKey({
    required int userId,
    required String apiKey,
  }) async {
    final response = await _protectedDio.post(
      '/auth/fireflies/save-key',
      data: {
        'fireflies_api_key': apiKey,
      },
    );

    return {
      'statusCode': response.statusCode,
      'data': response.data,
    };
  }

  Future<Map<String, dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final response = await _protectedDio.post(
      '/auth/change-password',
      data: {
        'old_password': oldPassword,
        'new_password': newPassword,
        'confirm_password': confirmPassword,
      },
    );

    return {
      'statusCode': response.statusCode,
      'data': response.data,
    };
  }

  // ✅ Avatar upload only - uses multipart Dio
  Future<Map<String, dynamic>> uploadUserAvatar(File imageFile) async {
    return updateUserProfile(avatar: imageFile);
  }

  // ✅ Main update function - intelligently chooses multipart vs JSON
Future<Map<String, dynamic>> updateUserProfile({
  File? avatar,
  String? firstName,
  String? lastName,
  String? phoneNumber,
  String? fcmToken,
  double? latitude,
  double? longitude,
  String? timezone,
  String? country,
}) async {
  try {
    final Map<String, dynamic> map = {};

    // Add text fields if provided
    if (firstName != null) map['first_name'] = firstName;
    if (lastName != null) map['last_name'] = lastName;
    if (phoneNumber != null) map['phone_number'] = phoneNumber;
    if (fcmToken != null) map['fcm_token'] = fcmToken;
    if (latitude != null) map['latitude'] = latitude.toString();
    if (longitude != null) map['longitude'] = longitude.toString();
    if (timezone != null) map['timezone'] = timezone;
    if (country != null) map['country'] = country;

    // Add file if present
    if (avatar != null) {
      final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
      map['profile_image'] = await MultipartFile.fromFile(
        avatar.path,
        filename: fileName,
        contentType: MediaType('image', 'jpeg'),
      );
    }

    final formData = FormData.fromMap(map);

    print("📤 Updating via MULTIPART");

    final response = await _multipartDio.patch(
      '/auth/users/update',
      data: formData,
      options: Options(
        headers: {
          // ❌ Do NOT set Content-Type manually
          // Dio will auto-generate boundary header
        },
      ),
    );

    return {
      'statusCode': response.statusCode,
      'data': response.data,
    };
  } on DioException catch (e) {
    print("❌ Dio Exception: ${e.response?.data}");
    return {
      'statusCode': e.response?.statusCode ?? 500,
      'data': e.response?.data ?? {'success': false},
    };
  }
}


}