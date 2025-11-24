// profile_page.dart - EXACTLY LIKE YOUR ORIGINAL DESIGN + REAL API CALLS
import 'dart:io';
import 'package:Maya/core/constants/colors.dart';
import 'package:Maya/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:Maya/features/authentication/presentation/bloc/auth_event.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:Maya/core/network/api_client.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';


final getIt = GetIt.instance;

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String fullName = "Loading...";
  String email = "";
  String phone = "";
  String location = "Delhi, India";
  String bio = "UX/UI Designer passionate";

  String? _avatarUrl;
  bool _isUploadingAvatar = false;

  final TextEditingController _dialogController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  Map<String, dynamic>? userData;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _dialogController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final res = await getIt<ApiClient>().getCurrentUser();
    if (res['statusCode'] == 200) {
      userData = res['data']['data'];
      setState(() {
        fullName = "${userData?['first_name'] ?? ''} ${userData?['last_name'] ?? ''}".trim();
        email = userData?['email'] ?? '';
        phone = userData?['phone_number'] ?? '';
        _avatarUrl = userData?['profile_image_url'];
      });
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    if (_isUploadingAvatar) return;
    setState(() => _isUploadingAvatar = true);

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (pickedFile == null) return;

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        compressQuality: 90,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Image',
            toolbarColor: AppColors.primary,
            toolbarWidgetColor: Colors.white,
          ),
        ],
      );

      if (croppedFile == null) return;

      final tempDir = await getTemporaryDirectory();
      final file = File(croppedFile.path).copySync(
        "${tempDir.path}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg",
      );

      final res = await getIt<ApiClient>().uploadUserAvatar(file);
      if (res['statusCode'] == 200) {
        setState(() {
          _avatarUrl = res['data']['data']['profile_image_url'] ?? res['data']['data']['avatar'];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Profile picture updated!"), backgroundColor: AppColors.primary),
        );
        _loadUser();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload failed"), backgroundColor: AppColors.redColor),
      );
    } finally {
      setState(() => _isUploadingAvatar = false);
    }
  }

  Widget _buildInfoRow(String title, String value, String fieldKey, VoidCallback onEdit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 15)),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(onTap: onEdit, child: const Icon(Icons.edit, size: 18)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showOtpDialog() async {
    String digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 10) digits = digits.substring(digits.length - 10);
    _phoneController.text = digits;

    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Tell Us your Phone Number", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text("We'll text you a code so we can confirm that it's you.", style: TextStyle(color: Colors.grey[600], fontSize: 14)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                    child: const Text('+91', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: "78967157628",
                        fillColor: Colors.grey[200],
                        filled: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    final newPhone = '+91-${_phoneController.text}';
                    final res = await getIt<ApiClient>().updateUserProfile(phoneNumber: _phoneController.text.trim());
                    if (res['statusCode'] == 200) {
                      setState(() => phone = newPhone);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Phone updated successfully!"), backgroundColor: AppColors.primary),
                      );
                      _loadUser();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Update failed"), backgroundColor: AppColors.redColor),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 5,
                  ),
                  child: const Text('Send OTP', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showEditDialog(String title, String currentValue, String fieldKey) async {
    _dialogController.text = currentValue;

    return showDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          contentPadding: EdgeInsets.zero,
          content: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Edit $title', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 20)),
                const SizedBox(height: 16),
                TextField(
                  controller: _dialogController,
                  decoration: InputDecoration(
                    labelText: title,
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
                  ),
                  maxLines: fieldKey == 'bio' ? 3 : 1,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(fontSize: 16))),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      onPressed: () async {
                        final newValue = _dialogController.text.trim();
                        Navigator.pop(context);

                        Map<String, dynamic> updateData = {};
                        if (fieldKey == 'fullName') {
                          final names = newValue.split(' ');
                          updateData['first_name'] = names.first;
                          updateData['last_name'] = names.length > 1 ? names.sublist(1).join(' ') : '';
                        } else if (fieldKey == 'email') {
                          updateData['email'] = newValue;
                        } else if (fieldKey == 'location') {
                          updateData['location'] = newValue;
                        }

                        final res = await getIt<ApiClient>().updateUserProfile(
                          firstName: updateData['first_name'] ?? '',
                          lastName: updateData['last_name'] ?? '',
                        );

                        if (res['statusCode'] == 200) {
                          setState(() {
                            if (fieldKey == 'fullName') fullName = newValue;
                            if (fieldKey == 'email') email = newValue;
                            if (fieldKey == 'location') location = newValue;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("$title updated!"), backgroundColor: AppColors.primary),
                          );
                          _loadUser();
                        }
                      },
                      child: const Text('Save', style: TextStyle(fontSize: 16, color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            Row(
              children: [
                InkWell(
                  onTap: () => context.go('/other'),
                  child: Container(
                    height: 35,
                    width: 35,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xffB2B2B2)),
                    child: const Icon(Icons.arrow_back_outlined, color: Colors.black, size: 17),
                  ),
                ),
                const Text(" Profile", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
Row(
  children: [
    CircleAvatar(
      radius: 30,
      backgroundColor: AppColors.greyColor,          // <- same background as OtherPage
      backgroundImage: (_avatarUrl != null && _avatarUrl!.isNotEmpty)
          ? CachedNetworkImageProvider(_avatarUrl!) as ImageProvider
          : null,
      child: (_avatarUrl == null || _avatarUrl!.isEmpty)
          ? Text(
              // ── Initials logic (same as in OtherPage) ──
              fullName.isNotEmpty
                  ? fullName.trim().split(' ').first[0].toUpperCase()
                  : 'U',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.balckClr,
              ),
            )
          : null,
    ),
    const SizedBox(width: 15),
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(fullName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(email, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    ),
    // Change Picture Button
    GestureDetector(
      onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: _isUploadingAvatar
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
                        : const Text(
                            "Change Picture",
                            style: TextStyle(fontSize: 12, color: Colors.white),
                          ),
      ),
    ),
    // Remove Picture Button (only when a picture exists)
    if (_avatarUrl != null && _avatarUrl!.isNotEmpty) ...[
      const SizedBox(width: 8),
      GestureDetector(
        onTap: _isUploadingAvatar ? null : _removeProfilePicture,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.red.shade600,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
      ),
    ],
  ],
),  
            const SizedBox(height: 10),

       Container(
  
  
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, spreadRadius: 1)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Personal Information", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  const Divider(color: Color(0xffC1BEC9)),
                  _buildInfoRow("Full Name", fullName, 'fullName', () => _showEditDialog("Full Name", fullName, 'fullName')),
                  const Divider(color: Color(0xffC1BEC9)),
                  _buildInfoRow("Email", email, 'email', () => _showEditDialog("Email", email, 'email')),
                  const Divider(color: Color(0xffC1BEC9)),
                  _buildInfoRow("Phone", phone, 'phone', _showOtpDialog),
                  const Divider(color: Color(0xffC1BEC9)),
                  _buildInfoRow("Location", location, 'location', () => _showEditDialog("Location", location, 'location')),
                  const Divider(color: Color(0xffC1BEC9)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: _showChangePasswordDialog,
                  child: Text("Change Password", style: TextStyle(color: Color(0xffB2B2B2), fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                ),
                InkWell(
                  onTap: () => _deleteAccount(),
                  child: Text("Delete Account", style: TextStyle(color: AppColors.redColor, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                ),
              ],
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }


  Future<void> _removeProfilePicture() async {
  // Show confirmation dialog
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text("Remove Profile Picture"),
      content: const Text("Are you sure you want to remove your profile picture?"),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text("Cancel"),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          onPressed: () => Navigator.pop(context, true),
          child: const Text("Remove"),
        ),
      ],
    ),
  );

  if (confirm != true) return;

  setState(() => _isUploadingAvatar = true);

  try {
    final res = await getIt<ApiClient>().deleteProfileImage();

    if (res['statusCode'] == 200 || res['statusCode'] == 204) {
      setState(() {
        _avatarUrl = null; // This will show the default placeholder
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Profile picture removed successfully"),
          backgroundColor: Colors.green,
        ),
      );

      // Refresh user data (optional – in case backend returns updated URLs)
      _loadUser();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['data']['message'] ?? "Failed to remove picture"),
          backgroundColor: AppColors.redColor,
        ),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Something went wrong"), backgroundColor: Colors.red),
    );
  } finally {
    if (mounted) {
      setState(() => _isUploadingAvatar = false);
    }
  }
}

  void _deleteAccount() async {
  // Show confirmation first (recommended)
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Delete Account"),
      content: const Text("This action cannot be undone. Are you sure?"),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text("Cancel"),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          onPressed: () => Navigator.pop(context, true),
          child: const Text("Delete"),
        ),
      ],
    ),
  );

  if (confirm != true) return;

  // Optional: Show loading
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("Deleting account...")),
  );

  final res = await getIt<ApiClient>().deleteUser();

  if (res['statusCode'] == 200 || res['statusCode'] == 204) {
    // Critical: Trigger the same auth cleanup as logout
    BlocProvider.of<AuthBloc>(context).add(LogoutRequested());

    // Small delay to let BLoC process the event
    await Future.delayed(const Duration(milliseconds: 150));

    // Now safely navigate
    if (mounted) {
      context.go('/login');
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Account deleted successfully"),
        backgroundColor: Colors.green,
      ),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res['data']['message'] ?? "Failed to delete account"),
        backgroundColor: AppColors.redColor,
      ),
    );
  }
}




  void _showChangePasswordDialog() {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Change Password", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(obscureText: true, controller: oldCtrl, decoration: InputDecoration(labelText: "Old Password", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              const SizedBox(height: 12),
              TextField(obscureText: true, controller: newCtrl, decoration: InputDecoration(labelText: "New Password", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              const SizedBox(height: 12),
              TextField(obscureText: true, controller: confirmCtrl, decoration: InputDecoration(labelText: "Confirm Password", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              const SizedBox(height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.red))),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: () async {
                      if (newCtrl.text != confirmCtrl.text) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Passwords don't match")));
                        return;
                      }
                      Navigator.pop(context);
                      final res = await getIt<ApiClient>().changePassword(
                        oldPassword: oldCtrl.text,
                        newPassword: newCtrl.text,
                        confirmPassword: confirmCtrl.text,
                      );
                      if (res['statusCode'] == 200) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Password changed!"), backgroundColor: AppColors.primary));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed"), backgroundColor: AppColors.redColor));
                      }
                    },
                    child: const Text("Update", style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}