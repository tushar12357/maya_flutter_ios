// tab_layout.dart
import 'package:Maya/core/constants/colors.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:Maya/features/authentication/presentation/pages/home_page.dart';
import 'package:Maya/features/authentication/presentation/pages/tasks_page.dart';
import 'package:Maya/features/widgets/talk_to_maya.dart';
import 'package:Maya/features/authentication/presentation/pages/settings_page.dart';
import 'package:Maya/features/authentication/presentation/pages/other_page.dart';

class TabLayout extends StatefulWidget {
  final Widget child;
  const TabLayout({super.key, required this.child});

  @override
  State<TabLayout> createState() => _TabLayoutState();
}

class _TabLayoutState extends State<TabLayout> {
  // Keep all tab screens alive
  static final List<Widget> _tabPages = [
    const HomePage(),
    const TasksPage(),
    const TalkToMaya(),
    const SettingsPage(),
    const OtherPage(),
  ];

  int get currentIndex {
    final location = GoRouterState.of(context).uri.path;
    return switch (location) {
      '/home' => 0,
      '/tasks' => 1,
      '/maya' => 2,
      '/settings' => 3,
      '/other' => 4,
      _ => 0,
    };
  }

  void _onTabTapped(int index) {
    final routes = ['/home', '/tasks', '/maya', '/settings', '/other'];
    context.go(routes[index]); // Important: go() not push()
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgColor, // Light background
      extendBody: true,
      body: IndexedStack(
        index: currentIndex,
        children: _tabPages, // Never rebuilt → keeps state
      ),
      bottomNavigationBar: CurvedNavigationBar(
        key: const ValueKey('curved_nav'),
        index: currentIndex,
        height: 75,
        color: AppColors.whiteClr, // Nav bar background
        buttonBackgroundColor: Colors.transparent,
        backgroundColor: Colors.transparent,
        animationDuration: const Duration(milliseconds: 300),
        items: [
          _buildNavItem('assets/home.png', 'Home', 0),
          _buildNavItem('assets/task.png', 'Tasks', 1),
          _buildCenterItem(),
          _buildNavItem('assets/setup.png', 'Setup', 3),
          _buildNavItem('assets/other.png', 'Others', 4),
        ],
        onTap: _onTabTapped,
      ),
    );
  }

  Widget _buildNavItem(String asset, String label, int index) {
    final bool isSelected = currentIndex == index;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: isSelected ? const EdgeInsets.all(10) : EdgeInsets.zero,
          decoration: isSelected
              ? const BoxDecoration(
                  color: AppColors.primary, // Orange circle when active
                  shape: BoxShape.circle,
                )
              : null,
          child: Image.asset(
            asset,
            height: 26,
            color: isSelected ? Colors.white : AppColors.balckClr.withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          isSelected ? label : '',
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildCenterItem() {
    final bool isSelected = currentIndex == 2;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: isSelected ? const EdgeInsets.all(16) : const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isSelected
                  ? [AppColors.primary, AppColors.primary.withOpacity(0.8)]
                  : [AppColors.primary.withOpacity(0.7), AppColors.primary.withOpacity(0.5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 3,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: const Icon(
            Icons.auto_awesome,
            size: 34,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          isSelected ? 'AI' : '',
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}