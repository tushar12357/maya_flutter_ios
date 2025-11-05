import 'package:Maya/core/network/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../authentication/presentation/bloc/auth_bloc.dart';
import '../../../authentication/presentation/bloc/auth_event.dart';
import '../../../authentication/presentation/bloc/auth_state.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: getIt<ApiClient>().getCurrentUser(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: Stack(
              children: [
                // Background color
                Container(color: const Color(0xFF111827)),
                // Gradient overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x992A57E8), Colors.transparent],
                    ),
                  ),
                ),
                // Loading
                const SafeArea(
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
              ],
            ),
          );
        }

        Map<String, dynamic>? userData;
        if (snapshot.hasError) {
          print('Error fetching user in ProfilePage: ${snapshot.error}');
        } else if (snapshot.hasData) {
          final response = snapshot.data!;
          if (response['statusCode'] == 200) {
            userData = response['data']['data'] as Map<String, dynamic>?;
            print('🔍 Profile Page: User data - ${userData?['first_name']}');
          }
        }

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
                child: userData == null
                    ? const Center(
                        child: Text(
                          'No user data available',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      )
                    : _buildMainContent(userData, context),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMainContent(Map<String, dynamic> userData, BuildContext context) {
    return Column(
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
                    color: const Color(0xFF111827).withOpacity(0.8),
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
                'Profile',
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
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                // Profile Picture Section
                _buildProfileHeader(userData, context),
                const SizedBox(height: 24),
                // Personal Information Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D4A6F).withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Personal information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow(
                        'Full Name',
                        '${userData['first_name'] ?? ''} ${userData['last_name'] ?? ''}',
                      ),
                      _buildInfoRow(
                        'Email',
                        userData['email'] ?? '',
                      ),
                      _buildInfoRow(
                        'Phone',
                        userData['phone_number'] ?? '+91 9876543210',
                      ),
                      _buildInfoRow(
                        'Location',
                        'New Delhi, India',
                      ),
                      _buildInfoRow(
                        'Bio',
                        'UI/UX Designer passionate',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Account Information Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D4A6F).withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Account information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow(
                        'User ID',
                        'USR-${userData['ID'] ?? 3047}',
                      ),
                      _buildInfoRow(
                        'Username',
                        '@kaarthi-design',
                      ),
                      _buildInfoRow(
                        'Member Since',
                        _formatDate(userData['CreatedAt']),
                      ),
                      _buildInfoRow(
                        'Account Type',
                        'Premium',
                      ),
                      _buildInfoRow('Status', 'Active'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Save Changes Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      // Placeholder for save functionality
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Changes saved!'),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4B5563),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Save Changes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Change Password Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      // Placeholder for change password
                      context.go('/change-password'); // Assuming route exists
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Change Password',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Delete Account Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _showDeleteDialog(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFEF4444)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Delete Account',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileHeader(Map<String, dynamic> userData, BuildContext context) {
    final name = userData['first_name'] ?? 'Kaarthi';
    final email = userData['email'] ?? 'kaarthi@gmail.com';
    final avatarLetter = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'K';

    return Row(
      children: [
        // Avatar
        Container(
          width: 80,
          height: 80,
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
                fontSize: 32,
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
        TextButton(
          onPressed: () {
            // Placeholder for change picture
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Change picture functionality')),
            );
          },
          child: const Text(
            'Change Picture',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? createdAt) {
    if (createdAt == null) {
      return 'Oct 29, 11:45 AM IST';
    }
    try {
      final dateTime = DateTime.parse(createdAt);
      return DateFormat('MMM dd, h:mm a').format(dateTime) + ' IST';
    } catch (e) {
      return 'Oct 29, 11:45 AM IST';
    }
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(
            color: Color(0x1AFFFFFF),
          ), // white.withOpacity(0.1)
        ),
        contentPadding: const EdgeInsets.all(16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.delete_outline,
              color: Color(0xFFEF4444),
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'Delete Account',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Are you sure you want to delete your account?\n\nThis action cannot be undone.',
              style: TextStyle(
                fontSize: 14,
                color: Color.fromRGBO(189, 189, 189, 1),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0x1AFFFFFF), // white.withOpacity(0.1)
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              // Placeholder for delete functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Account deleted!')),
              );
              context.read<AuthBloc>().add(LogoutRequested());
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0x1AFF4444), // EF4444.withOpacity(0.1)
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Delete',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFEF4444),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}