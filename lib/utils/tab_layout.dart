import 'package:flutter/material.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:go_router/go_router.dart';

class TabLayout extends StatelessWidget {
  final Widget child;
    final int currentIndex;
 const TabLayout({
    super.key,
    required this.child,
    required this.currentIndex,
  });

  static const _tabs = [
    {'route': '/home', 'icon': FeatherIcons.home,           'label': 'Home'},
    {'route': '/tasks', 'icon': FeatherIcons.checkSquare,   'label': 'Tasks'},
    {'route': '/maya',  'icon': FeatherIcons.star,          'label': 'Maya'},
    {'route': '/settings','icon': FeatherIcons.settings,    'label': 'Settings'},
    {'route': '/other', 'icon': FeatherIcons.moreHorizontal,'label': 'Other'},
  ];

  int _currentIndexFromRoute(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final index = _tabs.indexWhere(
      (tab) => location == tab['route'] || location.startsWith('${tab['route']}/'),
    );
    return index == -1 ? 0 : index;
  }

  Future<bool> _handleBack(BuildContext context) async {
  final rootNavigator = Navigator.of(context, rootNavigator: true);

  if (rootNavigator.canPop()) {
    rootNavigator.pop();
    return false; // don't close app
  }

  return true; // allow app exit
}


  @override
  Widget build(BuildContext context) {
    final currentIndex = _currentIndexFromRoute(context);

    return WillPopScope(
      onWillPop: () => _handleBack(context),
      child: Scaffold(
        backgroundColor: const Color(0xFF111827),
        extendBody: true,
        body: child,
        bottomNavigationBar: _buildBottomNavigationBar(context, currentIndex),
      ),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context, int currentIndex) {
    const activeColor = Color(0xFF60A5FA);
    const inactiveColor = Color(0xFF9CA3AF);
    const backgroundColor = Color(0xFF1E293B);

    return Container(
      margin: const EdgeInsets.all(16),
      height: 90,
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            bottom: 0, left: 0, right: 0,
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
                      final isActive = currentIndex == index;
                      final isCentral = index == 2;

                      if (isCentral) {
                        return const Expanded(child: SizedBox());
                      }

                      return Expanded(
                        child: InkWell(
                          onTap: () {
                            if (!isActive) {
                              context.push(tab['route'] as String);
                            }
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
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
                    }),
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            top: 0,
            child: GestureDetector(
              onTap: () {
                if (currentIndex != 2) {
                  context.push('/maya');
                }
              },
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
                child: Center(
                  child: Image.asset(
                    'assets/maya_logo.png',
                    width: 28,
                    height: 28,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        FeatherIcons.star,
                        color: Colors.white,
                        size: 28,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavBarNotchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width, 0);

    final notchCenter = size.width / 2;
    const notchRadius = 38.0;

    path
      ..moveTo(notchCenter - notchRadius - 10, 0)
      ..quadraticBezierTo(
          notchCenter - notchRadius, -5, notchCenter - notchRadius + 5, -10)
      ..arcToPoint(
        Offset(notchCenter + notchRadius - 5, -10),
        radius: const Radius.circular(notchRadius),
        clockwise: false,
      )
      ..quadraticBezierTo(
          notchCenter + notchRadius, -5, notchCenter + notchRadius + 10, 0);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}