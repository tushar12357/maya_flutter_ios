import 'package:Maya/core/network/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../authentication/presentation/bloc/auth_bloc.dart';
import '../../../authentication/presentation/bloc/auth_event.dart';
import '../../../authentication/presentation/bloc/auth_state.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final phoneController = TextEditingController();

  Map<String, dynamic>? userData;



  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: getIt<ApiClient>().getCurrentUser(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _loadingView();
        }

        if (snapshot.hasData && snapshot.data?['statusCode'] == 200) {
          userData = snapshot.data!['data']['data'];

          firstNameController.text = userData?['first_name'] ?? '';
          lastNameController.text = userData?['last_name'] ?? '';
          phoneController.text = userData?['phone_number'] ?? '';
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              Container(color: const Color(0xFF111827)),
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x992A57E8), Colors.transparent],
                  ),
                ),
              ),
              SafeArea(
                child: userData == null
                    ? const Center(
                        child: Text(
                          'No user data available',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      )
                    : _buildMainContent(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => context.push('/other'),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827).withOpacity(0.8),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
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
              children: [
                const SizedBox(height: 8),

                // Profile Header (Avatar + Name)
                _buildProfileHeader(),

                const SizedBox(height: 24),

                // Editable Personal Information
                _personalInformationCard(),
                const SizedBox(height: 24),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveUpdatedProfile,
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
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Change Password Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
onPressed: _showChangePasswordDialog,
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
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Delete Account Button
                               const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _personalInformationCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2D4A6F).withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Personal information',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 16),

          _editableField("First Name", firstNameController),
          _editableField("Last Name", lastNameController),
          _editableField("Phone Number", phoneController),

          _buildInfoRow("Email", userData?['email'] ?? ''),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    final name = firstNameController.text.isNotEmpty ? firstNameController.text : 'User';
    final email = userData?['email'] ?? '';
    final avatarLetter = name.substring(0, 1).toUpperCase();

    return Row(
      children: [
        // Gradient Avatar
        Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2A57E8), Color(0xFF1D4ED8)],
            ),
          ),
          child: Center(
            child: Text(
              avatarLetter,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
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
                  fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                email,
                style: const TextStyle(fontSize: 14, color: Color.fromRGBO(189, 189, 189, 1)),
              ),
            ],
          ),
        ),

        TextButton(
          onPressed: () {
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Change picture functionality')));
          },
          child: const Text('Change Picture',
              style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _editableField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),

          const SizedBox(height: 6),

          TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white10,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _accountInformationCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2D4A6F).withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Account information',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 16),

          _buildInfoRow("User ID", 'USR-${userData?['ID']}'),
          _buildInfoRow("Member Since", _formatDate(userData?['CreatedAt'])),
          _buildInfoRow("Account Type", 'Premium'),
          _buildInfoRow("Status", 'Active'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
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
    if (createdAt == null) return "N/A";
    try {
      final dateTime = DateTime.parse(createdAt);
      return DateFormat('MMM dd, h:mm a').format(dateTime) + ' IST';
    } catch (_) {
      return "N/A";
    }
  }

  Future<void> _saveUpdatedProfile() async {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Updating profile...")));

    final result = await getIt<ApiClient>().updateUserProfile(
      firstName: firstNameController.text,
      lastName: lastNameController.text,
      fcmToken: userData?['fcm_token'] ?? '',
      latitude: userData?['latitude'] ?? 0.0,
      longitude: userData?['longitude'] ?? 0.0,
      timezone: userData?['timezone'] ?? 'Asia/Kolkata',
      phoneNumber: phoneController.text,
    );

    if (result['statusCode'] == 200) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Profile updated!")));
      setState(() {});
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Update failed")));
    }
  }

  Widget _loadingView() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Container(color: const Color(0xFF111827)),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x992A57E8), Colors.transparent],
              ),
            ),
          ),
          const SafeArea(
            child: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0x1AFFFFFF)),
        ),
        contentPadding: const EdgeInsets.all(16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 48),
            SizedBox(height: 16),
            Text(
              'Delete Account',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            SizedBox(height: 12),
            Text(
              'Are you sure you want to delete your account?\n\nThis action cannot be undone.',
              style: TextStyle(fontSize: 14, color: Color.fromRGBO(189, 189, 189, 1)),
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
                color: const Color(0x1AFFFFFF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Account deleted!')));
              context.read<AuthBloc>().add(LogoutRequested());
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0x1AFF4444),
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

void _showChangePasswordDialog() {
  final oldPassController = TextEditingController();
  final newPassController = TextEditingController();
  final confirmPassController = TextEditingController();

  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {

      Future<void> submit() async {
        if (oldPassController.text.isEmpty ||
            newPassController.text.isEmpty ||
            confirmPassController.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Please fill all fields")),
          );
          return;
        }

        if (newPassController.text != confirmPassController.text) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Passwords do not match")),
          );
          return;
        }

        Navigator.of(dialogContext).pop(); // close UI first

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Changing password...")),
        );

        final res = await getIt<ApiClient>().changePassword(
          oldPassword: oldPassController.text,
          newPassword: newPassController.text,
          confirmPassword: confirmPassController.text,
        );

        if (res['statusCode'] == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Password changed successfully!")),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['data']?['message'] ?? "Password change failed"),
            ),
          );
        }
      }

      return AlertDialog(
        backgroundColor: const Color(0xFF111827).withOpacity(0.94),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0x1AFFFFFF)),
        ),
        contentPadding: const EdgeInsets.all(20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Change Password",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 20),

            _passwordField("Old Password", oldPassController),
            const SizedBox(height: 12),
            _passwordField("New Password", newPassController),
            const SizedBox(height: 12),
            _passwordField("Confirm Password", confirmPassController),

            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0x1AFFFFFF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      "Cancel",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: submit,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A57E8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      "Update",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      );
    },
  );
}

Widget _passwordField(String label, TextEditingController controller) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
      const SizedBox(height: 6),
      TextField(
        controller: controller,
        obscureText: true,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white10,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    ],
  );
}

}
