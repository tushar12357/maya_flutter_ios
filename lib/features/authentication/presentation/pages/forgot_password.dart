import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:Maya/core/network/api_client.dart'; // <-- your API client import

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  int _step = 1; // 1: Email, 2: OTP, 3: Reset Password
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleForgotPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final response = await getIt<ApiClient>().forgotPassword(_emailController.text);
      if (response['statusCode'] == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP sent to your email')),
        );
        setState(() => _step = 2);
      } else {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text(response['data']['message'] ?? 'Error sending OTP')),
        // );
      }
    } catch (e) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Error: $e')),
      // );
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _handleVerifyOTP() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final response = await getIt<ApiClient>().verifyOTP(
        _emailController.text,
        _otpController.text,
      );

      if (response['statusCode'] == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP verified! Proceed to reset password.')),
        );
        setState(() => _step = 3);
      } else {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text(response['data']['message'] ?? 'Invalid OTP')),
        // );
      }
    } catch (e) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Error: $e')),
      // );
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final response = await getIt<ApiClient>().resetPassword(
        _emailController.text,
        _otpController.text,
        _newPasswordController.text,
        _confirmPasswordController.text,
      );

      if (response['statusCode'] == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset successful!')),
        );
        context.go('/login');
      } else {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text(response['data']['message'] ?? 'Failed to reset password')),
        // );
      }
    } catch (e) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Error: $e')),
      // );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          Container(color: const Color(0xFF111827)),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x992A57E8),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: size.height - 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 60),
                    Image.asset(
                      'assets/maya_logo.png',
                      height: 160,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.lock, size: 80, color: Colors.white);
                      },
                    ),
                    const SizedBox(height: 40),

                    Text(
                      _step == 1
                          ? "Forgot Password"
                          : _step == 2
                              ? "Verify OTP"
                              : "Reset Password",
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Text(
                      _step == 1
                          ? "Enter your email to receive an OTP"
                          : _step == 2
                              ? "Enter the OTP sent to your email"
                              : "Set your new password",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),

                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          if (_step == 1)
                            _buildTextField(
                              controller: _emailController,
                              hint: "Enter your email",
                              icon: Icons.mail_outline,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                if (v == null || v.isEmpty) return "Please enter your email";
                                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) {
                                  return "Enter a valid email";
                                }
                                return null;
                              },
                            )
                          else if (_step == 2)
                            _buildTextField(
                              controller: _otpController,
                              hint: "Enter OTP",
                              icon: Icons.lock_clock_outlined,
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (v == null || v.isEmpty) return "Please enter OTP";
                                if (v.length != 6) return "OTP must be 6 digits";
                                return null;
                              },
                            )
                          else ...[
                            _buildTextField(
                              controller: _newPasswordController,
                              hint: "New Password",
                              icon: Icons.lock_outline,
                              obscureText: _obscureNewPassword,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureNewPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.white70,
                                ),
                                onPressed: () => setState(() {
                                  _obscureNewPassword = !_obscureNewPassword;
                                }),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) return "Enter new password";
                                if (v.length < 6) return "Password too short";
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _confirmPasswordController,
                              hint: "Confirm Password",
                              icon: Icons.lock_reset,
                              obscureText: _obscureConfirmPassword,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.white70,
                                ),
                                onPressed: () => setState(() {
                                  _obscureConfirmPassword = !_obscureConfirmPassword;
                                }),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) return "Confirm your password";
                                if (v != _newPasswordController.text) {
                                  return "Passwords do not match";
                                }
                                return null;
                              },
                            ),
                          ],

                          const SizedBox(height: 32),

                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _loading
                                  ? null
                                  : _step == 1
                                      ? _handleForgotPassword
                                      : _step == 2
                                          ? _handleVerifyOTP
                                          : _handleResetPassword,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00D1FF),
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: _loading
                                  ? const CircularProgressIndicator(color: Colors.black)
                                  : Text(
                                      _step == 1
                                          ? "Send OTP"
                                          : _step == 2
                                              ? "Verify OTP"
                                              : "Reset Password",
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () => context.go('/login'),
                            child: const Text(
                              "Back to Login",
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.white70),
        suffixIcon: suffixIcon,
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: Color(0xFF00D1FF), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      ),
      validator: validator,
    );
  }
}
