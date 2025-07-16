import 'package:flutter/material.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/theme/app_theme.dart';

class RoleCard extends StatelessWidget {
  final UserProfile profile;

  const RoleCard({super.key, required this.profile});

  String _getRoleDescription(String role) {
    switch (role.toLowerCase()) {
      case 'superadmin':
        return 'Full system access with all privileges';
      case 'admin':
        return 'Administrative access to manage users and content';
      case 'moderator':
        return 'Content moderation and user support';
      case 'user':
        return 'Standard user access to basic features';
      default:
        return 'Unknown role';
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleColor = AppTheme.getRoleColor(profile.role);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: roleColor, width: 4),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: roleColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.shield,
                  color: roleColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                profile.role.toUpperCase(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: roleColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _getRoleDescription(profile.role),
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}