import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/post_report_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notifications = true;
  bool _darkMode = true;

  @override
  Widget build(BuildContext context) {
    final userProfileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        automaticallyImplyLeading: false,
      ),
      body: userProfileAsync.when(
        data: (profile) {
          if (profile == null) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Section
                const Text(
                  'Profile',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                ),
                SizedBox(height: 12),
                GestureDetector(
                  onTap: () {
                    context.go('/profile');
                  },
                  child: Card(
                    color: Color(0xFF232A36),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: Icon(Icons.person, color: Colors.white),
                      title: Text('Profile', style: TextStyle(color: Colors.white)),
                      trailing: Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 18),
                    ),
                  ),
                ),
                SizedBox(height: 12),
                if (profile.canManageUsers())
                  GestureDetector(
                    onTap: () {
                      context.go('/users');
                    },
                    child: Card(
                      color: Color(0xFF232A36),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: Icon(Icons.people, color: Colors.white),
                        title: Text('Users', style: TextStyle(color: Colors.white)),
                        trailing: Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 18),
                      ),
                    ),
                  ),
                SizedBox(height: 24),
                // General Settings
                _buildSection(
                  'General',
                  [
                    _buildActionTile(
                      'Notification Preferences',
                      Icons.notifications_active,
                      () => context.push('/settings/notifications'),
                    ),

                    _buildSwitchTile(
                      'Dark Mode',
                      Icons.dark_mode,
                      _darkMode,
                      (value) => setState(() => _darkMode = value),
                    ),
                  ],
                ),
                
                // Administration Settings
                if (profile.canManageUsers())
                  _buildSection(
                    'Administration',
                    [
                      _buildActionTile(
                        'Reported Posts',
                        Icons.report_problem,
                        () => context.push('/reported-posts'),
                      ),
                      _buildActionTile(
                        'Database Management',
                        Icons.storage,
                        () {},
                      ),
                      _buildActionTile(
                        'System Configuration',
                        Icons.settings,
                        () {},
                      ),
                    ],
                  ),
                
                // Super Admin Settings
                if (profile.isSuperAdmin)
                  _buildSection(
                    'Super Admin',
                    [
                      _buildDangerTile(
                        'Reset System',
                        () {},
                      ),
                    ],
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

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSwitchTile(
    String title,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(String title, IconData icon, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: Colors.grey),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white,
          ),
        ),
        onTap: onTap,
        tileColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildDangerTile(String title, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.red,
            fontWeight: FontWeight.w600,
          ),
        ),
        onTap: onTap,
        tileColor: Colors.red.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}