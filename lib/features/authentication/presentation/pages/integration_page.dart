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
      imagePath: 'assets/google_calendar.png',

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
      imagePath: 'assets/gohighlevel.png',
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
      imagePath: 'assets/fireflies.png',
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
      imagePath: 'assets/asana.png',
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
      imagePath: 'assets/meta.png',
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
      imagePath: 'assets/stripe.png',
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



    Future<void> _disconnectIntegrationApi(String provider) async {
    try {
      final result =
          await getIt<ApiClient>().disconnectIntegration(provider: provider);
      if (result['statusCode'] == 200) {
        // server-side disconnect successful; clear local tokens
        await _resetConnection(provider);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['data']['message'] ?? 'Disconnect failed')),
        );
      }
    } catch (e) {
      debugPrint('Disconnect error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Disconnect failed: $e')),
      );
    }
  }


   Future<void> _onToggleIntegration(Integration integration, bool newValue) async {
    if (newValue) {
      // Turn ON -> call existing connect flow (Reconnect = A)
      if (integration.id == 'google-calendar') {
        await _handleGoogleSignIn(integration);
      } else if (integration.id == 'gohighlevel') {
        await _launchURL(
            'https://marketplace.gohighlevel.com/oauth/chooselocation?response_type=code&redirect_uri=https%3A%2F%2Fmaya.ravan.ai%2Fapi%2Fcrm%2Fleadconnector%2Fcode&client_id=68755e91a1a7f90cd15877d5-me8gas4x&scope=socialplanner%2Fpost.readonly+saas%2Flocation.write+socialplanner%2Foauth.readonly+saas%2Flocation.read+socialplanner%2Foauth.write+conversations%2Freports.readonly+calendars%2Fresources.write+campaigns.readonly+conversations.readonly+conversations.write+conversations%2Fmessage.readonly+conversations%2Fmessage.write+calendars%2Fgroups.readonly+calendars%2Fgroups.write+calendars%2Fresources.readonly+calendars%2Fevents.write+calendars%2Fevents.readonly+calendars.write+calendars.readonly+businesses.write+businesses.readonly+conversations%2Flivechat.write+contacts.readonly+contacts.write+objects%2Fschema.readonly+objects%2Fschema.write+objects%2Frecord.readonly+objects%2Frecord.write+associations.write+associations.readonly+associations%2Frelation.readonly+associations%2Frelation.write+courses.write+courses.readonly+forms.readonly+forms.write+invoices.readonly+invoices.write+invoices%2Fschedule.readonly+invoices%2Fschedule.write+invoices%2Ftemplate.readonly+invoices%2Ftemplate.write+invoices%2Festimate.readonly+invoices%2Festimate.write+links.readonly+lc-email.readonly+links.write+locations%2FcustomValues.readonly+medias.write+medias.readonly+locations%2Ftemplates.readonly+locations%2Ftags.write+funnels%2Fredirect.readonly+funnels%2Fpage.readonly+funnels%2Ffunnel.readonly+oauth.write+oauth.readonly+opportunities.readonly+opportunities.write+socialplanner%2Fpost.write+socialplanner%2Faccount.readonly+socialplanner%2Faccount.write+socialplanner%2Fcsv.readonly+socialplanner%2Fcsv.write+socialplanner%2Fcategory.readonly+socialplanner%2Ftag.readonly+store%2Fshipping.readonly+socialplanner%2Fstatistics.readonly+store%2Fshipping.write+store%2Fsetting.readonly+surveys.readonly+store%2Fsetting.write+workflows.readonly+emails%2Fschedule.readonly+emails%2Fbuilder.write+emails%2Fbuilder.readonly+wordpress.site.readonly+blogs%2Fpost.write+blogs%2Fpost-update.write+blogs%2Fcheck-slug.readonly+blogs%2Fcategory.readonly+blogs%2Fauthor.readonly+socialplanner%2Fcategory.write+socialplanner%2Ftag.write+blogs%2Fposts.readonly+blogs%2Flist.readonly+charges.readonly+charges.write+marketplace-installer-details.readonly+twilioaccount.read+documents_contracts%2Flist.readonly+documents_contracts%2FsendLink.write+documents_contracts_template%2FsendLink.write+documents_contracts_template%2Flist.readonly+products%2Fcollection.write+products%2Fcollection.readonly+products%2Fprices.write+products%2Fprices.readonly+products.write+products.readonly+payments%2Fcustom-provider.write+payments%2Fcoupons.write+payments%2Fcustom-provider.readonly+payments%2Fcoupons.readonly+payments%2Fsubscriptions.readonly+payments%2Ftransactions.readonly+payments%2Fintegration.write+payments%2Fintegration.readonly+payments%2Forders.write+payments%2Forders.readonly+funnels%2Fredirect.write+funnels%2Fpagecount.readonly&version_id=68755e91a1a7f90cd15877d5'); // keep your long URL
      } else if (integration.id == 'fireflies') {
        _showFirefliesKeyPopup();
      } else if (integration.id == 'asana') {
        await _handleAsanaSignIn(integration);
      } else if (integration.id == 'meta') {
        await _handleMetaSignIn(integration);
      } else if (integration.id == 'stripe') {
        await _handleStripeSignIn(integration);
      }
    } else {
      // Turn OFF -> call disconnect API then reset local tokens/storage
      await _disconnectIntegrationApi(integration.id);
    }
  }


  List<dynamic> _extractAsanaWorkspaces(Map<String, dynamic> raw) {
  if (raw['data'] is List) {
    // Case 1: "data": [ ... ]
    return raw['data'];
  }

  if (raw['data'] is Map && raw['data']['data'] is List) {
    // Case 2: "data": { "data": [ ... ] }
    return raw['data']['data'];
  }

  return [];
}



void _openManageSheet(Integration integration) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Wrap(
            children: [
              ListTile(
                title: Text('Manage ${integration.name}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Reconnect'),
                onTap: () async {
                  Navigator.of(context).pop();
                  // Reconnect uses existing flows (A)
                  await _onToggleIntegration(integration, true);
                },
              ),
if (integration.id == 'asana')
  FutureBuilder<Map<String, dynamic>>(
    future: getIt<ApiClient>().getAsanaWorkspace(userId: _currentUserId),
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        );
      }

      final raw = snapshot.data!;
      final workspaces = _extractAsanaWorkspaces(raw);

      if (workspaces.isEmpty) {
        return const Padding(
          padding: EdgeInsets.all(16),
          child: Text('No workspaces found'),
        );
      }

      return ExpansionTile(
        leading: const Icon(Icons.workspaces_filled),
        title: const Text('Workspace'),
        children: workspaces.map((ws) {
          return ListTile(
            title: Text(ws['name']),
            onTap: () async {
              await getIt<ApiClient>().setAsanaWorkspace(
                userId: _currentUserId,
                workspaceId: ws['gid'],
              );

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Workspace set: ${ws['name']}')),
              );
            },
          );
        }).toList(),
      );
    },
  ),
   const SizedBox(height: 12),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    backgroundColor: const Color(0xFFE5E7EB),
                    foregroundColor: const Color(0xFF1F2937),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
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


Widget _buildIntegrationTile(Integration integration) {
  return Card(
    elevation: 0.5,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ------ MAIN ROW (icon, text, switch)
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: integration.iconColor.withOpacity(0.12),
                ),
                child: Container(
  width: 44,
  height: 44,
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(8),
    color: Colors.grey.shade200,
  ),
  child: ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: Image.asset(
      integration.imagePath,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) =>
          const Icon(Icons.broken_image, color: Colors.red),
    ),
  ),
),

              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      integration.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      integration.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      integration.connected ? 'Connected' : 'Not Connected',
                      style: TextStyle(
                        fontSize: 12,
                        color: integration.connected
                            ? Colors.green
                            : Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              Switch(
                value: integration.connected,
                onChanged: (value) async {
                  await _onToggleIntegration(integration, value);
                  setState(() {
                    integration.connected = value;
                  });
                },
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ------ MANAGE BUTTON (inside the card, full white background)
          InkWell(
            onTap: () => _openManageSheet(integration),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.settings, size: 18, color: Colors.grey),
                  SizedBox(width: 8),
                  Text(
                    'Manage',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  
@override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgColor,
      appBar: AppBar(
        centerTitle: false,
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
      ),
      body: _isInitializing
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
                    return _buildIntegrationTile(integration);
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