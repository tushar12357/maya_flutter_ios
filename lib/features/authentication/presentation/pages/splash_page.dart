import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:math' as math;
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
        body: Stack(
          children: [
            // Background gradient
            Container(color: const Color(0xFF111827)),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x992A57E8), // #2A57E8 at 60%
                    Colors.transparent,
                    // Or: Color(0xFF111827).withOpacity(0.0)
                  ],
                ),
              ),
            ),
            // Main content
            SafeArea(
              child: Column(
                children: [
                  const Spacer(), // Push content to center vertically
                  // Centered Title + Subtitle + Logo
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Title
                      const Text(
                        'Maya AI Secretary',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Subtitle
                      const Text(
                        'Your intelligent AI assistant handles\nscheduling, emails, and conversations\neffortlessly. Work smarter, not harder.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 40),
                      // Logo
                      Image.asset(
                        '../../../../../assets/maya_logo.png',
                        height: 300,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 300,
                            color: Colors.grey.withOpacity(0.1),
                            child: const Icon(
                              Icons.image_not_supported,
                              size: 100,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // Loading Animation
                  const _BouncingDots(),

                  const SizedBox(height: 20),

                  // Loading Text
                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) {
                      String loadingText = 'Initializing...';
                      if (state is AuthLoading) {
                        loadingText = 'Checking authentication...';
                      }
                      return Text(
                        loadingText,
                        style: const TextStyle(
                          color: Color.fromRGBO(189, 189, 189, 1),
                          fontSize: 14,
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 40),
                  const Spacer(), // Push loading to bottom
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Bouncing Dots Widget (kept for functionality)
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
    _animations = [
      Tween<double>(begin: 0, end: -10).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
        ),
      ),
      Tween<double>(begin: 0, end: -10).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.15, 0.85, curve: Curves.easeOut),
        ),
      ),
      Tween<double>(begin: 0, end: -10).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
        ),
      ),
    ];
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
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _animations[index].value),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
