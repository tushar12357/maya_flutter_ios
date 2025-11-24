import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_state.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        print('Splash: Auth state changed to ${state.runtimeType}');
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 60),

                // Title
                const Text(
                  "Infinite Voice Lines",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),

                // Subtitle
                const Text(
                  "Your AI Employee can handle 1,000+ voice conversations simultaneously.\nScale without limits.",
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    height: 1.6,
                    fontWeight: FontWeight.w400,
                  ),
                ),

                const Spacer(),

                // Avatar + Arrow Button (Fixed Overflow)
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Main Avatar Image
                    Center(
                      child: Image.asset(
                        'assets/avatar.png', // Correct path as requested
                        height: 360,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 360,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.smart_toy,
                              size: 120,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
                    ),

                    // Floating Arrow Button (Bottom-right of avatar)
                    Positioned(
                      right: 20,
                      bottom: 30,
                      child: InkWell(
                        onTap: () {
                          // Optional: manual navigation (Bloc usually handles this)
                          // Navigator.pushNamed(context, '/login');
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          height: 50,
                          width: 50,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.orange,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_forward,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 80), // Safe bottom padding
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Keep bouncing dots (unused in UI but preserved for future)
class _BouncingDots extends StatefulWidget {
  const _BouncingDots();

  @override
  State<_BouncingDots> createState() => __BouncingDotsState();
}

class __BouncingDotsState extends State<_BouncingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _animations = List.generate(3, (i) {
      return Tween<double>(begin: 0, end: -12).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(i * 0.15, 0.7 + i * 0.15, curve: Curves.easeOut),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (_, __) => Transform.translate(
            offset: Offset(0, _animations[i].value),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.orange,
              ),
            ),
          ),
        );
      }),
    );
  }
}