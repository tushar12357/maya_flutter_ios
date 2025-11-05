import 'package:Maya/core/network/api_client.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

// ------------------------------------------------------------------
// USER MODEL – matches your API response
// ------------------------------------------------------------------
class User {
  final int? id; // <-- Now nullable
  final String firstName;
  final String lastName;
  final String email;
  final String phone_number;
  final String apiKey;
  final String deviceId;

  User({
    this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone_number,
    required this.apiKey,
    required this.deviceId,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final data = json['data']['data'] as Map<String, dynamic>;
    print(data);
    return User(
      id: data['ID'] as int?, // <-- Safe cast
      firstName: data['first_name'] as String,
      lastName: data['last_name'] as String,
      email: data['email'] as String,
      phone_number: data['phone_number'] as String,
      apiKey: data['api_key'] as String,
      deviceId: data['device_id'] as String,
    );
  }

  String get fullName => '$firstName $lastName';
  String get initials =>
      firstName.isNotEmpty ? firstName[0].toUpperCase() : 'U';
}

// ------------------------------------------------------------------
// OTHER PAGE – fetches user from ApiClient
// ------------------------------------------------------------------
class OtherPage extends StatefulWidget {
  const OtherPage({super.key});

  @override
  State<OtherPage> createState() => _OtherPageState();
}

class _OtherPageState extends State<OtherPage> {
  User? _user;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchUser();
  }

  Future<void> _fetchUser() async {
    try {
      // Use your real ApiClient
      final result = await GetIt.I<ApiClient>().getCurrentUser();

      if (result['statusCode'] == 200 && result['data']['success'] == true) {
        setState(() {
          _user = User.fromJson(result);
          _isLoading = false;
        });
      } else {
        throw Exception(result['data']['message'] ?? 'Failed to load user');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

                  // Profile Section – Real Data
                  _buildProfileSection(context),

                  const SizedBox(height: 16),
                  _buildFeatureTiles(context),
                  const SizedBox(height: 32),
                  _buildLogoutButton(context),
                ],
              ),
            ),
          ),

          // Loading / Error Overlay
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            )
          else if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Failed to load user: $_error',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------
  // PROFILE SECTION – uses real user data
  // --------------------------------------------------------------
  Widget _buildProfileSection(BuildContext context) {
    final name = _user?.fullName ?? 'Kaarthi';
    final email = _user?.email ?? 'kaarthi@example.com';
    final avatarLetter = _user?.initials ?? 'K';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2D4A6F).withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2A57E8), Color(0xFF1D4ED8)],
              ),
            ),
            child: Center(
              child: Text(
                avatarLetter,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color.fromRGBO(189, 189, 189, 1),
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () => context.go('/profile'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF2A57E8),
              side: const BorderSide(color: Color(0xFF2A57E8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Edit',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------
  // FEATURE TILES (vertical list)
  // --------------------------------------------------------------
  Widget _buildFeatureTiles(BuildContext context) {
    return Column(
      children: [
        _buildFeatureTile(
          context: context,
          route: '/generations',
          icon: Icons.add,
          iconColor: const Color(0xFF2A57E8),
          backgroundColor: const Color(0xFF2A57E8),
          title: 'Generations',
        ),
        const SizedBox(height: 12),
        _buildFeatureTile(
          context: context,
          route: '/reminders',
          icon: Icons.notifications_outlined,
          iconColor: const Color(0xFF2A57E8),
          backgroundColor: const Color(0xFF2A57E8),
          title: 'Reminders',
        ),
        const SizedBox(height: 12),
        _buildFeatureTile(
          context: context,
          route: '/todos',
          icon: Icons.check,
          iconColor: const Color(0xFF2A57E8),
          backgroundColor: const Color(0xFF2A57E8),
          title: 'To-Do',
        ),
        const SizedBox(height: 12),
        _buildFeatureTile(
          context: context,
          route: '/integrations',
          icon: Icons.settings_outlined,
          iconColor: const Color(0xFF2A57E8),
          backgroundColor: const Color(0xFF2A57E8),
          title: 'Integrations',
        ),
      ],
    );
  }

  Widget _buildFeatureTile({
    required BuildContext context,
    required String route,
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    required String title,
  }) {
    return GestureDetector(
      onTap: () => context.go(route),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2D4A6F).withOpacity(0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: backgroundColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 24, color: iconColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: Color(0xFF6B7280)),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------
  // LOGOUT BUTTON
  // --------------------------------------------------------------
  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => context.go('/login'),
        icon: const Icon(Icons.logout, color: Colors.white, size: 18),
        label: const Text(
          'Log out',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromARGB(255, 207, 25, 25),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}
