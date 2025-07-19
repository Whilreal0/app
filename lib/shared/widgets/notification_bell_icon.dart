import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/notification_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/config/notification_polling_config.dart';
import '../../core/models/notification.dart';
import 'dart:async';

class NotificationBellIcon extends ConsumerStatefulWidget {
  const NotificationBellIcon({Key? key}) : super(key: key);

  @override
  ConsumerState<NotificationBellIcon> createState() => _NotificationBellIconState();
}

class _NotificationBellIconState extends ConsumerState<NotificationBellIcon> with WidgetsBindingObserver {
  bool _pollingStarted = false;
  bool _disposed = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Check if user changed and register for real-time updates
    final authState = ref.read(authStateProvider);
    authState.whenData((user) {
      if (user != null && user.id != _currentUserId && !_disposed) {
        _currentUserId = user.id;
        
        // Register for real-time updates
        NotificationManager.addListener(user.id, _handleRealTimeUpdate);
        
        // Start polling when dependencies change (user auth state)
        if (!_pollingStarted) {
          _startPolling();
        }
      }
    });
  }

  void _handleRealTimeUpdate() {
    if (!_disposed && _currentUserId != null) {
      // Force a rebuild to show the updated count
      setState(() {});
      
      // Also refresh the unread count provider directly
      try {
        ref.read(unreadNotificationCountProvider(_currentUserId!).notifier).refreshSilently();
      } catch (e) {
        // Ignore errors if provider is disposed
      }
    }
  }

  void _startPolling() {
    if (_disposed || _pollingStarted) {
      return;
    }
    
    final authState = ref.read(authStateProvider);
    authState.whenData((user) {
      if (user != null && !_pollingStarted && !_disposed) {
        try {
          // Start polling for notifications with reasonable interval
          ref.read(notificationsProvider(user.id).notifier).startPolling(
            interval: const Duration(seconds: 60), // Less frequent to prevent flickering
          );
          
          _pollingStarted = true;
        } catch (e) {
          // Ignore errors if provider is disposed
        }
      }
    });
  }

  void _stopPolling() {
    if (_disposed || !_pollingStarted) {
      return;
    }
    
    final authState = ref.read(authStateProvider);
    authState.whenData((user) {
      if (user != null && _pollingStarted && !_disposed) {
        try {
          ref.read(notificationsProvider(user.id).notifier).stopPolling();
          _pollingStarted = false;
        } catch (e) {
          // Ignore errors if provider is disposed
        }
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    
    // Remove from real-time update listeners
    if (_currentUserId != null) {
      NotificationManager.removeListener(_currentUserId!);
    }
    
    _stopPolling();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    
    if (state == AppLifecycleState.resumed) {
      _startPolling();
    } else if (state == AppLifecycleState.paused) {
      _stopPolling();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    
    // Watch for immediate bell icon updates
    ref.watch(bellIconUpdateProvider);
    
    return authState.when(
      data: (user) {
        if (user == null) {
          return IconButton(
            icon: const Icon(Icons.notifications_none, size: 28),
            onPressed: () {
              context.push('/notifications');
            },
          );
        }
        
        // Watch the unread count provider more actively
        final unreadCountAsync = ref.watch(currentUserUnreadCountProvider);
        
        // Also watch the specific user's unread count provider for immediate updates
        ref.watch(unreadNotificationCountProvider(user.id));
        
        return unreadCountAsync.when(
          data: (unreadCount) {
            return IconButton(
              icon: Stack(
                children: [
                  const Icon(Icons.notifications_none, size: 28),
                  if (unreadCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              onPressed: () {
                context.push('/notifications');
              },
            );
          },
          loading: () {
            return IconButton(
              icon: const Icon(Icons.notifications_none, size: 28),
              onPressed: () {
                context.push('/notifications');
              },
            );
          },
          error: (error, stack) {
            return IconButton(
              icon: const Icon(Icons.notifications_none, size: 28),
              onPressed: () {
                context.push('/notifications');
              },
            );
          },
        );
      },
      loading: () {
        return IconButton(
          icon: const Icon(Icons.notifications_none, size: 28),
          onPressed: () {
            context.push('/notifications');
          },
        );
      },
      error: (error, stack) {
        return IconButton(
          icon: const Icon(Icons.notifications_none, size: 28),
          onPressed: () {
            context.push('/notifications');
          },
        );
      },
    );
  }
} 