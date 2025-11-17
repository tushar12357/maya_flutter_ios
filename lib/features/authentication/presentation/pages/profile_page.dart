// profile_page.dart - FIXED VERSION
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:Maya/core/network/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:get_it/get_it.dart';

import '../../../authentication/presentation/bloc/auth_bloc.dart';
import '../../../authentication/presentation/bloc/auth_event.dart';

final getIt = GetIt.instance;

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final phoneController = TextEditingController();

  // ✅ Single flag to prevent any API calls during avatar upload
  bool _isUploadingAvatar = false;
  String? _avatarUrl;
  Map<String, dynamic>? userData;

  Future<Map<String, dynamic>>? _userFuture;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    _userFuture = getIt<ApiClient>().getCurrentUser().then((res) {
      if (res['statusCode'] == 200) {
        userData = res['data']['data'];
        firstNameController.text = userData?['first_name'] ?? '';
        lastNameController.text = userData?['last_name'] ?? '';
        phoneController.text = userData?['phone_number'] ?? '';
        _avatarUrl = userData?['profile_image_url'];
      }
      return res;
    });
    setState(() {});
  }

  Future<void> _pickAndUploadAvatar() async {
    // ✅ Prevent multiple clicks
    if (_isUploadingAvatar) return;

    setState(() => _isUploadingAvatar = true);

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (pickedFile == null) {
        setState(() => _isUploadingAvatar = false);
        return;
      }

      final CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        compressQuality: 90,
        compressFormat: ImageCompressFormat.jpg,
      );

      if (croppedFile == null) {
        setState(() => _isUploadingAvatar = false);
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final file = File(croppedFile.path).copySync(
        "${tempDir.path}/maya_${DateTime.now().millisecondsSinceEpoch}.jpg",
      );

      // ✅ Upload avatar - ONLY ONE API CALL
      final res = await getIt<ApiClient>().uploadUserAvatar(file);

      if (res['statusCode'] == 200) {
        setState(() {
          _avatarUrl = res['data']['data']['profile_image_url'] ?? 
                       res['data']['data']['avatar'];
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Profile picture updated!")),
          );
        }

        // ✅ Refresh user data after successful upload
        await _loadUser();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['data']?['message'] ?? "Upload failed"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isUploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _userFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _loadingView();
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
    final fullName = '${firstNameController.text} ${lastNameController.text}'.trim();
    final displayName = fullName.isEmpty ? 'User' : fullName;
    final email = userData?['email'] ?? '';
    final avatarLetter = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

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
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Profile',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
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

                // Profile Header
                Row(
                  children: [
                    // ✅ Avatar with proper upload state
                    GestureDetector(
                      onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Fallback gradient circle
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
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),

                          // Remote avatar
                          if (!_isUploadingAvatar &&
                              _avatarUrl != null &&
                              _avatarUrl!.isNotEmpty)
                            ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: _avatarUrl!,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white54,
                                    strokeWidth: 2,
                                  ),
                                ),
                                errorWidget: (_, __, ___) => Center(
                                  child: Text(
                                    avatarLetter,
                                    style: const TextStyle(
                                      fontSize: 32,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          // Upload progress ring
                          if (_isUploadingAvatar)
                            const Positioned.fill(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Name + Email
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
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

                    // Change Picture Button
                    TextButton(
                      onPressed: _isUploadingAvatar ? null : _pickAndUploadAvatar,
                      child: _isUploadingAvatar
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Change Picture',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Personal Information Card
                _personalInformationCard(),

                const SizedBox(height: 24),

                // ✅ Save Changes Button - disabled during avatar upload
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isUploadingAvatar ? null : _saveUpdatedProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4B5563),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                      disabledBackgroundColor: const Color(0xFF4B5563).withOpacity(0.5),
                    ),
                    child: const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Change Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),

                const SizedBox(height: 40),
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
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
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

  // ✅ Only updates text fields (firstName, lastName, phoneNumber)
  Future<void> _saveUpdatedProfile() async {
    // Block if avatar upload is in progress
    if (_isUploadingAvatar) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please wait for avatar upload to complete")),
      );
      return;
    }

    String? firstName;
    String? lastName;
    String? phoneNumber;

    if (firstNameController.text.trim() != (userData?['first_name'] ?? '')) {
      firstName = firstNameController.text.trim();
    }
    if (lastNameController.text.trim() != (userData?['last_name'] ?? '')) {
      lastName = lastNameController.text.trim();
    }
    if (phoneController.text.trim() != (userData?['phone_number'] ?? '')) {
      phoneNumber = phoneController.text.trim();
    }

    if (firstName == null && lastName == null && phoneNumber == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No changes made.")),
      );
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Updating profile...")));

    final res = await getIt<ApiClient>().updateUserProfile(
      firstName: firstName,
      lastName: lastName,
      phoneNumber: phoneNumber,
    );

    if (res['statusCode'] == 200) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Profile updated!")));
      await _loadUser();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['data']?['message'] ?? "Update failed"),
          backgroundColor: Colors.red,
        ),
      );
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
            child: Center(child: CircularProgressIndicator(color: Colors.white)),
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
      builder: (dialogContext) {
        Future<void> submit() async {
          if (oldPassController.text.isEmpty || newPassController.text.isEmpty || confirmPassController.text.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
            return;
          }
          if (newPassController.text != confirmPassController.text) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Passwords do not match")));
            return;
          }

          Navigator.of(dialogContext).pop();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Changing password...")));

          final res = await getIt<ApiClient>().changePassword(
            oldPassword: oldPassController.text,
            newPassword: newPassController.text,
            confirmPassword: confirmPassController.text,
          );

          if (res['statusCode'] == 200) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password changed successfully!")));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(res['data']?['message'] ?? "Password change failed")),
            );
          }
        }

        return AlertDialog(
          backgroundColor: const Color(0xFF111827).withOpacity(0.94),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Color(0x1AFFFFFF))),
          contentPadding: const EdgeInsets.all(20),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Change Password", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
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
                      decoration: BoxDecoration(color: const Color(0x1AFFFFFF), borderRadius: BorderRadius.circular(12)),
                      child: const Text("Cancel", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                    ),
                  ),
                  TextButton(
                    onPressed: submit,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(color: const Color(0xFF2A57E8), borderRadius: BorderRadius.circular(12)),
                      child: const Text("Update", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                    ),
                  ),
                ],
              ),
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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }
}