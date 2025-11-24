import 'package:Maya/core/constants/colors.dart';
import 'package:Maya/core/network/api_client.dart';
import 'package:Maya/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:Maya/features/authentication/presentation/bloc/auth_event.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';



// ================================================================
// USER MODEL (unchanged)
// ================================================================
class User {
  final int? id;
  final String firstName;
  final String lastName;
  final String email;
  final String phone_number;
  final String apiKey;
  final String deviceId;
  final String profile_image_url;

  User({
    this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone_number,
    required this.apiKey,
    required this.deviceId,
    required this.profile_image_url,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final data = json['data']['data'] as Map<String, dynamic>;
    return User(
      id: data['ID'] as int?,
      firstName: data['first_name'] as String,
      lastName: data['last_name'] as String,
      email: data['email'] as String,
      phone_number: data['phone_number'] as String,
      apiKey: data['api_key'] as String,
      deviceId: data['device_id'] as String,
      profile_image_url: data['profile_image_url'] as String,
    );
  }

  String get fullName => '$firstName $lastName';
  String get initials => firstName.isNotEmpty ? firstName[0].toUpperCase() : 'U';
}

// ================================================================
// OTHER PAGE - Full Profile Screen with Your Design & Colors
// ================================================================
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
      backgroundColor: AppColors.bgColor,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ==================== HEADER ====================
                  _buildHeader(),
                  const SizedBox(height: 25),

                  // ==================== FEATURE TILES ====================
                  _buildTile(
                    title: "Generations",
                    icon: Icons.auto_awesome,
                    color: const Color(0xFFE3CCF8), // Pastel purple (as in original design)
                    onTap: () => context.go('/generations'),
                  ),
                  _buildTile(
                    title: "Reminders",
                    icon: Icons.lock_clock,
                    color: const Color(0xFFCFE9FF), // Pastel blue
                    onTap: () => context.go('/reminders'),
                  ),
                  _buildTile(
                    title: "To-Do",
                    icon: Icons.check_circle_outline,
                    color: const Color(0xFFCFF5E1), // Pastel green
                    onTap: () => context.go('/todos'),
                  ),
                  _buildTile(
                    title: "Integrations",
                    icon: Icons.link,
                    color: const Color(0xFFFFE6C9), // Pastel orange
                    onTap: () => context.go('/integrations'),
                  ),
                  _buildTile(
                    title: "Energy",
                    icon: Icons.energy_savings_leaf_outlined,
color: const Color(0xff00C75A).withOpacity(0.2),                    onTap: () {
                      // Replace with your actual Energy screen route
                      context.go('/energy');
                    },
                  ),

                  const SizedBox(height: 30),

                  // ==================== LOGOUT BUTTON ====================
                  InkWell(
                    onTap: () async {
                      BlocProvider.of<AuthBloc>(context).add(LogoutRequested());
                      await Future.delayed(const Duration(milliseconds: 100));
                      context.go('/login');
                    },
                    child: Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: const LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            AppColors.primary,   // #F97418
                            AppColors.secondary, // #ECB48D
                          ],
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout, color: Colors.white),
                          SizedBox(width: 12),
                          Text(
                            "Logout",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),

            // ==================== LOADING OVERLAY ====================
            if (_isLoading)
              Container(
                color: Colors.black54,
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 3,
                  ),
                ),
              ),

            // ==================== ERROR OVERLAY ====================
            if (_error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.redColor, size: 64),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load profile',
                        style: TextStyle(
                          color: AppColors.balckClr,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: TextStyle(color: AppColors.redColor),
                        textAlign: TextAlign.center,
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

  // ==================== HEADER WITH AVATAR & EDIT ====================
  Widget _buildHeader() {
    final avatarUrl = _user?.profile_image_url;
    final initials = _user?.initials ?? 'U';

    return Row(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: AppColors.greyColor,
          backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
              ? CachedNetworkImageProvider(avatarUrl) as ImageProvider
              : null,
          child: (avatarUrl == null || avatarUrl.isEmpty)
              ? Text(
                  initials,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.balckClr,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _user?.fullName ?? 'Loading...',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.balckClr,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _user?.email ?? '',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 2),
              const Text(
                "Member since October 2025",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: () => context.go('/profile'), // or your edit profile route
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              "Edit",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==================== REUSABLE TILE ====================
  Widget _buildTile({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 56,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 24, color: AppColors.balckClr.withOpacity(0.85)),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.balckClr,
              ),
            ),
          ],
        ),
      ),
    );
  }
}