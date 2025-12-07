import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
// Assuming these imports are correctly set up in your project
import 'package:Maya/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:Maya/features/authentication/presentation/bloc/auth_event.dart';
import 'package:Maya/features/authentication/presentation/bloc/auth_state.dart';
import 'package:Maya/core/constants/colors.dart';

// --- Custom Colors Placeholder (Add these to your AppColors file if they are missing) ---
// Note: Since I don't have access to your actual AppColors,
// I'm assuming you will define these colors correctly there.
// For demonstration, I'm defining a placeholder class here.
// class AppColors {
//   static const Color whiteClr = Colors.white;
//   static const Color balckClr = Colors.black;
//   static const Color borderColor = Colors.black12;
//   static const Color primary = Color(0xFFFF9800); // Deep orange
//   static const Color secondary = Color(0xFFFFCC80); // Light orange
//   static const Color redColor = Colors.red;
//   static const Color curveBgColor = Color(0xFFF7F7F7); // Very light grey for background curve
// }
// --- End Custom Colors Placeholder ---

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submitLogin() {
    if (_formKey.currentState!.validate()) {
      // BLoC event dispatch logic (as per your original code)
      context.read<AuthBloc>().add(
        LoginRequested(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        ),
      );
    }
  }

  // Updated Colors using AppColors
  final Color bg = AppColors.whiteClr;
  final Color textColor = AppColors.balckClr;
  final Color hint = Colors.black45;
  final Color border = AppColors.borderColor;
  // Assuming you have 'curveBgColor' in your AppColors
  final Color topCurveColor = const Color(0xFFF7F7F7); // AppColors.curveBgColor

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          // 1. TOP CURVED BACKGROUND (Grey Area)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: size.height * 0.43,
              decoration: BoxDecoration(
                color: topCurveColor, // Light grey background
              ),
              child: CustomPaint(
                // This draws the white curve at the bottom of the grey section
                painter: CurvePainter(),
              ),
            ),
          ),

          SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 40),

                  // Logo (Placeholder Image)
                  Center(
                    child: SizedBox(
                      width: size.width * 0.70,
                      height: size.width * 0.70,
                      child: Image.asset(
                        'assets/animation.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(Icons.cloud, size: 120, color: AppColors.primary),
                      ),
                    ),
                  ),

                  const SizedBox(height: 80),
                  Text(
                    "Login to Access Your",
                    style: TextStyle(fontSize: 22, color: textColor, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 30),

                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Email Field
                        _buildTextField(
                          controller: _emailController,
                          hint: 'Enter your email',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Please enter your email';
                            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) return 'Enter a valid email';
                            return null;
                          },
                        ),

                        const SizedBox(height: 18),

                        // Password Field
                        _buildTextField(
                          controller: _passwordController,
                          hint: 'Enter your password',
                          icon: Icons.lock_outline,
                          obscureText: _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: hint),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Please enter your password';
                            if (v.length < 6) return 'Password must be at least 6 characters';
                            return null;
                          },
                        ),

                        const SizedBox(height: 12),

                        // Remember me + Forgot password (Adjusted padding/size for image match)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: Checkbox(
                                      value: _rememberMe,
                                      activeColor: AppColors.primary,
                                      onChanged: (v) => setState(() => _rememberMe = v ?? false),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text("Remember me", style: TextStyle(color: hint, fontSize: 13)),
                                ],
                              ),
                              TextButton(
                                onPressed: () => context.push('/forgot-password'),
                                child: Text("Forgot password?", style: TextStyle(color: hint, fontSize: 13)),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 30),

                        // ORANGE GRADIENT LOGIN BUTTON
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _submitLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            ),
                            child: Ink(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [AppColors.secondary, AppColors.primary],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Container(
                                alignment: Alignment.center,
                                child: BlocConsumer<AuthBloc, AuthState>(
                                  listener: (context, state) {
                                    if (state is AuthAuthenticated) context.go('/home');
                                    if (state is AuthError) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(state.message), backgroundColor: AppColors.redColor),
                                      );
                                    }
                                  },
                                  builder: (context, state) {
                                    if (state is AuthLoading) {
                                      return const SizedBox(
                                        height: 26,
                                        width: 26,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                                      );
                                    }
                                    return const Text(
                                      'Login',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 30),

                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper Widgets ---

  // Custom Text Field (as in your original code)
  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    required String? Function(String?) validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
            prefixIcon: Icon(icon, color: Colors.black45, size: 22),
            suffixIcon: suffixIcon,
            hintText: hint,
            hintStyle: TextStyle(color: Colors.black45),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: const BorderSide(color: Colors.red),
            ),
          ),
          validator: validator,
        ),
      ),
    );
  }

  // Social Login Button (New)
  Widget _buildSocialButton({
    required String label,
    required String icon,
    required VoidCallback onPressed,
    required Color borderColor,
  }) {
    final bool isFacebook = label == 'Facebook';

    return SizedBox(
      height: 50,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: borderColor, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          backgroundColor: isFacebook ? const Color(0xFF1877F2) : Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Placeholder for Google/Facebook Icon (Update these to use Image.asset(icon) once files are ready)
            Icon(
              isFacebook ? Icons.facebook : Icons.email,
              color: isFacebook ? Colors.white : Colors.black,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                color: isFacebook ? Colors.white : textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- CURVE PAINTER CLASS (New) ---
class CurvePainter extends CustomPainter {

  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint();
    // Draw the white curve
    paint.color = AppColors.whiteClr;
    paint.style = PaintingStyle.fill;

    var path = Path();
    // Start drawing from the bottom-left corner of the grey container
    path.moveTo(0, size.height);

    // Create the gentle curve
    path.cubicTo(
      size.width / 4,
      size.height - 40,
      size.width / 4 * 3,
      size.height - 40,
      size.width,
      size.height,
    );

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }
}