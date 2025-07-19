import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification.dart';
import '../services/notification_service.dart';
import 'auth_provider.dart';
import 'dart:async';

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
      if (user == null) return const AsyncValue.data(0);
      return ref.watch(unreadNotificationCountProvider(user.id));
    },
    loading: () => const AsyncValue.loading(),
    error: (_, __) => AsyncValue.error('User not found', StackTrace.current),
  );
});

class NotificationsNotifier extends StateNotifier<AsyncValue<List<Notification>>> {
  final Ref ref;
  final String? userId;
  Timer? _pollingTimer;
  bool _disposed = false;
  
  NotificationsNotifier(this.ref, this.userId) : super(const AsyncValue.loading()) {
    if (userId != null && !_disposed) {
      loadNotifications();
    }
  }

  Future<void> loadNotifications() async {
    if (userId == null || _disposed) return;
    
    try {
      if (_disposed) return;
      state = const AsyncValue.loading();
      final notifications = await ref.read(notificationServiceProvider).fetchNotifications(userId!);
      if (_disposed) return;
      state = AsyncValue.data(notifications);
    } catch (e) {
      if (_disposed) return;
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  void startPolling() {
    if (userId == null || _pollingTimer != null) return;
    
    // Poll every 5 seconds for new notifications
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (_disposed) {
        timer.cancel();
        return;
      }
      
      // Refresh notifications
      await loadNotifications();
      
      // Also refresh unread count
      if (!_disposed && userId != null) {
        await ref.read(unreadNotificationCountProvider(userId!).notifier).refresh();
      }
    });
  }

  void stopPolling() {
    if (_pollingTimer != null) {
      _pollingTimer!.cancel();
      _pollingTimer = null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    stopPolling();
    super.dispose();
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
    
    // Also refresh unread count when notification is added
    if (!_disposed && userId != null) {
      ref.read(unreadNotificationCountProvider(userId!).notifier).refresh();
    }
  }

  // Method to manually test polling
  void testPolling() {
    if (_pollingTimer != null) {
      // Polling timer exists and is set up
    } else {
      // No polling timer exists, starting polling
      startPolling();
    }
  }

  // Method to manually refresh unread count
  void refreshUnreadCount() {
    if (!_disposed && userId != null) {
      ref.read(unreadNotificationCountProvider(userId!).notifier).refresh();
    }
  }
}

class UnreadCountNotifier extends StateNotifier<AsyncValue<int>> {
  final Ref ref;
  final String? userId;
  bool _disposed = false;
  
  UnreadCountNotifier(this.ref, this.userId) : super(const AsyncValue.loading()) {
    if (userId != null && !_disposed) {
      loadUnreadCount();
    }
  }

  Future<void> loadUnreadCount() async {
    if (userId == null || _disposed) return;
    
    try {
      if (_disposed) return;
      state = const AsyncValue.loading();
      final count = await ref.read(notificationServiceProvider).getUnreadCount(userId!);
      if (_disposed) return;
      state = AsyncValue.data(count);
    } catch (e) {
      if (_disposed) return;
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> refresh() async {
    if (_disposed) return;
    await loadUnreadCount();
  }

  void increment() {
    if (_disposed) return;
    state.whenData((count) {
      if (_disposed) return;
      final newCount = count + 1;
      state = AsyncValue.data(newCount);
    });
    
    // If state is not AsyncData, handle it
    if (state is! AsyncData) {
      state = const AsyncValue.data(1);
    }
  }

  void decrement() {
    if (_disposed) return;
    state.whenData((count) {
      if (_disposed) return;
      final newCount = (count - 1).clamp(0, double.infinity).toInt();
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