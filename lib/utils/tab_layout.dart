import 'package:flutter/material.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../features/authentication/presentation/bloc/auth_bloc.dart';
import '../../../features/authentication/presentation/bloc/auth_event.dart';

class TabLayout extends StatefulWidget {
  final Widget child;

  const TabLayout({super.key, required this.child});

  @override
  State<TabLayout> createState() => _TabLayoutState();
}

class _TabLayoutState extends State<TabLayout> with TickerProviderStateMixin {
  late TabController _tabController;
  int _currentIndex = 0;

  static const List<Map<String, dynamic>> _tabs = [
    {'route': '/home', 'icon': FeatherIcons.home, 'label': 'Home'},
    {'route': '/tasks', 'icon': FeatherIcons.checkSquare, 'label': 'Tasks'},
    {'route': '/maya', 'icon': FeatherIcons.star, 'label': 'Maya'},
    {'route': '/settings', 'icon': FeatherIcons.settings, 'label': 'Settings'},
    {'route': '/other', 'icon': FeatherIcons.moreHorizontal, 'label': 'Other'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging || _tabController.index != _currentIndex) {
      setState(() {
        _currentIndex = _tabController.index;
      });
      context.go(_tabs[_currentIndex]['route'] as String);
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _updateTabFromRoute() {
    final location = GoRouterState.of(context).uri.path;
    final newIndex = _tabs.indexWhere(
      (tab) => location == tab['route'] || location.startsWith('${tab['route']}/'),
    );
    if (newIndex != -1 && newIndex != _currentIndex) {
      setState(() {
        _currentIndex = newIndex;
      });
      _tabController.animateTo(newIndex);
    }
  }

  Future<void> _handleLogout() async {
    context.read<AuthBloc>().add(LogoutRequested());
  }

  String _getAppBarTitle() {
    return _tabs[_currentIndex]['label'] as String;
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateTabFromRoute();
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final currentLocation = GoRouterState.of(context).uri.path;
        final isTabRoute = _tabs.any((tab) => tab['route'] == currentLocation);

        if (!isTabRoute && currentLocation != '/home') {
          context.go('/home');
        } else if (currentLocation == '/home') {
          Navigator.of(context).maybePop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF111827),
        extendBody: true, // Allows body to extend behind the navigation bar
        body: widget.child,
        bottomNavigationBar: _buildBottomNavigationBar(),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    const activeColor = Color(0xFF60A5FA); // Light blue for active
    const inactiveColor = Color(0xFF9CA3AF); // Grey for inactive
    const backgroundColor = Color(0xFF1E293B); // Dark navy background

    return Container(
      margin: const EdgeInsets.all(16),
      height: 90, // Increased to accommodate elevated button
      decoration: const BoxDecoration(
        color: Colors.transparent, // Transparent container
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // Bottom navigation bar with notch
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: CustomPaint(
                  painter: _NavBarNotchPainter(),
                  child: Row(
                    children: List.generate(_tabs.length, (index) {
                      final tab = _tabs[index];
                      final isActive = _currentIndex == index;
                      final isCentral = index == 2;

                      if (isCentral) {
                        // Empty space for central button
                        return const Expanded(child: SizedBox());
                      } else {
                        // Regular side tabs
                        return Expanded(
                          child: InkWell(
                            onTap: () => _tabController.animateTo(index),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    tab['icon'] as IconData,
                                    size: 22,
                                    color: isActive ? activeColor : inactiveColor,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    tab['label'] as String,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: isActive ? activeColor : inactiveColor,
                                    ),
                                  ),
                                  // Active indicator line
                                  if (isActive)
                                    Container(
                                      margin: const EdgeInsets.only(top: 4),
                                      width: 32,
                                      height: 3,
                                      decoration: BoxDecoration(
                                        color: activeColor,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }
                    }),
                  ),
                ),
              ),
            ),
          ),
          // Elevated central FAB button
          Positioned(
            top: 0,
            child: GestureDetector(
              onTap: () => _tabController.animateTo(2),
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withOpacity(0.6),
                      blurRadius: 20,
                      spreadRadius: 2,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child:  Image.asset(
                  '../../assets/maya_logo.png',
                  width: 28,
                  height: 28,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter to create a notch/cutout for the central button
class _NavBarNotchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.fill;

    final path = Path();
    
    // Start from left
    path.moveTo(0, 0);
    path.lineTo(0, size.height);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width, 0);
    
    // Create a circular notch in the center
    final notchCenter = size.width / 2;
    final notchRadius = 38.0; // Slightly larger than button radius for clearance
    
    path.moveTo(notchCenter - notchRadius - 10, 0);
    path.quadraticBezierTo(
      notchCenter - notchRadius, -5,
      notchCenter - notchRadius + 5, -10,
    );
    
    path.arcToPoint(
      Offset(notchCenter + notchRadius - 5, -10),
      radius: Radius.circular(notchRadius),
      clockwise: false,
    );
    
    path.quadraticBezierTo(
      notchCenter + notchRadius, -5,
      notchCenter + notchRadius + 10, 0,
    );
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}