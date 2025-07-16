import 'package:flutter/material.dart';
import '../../../core/models/user_profile.dart';

class QuickActions extends StatelessWidget {
  final UserProfile profile;

  const QuickActions({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        if (profile.isSuperAdmin)
          const ActionItem(text: '• Manage system settings'),
        if (profile.canManageUsers()) ...[
          const ActionItem(text: '• Manage users'),
          const ActionItem(text: '• View analytics'),
        ],
        if (profile.canModerateContent())
          const ActionItem(text: '• Moderate content'),
        const ActionItem(text: '• Update profile'),
      ],
    );
  }
}

class ActionItem extends StatelessWidget {
  final String text;

  const ActionItem({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          color: Colors.grey,
        ),
      ),
    );
  }
}