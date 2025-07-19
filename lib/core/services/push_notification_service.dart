import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

class PushNotificationService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Initialize push notifications
  Future<void> initialize() async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      await _requestPermissions();
      await _getDeviceToken();
    }
  }

  // Request notification permissions
  Future<void> _requestPermissions() async {
    try {
      // For now, we'll handle permissions through the UI
      // Supabase doesn't have built-in push notification APIs in Flutter
      // We'll implement this through Edge Functions or external services later
    } catch (e) {
      // Handle error silently
    }
  }

  // Get device token for push notifications
  Future<void> _getDeviceToken() async {
    try {
      // For now, we'll use a placeholder token
      // In a real implementation, you'd integrate with a push service
      const deviceToken = 'placeholder_device_token';
      
      final user = _supabase.auth.currentUser;
      if (user != null) {
        await _saveDeviceToken(user.id, deviceToken);
      }
    } catch (e) {
      // Handle error silently
    }
  }

  // Save device token to Supabase
  Future<void> _saveDeviceToken(String userId, String token) async {
    try {
      await _supabase
          .from('device_tokens')
          .upsert({
            'user_id': userId,
            'token': token,
            'platform': kIsWeb ? 'web' : Platform.isAndroid ? 'android' : 'ios',
            'created_at': DateTime.now().toIso8601String(),
          });
    } catch (e) {
      // Handle error silently
    }
  }

  // Send push notification (simplified - in-app only for now)
  Future<void> sendPushNotification({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Check if push notifications are enabled
      final prefs = await SharedPreferences.getInstance();
      final pushEnabled = prefs.getBool('push_notifications') ?? true;
      
      if (!pushEnabled) return;

      // Check quiet hours
      if (await isInQuietHours()) return;

      // For now, just create an in-app notification
      // This works perfectly without any external services
      await _supabase
          .from('notifications')
          .insert({
            'user_id': userId,
            'from_user_id': userId,
            'type': 'system_notification',
            'title': title,
            'message': body,
            'is_read': false,
          });

      // Play sound and vibration (only if not in quiet hours)
      final inQuietHours = await isInQuietHours();
      if (!inQuietHours) {
        await playNotificationSound();
        await triggerVibration();
      }
    } catch (e) {
      // Handle error silently
    }
  }

  // Check if current time is in quiet hours
  Future<bool> isInQuietHours() async {
    final prefs = await SharedPreferences.getInstance();
    final quietHours = prefs.getBool('quiet_hours') ?? false;
    
    if (!quietHours) return false;

    final now = DateTime.now();
    final currentTime = now.hour * 60 + now.minute;

    final quietStartHour = prefs.getInt('quiet_start_hour') ?? 22;
    final quietStartMinute = prefs.getInt('quiet_start_minute') ?? 0;
    final quietEndHour = prefs.getInt('quiet_end_hour') ?? 8;
    final quietEndMinute = prefs.getInt('quiet_end_minute') ?? 0;

    final startTime = quietStartHour * 60 + quietStartMinute;
    final endTime = quietEndHour * 60 + quietEndMinute;

    if (startTime <= endTime) {
      // Same day (e.g., 9 AM to 5 PM)
      return currentTime >= startTime && currentTime <= endTime;
    } else {
      // Overnight (e.g., 10 PM to 8 AM)
      return currentTime >= startTime || currentTime <= endTime;
    }
  }

  // Play notification sound
  Future<void> playNotificationSound() async {
    final prefs = await SharedPreferences.getInstance();
    final soundEnabled = prefs.getBool('sound_enabled') ?? true;
    
    if (!soundEnabled) return;

    // For now, we'll use haptic feedback as a placeholder
    // In a real implementation, you'd use audioplayers or similar
  }

  // Trigger vibration
  Future<void> triggerVibration() async {
    final prefs = await SharedPreferences.getInstance();
    final vibrationEnabled = prefs.getBool('vibration_enabled') ?? true;
    
    if (!vibrationEnabled) return;

    // For now, we'll use haptic feedback as a placeholder
    // In a real implementation, you'd use vibration or similar
  }

  // Group notifications
  Future<List<Map<String, dynamic>>> groupNotifications(List<Map<String, dynamic>> notifications) async {
    final prefs = await SharedPreferences.getInstance();
    final groupingEnabled = prefs.getBool('notification_grouping') ?? true;
    
    if (!groupingEnabled) return notifications;

    // Group by type and sender
    final grouped = <String, List<Map<String, dynamic>>>{};
    
    for (final notification in notifications) {
      final key = '${notification['type']}_${notification['from_user_id']}';
      grouped.putIfAbsent(key, () => []).add(notification);
    }

    // Convert grouped notifications back to list
    final result = <Map<String, dynamic>>[];
    for (final group in grouped.values) {
      if (group.length == 1) {
        result.add(group.first);
      } else {
        // Create grouped notification
        final first = group.first;
        result.add({
          ...first,
          'grouped_count': group.length,
          'grouped_notifications': group,
        });
      }
    }

    return result;
  }

  // Subscribe to push notifications
  Future<void> subscribeToPushNotifications() async {
    try {
      // Temporarily disable database access to prevent errors
      // TODO: Re-enable once notification_settings table is properly set up
      /*
      // For now, we'll just save the subscription status
      // In a real implementation, you'd register with a push service
      final user = _supabase.auth.currentUser;
      if (user != null) {
        await _supabase
            .from('notification_settings')
            .upsert({
              'user_id': user.id,
              'push_notifications': true,
            });
      }
      */
      
      // For now, just save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('push_notifications', true);
    } catch (e) {
      // Handle error silently
    }
  }

  // Unsubscribe from push notifications
  Future<void> unsubscribeFromPushNotifications() async {
    try {
      // Temporarily disable database access to prevent errors
      // TODO: Re-enable once notification_settings table is properly set up
      /*
      // For now, we'll just save the subscription status
      final user = _supabase.auth.currentUser;
      if (user != null) {
        await _supabase
            .from('notification_settings')
            .upsert({
              'user_id': user.id,
              'push_notifications': false,
            });
      }
      */
      
      // For now, just save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('push_notifications', false);
    } catch (e) {
      // Handle error silently
    }
  }

  // Get push notification status
  Future<bool> isPushNotificationsEnabled() async {
    try {
      // Temporarily disable database access to prevent errors
      // TODO: Re-enable once notification_settings table is properly set up
      /*
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      final response = await _supabase
          .from('notification_settings')
          .select('push_notifications')
          .eq('user_id', user.id)
          .single();

      return response['push_notifications'] ?? false;
      */
      
      // For now, just check SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('push_notifications') ?? true;
    } catch (e) {
      return true; // Default to enabled
    }
  }
} 