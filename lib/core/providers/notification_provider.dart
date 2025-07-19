import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification.dart';
import '../services/notification_service.dart';
import '../config/notification_polling_config.dart';
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

// Simple state notifier for immediate bell icon updates
final bellIconUpdateProvider = StateNotifierProvider<BellIconUpdateNotifier, int>((ref) {
  final notifier = BellIconUpdateNotifier();
  NotificationManager.setBellIconNotifier(notifier);
  return notifier;
});

class BellIconUpdateNotifier extends StateNotifier<int> {
  BellIconUpdateNotifier() : super(0);
  
  void triggerUpdate() {
    state = DateTime.now().millisecondsSinceEpoch;
  }
}

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

// Global notification manager for real-time updates
class NotificationManager {
  static final Map<String, void Function()> _listeners = {};
  static BellIconUpdateNotifier? _bellIconNotifier;
  static final Map<String, UnreadCountNotifier?> _unreadCountNotifiers = {};
  
  static void addListener(String userId, void Function() callback) {
    _listeners[userId] = callback;
  }
  
  static void removeListener(String userId) {
    _listeners.remove(userId);
    _unreadCountNotifiers.remove(userId);
  }
  
  static void setBellIconNotifier(BellIconUpdateNotifier notifier) {
    _bellIconNotifier = notifier;
  }
  
  static void setUnreadCountNotifier(String userId, UnreadCountNotifier notifier) {
    _unreadCountNotifiers[userId] = notifier;
  }
  
  static void notifyUpdate(String userId) {
    _listeners[userId]?.call();
    
    // Trigger immediate bell icon update
    _bellIconNotifier?.triggerUpdate();
    
    // Also refresh the unread count for this user
    final unreadNotifier = _unreadCountNotifiers[userId];
    if (unreadNotifier != null) {
      unreadNotifier.refreshSilently();
    }
  }
}

class NotificationsNotifier extends StateNotifier<AsyncValue<List<Notification>>> {
  final Ref ref;
  final String? userId;
  Timer? _pollingTimer;
  bool _disposed = false;
  DateTime? _lastUpdate;
  bool _isLoading = false;
  
  NotificationsNotifier(this.ref, this.userId) : super(const AsyncValue.loading()) {
    if (userId != null && !_disposed) {
      // Register for real-time updates
      NotificationManager.addListener(userId!, _handleRealTimeUpdate);
      
      // Use a microtask to ensure the widget is fully built before loading
      Future.microtask(() {
        if (!_disposed) {
          loadNotifications();
        }
      });
    }
  }

  void _handleRealTimeUpdate() {
    if (!_disposed && userId != null) {
      // Refresh immediately when notified
      _refreshSilently();
    }
  }

  Future<void> loadNotifications() async {
    if (_disposed || userId == null || _isLoading) {
      return;
    }
    
    try {
      _isLoading = true;
      
      // Only show loading state if we don't have data yet
      if (state is! AsyncData) {
        state = const AsyncValue.loading();
      }
      
      final notifications = await ref.read(notificationServiceProvider).fetchNotifications(userId!);
      
      if (!_disposed) {
        state = AsyncValue.data(notifications);
        _lastUpdate = DateTime.now();
      }
    } catch (e) {
      if (!_disposed) {
        state = AsyncValue.error(e, StackTrace.current);
      }
    } finally {
      _isLoading = false;
    }
  }

  void startPolling({Duration? interval}) {
    if (userId == null || _pollingTimer != null || _disposed) {
      return;
    }
    
    final pollingInterval = interval ?? NotificationPollingConfig.defaultPollingInterval;
    
    // Poll at the specified interval for new notifications
    _pollingTimer = Timer.periodic(pollingInterval, (timer) async {
      if (_disposed) {
        timer.cancel();
        return;
      }
      
      // Debounce: prevent updates more frequent than 5 seconds
      if (_lastUpdate != null && 
          DateTime.now().difference(_lastUpdate!) < const Duration(seconds: 5)) {
        return;
      }
      
      try {
        // Refresh notifications silently (without showing loading state)
        await _refreshSilently();
        
        // Also refresh unread count
        if (!_disposed && userId != null) {
          try {
            await ref.read(unreadNotificationCountProvider(userId!).notifier).refreshSilently();
          } catch (e) {
            // Ignore errors if provider is disposed
          }
        }
      } catch (e) {
        // Ignore errors if disposed
      }
    });
  }

  Future<void> _refreshSilently() async {
    if (_disposed || userId == null || _isLoading) return;
    
    try {
      _isLoading = true;
      final notifications = await ref.read(notificationServiceProvider).fetchNotifications(userId!);
      
      if (!_disposed) {
        // Only update if data actually changed to prevent unnecessary rebuilds
        final currentState = state;
        if (currentState is AsyncData) {
          final currentNotifications = currentState.value;
          if (currentNotifications == null || _hasNotificationsChanged(currentNotifications, notifications)) {
            state = AsyncValue.data(notifications);
            _lastUpdate = DateTime.now();
          }
        } else {
          state = AsyncValue.data(notifications);
          _lastUpdate = DateTime.now();
        }
      }
    } catch (e) {
      // Don't update state on error during silent refresh
    } finally {
      _isLoading = false;
    }
  }

  bool _hasNotificationsChanged(List<Notification> oldNotifications, List<Notification> newNotifications) {
    if (oldNotifications.length != newNotifications.length) return true;
    
    for (int i = 0; i < oldNotifications.length; i++) {
      if (oldNotifications[i].id != newNotifications[i].id ||
          oldNotifications[i].isRead != newNotifications[i].isRead) {
        return true;
      }
    }
    return false;
  }

  void stopPolling() {
    if (_pollingTimer != null) {
      _pollingTimer!.cancel();
      _pollingTimer = null;
    }
  }

  void changePollingInterval(Duration newInterval) {
    if (_disposed) return;
    
    // Stop current polling
    stopPolling();
    
    // Start polling with new interval
    startPolling(interval: newInterval);
  }

  @override
  void dispose() {
    _disposed = true;
    _pollingTimer?.cancel();
    
    // Remove from real-time update listeners
    if (userId != null) {
      NotificationManager.removeListener(userId!);
    }
    
    super.dispose();
  }

  Future<void> markAsRead({List<String>? notificationIds}) async {
    if (userId == null || _disposed) return;

    try {
      await ref.read(notificationServiceProvider).markAsRead(userId!, notificationIds: notificationIds);
      
      // Update state optimistically only if not disposed
      if (!_disposed) {
        final currentState = state;
        if (currentState is AsyncData) {
          final notifications = currentState.value;
          if (notifications != null) {
            final updatedNotifications = notifications.map((notification) {
              if (notificationIds == null || notificationIds.contains(notification.id)) {
                return notification.copyWith(isRead: true);
              }
              return notification;
            }).toList();
            
            if (!_disposed) {
              state = AsyncValue.data(updatedNotifications);
            }
          }
        }
      }

      // Refresh unread count
      if (!_disposed && userId != null) {
        try {
          // Decrement unread count for each notification marked as read
          final countToDecrement = notificationIds?.length ?? 1;
          for (int i = 0; i < countToDecrement; i++) {
            ref.read(unreadNotificationCountProvider(userId!).notifier).decrement();
          }
        } catch (e) {
          // Ignore errors if provider is disposed
        }
      }
    } catch (e) {
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
    
    final currentState = state;
    if (currentState is AsyncData && !_disposed) {
      final notifications = currentState.value;
      if (notifications != null) {
        final updated = notifications.where((n) => n.id != notificationId).toList();
        if (!_disposed) {
          state = AsyncValue.data(updated);
        }
      }
    }
  }

  void addNotification(Notification notification) {
    if (_disposed) return;
    
    final currentState = state;
    if (currentState is AsyncData && !_disposed) {
      final notifications = currentState.value;
      if (notifications != null) {
        final updated = [notification, ...notifications];
        if (!_disposed) {
          state = AsyncValue.data(updated);
        }
      }
    }
    
    // Also refresh unread count when notification is added
    if (!_disposed && userId != null) {
      try {
        ref.read(unreadNotificationCountProvider(userId!).notifier).increment();
      } catch (e) {
        // Ignore errors if provider is disposed
      }
    }
  }
}

class UnreadCountNotifier extends StateNotifier<AsyncValue<int>> {
  final Ref ref;
  final String? userId;
  bool _disposed = false;
  bool _isLoading = false;
  
  UnreadCountNotifier(this.ref, this.userId) : super(const AsyncValue.loading()) {
    if (userId != null && !_disposed) {
      // Register for real-time updates
      NotificationManager.addListener(userId!, _handleRealTimeUpdate);
      NotificationManager.setUnreadCountNotifier(userId!, this);
      
      // Use a microtask to ensure the widget is fully built before loading
      Future.microtask(() {
        if (!_disposed) {
          loadUnreadCount();
        }
      });
    }
  }

  void _handleRealTimeUpdate() {
    if (!_disposed && userId != null) {
      // Refresh immediately when notified
      refreshSilently();
    }
  }

  Future<void> loadUnreadCount() async {
    if (userId == null || _disposed || _isLoading) {
      return;
    }
    
    try {
      _isLoading = true;
      state = const AsyncValue.loading();
      final count = await ref.read(notificationServiceProvider).getUnreadCount(userId!);
      
      if (!_disposed) {
        state = AsyncValue.data(count);
      }
    } catch (e) {
      if (!_disposed) {
        state = AsyncValue.error(e, StackTrace.current);
      }
    } finally {
      _isLoading = false;
    }
  }

  Future<void> refresh() async {
    if (_disposed) return;
    await loadUnreadCount();
  }

  Future<void> refreshSilently() async {
    if (userId == null || _disposed || _isLoading) return;
    
    try {
      _isLoading = true;
      final count = await ref.read(notificationServiceProvider).getUnreadCount(userId!);
      
      if (!_disposed) {
        // Only update if count actually changed to prevent unnecessary rebuilds
        final currentState = state;
        if (currentState is AsyncData) {
          final currentCount = currentState.value;
          if (currentCount != count) {
            state = AsyncValue.data(count);
          }
        } else {
          state = AsyncValue.data(count);
        }
      }
    } catch (e) {
      // Don't update state on error during silent refresh
    } finally {
      _isLoading = false;
    }
  }

  void increment() {
    if (_disposed) return;
    
    try {
      // Handle different state types safely
      if (state is AsyncData) {
        final currentCount = state.value ?? 0;
        final newCount = currentCount + 1;
        if (!_disposed) {
          state = AsyncValue.data(newCount);
        }
      } else {
        // If state is not AsyncData, set to 1
        if (!_disposed) {
          state = const AsyncValue.data(1);
        }
      }
    } catch (e) {
      // Ignore errors if disposed
    }
  }

  void decrement() {
    if (_disposed) return;
    
    try {
      // Handle different state types safely
      if (state is AsyncData) {
        final currentCount = state.value ?? 0;
        final newCount = (currentCount - 1).clamp(0, double.infinity).toInt();
        if (!_disposed) {
          state = AsyncValue.data(newCount);
        }
      } else {
        // If state is not AsyncData, set to 0
        if (!_disposed) {
          state = const AsyncValue.data(0);
        }
      }
    } catch (e) {
      // Ignore errors if disposed
    }
  }

  void reset() {
    if (_disposed) return;
    state = const AsyncValue.data(0);
  }

  @override
  void dispose() {
    _disposed = true;
    
    // Remove from real-time update listeners
    if (userId != null) {
      NotificationManager.removeListener(userId!);
    }
    
    super.dispose();
  }
} 