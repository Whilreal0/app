import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/providers/bottom_nav_provider.dart';
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  void _showSignOutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(authNotifierProvider.notifier).signOut();
              ref.read(bottomNavProvider.notifier).state = 0;
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/settings'); // or another fallback route
            }
          },
        ),
      ),
      body: userProfileAsync.when(
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('No profile found'));
          }

          final roleColor = AppTheme.getRoleColor(profile.role);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Profile Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: roleColor,
                          borderRadius: BorderRadius.circular(40),
                        ),
                        child: const Icon(
                          Icons.shield,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildInfoRow(Icons.email, profile.email),
                      const SizedBox(height: 16),
                      _buildInfoRow(
                        Icons.shield,
                        profile.role.toUpperCase(),
                        color: roleColor,
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow(
                        Icons.calendar_today,
                        'Joined ${profile.createdAt.day}/${profile.createdAt.month}/${profile.createdAt.year}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                
                // Permissions Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Permissions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (profile.isSuperAdmin) ...[
                        _buildPermissionItem('✓ Full system access'),
                        _buildPermissionItem('✓ Manage all users'),
                        _buildPermissionItem('✓ System configuration'),
                      ] else if (profile.isAdmin) ...[
                        _buildPermissionItem('✓ User management'),
                        _buildPermissionItem('✓ Content moderation'),
                        _buildPermissionItem('✓ Analytics access'),
                      ] else if (profile.isModerator) ...[
                        _buildPermissionItem('✓ Content moderation'),
                        _buildPermissionItem('✓ User support'),
                      ] else ...[
                        _buildPermissionItem('✓ Basic platform access'),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                
                // Sign Out Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showSignOutDialog(context, ref),
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign Out'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error: $error'),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 12),
        Text(
          text,
          style: TextStyle(
            fontSize: 16,
            color: color ?? Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          color: Colors.green,
        ),
      ),
    );
  }
}