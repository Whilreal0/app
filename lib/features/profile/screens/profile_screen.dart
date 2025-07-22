import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/providers/bottom_nav_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // For User type
import '../../../core/models/user_profile.dart';
import '../../../core/services/auth_service.dart';

class UserProfileNotifier extends StateNotifier<AsyncValue<UserProfile?>> {
  final AuthService _authService;
  final String userId;

  UserProfileNotifier(this._authService, this.userId) : super(const AsyncValue.loading()) {
    loadProfile();
  }

  Future<void> loadProfile() async {
    state = const AsyncValue.loading();
    try {
      final profile = await _authService.getUserProfile(userId);
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateProfile({
    required String newUsername,
    required String newFullName,
    required String newEmail,
    String? newPassword,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _authService.updateProfile(
        userId: userId,
        newUsername: newUsername,
        newEmail: newEmail,
      );
      await _authService.updateFullName(userId, newFullName);
      await loadProfile(); // <-- This will update the state and UI
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final userProfileNotifierProvider = StateNotifierProvider<UserProfileNotifier, AsyncValue<UserProfile?>>((ref) {
  final authService = ref.watch(authServiceProvider);
  final user = ref.watch(authStateProvider).asData?.value;
  return UserProfileNotifier(authService, user?.id ?? '');
});

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
    final userProfileAsync = ref.watch(userProfileNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              ref.read(bottomNavProvider.notifier).state = 0;
              context.go('/');
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
                // Redesigned Profile Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Avatar with border
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.10),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: roleColor,
                          backgroundImage: (profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty)
                              ? NetworkImage(profile.avatarUrl!)
                              : null,
                          child: (profile.avatarUrl == null || profile.avatarUrl!.isEmpty)
                              ? const Icon(Icons.person, color: Colors.white, size: 40)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 28),
                      // User Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.fullName ?? '',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '@${profile.username}',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                                const SizedBox(width: 6),
                                Text(
                                  'Joined ${profile.createdAt.day}/${profile.createdAt.month}/${profile.createdAt.year}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Edit/Delete Buttons
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _ProfileActionButton(
                            icon: Icons.edit,
                            color: Colors.blue,
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (context) => EditProfileDialog(
                                  initialUsername: profile.username ?? '',
                                  initialFullName: profile.fullName ?? '',
                                  initialEmail: profile.email,
                                ),
                              );
                            },
                            tooltip: 'Edit Profile',
                          ),
                          const SizedBox(height: 12),
                          _ProfileActionButton(
                            icon: Icons.delete,
                            color: Colors.red,
                            onTap: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Account'),
                                  content: const Text('Are you sure you want to delete your account? This action cannot be undone.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(true),
                                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                final notifier = ref.read(authNotifierProvider.notifier);
                                final userId = ref.read(userProfileNotifierProvider).value?.id;
                                if (userId != null) {
                                  await notifier.deleteAccount(userId);
                                  try {
                                    await Supabase.instance.client.auth.signOut();
                                  } catch (e) {
                                    // Ignore 403 errors after user deletion
                                  }
                                }
                              }
                            },
                            tooltip: 'Delete Account',
                          ),
                        ],
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

class _ProfileActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  const _ProfileActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: Container(
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: color, size: 24),
          ),
        ),
      ),
    );
  }
}

class EditProfileDialog extends StatefulWidget {
  final String initialUsername;
  final String initialFullName;
  final String initialEmail;

  const EditProfileDialog({
    Key? key,
    required this.initialUsername,
    required this.initialFullName,
    required this.initialEmail,
  }) : super(key: key);

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  late TextEditingController _usernameController;
  late TextEditingController _fullNameController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.initialUsername);
    _fullNameController = TextEditingController(text: widget.initialFullName);
    _emailController = TextEditingController(text: widget.initialEmail);
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile(BuildContext context, WidgetRef ref) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
      _success = null;
    });
    try {
      final userProfile = ref.read(userProfileNotifierProvider).value;
      if (userProfile == null) throw Exception('User not found');
      await ref.read(authNotifierProvider.notifier).updateProfile(
        userId: userProfile.id,
        newUsername: _usernameController.text.trim(),
        newFullName: _fullNameController.text.trim(),
        newEmail: _emailController.text.trim(),
        newPassword: _passwordController.text.isNotEmpty ? _passwordController.text : null,
      );
      if (mounted) {
        setState(() {
          _success = 'Profile updated successfully!';
        });
      }
      // Refresh profile
      ref.refresh(userProfileNotifierProvider);
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar with edit icon
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.grey[200],
                    child: Icon(Icons.person, size: 48, color: Colors.grey[600]),
                  ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: const Icon(Icons.edit, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                _fullNameController.text,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Full Name', style: TextStyle(color: Colors.grey, fontSize: 13)),
              ),
              TextField(
                controller: _fullNameController,
                decoration: const InputDecoration(
                  border: UnderlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Username', style: TextStyle(color: Colors.grey, fontSize: 13)),
              ),
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  border: const UnderlineInputBorder(),
                  isDense: true,
                  prefixText: '@ ',
                  suffixIcon: Icon(Icons.check_circle, color: Colors.green[400], size: 20),
                ),
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Email Address', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              ),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  border: UnderlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Password', style: TextStyle(color: Colors.grey, fontSize: 13)),
              ),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  border: const UnderlineInputBorder(),
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 20),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (_error != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _error!,
                    style: TextStyle(color: Colors.red[400], fontSize: 12),
                  ),
                )
              else
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Password should contain at least 8 characters!',
                    style: TextStyle(color: Colors.red[400], fontSize: 12),
                  ),
                ),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: CircularProgressIndicator(),
                ),
              if (_success != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(_success!, style: const TextStyle(color: Colors.green)),
                ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : () => _saveProfile(context, ref),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}