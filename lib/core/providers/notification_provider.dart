import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification.dart';
import '../services/notification_service.dart';
import 'auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:realtime_client/realtime_client.dart' show PostgresChangeFilterType;

// Provider for notification service
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

// Family provider for notifications list
final notificationsProvider = StateNotifierProvider.family<NotificationsNotifier, AsyncValue<List<Notification>>, String?>((ref, userId) {
  return NotificationsNotifier(ref, userId);
});

// Family provider for unread notification count
final unreadNotificationCountProvider = StateNotifierProvider.family<UnreadCountNotifier, AsyncValue<int>, String?>((ref, userId) {
  return UnreadCountNotifier(ref, userId);
});

// Convenience providers that automatically get the current user's data
final currentUserNotificationsProvider = Provider<AsyncValue<List<Notification>>>((ref) {
  final authState = ref.watch(authStateProvider);
  
  return authState.when(
    data: (user) {
      if (user == null) return const AsyncValue.data([]);
      return ref.watch(notificationsProvider(user.id));
    },
    loading: () => const AsyncValue.loading(),
    error: (_, __) => AsyncValue.error('User not found', StackTrace.current),
  );
});

final currentUserUnreadCountProvider = Provider<AsyncValue<int>>((ref) {
  final authState = ref.watch(authStateProvider);
  
  return authState.when(
    data: (user) {
      if (user == null) {
        print('currentUserUnreadCountProvider - user is null, returning 0');
        return const AsyncValue.data(0);
      }
      print('currentUserUnreadCountProvider - user: ${user.id}');
      final result = ref.watch(unreadNotificationCountProvider(user.id));
      print('currentUserUnreadCountProvider - result: $result');
      return result;
    },
    loading: () {
      print('currentUserUnreadCountProvider - loading');
      return const AsyncValue.loading();
    },
    error: (_, __) {
      print('currentUserUnreadCountProvider - error');
      return AsyncValue.error('User not found', StackTrace.current);
    },
  );
});

class NotificationsNotifier extends StateNotifier<AsyncValue<List<Notification>>> {
  final Ref ref;
  final String? userId;
  RealtimeChannel? _realtimeChannel;
  bool _disposed = false;
  
  NotificationsNotifier(this.ref, this.userId) : super(const AsyncValue.loading()) {
    print('NotificationsNotifier constructor called for user: $userId');
    if (userId != null && !_disposed) {
      print('NotificationsNotifier constructor - loading notifications and setting up realtime');
      loadNotifications();
      _setupRealtimeSubscription();
    } else {
      print('NotificationsNotifier constructor - userId is null or disposed');
    }
  }

  Future<void> loadNotifications() async {
    if (userId == null || _disposed) return;
    
    try {
      print('Loading notifications for user: $userId');
      if (_disposed) return;
      state = const AsyncValue.loading();
      final notifications = await ref.read(notificationServiceProvider).fetchNotifications(userId!);
      if (_disposed) return;
      state = AsyncValue.data(notifications);
    } catch (e) {
      if (_disposed) return;
      print('Error loading notifications: $e');
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> markAsRead({List<String>? notificationIds}) async {
    if (userId == null || _disposed) return;

    try {
      await ref.read(notificationServiceProvider).markAsRead(userId!, notificationIds: notificationIds);
      
      // Update state optimistically
      state.whenData((notifications) {
        final updatedNotifications = notifications.map((notification) {
          if (notificationIds == null || notificationIds.contains(notification.id)) {
            return notification.copyWith(isRead: true);
          }
          return notification;
        }).toList();
        
        state = AsyncValue.data(updatedNotifications);
      });

      // Refresh unread count
      if (!_disposed && userId != null) {
        // Decrement unread count for each notification marked as read
        final countToDecrement = notificationIds?.length ?? 1;
        for (int i = 0; i < countToDecrement; i++) {
          ref.read(unreadNotificationCountProvider(userId!).notifier).decrement();
        }
      }
    } catch (e) {
      print('Error marking notifications as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    if (_disposed) return;
    await markAsRead();
  }

  void _setupRealtimeSubscription() {
    if (userId == null || _realtimeChannel != null) return;
    
    print('_setupRealtimeSubscription - setting up for user: $userId');
    
    try {
      _realtimeChannel = Supabase.instance.client.channel('public:notifications_user_$userId')
        ..onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId!,
          ),
          callback: (payload) {
            print('New notification received: $payload');
            _handleNewNotification(payload);
          },
        )
        ..subscribe((status, [error]) {
          print('_setupRealtimeSubscription - subscription status: $status');
          if (error != null) {
            print('_setupRealtimeSubscription - subscription error: $error');
          }
        });
        
      print('_setupRealtimeSubscription - subscription set up for user: $userId');
    } catch (e) {
      print('_setupRealtimeSubscription - error setting up subscription: $e');
    }
  }

  @override
  void dispose() {
    print('NotificationsNotifier.dispose() called for user: $userId');
    _disposed = true;
    if (_realtimeChannel != null) {
      print('NotificationsNotifier.dispose() - unsubscribing from realtime channel');
      _realtimeChannel!.unsubscribe();
      _realtimeChannel = null;
    }
    super.dispose();
  }

  void _handleNewNotification(dynamic payload) {
    if (_disposed) return; // Prevent updates after disposal
    
    print('_handleNewNotification called for user: $userId');
    
    try {
      final newNotificationData = payload.newRecord as Map<String, dynamic>;
      print('_handleNewNotification - new notification data: $newNotificationData');
      
      // Get from user's profile
      _getFromUserProfile(newNotificationData['from_user_id']).then((fromUser) {
        if (_disposed) return; // Check again after async operation
        
        final notification = Notification.fromMap({
          ...newNotificationData,
          'from_username': fromUser?['username'],
          'from_avatar_url': fromUser?['avatar_url'],
        });

        print('_handleNewNotification - created notification: ${notification.id}');

        // Add to state
        state.whenData((notifications) {
          if (_disposed) return; // Check before state update
          final updatedNotifications = [notification, ...notifications];
          state = AsyncValue.data(updatedNotifications);
        });

        // Update unread count
        if (!_disposed && userId != null) {
          print('_handleNewNotification - incrementing unread count');
          ref.read(unreadNotificationCountProvider(userId!).notifier).increment();
        }
      });
    } catch (e) {
      print('Error handling new notification: $e');
    }
  }

  Future<Map<String, dynamic>?> _getFromUserProfile(String fromUserId) async {
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('username, avatar_url')
          .eq('id', fromUserId)
          .single();
      return response;
    } catch (e) {
      print('Error getting from user profile: $e');
      return null;
    }
  }

  Future<void> refresh() async {
    if (_disposed) return;
    await loadNotifications();
  }

  void removeNotification(String notificationId) {
    if (_disposed) return;
    state.whenData((notifications) {
      if (_disposed) return;
      final updated = notifications.where((n) => n.id != notificationId).toList();
      state = AsyncValue.data(updated);
    });
  }

  void addNotification(Notification notification) {
    if (_disposed) return;
    state.whenData((notifications) {
      if (_disposed) return;
      final updated = [notification, ...notifications];
      state = AsyncValue.data(updated);
    });
  }

  // Method to manually test realtime subscription
  void testRealtimeSubscription() {
    print('testRealtimeSubscription called for user: $userId');
    print('testRealtimeSubscription - _realtimeChannel: $_realtimeChannel');
    print('testRealtimeSubscription - _disposed: $_disposed');
    
    if (_realtimeChannel != null) {
      print('testRealtimeSubscription - channel exists and is set up');
    } else {
      print('testRealtimeSubscription - no channel exists, trying to set up');
      _setupRealtimeSubscription();
    }
  }
}

class UnreadCountNotifier extends StateNotifier<AsyncValue<int>> {
  final Ref ref;
  final String? userId;
  bool _disposed = false;
  
  UnreadCountNotifier(this.ref, this.userId) : super(const AsyncValue.loading()) {
    print('UnreadCountNotifier constructor called for user: $userId');
    if (userId != null && !_disposed) {
      print('UnreadCountNotifier constructor - loading unread count');
      loadUnreadCount();
    } else {
      print('UnreadCountNotifier constructor - userId is null or disposed');
    }
  }

  Future<void> loadUnreadCount() async {
    if (userId == null || _disposed) return;
    
    try {
      if (_disposed) return;
      print('UnreadCountNotifier.loadUnreadCount() called for user: $userId');
      state = const AsyncValue.loading();
      final count = await ref.read(notificationServiceProvider).getUnreadCount(userId!);
      if (_disposed) return;
      print('UnreadCountNotifier.loadUnreadCount() - loaded count: $count');
      state = AsyncValue.data(count);
    } catch (e) {
      if (_disposed) return;
      print('Error loading unread count: $e');
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> refresh() async {
    if (_disposed) return;
    await loadUnreadCount();
  }

  void increment() {
    if (_disposed) return;
    print('UnreadCountNotifier.increment() called for user: $userId');
    print('UnreadCountNotifier.increment() - current state: $state');
    
    state.whenData((count) {
      if (_disposed) return;
      final newCount = count + 1;
      print('UnreadCountNotifier.increment() - old count: $count, new count: $newCount');
      state = AsyncValue.data(newCount);
      print('UnreadCountNotifier.increment() - state updated to: $state');
    });
    
    // If state is not AsyncData, handle it
    if (state is! AsyncData) {
      print('UnreadCountNotifier.increment() - state is not AsyncData, setting to 1');
      state = const AsyncValue.data(1);
    }
  }

  void decrement() {
    if (_disposed) return;
    print('UnreadCountNotifier.decrement() called for user: $userId');
    state.whenData((count) {
      if (_disposed) return;
      final newCount = (count - 1).clamp(0, double.infinity).toInt();
      print('UnreadCountNotifier.decrement() - old count: $count, new count: $newCount');
      state = AsyncValue.data(newCount);
    });
  }

  void reset() {
    if (_disposed) return;
    state = const AsyncValue.data(0);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
} 