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

// tab_layout.dart
class TabLayout extends StatefulWidget {
  final Widget child;
  const TabLayout({super.key, required this.child});

  @override
  State<TabLayout> createState() => _TabLayoutState();
}

class _TabLayoutState extends State<TabLayout> {
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
    context.go(routes[index]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgColor, // ← Must match page background
      extendBody: true, // ← Allows curve to float
      body: IndexedStack(
        index: currentIndex,
        children: _tabPages,
      ),
      bottomNavigationBar: CurvedNavigationBar(
        index: currentIndex,
        height: 75,
        color: AppColors.whiteClr,
        buttonBackgroundColor: Colors.transparent,
        backgroundColor: AppColors.bgColor, // ← THIS FIXES THE TRANSPARENCY!
        animationDuration: const Duration(milliseconds: 300),
        items: [
          _buildNavItem('assets/home.png', 'Home', 0),
          _buildNavItem('assets/task.png', 'Tasks', 1),
          _buildNavItem('assets/star.png', 'AI', 2),
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
          padding: isSelected ? const EdgeInsets.all(12) : EdgeInsets.zero,
          decoration: isSelected
              ? BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                )
              : null,
          child: Image.asset(
            asset,
            height: 26,
            color: isSelected ? Colors.white : AppColors.balckClr.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          isSelected ? label : '',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}