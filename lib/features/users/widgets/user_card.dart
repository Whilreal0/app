import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/users_provider.dart';

class UserCard extends ConsumerWidget {
  final UserProfile user;
  final bool canEdit;

  const UserCard({
    super.key,
    required this.user,
    required this.canEdit,
  });

  void _showRoleChangeDialog(BuildContext context, WidgetRef ref) {
    if (!canEdit) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Role'),
        content: const Text('Select a new role for this user:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ...['user', 'moderator', 'admin', 'superadmin'].map(
            (role) => TextButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await ref
                      .read(usersNotifierProvider.notifier)
                      .updateUserRole(user.id, role);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              child: Text(role.toUpperCase()),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roleColor = AppTheme.getRoleColor(user.role);
    final usersNotifier = ref.read(usersNotifierProvider.notifier);
    final usersState = ref.watch(usersNotifierProvider);
    final isLoading = usersState.isLoading;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        // No border, no boxShadow
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: roleColor,
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              Icons.person,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (user.fullName != null && user.fullName!.isNotEmpty)
                  Text(
                    user.fullName!,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                if (user.username != null && user.username!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Text(
                      '@${user.username!}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                if ((user.fullName == null || user.fullName!.isEmpty) && (user.username == null || user.username!.isEmpty))
                  Text(
                    user.email,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
          // Dropdown and joined date stacked vertically, right-aligned, centered with avatar
          if (canEdit)
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                DropdownButtonHideUnderline(
                  child: Container(
                    alignment: Alignment.centerRight,
                    child: DropdownButton<String>(
                      value: user.role,
                      dropdownColor: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      isDense: true,
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.white70,
                        size: 18,
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                      // Removed selectedItemBuilder
                      items: ['superadmin', 'admin', 'moderator', 'user']
                          .map((role) => DropdownMenuItem(
                                value: role,
                                child: Text(
                                  role.toUpperCase(),
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                                ),
                              ))
                          .toList(),
                      onChanged: isLoading
                          ? null
                          : (newRole) async {
                              if (newRole != null && newRole != user.role) {
                                try {
                                  await usersNotifier.updateUserRole(user.id, newRole);
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e')),
                                    );
                                  }
                                }
                              }
                            },
                      alignment: Alignment.centerRight, // Ensure right alignment (Flutter 3.7+)
                    ),
                  ),
                ),
                // const SizedBox(height: 12),
                Text(
                  'Joined ${user.createdAt.day}/${user.createdAt.month}/${user.createdAt.year}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white38,
                  ),
                ),
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}