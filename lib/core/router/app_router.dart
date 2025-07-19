import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../features/auth/screens/auth_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/home/screens/comments_screen.dart';
import '../../features/home/screens/fyp_screen.dart';
import '../../features/notifications/screens/notification_center_screen.dart';
import '../../features/post/screens/post_screen.dart';
import '../../features/post/screens/post_details_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/search/screens/search_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/settings/screens/notification_settings_screen.dart';
import '../../features/settings/screens/reported_posts_screen.dart';
import '../../features/users/screens/users_screen.dart';
import '../../shared/widgets/main_layout.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      return authState.when(
        data: (user) {
          final isLoggedIn = user != null;
          final isLoggingIn = state.matchedLocation == '/auth';
          final isDashboard = state.matchedLocation == '/dashboard';
          
          if (!isLoggedIn && !isLoggingIn) return '/auth';
          if (isLoggedIn && isLoggingIn) return '/';
          if (isDashboard) return '/'; // Redirect dashboard to home
          return null;
        },
        loading: () => null,
        error: (_, __) => '/auth',
      );
    },
    routes: [
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainLayout(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/users',
            builder: (context, state) => const UsersScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/settings/notifications',
            builder: (context, state) => const NotificationSettingsScreen(),
          ),
          GoRoute(
            path: '/reported-posts',
            builder: (context, state) => const ReportedPostsScreen(),
          ),

          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/search',
            builder: (context, state) => const SearchScreen(),
          ),
          GoRoute(
            path: '/post',
            builder: (context, state) => const PostScreen(),
          ),
          GoRoute(
            path: '/post/:postId',
            builder: (context, state) {
              final postId = state.pathParameters['postId']!;
              return PostDetailsScreen(postId: postId);
            },
          ),
          GoRoute(
            path: '/notifications',
            builder: (context, state) => const NotificationCenterScreen(),
          ),
        ],
      ),
      // Comments route (outside ShellRoute so it has its own AppBar)
      GoRoute(
        path: '/comments/:postId',
        builder: (context, state) {
          final postId = state.pathParameters['postId']!;
          return CommentsScreen(postId: postId);
        },
      ),
    ],
  );
});