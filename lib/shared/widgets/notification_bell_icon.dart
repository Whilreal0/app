import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/notification_provider.dart';
import '../../core/providers/auth_provider.dart';

class NotificationBellIcon extends ConsumerWidget {
  const NotificationBellIcon({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        
        final unreadCountAsync = ref.watch(unreadNotificationCountProvider(user.id));
        final unreadCount = unreadCountAsync is AsyncData ? unreadCountAsync.value ?? 0 : 0;
        
        // Debug print
        print('NotificationBellIcon - user: ${user.id}, unreadCountAsync: $unreadCountAsync, unreadCount: $unreadCount');

        return IconButton(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_none, size: 28),
              if ((unreadCount ?? 0) > 0)
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
          tooltip: 'Notifications',
          onPressed: () => context.push('/notifications'),
          onLongPress: () {
            // Test: manually increment the count and test realtime subscription
            print('Test: manually incrementing unread count');
            try {
              final notifier = ref.read(unreadNotificationCountProvider(user.id).notifier);
              print('Test: got notifier: $notifier');
              notifier.increment();
              print('Test: increment called');
              
              // Test realtime subscription
              final notificationsNotifier = ref.read(notificationsProvider(user.id).notifier);
              print('Test: got notifications notifier: $notificationsNotifier');
              notificationsNotifier.testRealtimeSubscription();
              print('Test: realtime subscription test called');
            } catch (e) {
              print('Test: error incrementing: $e');
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
  }
} 