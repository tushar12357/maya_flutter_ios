import 'dart:ui';

import 'package:Maya/core/constants/colors.dart';
import 'package:Maya/core/network/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:Maya/features/widgets/integration.dart';
import 'package:url_launcher/url_launcher.dart';

class IntegrationsPage extends StatefulWidget {
  const IntegrationsPage({super.key});

  @override
  _IntegrationsPageState createState() => _IntegrationsPageState();
}

Future<void> _launchURL(String url) async {
  try {
    final Uri uri = Uri.parse(url);  // <-- Remove Uri.encodeFull(url)
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $url';
    }
  } catch (e) {
    print('Error launching URL: $e');
    
  }
}

class _IntegrationsPageState extends State<IntegrationsPage> with WidgetsBindingObserver  {
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  GoogleSignInAccount? _currentUser;
  bool _isInitializing = false;
  final _storage = const FlutterSecureStorage();
  late int _currentUserId;
  bool _isLoadingStatus = true;
  final List<Integration> integrations = [
    Integration(
      id: 'google-calendar',
      name: 'Google Calendar',
      description: 'Sync events with Google Calendar',
      icon: Icons.calendar_today,
      iconColor: const Color(0xFF4285F4),
      connected: false,
      category: 'calendar',
      scopes: [
        'https://www.googleapis.com/auth/userinfo.email',
        'https://www.googleapis.com/auth/userinfo.profile',
        'https://www.googleapis.com/auth/calendar',
        'https://www.googleapis.com/auth/drive.file',
        'https://www.googleapis.com/auth/spreadsheets',
        "https://www.googleapis.com/auth/gmail.readonly",
        "https://www.googleapis.com/auth/gmail.modify",
        "https://www.googleapis.com/auth/gmail.send",
      ],
    ),
    Integration(
      id: 'gohighlevel',
      name: 'GoHighLevel',
      description: 'Manage leads and automate marketing campaigns',
      icon: Icons.campaign,
      iconColor: const Color(0xFF00C4B4),
      connected: false,
      category: 'crm',
      scopes: ['api_key'],
    ),
    Integration(
      id: 'fireflies',
      name: 'Fireflies',
      description: 'AI Meeting Notes | Call Transcription',
      icon: Icons.mic,
      iconColor: Color(0xFFF97316),
      connected: false,
      category: 'productivity',
      scopes: [],
    ),
    Integration(
      id: 'asana',
      name: 'Asana',
      description: 'Manage your tasks and projects',
      icon: Icons.task,
      iconColor: Color(0xFF007AFF),
      connected: false,
      category: 'productivity',
      scopes: [],
    ),
    Integration(
      id: 'meta',
      name: 'Meta',
      description: 'Manage your meta account',
      icon: Icons.facebook,
      iconColor: Color(0xFF1877F2),
      connected: false,
      category: 'social',
      scopes: [],
    ),
    Integration(
      id: 'stripe',
      name: 'Stripe',
      description: 'Manage your stripe account',
      icon: Icons.credit_card,
      iconColor: Color(0xFF007AFF),
      connected: false,
      category: 'payment',
      scopes: [],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeGoogleSignIn();
  WidgetsBinding.instance.addObserver(this);   // <-- add this

    _loadCurrentUser();
    _loadIntegrationStatus();
  }

 @override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.resumed) {
    _loadIntegrationStatus();  // <-- hits only when user RETURNS to app
  }
}

@override
void dispose() {
  WidgetsBinding.instance.removeObserver(this);
  super.dispose();
}


  Future<void> _loadIntegrationStatus() async {
    try {
      final result = await getIt<ApiClient>().getIntegrationStatus();

      if (result['statusCode'] == 200) {
        final Map<String, dynamic> data =
            result['data']['data'] as Map<String, dynamic>;

        setState(() {
          for (final integration in integrations) {
            switch (integration.id) {
              case 'google-calendar':
                integration.connected = data['google'] ?? false;
                break;
              case 'gohighlevel':
                integration.connected = data['ghl'] ?? false;
                break;
              case 'fireflies':
                integration.connected = data['fireflies'] ?? false;
                break;
              case 'asana':
                integration.connected = data['asana'] ?? false;
                break;
              case 'meta':
                integration.connected = data['meta'] ?? false;
                break;
              case 'stripe':
                integration.connected = data['stripe'] ?? false;
                break;
            }
          }
          _isLoadingStatus = false; // <-- SUCCESS
        });
      } else {
        setState(
          () => _isLoadingStatus = false,
        ); // <-- ERROR (still stop spinner)
      }
    } catch (e) {
      debugPrint('Failed to load integration status: $e');
      setState(() => _isLoadingStatus = false); // <-- ERROR
    }
  }

  Future<void> _loadCurrentUser() async {
    try {
      final result = await getIt<ApiClient>().getCurrentUser();
      if (result['statusCode'] == 200) {
        final user = result['data']['data'] as Map<String, dynamic>;
        setState(() => _currentUserId = user['ID'] as int);
      }
    } catch (e) {
      debugPrint("Error fetching current user: $e");
    }
  }

  void _showFirefliesKeyPopup() {
    final TextEditingController keyController = TextEditingController();

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Dialog(
            backgroundColor: Colors.white.withOpacity(0.15),
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(horizontal: 32),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: Colors.white.withOpacity(0.2)),
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Connect Fireflies",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Paste your Fireflies API key below to enable transcription.",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 20),

                  // Input Box
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white.withOpacity(0.08),
                      border: Border.all(color: Colors.white.withOpacity(0.15)),
                    ),
                    child: TextField(
                      controller: keyController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: "Enter API Key",
                        hintStyle: TextStyle(color: Colors.white54),
                        border: InputBorder.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Buttons Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          "Cancel",
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () async {
                          final apiKey = keyController.text.trim();
                          if (apiKey.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("API Key cannot be empty"),
                              ),
                            );
                            return;
                          }

                          Navigator.pop(context);
                          await _saveFirefliesKey(apiKey);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                          child: const Text(
                            "Save",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveFirefliesKey(String apiKey) async {
    try {
      final result = await getIt<ApiClient>().saveFirefliesKey(
        userId: _currentUserId,
        apiKey: apiKey,
      );

      if (result['statusCode'] != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['data']['message'] ?? 'API error')),
        );
        return;
      }

      await _storage.write(key: 'fireflies_api_key', value: apiKey);

      setState(() {
        integrations.firstWhere((i) => i.id == 'fireflies').connected = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Fireflies connected successfully")),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error connecting Fireflies: $e")));
    }
  }

  Future<void> _initializeGoogleSignIn() async {
    try {
      setState(() => _isInitializing = true);
      await _googleSignIn.initialize(
        clientId:
            '452755436213-kls0a46r5v4sido47mlvccr17s4uu90q.apps.googleusercontent.com',
        serverClientId:
            '452755436213-iqqujbpasvp3o0qn8b7rf6u5uasldbbe.apps.googleusercontent.com',
      );
      await _checkStoredTokens();
      _googleSignIn.authenticationEvents.listen((event) {
        setState(() {
          if (event is GoogleSignInAuthenticationEventSignIn) {
            _currentUser = event.user;
            _updateIntegrationStatus(true, ['google-calendar']);
          } else if (event is GoogleSignInAuthenticationEventSignOut) {
            _currentUser = null;
            _updateIntegrationStatus(false, ['google-calendar']);
          } else if (event is Error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Google Sign-In error: $event')),
            );
          }
        });
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Initialization failed: $e')));
    } finally {
      setState(() => _isInitializing = false);
    }
  }

  Future<void> _checkStoredTokens() async {
    for (var integration in integrations) {
      final accessToken = await _storage.read(
        key: '${integration.id}_access_token',
      );
      if (accessToken != null) {
        setState(() {
          integration.connected = true;
        });
      }
    }
  }

  void _updateIntegrationStatus(bool connected, List<String> integrationIds) {
    setState(() {
      for (var integration in integrations) {
        if (integrationIds.contains(integration.id)) {
          integration.connected = connected;
        }
      }
    });
  }

  void _showTokensDialog(
    String integrationId,
    String accessToken,
    String? serverAuthCode,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.white.withOpacity(0.5)),
          ),
          contentPadding: const EdgeInsets.all(16),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$integrationId Tokens',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Text(
                        'Access Token: $accessToken',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, color: Color(0xFF3B82F6)),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: accessToken));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Access Token copied to clipboard'),
                        ),
                      );
                    },
                  ),
                ],
              ),
              if (serverAuthCode != null) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Text(
                          'Server Auth Code: $serverAuthCode',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, color: Color(0xFF3B82F6)),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: serverAuthCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Server Auth Code copied to clipboard',
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x66E5E7EB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleGoogleSignIn(Integration integration) async {
    try {
      GoogleSignInAccount? account = _currentUser;
      if (account == null) {
        account = await _googleSignIn.authenticate(
          scopeHint: integration.scopes,
        );
        setState(() => _currentUser = account);
      }

      final authClient = account.authorizationClient;
      final serverAuth = await authClient.authorizeServer(integration.scopes);
      final authCode = serverAuth?.serverAuthCode;

      if (authCode == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to get auth code')),
        );
        return;
      }

      // ✅ Call backend like Android
      final result = await getIt<ApiClient>().googleAccessTokenMobile(
        userId: _currentUserId,
        authCode: authCode,
      );

      if (result['statusCode'] != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['data']['message'] ?? 'API error')),
        );
        return;
      }

      final tokenInfo = result['data']['data'];

      await _storeTokens(
        integration.id,
        tokenInfo["access_token"],
        tokenInfo["refresh_token"],
      );

      setState(() => integration.connected = true);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google Calendar connected!')),
      );
    } catch (e) {
      debugPrint("Google error: $e");
    }
  }

  Future<void> _storeTokens(
    String integrationId,
    String accessToken,
    String? serverAuthCode,
  ) async {
    await _storage.write(
      key: '${integrationId}_access_token',
      value: accessToken,
    );
    if (serverAuthCode != null) {
      await _storage.write(
        key: '${integrationId}_server_auth_code',
        value: serverAuthCode,
      );
    }
  }

  Future<void> _sendTokensToApi(
    String integrationId,
    String accessToken,
    String serverAuthCode,
    String scopes,
  ) async {
    try {
      print("serverAuthCode: $serverAuthCode");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Tokens sent for $integrationId')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending tokens to API: $e')),
      );
    }
  }

  Future<void> _resetConnection(String integrationId) async {
    try {
      await _storage.delete(key: '${integrationId}_access_token');
      await _storage.delete(key: '${integrationId}_server_auth_code');
      if (integrationId == 'google-calendar') {
        await _googleSignIn.signOut();
        setState(() {
          _currentUser = null;
          _updateIntegrationStatus(false, ['google-calendar']);
        });
      } else if (integrationId == 'fireflies') {
        await _storage.delete(key: 'fireflies_api_key');
        setState(() {
          integrations.firstWhere((i) => i.id == integrationId).connected =
              false;
        });
      } else {
        setState(() {
          integrations.firstWhere((i) => i.id == integrationId).connected =
              false;
        });
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Connection reset')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Reset failed: $e')));
    }
  }


  Future<void> _handleAsanaSignIn(Integration integration) async {
    await _launchIntegrationUrl(
      requester: () => getIt<ApiClient>().handleAsanaSignIn(),
      integrationName: integration.name,
    );
  }

  Future<void> _handleMetaSignIn(Integration integration) async {
    await _launchIntegrationUrl(
      requester: () => getIt<ApiClient>().handleMetaSignIn(),
      integrationName: integration.name,
    );
  }

  Future<void> _handleStripeSignIn(Integration integration) async {
    await _launchIntegrationUrl(
      requester: () => getIt<ApiClient>().handleStripeSignIn(),
      integrationName: integration.name,
    );
  }

  Future<void> _launchIntegrationUrl({
    required Future<Map<String, dynamic>> Function() requester,
    required String integrationName,
  }) async {
    try {
      final result = await requester();
      print("result: ${result['data']}");
      if (result['statusCode'] == 200) {
        final url = _extractIntegrationUrl(result['data']);
        if (url != null) {
          await _launchURL(url);
          return;
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to open $integrationName connection.'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error launching $integrationName: $e'),
        ),
      );
    }
  }

  String? _extractIntegrationUrl(dynamic responseData) {
    if (responseData is Map<String, dynamic>) {
      final directUrl = responseData['url'];
      if (directUrl is String && directUrl.isNotEmpty) {
        return directUrl;
      }
      final nestedData = responseData['data'];
      if (nestedData is Map<String, dynamic>) {
        final nestedUrl = nestedData['url'];
        if (nestedUrl is String && nestedUrl.isNotEmpty) {
          return nestedUrl;
        }
      }
    }
    return null;
  }


  
@override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgColor,
   appBar: AppBar(
  centerTitle: false,   // <-- add this
  leading: IconButton(
    icon: const Icon(Icons.arrow_back, color: Colors.black),
    onPressed: () => context.go('/other'),
  ),
  title: const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Integrations',
        style: TextStyle(
          color: Colors.black,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      Text(
        'Connected apps and services',
        style: TextStyle(
          color: Colors.grey,
          fontSize: 14,
        ),
      ),
    ],
  ),
  backgroundColor: Colors.white,
  elevation: 0,
  systemOverlayStyle: SystemUiOverlayStyle(
    statusBarBrightness: Brightness.light,
  ),
),    body: _isInitializing
          ? const Center(child: CircularProgressIndicator())
          : _isLoadingStatus
              ? ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: integrations.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, __) => const _SkeletonCard(),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: integrations.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final integration = integrations[index];
                    return GestureDetector(
                      onTap: () {
                        if (integration.id == 'google-calendar') {
                          _handleGoogleSignIn(integration);
                        } else if (integration.id == 'gohighlevel') {
                          _launchURL(
                              'https://marketplace.gohighlevel.com/oauth/chooselocation?...'); // (your long URL)
                        } else if (integration.id == 'fireflies') {
                          _showFirefliesKeyPopup();
                        } else if (integration.id == 'asana') {
                          _handleAsanaSignIn(integration);
                        } else if (integration.id == 'meta') {
                          _handleMetaSignIn(integration);
                        } else if (integration.id == 'stripe') {
                          _handleStripeSignIn(integration);
                        }
                      },
                      child: IntegrationCard(
                        // You can replace with actual asset paths later
                        icon: 'assets/${integration.id.replaceAll('-', '_')}.png',
                        title: integration.name,
                        subtitle: integration.description,
                        status: integration.connected
                            ? 'Connected'
                            : 'Not Connected',
                        statusColor:
                            integration.connected ? Colors.green : AppColors.redColor,
                      ),
                    );
                  },
                ),
    );
  }
}

// New clean card exactly matching the design you provided
class IntegrationCard extends StatelessWidget {
  const IntegrationCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.statusColor,
  });

  final String icon;
  final String title;
  final String subtitle;
  final String status;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                image: DecorationImage(
                  image: AssetImage(icon),
                  fit: BoxFit.cover,
                  onError: (_, __) => const Icon(Icons.broken_image),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    status,
                    style: TextStyle(
                      fontSize: 12,
                      color: statusColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

// Skeleton card for loading state (matches new design)
class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 16,
                    width: 140,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 14,
                    width: double.infinity,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 12,
                    width: 80,
                    color: Colors.grey[300],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}