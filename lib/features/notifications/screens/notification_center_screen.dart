import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/notification.dart' as model;
import '../../../core/providers/notification_provider.dart';
import 'package:go_router/go_router.dart';

class NotificationCenterScreen extends ConsumerWidget {
  const NotificationCenterScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final notifier = ref.read(notificationsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.mark_email_read_outlined),
            tooltip: 'Mark all as read',
            onPressed: () => notifier.markAllAsRead(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => notifier.refresh(),
        child: notificationsAsync.when(
          data: (notifications) {
            if (notifications.isEmpty) {
              return const Center(
                child: Text('No notifications yet.', style: TextStyle(color: Colors.grey)),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 16),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.transparent),
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return _NotificationTile(
                  notification: notification,
                  onTap: () async {
                    await notifier.markAsRead(notificationIds: [notification.id]);
                    // Navigate to post/comment/profile based on notification type
                    final type = notification.type;
                    final postId = notification.postId;
                    final commentId = notification.commentId;
                    final fromUserId = notification.fromUserId;
                    if (type == model.NotificationType.commentLike || type == model.NotificationType.commentReply) {
                      if (postId != null) {
                        context.go('/comments/$postId');
                      }
                    } else if (type == model.NotificationType.postLike || type == model.NotificationType.mention) {
                      if (postId != null) {
                        context.go('/post/$postId'); // <-- use this format
                      }
                    } else if (type == model.NotificationType.follow) {
                      if (fromUserId != null) {
                        context.go('/profile?userId=$fromUserId');
                      } else {
                        context.go('/profile');
                      }
                    }
                  },
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Text('Error loading notifications: $error', style: const TextStyle(color: Colors.red)),
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final model.Notification notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;
    return Material(
      color: isUnread ? Colors.blue.shade50.withOpacity(0.08) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: notification.iconColor.withOpacity(0.15),
                child: Icon(notification.icon, color: notification.iconColor, size: 22),
                radius: 22,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.displayTitle,
                      style: TextStyle(
                        fontWeight: isUnread ? FontWeight.bold : FontWeight.w500,
                        color: isUnread ? Colors.white : Colors.grey.shade300,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.displayMessage,
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                children: [
                  if (isUnread)
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    _formatTimestamp(notification.createdAt),
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 11,
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

String _formatTimestamp(DateTime timestamp) {
  final now = DateTime.now();
  final difference = now.difference(timestamp);
  if (difference.inMinutes < 1) return 'Just now';
  if (difference.inHours < 1) return '${difference.inMinutes}m ago';
  if (difference.inDays < 1) return '${difference.inHours}h ago';
  if (difference.inDays < 7) return '${difference.inDays}d ago';
  if (difference.inDays < 30) return '${(difference.inDays / 7).floor()}w ago';
  if (difference.inDays < 365) return '${(difference.inDays / 30).floor()}mo ago';
  return '${(difference.inDays / 365).floor()}y ago';
} 