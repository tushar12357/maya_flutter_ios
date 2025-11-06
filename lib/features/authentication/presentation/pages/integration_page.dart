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
    final Uri uri = Uri.parse(Uri.encodeFull(url));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $url';
    }
  } catch (e) {
    print('Error launching URL: $e');
  }
}

class _IntegrationsPageState extends State<IntegrationsPage> {
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  GoogleSignInAccount? _currentUser;
  bool _isInitializing = false;
  final _storage = const FlutterSecureStorage();

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
        'email',
        'profile',
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
  ];

  @override
  void initState() {
    super.initState();
    _initializeGoogleSignIn();
  }

  Future<void> _initializeGoogleSignIn() async {
    try {
      setState(() => _isInitializing = true);
      await _googleSignIn.initialize(
        clientId:
            '452755436213-5hcr78ntadqv75462th9qb3oue5hdgtg.apps.googleusercontent.com',
        serverClientId:
            '452755436213-5d2ujo6g7d4tthk86adluob7q4frege6.apps.googleusercontent.com',
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
        setState(() {
          _currentUser = account;
        });
      }

      final authClient = account.authorizationClient;
      final serverAuth = await authClient.authorizeServer(integration.scopes);
      final auth = await authClient.authorizeScopes(integration.scopes);
      if (serverAuth == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to retrieve server auth code')),
        );
        return;
      }

      _showTokensDialog(
        integration.id,
        auth.accessToken,
        serverAuth.serverAuthCode,
      );

      await _sendTokensToApi(
        integration.id,
        auth.accessToken,
        serverAuth.serverAuthCode,
        integration.scopes.join(' '),
      );
      await _storeTokens(
        integration.id,
        auth.accessToken,
        serverAuth.serverAuthCode,
      );

      setState(() {
        integration.connected = true;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Successfully connected!')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sign-in error: $e')));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background color
          Container(color: const Color(0xFF111827)),
          // Gradient overlay
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x992A57E8), Colors.transparent],
              ),
            ),
          ),
          // Main content
          SafeArea(
            child: _isInitializing
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : Column(
                    children: [
                      // Custom Header with Back Button
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => context.go('/other'),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF111827,
                                  ).withOpacity(0.8),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.1),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.arrow_back,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Integrations',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const Spacer(),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: const Text(
                          'Connected apps and services',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color.fromRGBO(189, 189, 189, 1),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: integrations.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final integration = integrations[index];
                            return GestureDetector(
                              onTap: () {
                                if (integration.connected) {
                                  _resetConnection(integration.id);
                                } else {
                                  if (integration.id == 'google-calendar') {
                                    _handleGoogleSignIn(integration);
                                  } else if (integration.id == 'gohighlevel') {
                                    _launchURL(
                                      'https://marketplace.gohighlevel.com/oauth/chooselocation?response_type=code&redirect_uri=https%3A%2F%2Fmaya.ravan.ai%2Fapi%2Fcrm%2Fleadconnector%2Fcode&client_id=68755e91a1a7f90cd15877d5-me8gas4x&scope=socialplanner%2Fpost.readonly+saas%2Flocation.write+socialplanner%2Foauth.readonly+saas%2Flocation.read+socialplanner%2Foauth.write+conversations%2Freports.readonly+calendars%2Fresources.write+campaigns.readonly+conversations.readonly+conversations.write+conversations%2Fmessage.readonly+conversations%2Fmessage.write+calendars%2Fgroups.readonly+calendars%2Fgroups.write+calendars%2Fresources.readonly+calendars%2Fevents.write+calendars%2Fevents.readonly+calendars.write+calendars.readonly+businesses.write+businesses.readonly+conversations%2Flivechat.write+contacts.readonly+contacts.write+objects%2Fschema.readonly+objects%2Fschema.write+objects%2Frecord.readonly+objects%2Frecord.write+associations.write+associations.readonly+associations%2Frelation.readonly+associations%2Frelation.write+courses.write+courses.readonly+forms.readonly+forms.write+invoices.readonly+invoices.write+invoices%2Fschedule.readonly+invoices%2Fschedule.write+invoices%2Ftemplate.readonly+invoices%2Ftemplate.write+invoices%2Festimate.readonly+invoices%2Festimate.write+links.readonly+lc-email.readonly+links.write+locations%2FcustomValues.readonly+medias.write+medias.readonly+locations%2Ftemplates.readonly+locations%2Ftags.write+funnels%2Fredirect.readonly+funnels%2Fpage.readonly+funnels%2Ffunnel.readonly+oauth.write+oauth.readonly+opportunities.readonly+opportunities.write+socialplanner%2Fpost.write+socialplanner%2Faccount.readonly+socialplanner%2Faccount.write+socialplanner%2Fcsv.readonly+socialplanner%2Fcsv.write+socialplanner%2Fcategory.readonly+socialplanner%2Ftag.readonly+store%2Fshipping.readonly+socialplanner%2Fstatistics.readonly+store%2Fshipping.write+store%2Fsetting.readonly+surveys.readonly+store%2Fsetting.write+workflows.readonly+emails%2Fschedule.readonly+emails%2Fbuilder.write+emails%2Fbuilder.readonly+wordpress.site.readonly+blogs%2Fpost.write+blogs%2Fpost-update.write+blogs%2Fcheck-slug.readonly+blogs%2Fcategory.readonly+blogs%2Fauthor.readonly+socialplanner%2Fcategory.write+socialplanner%2Ftag.write+blogs%2Fposts.readonly+blogs%2Flist.readonly+charges.readonly+charges.write+marketplace-installer-details.readonly+twilioaccount.read+documents_contracts%2Flist.readonly+documents_contracts%2FsendLink.write+documents_contracts_template%2FsendLink.write+documents_contracts_template%2Flist.readonly+products%2Fcollection.write+products%2Fcollection.readonly+products%2Fprices.write+products%2Fprices.readonly+products.write+products.readonly+payments%2Fcustom-provider.write+payments%2Fcoupons.write+payments%2Fcustom-provider.readonly+payments%2Fcoupons.readonly+payments%2Fsubscriptions.readonly+payments%2Ftransactions.readonly+payments%2Fintegration.write+payments%2Fintegration.readonly+payments%2Forders.write+payments%2Forders.readonly+funnels%2Fredirect.write+funnels%2Fpagecount.readonly&version_id=68755e91a1a7f90cd15877d5',
                                    );
                                  }
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF2D4A6F,
                                  ).withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.1),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Icon
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: integration.iconColor
                                            .withOpacity(0.2),
                                      ),
                                      child: Icon(
                                        integration.icon,
                                        color: integration.iconColor,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            integration.name,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            integration.connected
                                                ? 'Connected'
                                                : 'Not Connected',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: integration.connected
                                                  ? Colors.white
                                                  : const Color(0xFFEF4444),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right,
                                      color: const Color.fromRGBO(
                                        189,
                                        189,
                                        189,
                                        1,
                                      ),
                                      size: 24,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
