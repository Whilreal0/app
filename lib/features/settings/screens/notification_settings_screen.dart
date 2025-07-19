import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/notification_settings_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/app_initialization_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends ConsumerState<NotificationSettingsScreen> {
  bool _pushNotifications = true;
  bool _emailNotifications = false;
  
  // Notification type preferences
  bool _postLikes = true;
  bool _postComments = true;
  bool _commentLikes = true;
  bool _commentReplies = true;
  bool _follows = true;
  bool _mentions = true;
  
  // Push notification status
  bool _pushNotificationsAvailable = false;
  bool _pushNotificationsEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkPushNotificationStatus();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pushNotifications = prefs.getBool('push_notifications') ?? true;
      _emailNotifications = prefs.getBool('email_notifications') ?? false;
      
      _postLikes = prefs.getBool('notify_post_likes') ?? true;
      _postComments = prefs.getBool('notify_post_comments') ?? true;
      _commentLikes = prefs.getBool('notify_comment_likes') ?? true;
      _commentReplies = prefs.getBool('notify_comment_replies') ?? true;
      _follows = prefs.getBool('notify_follows') ?? true;
      _mentions = prefs.getBool('notify_mentions') ?? true;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('push_notifications', _pushNotifications);
    await prefs.setBool('email_notifications', _emailNotifications);
    
    await prefs.setBool('notify_post_likes', _postLikes);
    await prefs.setBool('notify_post_comments', _postComments);
    await prefs.setBool('notify_comment_likes', _commentLikes);
    await prefs.setBool('notify_comment_replies', _commentReplies);
    await prefs.setBool('notify_follows', _follows);
    await prefs.setBool('notify_mentions', _mentions);
    
    // Also save to Supabase for server-side preferences
    final user = ref.read(authStateProvider).value;
    if (user != null) {
      await ref.read(notificationSettingsProvider(user.id).notifier).updateSettings({
        'push_notifications': _pushNotifications,
        'email_notifications': _emailNotifications,
        'post_likes': _postLikes,
        'post_comments': _postComments,
        'comment_likes': _commentLikes,
        'comment_replies': _commentReplies,
        'follows': _follows,
        'mentions': _mentions,
      });
    }
  }

  Future<void> _checkPushNotificationStatus() async {
    final appInitService = AppInitializationService();
    final available = await appInitService.arePushNotificationsAvailable();
    final enabled = await appInitService.requestPushNotificationPermissions();
    
    setState(() {
      _pushNotificationsAvailable = available;
      _pushNotificationsEnabled = enabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Preferences'),
        backgroundColor: AppTheme.backgroundColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Push Notifications Section
            _buildSection(
              'Push Notifications',
              [
                if (!_pushNotificationsAvailable)
                  _buildInfoTile(
                    'Push Notifications Not Available',
                    Icons.info_outline,
                    'Push notifications are not available on this platform',
                    Colors.orange,
                  ),
                _buildSwitchTile(
                  'Enable Push Notifications',
                  Icons.notifications_active,
                  _pushNotifications && _pushNotificationsAvailable,
                  (value) async {
                    if (value && !_pushNotificationsEnabled) {
                      // Request permissions
                      final appInitService = AppInitializationService();
                      final granted = await appInitService.requestPushNotificationPermissions();
                      if (!granted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Push notification permissions denied'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                    }
                    setState(() => _pushNotifications = value);
                    await _saveSettings();
                  },
                ),
              ],
            ),

            // Email Notifications Section
            _buildSection(
              'Email Notifications',
              [
                _buildSwitchTile(
                  'Enable Email Notifications',
                  Icons.email,
                  _emailNotifications,
                  (value) async {
                    setState(() => _emailNotifications = value);
                    await _saveSettings();
                  },
                ),
              ],
            ),

            // Notification Types Section
            _buildSection(
              'Notification Types',
              [
                _buildSwitchTile(
                  'Post Likes',
                  Icons.favorite,
                  _postLikes,
                  (value) async {
                    setState(() => _postLikes = value);
                    await _saveSettings();
                  },
                ),
                _buildSwitchTile(
                  'Post Comments',
                  Icons.comment,
                  _postComments,
                  (value) async {
                    setState(() => _postComments = value);
                    await _saveSettings();
                  },
                ),
                _buildSwitchTile(
                  'Comment Likes',
                  Icons.favorite_border,
                  _commentLikes,
                  (value) async {
                    setState(() => _commentLikes = value);
                    await _saveSettings();
                  },
                ),
                _buildSwitchTile(
                  'Comment Replies',
                  Icons.reply,
                  _commentReplies,
                  (value) async {
                    setState(() => _commentReplies = value);
                    await _saveSettings();
                  },
                ),
                _buildSwitchTile(
                  'New Followers',
                  Icons.person_add,
                  _follows,
                  (value) async {
                    setState(() => _follows = value);
                    await _saveSettings();
                  },
                ),
                _buildSwitchTile(
                  'Mentions',
                  Icons.alternate_email,
                  _mentions,
                  (value) async {
                    setState(() => _mentions = value);
                    await _saveSettings();
                  },
                ),
              ],
            ),
          ],
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

  Widget _buildInfoTile(String title, IconData icon, String message, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
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
          const Icon(Icons.info_outline, color: Colors.orange),
        ],
      ),
    );
  }
} 