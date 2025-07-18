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

// Provider for notifications list
final notificationsProvider = StateNotifierProvider<NotificationsNotifier, AsyncValue<List<Notification>>>((ref) {
  final authState = ref.watch(authStateProvider);
  
  return authState.when(
    data: (user) {
      if (user == null) return NotificationsNotifier(ref, null);
      return NotificationsNotifier(ref, user.id);
    },
    loading: () => NotificationsNotifier(ref, null),
    error: (_, __) => NotificationsNotifier(ref, null),
  );
});

// Provider for unread notification count
final unreadNotificationCountProvider = StateNotifierProvider<UnreadCountNotifier, AsyncValue<int>>((ref) {
  final authState = ref.watch(authStateProvider);
  
  return authState.when(
    data: (user) {
      if (user == null) return UnreadCountNotifier(ref, null);
      return UnreadCountNotifier(ref, user.id);
    },
    loading: () => UnreadCountNotifier(ref, null),
    error: (_, __) => UnreadCountNotifier(ref, null),
  );
});

class NotificationsNotifier extends StateNotifier<AsyncValue<List<Notification>>> {
  final Ref ref;
  final String? userId;
  RealtimeChannel? _realtimeChannel;
  
  NotificationsNotifier(this.ref, this.userId) : super(const AsyncValue.loading()) {
    if (userId != null) {
      loadNotifications();
      _setupRealtimeSubscription();
    }
  }

  Future<void> loadNotifications() async {
    if (userId == null) return;
    
    try {
      print('Loading notifications for user: $userId');
      state = const AsyncValue.loading();
      final notifications = await ref.read(notificationServiceProvider).fetchNotifications(userId!);
      state = AsyncValue.data(notifications);
    } catch (e) {
      print('Error loading notifications: $e');
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> markAsRead({List<String>? notificationIds}) async {
    if (userId == null) return;

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
      ref.read(unreadNotificationCountProvider.notifier).refresh();
    } catch (e) {
      print('Error marking notifications as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    await markAsRead();
  }

  void _setupRealtimeSubscription() {
    if (userId == null) return;
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
      ..subscribe();
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  void _handleNewNotification(dynamic payload) {
    try {
      final newNotificationData = payload.newRecord as Map<String, dynamic>;
      
      // Get from user's profile
      _getFromUserProfile(newNotificationData['from_user_id']).then((fromUser) {
        final notification = Notification.fromMap({
          ...newNotificationData,
          'from_username': fromUser?['username'],
          'from_avatar_url': fromUser?['avatar_url'],
        });

        // Add to state
        state.whenData((notifications) {
          final updatedNotifications = [notification, ...notifications];
          state = AsyncValue.data(updatedNotifications);
        });

        // Update unread count
        ref.read(unreadNotificationCountProvider.notifier).refresh();
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
    await loadNotifications();
  }
}

class UnreadCountNotifier extends StateNotifier<AsyncValue<int>> {
  final Ref ref;
  final String? userId;
  
  UnreadCountNotifier(this.ref, this.userId) : super(const AsyncValue.loading()) {
    if (userId != null) {
      loadUnreadCount();
    }
  }

  Future<void> loadUnreadCount() async {
    if (userId == null) return;
    
    try {
      state = const AsyncValue.loading();
      final count = await ref.read(notificationServiceProvider).getUnreadCount(userId!);
      state = AsyncValue.data(count);
    } catch (e) {
      print('Error loading unread count: $e');
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> refresh() async {
    await loadUnreadCount();
  }

  void increment() {
    state.whenData((count) {
      state = AsyncValue.data(count + 1);
    });
  }

  void decrement() {
    state.whenData((count) {
      state = AsyncValue.data((count - 1).clamp(0, double.infinity).toInt());
    });
  }

  void reset() {
    state = const AsyncValue.data(0);
  }
} 