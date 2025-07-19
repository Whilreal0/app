import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/notification_service.dart';
import 'auth_provider.dart';

// Provider for notification service
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

// Provider for notification settings
final notificationSettingsProvider = StateNotifierProvider.family<NotificationSettingsNotifier, AsyncValue<Map<String, dynamic>?>, String?>((ref, userId) {
  return NotificationSettingsNotifier(ref, userId);
});

// Convenience provider for current user's notification settings
final currentUserNotificationSettingsProvider = Provider<AsyncValue<Map<String, dynamic>?>>((ref) {
  final authState = ref.watch(authStateProvider);
  
  return authState.when(
    data: (user) {
      if (user == null) return const AsyncValue.data(null);
      return ref.watch(notificationSettingsProvider(user.id));
    },
    loading: () => const AsyncValue.loading(),
    error: (_, __) => AsyncValue.error('User not found', StackTrace.current),
  );
});

class NotificationSettingsNotifier extends StateNotifier<AsyncValue<Map<String, dynamic>?>> {
  final Ref ref;
  final String? userId;
  
  NotificationSettingsNotifier(this.ref, this.userId) : super(const AsyncValue.loading()) {
    if (userId != null) {
      loadSettings();
    }
  }

  Future<void> loadSettings() async {
    if (userId == null) return;
    
    try {
      state = const AsyncValue.loading();
      // Temporarily return default settings to prevent database errors
      // TODO: Re-enable once notification_settings table is properly set up
      /*
      final settings = await ref.read(notificationServiceProvider).getNotificationSettings(userId!);
      state = AsyncValue.data(settings);
      */
      
      // Return default settings for now
      final defaultSettings = {
        'push_notifications': true,
        'email_notifications': false,
        'post_likes': true,
        'post_comments': true,
        'comment_likes': true,
        'comment_replies': true,
        'follows': true,
        'mentions': true,
      };
      state = AsyncValue.data(defaultSettings);
    } catch (e) {
      // Return default settings on error
      final defaultSettings = {
        'push_notifications': true,
        'email_notifications': false,
        'post_likes': true,
        'post_comments': true,
        'comment_likes': true,
        'comment_replies': true,
        'follows': true,
        'mentions': true,
      };
      state = AsyncValue.data(defaultSettings);
    }
  }

  Future<void> updateSettings(Map<String, dynamic> newSettings) async {
    if (userId == null) return;
    
    try {
      // Temporarily disable database updates to prevent errors
      // TODO: Re-enable once notification_settings table is properly set up
      /*
      await ref.read(notificationServiceProvider).updateNotificationSettings(userId!, newSettings);
      await loadSettings(); // Reload settings
      */
      
      // Just update the local state for now
      state = AsyncValue.data(newSettings);
    } catch (e) {
      // Handle error silently for now
    }
  }

  Future<void> toggleSetting(String settingKey, bool value) async {
    if (userId == null) return;
    
    final currentSettings = state.value ?? {};
    final newSettings = {
      ...currentSettings,
      settingKey: value,
    };
    
    await updateSettings(newSettings);
  }
} 