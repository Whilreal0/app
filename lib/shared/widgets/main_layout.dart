import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../features/search/screens/search_screen.dart';
import '../providers/bottom_nav_provider.dart';

class MainLayout extends ConsumerStatefulWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout> {
  // int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final userProfileAsync = ref.watch(userProfileProvider);

    return userProfileAsync.when(
      data: (profile) {
        if (profile == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final navigationItems = _getNavigationItems(profile);
        final selectedIndex = ref.watch(bottomNavProvider);

        return Scaffold(
          body: widget.child,
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: selectedIndex,
            onTap: (index) {
              // setState(() => _selectedIndex = index);
              // context.go(navigationItems[index]['route'] as String);
                  ref.read(bottomNavProvider.notifier).state = index;
        context.go(navigationItems[index]['route'] as String);
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: AppTheme.surfaceColor,
            selectedItemColor: AppTheme.primaryColor,
            unselectedItemColor: Colors.grey,
            items: navigationItems
                .map((item) => BottomNavigationBarItem(
                      icon: Icon(item['icon'] as IconData),
                      label: item['label'] as String,
                    ))
                .toList(),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(child: Text('Error: $error')),
      ),
    );
  }

  List<Map<String, dynamic>> _getNavigationItems(dynamic profile) {
    final items = <Map<String, dynamic>>[
      {
        'icon': Icons.home,
        'label': 'Home',
        'route': '/',
      },
      {
        'icon': Icons.dashboard,
        'label': 'Dashboard',
        'route': '/dashboard',
      },
      {
        'icon': Icons.add,
        'label': 'Post',
        'route': '/post', // Placeholder route, implement screen as needed
      },
      {
        'icon': Icons.search,
        'label': 'Search',
        'route': '/search',
      },
      {
        'icon': Icons.settings,
        'label': 'Settings',
        'route': '/settings',
      },
    ];
    return items;
  }
}