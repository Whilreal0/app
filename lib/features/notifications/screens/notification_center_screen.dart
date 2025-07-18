import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/notification_provider.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/models/notification.dart' as model;

class NotificationCenterScreen extends ConsumerWidget {
  const NotificationCenterScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    
    return authState.when(
      data: (user) {
        if (user == null) {
          return const Scaffold(
            body: Center(child: Text('Please log in')),
          );
        }
        
        final notificationsAsync = ref.watch(notificationsProvider(user.id));
        final notifier = ref.read(notificationsProvider(user.id).notifier);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Notifications'),
            actions: [
              IconButton(
                icon: const Icon(Icons.mark_email_read_outlined),
                tooltip: 'Mark all as read',
                onPressed: () {
                  try {
                    notifier.markAllAsRead();
                  } catch (e) {
                    // If notifier is disposed, just return
                    return;
                  }
                },
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              try {
                await notifier.refresh();
              } catch (e) {
                // If notifier is disposed, just return
                return;
              }
            },
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
                    return Dismissible(
                      key: ValueKey(notification.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (direction) async {
                        final removedNotification = notification;
                        
                        // Check if the notifier is still valid
                        try {
                          notifier.removeNotification(notification.id);
                        } catch (e) {
                          // If notifier is disposed, just return
                          return;
                        }
                        
                        // If the deleted notification was unread, decrement the unread count
                        if (!removedNotification.isRead) {
                          try {
                            final authState = ref.read(authStateProvider);
                            authState.whenData((user) {
                              if (user != null) {
                                ref.read(unreadNotificationCountProvider(user.id).notifier).decrement();
                              }
                            });
                          } catch (e) {
                            // If unread count notifier is disposed, ignore
                          }
                        }
                        
                        try {
                          await ref.read(notificationServiceProvider).deleteNotification(notification.id);
                        } catch (e) {
                          // If deletion fails, restore the notification
                          if (context.mounted) {
                            try {
                              notifier.addNotification(removedNotification);
                            } catch (e) {
                              // If notifier is disposed, just show error
                            }
                            
                            // If the notification was unread, increment the count back
                            if (!removedNotification.isRead) {
                              try {
                                final authState = ref.read(authStateProvider);
                                authState.whenData((user) {
                                  if (user != null) {
                                    ref.read(unreadNotificationCountProvider(user.id).notifier).increment();
                                  }
                                });
                              } catch (e) {
                                // If unread count notifier is disposed, ignore
                              }
                            }
                            
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to delete notification: $e')),
                            );
                          }
                          return;
                        }

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Notification deleted'),
                              action: SnackBarAction(
                                label: 'Undo',
                                onPressed: () async {
                                  if (context.mounted) {
                                    try {
                                      notifier.addNotification(removedNotification);
                                    } catch (e) {
                                      // If notifier is disposed, just return
                                      return;
                                    }
                                    
                                    // If the restored notification was unread, increment the count
                                    if (!removedNotification.isRead) {
                                      try {
                                        final authState = ref.read(authStateProvider);
                                        authState.whenData((user) {
                                          if (user != null) {
                                            ref.read(unreadNotificationCountProvider(user.id).notifier).increment();
                                          }
                                        });
                                      } catch (e) {
                                        // If unread count notifier is disposed, ignore
                                      }
                                    }
                                    
                                    try {
                                      await ref.read(notificationServiceProvider).restoreNotification(removedNotification);
                                    } catch (e) {
                                      if (context.mounted) {
                                        try {
                                          notifier.removeNotification(removedNotification.id);
                                        } catch (e) {
                                          // If notifier is disposed, just show error
                                        }
                                        
                                        // If the notification was unread, decrement the count back
                                        if (!removedNotification.isRead) {
                                          try {
                                            final authState = ref.read(authStateProvider);
                                            authState.whenData((user) {
                                              if (user != null) {
                                                ref.read(unreadNotificationCountProvider(user.id).notifier).decrement();
                                              }
                                            });
                                          } catch (e) {
                                            // If unread count notifier is disposed, ignore
                                          }
                                        }
                                        
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Failed to restore notification: $e')),
                                        );
                                      }
                                    }
                                  }
                                },
                              ),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        }
                      },
                      child: _NotificationTile(
                        notification: notification,
                        onTap: () async {
                          // If the notification is unread, decrement the count before marking as read
                          if (!notification.isRead) {
                            try {
                              final authState = ref.read(authStateProvider);
                              authState.whenData((user) {
                                if (user != null) {
                                  ref.read(unreadNotificationCountProvider(user.id).notifier).decrement();
                                }
                              });
                            } catch (e) {
                              // If unread count notifier is disposed, ignore
                            }
                          }
                          
                          try {
                            await notifier.markAsRead(notificationIds: [notification.id]);
                          } catch (e) {
                            // If notifier is disposed, just return
                            return;
                          }
                          
                          if (!context.mounted) return;
                          
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
                              context.go('/post/$postId');
                            }
                          } else if (type == model.NotificationType.follow) {
                            if (fromUserId != null) {
                              context.go('/profile?userId=$fromUserId');
                            } else {
                              context.go('/profile');
                            }
                          }
                        },
                      ),
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
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(child: Text('Error: $error')),
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