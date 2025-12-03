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
// OTHER PAGE - Full Profile Screen (clean unified cards)
// ================================================================
class OtherPage extends StatefulWidget {
  const OtherPage({super.key});

  @override
  State<OtherPage> createState() => _OtherPageState();
}

class _OtherPageState extends State<OtherPage> {
  User? _user;
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
        });
      } else {
        throw Exception(result['data']['message'] ?? 'Failed to load user');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgColor,
      body: SafeArea(
        child: _error != null
            ? _buildErrorState()
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ==================== HEADER ====================
                    _buildHeader(),
                    const SizedBox(height: 25),

                    // ==================== UNIFIED FEATURE CARDS ====================
                    _buildFeatureCard(
                      title: "Generations",
                      icon: Icons.auto_awesome,
                      onTap: () => context.go('/generations'),
                    ),
                    _buildFeatureCard(
                      title: "Reminders",
                      icon: Icons.lock_clock,
                      onTap: () => context.go('/reminders'),
                    ),
                    _buildFeatureCard(
                      title: "To-Do",
                      icon: Icons.check_circle_outline,
                      onTap: () => context.go('/todos'),
                    ),
                    _buildFeatureCard(
                      title: "Integrations",
                      icon: Icons.link,
                      onTap: () => context.go('/integrations'),
                    ),
                    _buildFeatureCard(
                      title: "Energy",
                      icon: Icons.energy_savings_leaf_outlined,
                      onTap: () => context.go('/energy'),
                    ),

                    const SizedBox(height: 20),

                    // ==================== LOGOUT BUTTON ====================
                    _buildLogoutButton(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
      ),
    );
  }

  // -----------------------------------------------------------------
  // ERROR STATE
  // -----------------------------------------------------------------
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.redColor, size: 64),
            const SizedBox(height: 16),
            const Text(
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
              style: const TextStyle(color: AppColors.redColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() => _error = null);
                _fetchUser();
              },
              child: const Text("Retry"),
            ),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------------------
  // HEADER (with skeleton)
  // -----------------------------------------------------------------
  Widget _buildHeader() {
    if (_user == null) {
      return Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.borderColor.withOpacity(0.3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 20,
                  width: 180,
                  decoration: BoxDecoration(
                    color: AppColors.borderColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 14,
                  width: 220,
                  decoration: BoxDecoration(
                    color: AppColors.borderColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 12,
                  width: 140,
                  decoration: BoxDecoration(
                    color: AppColors.borderColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.borderColor.withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ],
      );
    }

    final avatarUrl = _user!.profile_image_url;
    final initials = _user!.initials;

    return Row(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: AppColors.greyColor,
          backgroundImage: avatarUrl.isNotEmpty
              ? CachedNetworkImageProvider(avatarUrl) as ImageProvider
              : null,
          child: avatarUrl.isEmpty
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
                _user!.fullName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.balckClr,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _user!.email,
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
          onTap: () => context.go('/profile'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary,
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

  // -----------------------------------------------------------------
  // REUSABLE UNIFIED FEATURE CARD (same style as TasksPage cards)
  // -----------------------------------------------------------------
  Widget _buildFeatureCard({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final bool isLoading = _user == null && _error == null;

    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.whiteClr,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon container (same subtle background as task cards)
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.balckClr,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 18,
              color: Colors.grey.withOpacity(0.6),
            ),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------------------
  // LOGOUT BUTTON (unchanged, still gradient – looks great)
  // -----------------------------------------------------------------
  Widget _buildLogoutButton() {
    final bool isLoading = _user == null && _error == null;

    return InkWell(
      onTap: isLoading
          ? null
          : () async {
              BlocProvider.of<AuthBloc>(context).add(LogoutRequested());
              await Future.delayed(const Duration(milliseconds: 100));
              context.go('/login');
            },
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: isLoading
              ? null
              : const LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [AppColors.primary, AppColors.secondary],
                ),
          color: isLoading ? AppColors.borderColor.withOpacity(0.3) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Colors.white30,
                  shape: BoxShape.circle,
                ),
              )
            else
              const Icon(Icons.logout, color: Colors.white),
            const SizedBox(width: 12),
            isLoading
                ? Container(
                    width: 80,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.white30,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  )
                : const Text(
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
    );
  }
}