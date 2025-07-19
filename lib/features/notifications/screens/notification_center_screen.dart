import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/notification_provider.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/models/notification.dart' as model;

class NotificationCenterScreen extends ConsumerStatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  ConsumerState<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends ConsumerState<NotificationCenterScreen> {
  @override
  Widget build(BuildContext context) {
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
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh notifications',
                onPressed: () async {
                  try {
                    await notifier.refresh();
                  } catch (e) {
                    // If notifier is disposed, just return
                    return;
                  }
                },
              ),
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
          body: notificationsAsync.when(
            data: (notifications) {
              if (notifications.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_none,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No notifications yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  try {
                    await notifier.refresh();
                  } catch (e) {
                    // If notifier is disposed, just return
                    return;
                  }
                },
                child: ListView.separated(
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
                      child: NotificationTile(
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
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Text('Error: $error'),
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

class NotificationTile extends StatelessWidget {
  final model.Notification notification;
  final VoidCallback? onTap;

  const NotificationTile({
    super.key,
    required this.notification,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: notification.fromAvatarUrl != null
            ? NetworkImage(notification.fromAvatarUrl!)
            : null,
        child: notification.fromAvatarUrl == null
            ? Text(notification.fromUsername?.substring(0, 1).toUpperCase() ?? '?')
            : null,
      ),
      title: Text(
        notification.title,
        style: TextStyle(
          fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(notification.message),
          const SizedBox(height: 4),
          Text(
            _formatTimestamp(notification.createdAt),
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
      trailing: notification.isRead
          ? null
          : Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
            ),
      onTap: onTap,
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
} 