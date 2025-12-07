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
  String location = "";
  String bio = "UX/UI Designer passionate";

  String? _avatarUrl;
  bool _isUploadingAvatar = false;
  bool _isLoading = true;

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
    setState(() => _isLoading = true);
    try {
      final res = await getIt<ApiClient>().getCurrentUser();
      if (res['statusCode'] == 200) {
        userData = res['data']['data'];
        setState(() {
          fullName = "${userData?['first_name'] ?? ''} ${userData?['last_name'] ?? ''}".trim();
          email = userData?['email'] ?? '';
          phone = userData?['phone_number'] ?? '';
          _avatarUrl = userData?['profile_image_url'];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // Pull-to-refresh method
  Future<void> _onRefresh() async {
    await _loadUser();
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

Widget _buildInfoRow({
  required String title,
  required String value,
  bool editable = false,
  VoidCallback? onEdit,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 12.0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
          Text(title, style: const TextStyle(color: Color(0xff374957), fontSize: 15)),
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
              if (editable) ...[
                const SizedBox(width: 8),
                InkWell(onTap: onEdit, child: const Icon(Icons.edit, size: 18)),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

Future<void> _showOtpDialog() async {
    String initialPhoneDigits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (initialPhoneDigits.length > 2) {
      initialPhoneDigits = initialPhoneDigits.substring(2);
    }
    _phoneController.text = initialPhoneDigits;

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          backgroundColor: Colors.white70,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.black26, width: 1.4),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text("Tell Us your Phone Number",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text("We'll text you a code so we can confirm that it's you.",
                    style: TextStyle(color: Colors.black, fontSize: 14)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.borderColor),
                      ),
                      child: Row(
                        children: const [
                          Text("+91", style: TextStyle(fontSize: 16)),
                          Icon(Icons.arrow_drop_down, size: 22),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.borderColor),
                        ),
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: "78967157628",
                            contentPadding: EdgeInsets.symmetric(horizontal: 12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 25),
                GestureDetector(
                  onTap: () async {
                    Navigator.of(context).pop();
                    final newPhone = '+91-${_phoneController.text}';
                    final res = await getIt<ApiClient>().updateUserProfile(
                        phoneNumber: _phoneController.text.trim());
                    if (res['statusCode'] == 200) {
                      setState(() => phone = newPhone);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Phone updated successfully!")),
                      );
                      _loadUser();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Update failed")),
                      );
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: LinearGradient(
                        colors: [AppColors.secondary, AppColors.primary],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      "Send OTP",
                      style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

Future<void> _showEditDialog(String title, String currentValue) async {
    _dialogController.text = currentValue;
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          backgroundColor: Colors.white70,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.black26, width: 1.4),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Edit $title",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black26),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextField(
                    controller: _dialogController,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: "Enter value...",
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () async {
                    final newValue = _dialogController.text.trim();
                    if (newValue.isEmpty) return;

                    Navigator.of(context).pop();

                    final names = newValue.split(' ');
                    final res = await getIt<ApiClient>().updateUserProfile(
                      firstName: names.first,
                      lastName: names.length > 1 ? names.sublist(1).join(' ') : '',
                    );

                    if (res['statusCode'] == 200) {
                      setState(() => fullName = newValue);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$title updated to $newValue')),
                      );
                      _loadUser();
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: const LinearGradient(
                        colors: [AppColors.secondary, AppColors.primary],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      "Save",
                      style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
Future<void> _showChangePasswordDialog() async {
  bool oldPassVisible = false;
  bool newPassVisible = false;
  bool confirmVisible = false;

  final oldPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  return showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setStateDialog) {
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 20),
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.black26, width: 1.4),
              ),
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Text(
                        "Change Password",
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.black87),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Old Password
                    const Text("Current Password", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 6),
                    Container(
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: AppColors.borderColor),
                      ),
                      child: TextField(
                        controller: oldPasswordController,
                        obscureText: !oldPassVisible,
                        decoration: InputDecoration(
                          hintText: "Enter current password",
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                          prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
                          suffixIcon: IconButton(
                            icon: Icon(oldPassVisible ? Icons.visibility : Icons.visibility_off, color: Colors.grey),
                            onPressed: () => setStateDialog(() => oldPassVisible = !oldPassVisible),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // New Password
                    const Text("New Password", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 6),
                    Container(
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: AppColors.borderColor),
                      ),
                      child: TextField(
                        controller: newPasswordController,
                        obscureText: !newPassVisible,
                        decoration: InputDecoration(
                          hintText: "Enter new password",
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                          prefixIcon: const Icon(Icons.lock, color: Colors.grey),
                          suffixIcon: IconButton(
                            icon: Icon(newPassVisible ? Icons.visibility : Icons.visibility_off, color: Colors.grey),
                            onPressed: () => setStateDialog(() => newPassVisible = !newPassVisible),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text("Must be at least 8 characters.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 12),

                    // Confirm New Password
                    const Text("Confirm New Password", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 6),
                    Container(
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: AppColors.borderColor),
                      ),
                      child: TextField(
                        controller: confirmPasswordController,
                        obscureText: !confirmVisible,
                        decoration: InputDecoration(
                          hintText: "Re-enter new password",
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                          prefixIcon: const Icon(Icons.lock, color: Colors.grey),
                          suffixIcon: IconButton(
                            icon: Icon(
                              confirmVisible ? Icons.visibility : Icons.visibility_off,
                              color: Colors.grey,
                            ),
                            onPressed: () => setStateDialog(() => confirmVisible = !confirmVisible),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text("Both passwords must match", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 24),

                    // Submit Button
                    GestureDetector(
                      onTap: () async {
                        final oldPass = oldPasswordController.text.trim();
                        final newPass = newPasswordController.text;
                        final confirmPass = confirmPasswordController.text;

                        if (oldPass.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Please enter your current password")),
                          );
                          return;
                        }
                        if (newPass.length < 8) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("New password must be at least 8 characters")),
                          );
                          return;
                        }
                        if (newPass != confirmPass) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("New passwords do not match")),
                          );
                          return;
                        }

                        Navigator.pop(context); // Close dialog

                        // Optional: Show loading
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Row(children: [CircularProgressIndicator(), SizedBox(width: 16), Text("Updating password...")])),
                        );

                        final res = await getIt<ApiClient>().changePassword(
                          oldPassword: oldPass,
                          newPassword: newPass,
                          confirmPassword: confirmPass,
                        );

                        ScaffoldMessenger.of(context).clearSnackBars();

                        if (res['statusCode'] == 200) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Password changed successfully!"), backgroundColor: Colors.green),
                          );
                        } else {
                          final msg = res['data']?['message'] ?? res['message'] ?? "Failed to change password";
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(msg), backgroundColor: AppColors.redColor),
                          );
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          gradient: const LinearGradient(
                            colors: [AppColors.secondary, AppColors.primary],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          "Update Password",
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgColor,
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: AppColors.primary,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Row(
                children: [
                  InkWell(
                    onTap: () => context.go('/other'),
                    child: Container(
                      height: 40,
                      width: 40,
                      decoration: const BoxDecoration(shape: BoxShape.circle,                       color: Color(0xffF8F8F8),
),
                      child: const Icon(Icons.arrow_back_outlined, color: Colors.black, size: 17),
                    ),
                  ),
                  const Text(" Profile", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 10),
              if (_isLoading) ...[
                _buildProfileSkeleton(),
                const SizedBox(height: 10),
                _buildInfoSkeleton(),
                const SizedBox(height: 20),
                _buildActionButtonsSkeleton(),
              ] else ...[
                
             Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.cardColor,
                borderRadius: BorderRadius.circular(13),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.01),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
GestureDetector(
  onTap: _showAvatarMenu,
  child: CircleAvatar(
    radius: 30,
    backgroundColor: AppColors.greyColor,
    backgroundImage: (_avatarUrl != null && _avatarUrl!.isNotEmpty)
        ? CachedNetworkImageProvider(_avatarUrl!) as ImageProvider
        : null,
    child: (_avatarUrl == null || _avatarUrl!.isEmpty)
        ? Text(
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
),

                  const SizedBox(width: 15),

                  // NAME + EMAIL TEXT
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fullName,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // CHANGE PICTURE BUTTON
                  GestureDetector(
                    onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xffF29452),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: _isUploadingAvatar
                          ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Text(
                        "Change Picture",
                        style: TextStyle(fontSize: 12, color: Colors.white),
                      ),
                    ),
                  ),

                  // REMOVE PICTURE BUTTON
                 
              
              
                ],
              ),
            ),    const SizedBox(height: 10),
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
                      _buildInfoRow(
                        title: "Full Name",
                        value: fullName,
                        editable: true,
                        onEdit: () => _showEditDialog("Full Name", fullName),
                      ),
                      const Divider(color: Color(0xffC1BEC9)),
                      _buildInfoRow(title: "Email", value: email),
                      const Divider(color: Color(0xffC1BEC9)),
                      _buildInfoRow(title: "Phone", value: phone.isEmpty ? "Not set" : phone, editable: true,
                        onEdit: () => _showEditDialog("Phone", phone),),
                      const Divider(color: Color(0xffC1BEC9)),
                      _buildInfoRow(title: "Location", value: location.isEmpty ? "Not set" : location, editable: true,
                        onEdit: () => _showEditDialog("Location", location),),
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
              ],
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  // Skeleton widgets
  Widget _buildProfileSkeleton() => Row(
    children: [
      Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.borderColor,
        ),
      ),
      const SizedBox(width: 15),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 20,
              width: 150,
              decoration: BoxDecoration(
                color: AppColors.borderColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 16,
              width: 200,
              decoration: BoxDecoration(
                color: AppColors.borderColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
      Container(
        width: 100,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.borderColor,
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    ],
  );

  Widget _buildInfoSkeleton() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, spreadRadius: 1)],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 20,
          width: 150,
          decoration: BoxDecoration(
            color: AppColors.borderColor,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 10),
        const Divider(color: Color(0xffC1BEC9)),
        _buildInfoRowSkeleton(),
        const Divider(color: Color(0xffC1BEC9)),
        _buildInfoRowSkeleton(),
        const Divider(color: Color(0xffC1BEC9)),
        _buildInfoRowSkeleton(),
        const Divider(color: Color(0xffC1BEC9)),
        _buildInfoRowSkeleton(),
        const Divider(color: Color(0xffC1BEC9)),
      ],
    ),
  );

  Widget _buildInfoRowSkeleton() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12.0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          height: 16,
          width: 80,
          decoration: BoxDecoration(
            color: AppColors.borderColor,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        Container(
          height: 16,
          width: 120,
          decoration: BoxDecoration(
            color: AppColors.borderColor,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    ),
  );

  Widget _buildActionButtonsSkeleton() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Container(
        height: 16,
        width: 120,
        decoration: BoxDecoration(
          color: AppColors.borderColor,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      Container(
        height: 16,
        width: 120,
        decoration: BoxDecoration(
          color: AppColors.borderColor,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    ],
  );


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

void _showAvatarMenu() {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    backgroundColor: Colors.white,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              ListTile(
                leading: const Icon(Icons.photo_camera, color: Colors.black),
                title: const Text("Change Picture",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadAvatar();
                },
              ),

              if (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text(
                    "Remove Picture",
                    style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500, color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _removeProfilePicture();
                  },
                ),

              const SizedBox(height: 6),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text("Cancel"),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      );
    },
  );
}



}