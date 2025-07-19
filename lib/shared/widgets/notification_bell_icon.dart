import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/notification_provider.dart';
import '../../core/providers/auth_provider.dart';

class NotificationBellIcon extends ConsumerStatefulWidget {
  const NotificationBellIcon({Key? key}) : super(key: key);

  @override
  ConsumerState<NotificationBellIcon> createState() => _NotificationBellIconState();
}

class _NotificationBellIconState extends ConsumerState<NotificationBellIcon> {
  bool _pollingStarted = false;

  @override
  void initState() {
    super.initState();
    // Start polling after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startPolling();
    });
  }

  void _startPolling() {
    final authState = ref.read(authStateProvider);
    authState.whenData((user) {
      if (user != null && !_pollingStarted) {
        ref.read(notificationsProvider(user.id).notifier).startPolling();
        _pollingStarted = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    
    return authState.when(
      data: (user) {
        if (user == null) {
          return IconButton(
            icon: const Icon(Icons.notifications_none, size: 28),
            tooltip: 'Notifications',
            onPressed: () => context.push('/notifications'),
          );
        }
        
        final unreadCountAsync = ref.watch(currentUserUnreadCountProvider);
        
        return unreadCountAsync.when(
          data: (unreadCount) {
            return IconButton(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications_none, size: 28),
                  if (unreadCount > 0)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              tooltip: 'Notifications ($unreadCount unread)',
              onPressed: () => context.push('/notifications'),
              onLongPress: () async {
                // Manual refresh
                if (user != null) {
                  await ref.read(unreadNotificationCountProvider(user.id).notifier).refresh();
                  await ref.read(notificationsProvider(user.id).notifier).refresh();
                }
              },
            );
          },
          loading: () => IconButton(
            icon: const Icon(Icons.notifications_none, size: 28),
            tooltip: 'Notifications',
            onPressed: () => context.push('/notifications'),
          ),
          error: (_, __) => IconButton(
            icon: const Icon(Icons.notifications_none, size: 28),
            tooltip: 'Notifications',
            onPressed: () => context.push('/notifications'),
          ),
        );
      },
      loading: () => IconButton(
        icon: const Icon(Icons.notifications_none, size: 28),
        tooltip: 'Notifications',
        onPressed: () => context.push('/notifications'),
      ),
      error: (_, __) => IconButton(
        icon: const Icon(Icons.notifications_none, size: 28),
        tooltip: 'Notifications',
        onPressed: () => context.push('/notifications'),
      ),
    );
  }
} 