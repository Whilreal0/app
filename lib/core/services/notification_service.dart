import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification.dart';
import 'push_notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/notification_provider.dart';

class NotificationService {
  final SupabaseClient _supabase = Supabase.instance.client;
  // final PushNotificationService _pushService = PushNotificationService(); // Temporarily disabled

  // Fetch notifications for a user
  Future<List<Notification>> fetchNotifications(String userId, {int limit = 1000}) async {
    try {
      final response = await _supabase
          .from('notifications')
          .select('''
            *,
            from_user:from_user_id(
              id,
              username,
              avatar_url
            )
          ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      final notifications = <Notification>[];
      
      for (final notificationData in response) {
        final fromUser = notificationData['from_user'] as Map<String, dynamic>?;
        
        final notification = Notification.fromMap({
          ...notificationData,
          'from_username': fromUser?['username'],
          'from_avatar_url': fromUser?['avatar_url'],
        });

        notifications.add(notification);
      }
      
      return notifications;
    } catch (e) {
      return [];
    }
  }

  // Get unread notification count
  Future<int> getUnreadCount(String userId) async {
    try {
      // Try the RPC function first
      final response = await _supabase.rpc('get_unread_notification_count', params: {
        'user_uuid': userId,
      });

      if (response != null) {
        return response;
      }
    } catch (e) {
      // Fallback to direct query
    }

    // Fallback: direct database query
    try {
      final response = await _supabase
          .from('notifications')
          .select('id, is_read')
          .eq('user_id', userId)
          .eq('is_read', false);

      return response.length;
    } catch (e) {
      return 0;
    }
  }

  // Mark notifications as read
  Future<void> markAsRead(String userId, {List<String>? notificationIds}) async {
    try {
      if (notificationIds != null) {
        await _supabase.rpc('mark_notifications_as_read', params: {
          'user_uuid': userId,
          'notification_ids': notificationIds,
        });
      } else {
        await _supabase.rpc('mark_notifications_as_read', params: {
          'user_uuid': userId,
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }

  // Create a notification
  Future<void> createNotification({
    required String userId,
    required String fromUserId,
    required NotificationType type,
    required String title,
    required String message,
    String? postId,
    String? commentId,
    VoidCallback? onCreated, // Callback for immediate UI update
  }) async {
    try {
      final notificationData = {
        'user_id': userId,
        'from_user_id': fromUserId,
        'type': type.value,
        'title': title,
        'message': message,
        'post_id': postId,
        'comment_id': commentId,
        'is_read': false, // Changed from 'read' to 'is_read'
        'created_at': DateTime.now().toIso8601String(),
      };

      final result = await _supabase
          .from('notifications')
          .insert(notificationData)
          .select()
          .single();

      // Trigger real-time update for the user
      try {
        // Import the NotificationManager to trigger real-time updates
        // This will update the bell icon immediately
        NotificationManager.notifyUpdate(userId);
      } catch (e) {
        // Handle error silently
      }

      // Temporarily disable push notifications to prevent 400 errors
      // TODO: Re-enable once push notification service is properly set up
      /*
      // Send push notification
      await _pushService.sendPushNotification(
        userId: userId,
        title: title,
        body: message,
        data: {
          'type': type.value,
          'post_id': postId,
          'comment_id': commentId,
          'from_user_id': fromUserId,
        },
      );
      */

      // Note: Removed haptic feedback and vibration features

      // Call the callback for immediate UI update
      onCreated?.call();

    } catch (e) {
      // Handle error silently
    }
  }

  // Create comment like notification
  Future<void> createCommentLikeNotification({
    required String commentId,
    required String fromUserId,
    required String commentOwnerId,
  }) async {
    try {
      // Get comment details
      final comment = await _supabase
          .from('comments')
          .select('content, post_id')
          .eq('id', commentId)
          .single();

      // Get from user's profile
      final fromUserProfile = await _supabase
          .from('profiles')
          .select('username')
          .eq('id', fromUserId)
          .single();

      final title = '${fromUserProfile['username']} liked your comment';
      final message = 'Tap to view the comment';

      await createNotification(
        userId: commentOwnerId,
        fromUserId: fromUserId,
        type: NotificationType.commentLike,
        title: title,
        message: message,
        postId: comment['post_id'],
        commentId: commentId,
      );
    } catch (e) {
      // Handle error silently
    }
  }

  // Create comment reply notification
  Future<void> createCommentReplyNotification({
    required String commentId,
    required String fromUserId,
    required String parentCommentOwnerId,
  }) async {
    try {
      // Get comment details
      final comment = await _supabase
          .from('comments')
          .select('content, post_id')
          .eq('id', commentId)
          .single();

      // Get from user's profile
      final fromUserProfile = await _supabase
          .from('profiles')
          .select('username')
          .eq('id', fromUserId)
          .single();

      final title = '${fromUserProfile['username']} replied to your comment';
      final message = 'Tap to view the reply';

      await createNotification(
        userId: parentCommentOwnerId,
        fromUserId: fromUserId,
        type: NotificationType.commentReply,
        title: title,
        message: message,
        postId: comment['post_id'],
        commentId: commentId,
      );
    } catch (e) {
      // Handle error silently
    }
  }

  // Create post like notification
  Future<void> createPostLikeNotification({
    required String postId,
    required String fromUserId,
    required String postOwnerId,
  }) async {
    try {
      // Get from user's profile
      final fromUserProfile = await _supabase
          .from('profiles')
          .select('username')
          .eq('id', fromUserId)
          .single();

      final title = '${fromUserProfile['username']} liked your post';
      final message = 'Tap to view the post';

      await createNotification(
        userId: postOwnerId,
        fromUserId: fromUserId,
        type: NotificationType.postLike,
        title: title,
        message: message,
        postId: postId,
      );
    } catch (e) {
      // Handle error silently
    }
  }

  // Delete a notification by ID
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _supabase.from('notifications').delete().eq('id', notificationId);
    } catch (e) {
      // Optionally handle error
    }
  }

  // Restore a notification (for undo)
  Future<void> restoreNotification(Notification notification) async {
    try {
      await _supabase.from('notifications').insert(notification.toMap());
    } catch (e) {
      // Optionally handle error
    }
  }

  // Get notification settings for a user
  Future<Map<String, dynamic>?> getNotificationSettings(String userId) async {
    try {
      // Temporarily disable database access to prevent errors
      // TODO: Re-enable once notification_settings table is properly set up
      /*
      final response = await _supabase
          .from('notification_settings')
          .select('*')
          .eq('user_id', userId)
          .single();

      return response;
      */
      
      // Return default settings for now
      return {
        'push_notifications': true,
        'email_notifications': false,
        'post_likes': true,
        'post_comments': true,
        'comment_likes': true,
        'comment_replies': true,
        'follows': true,
        'mentions': true,
      };
    } catch (e) {
      // Return default settings on error
      return {
        'push_notifications': true,
        'email_notifications': false,
        'post_likes': true,
        'post_comments': true,
        'comment_likes': true,
        'comment_replies': true,
        'follows': true,
        'mentions': true,
      };
    }
  }

  // Get notification settings for a user (private method for internal use)
  Future<Map<String, dynamic>?> _getNotificationSettings(String userId) async {
    return await getNotificationSettings(userId);
  }

  // Initialize notification settings for a user
  Future<void> _initializeNotificationSettings(String userId) async {
    try {
      // Temporarily disable database access to prevent errors
      // TODO: Re-enable once notification_settings table is properly set up
      /*
      await _supabase
          .from('notification_settings')
          .insert({
            'user_id': userId,
            'push_notifications': true,
            'email_notifications': false,
            'post_likes': true,
            'post_comments': true,
            'comment_likes': true,
            'comment_replies': true,
            'follows': true,
            'mentions': true,
          });
      */
      
      // For now, do nothing - settings are handled by default values
    } catch (e) {
      // Handle error silently
    }
  }

  // Update notification settings
  Future<void> updateNotificationSettings(String userId, Map<String, dynamic> settings) async {
    try {
      // Temporarily disable database access to prevent errors
      // TODO: Re-enable once notification_settings table is properly set up
      /*
      await _supabase
          .from('notification_settings')
          .upsert({
            'user_id': userId,
            ...settings,
            'updated_at': DateTime.now().toIso8601String(),
          });
      */
      
      // For now, do nothing - settings are handled by default values
    } catch (e) {
      // Handle error silently
    }
  }

  // Check if notification type is enabled for user
  bool _isNotificationEnabled(Map<String, dynamic>? settings, NotificationType type) {
    if (settings == null) return true; // Default to enabled

    switch (type) {
      case NotificationType.postLike:
        return settings['post_likes'] ?? true;
      case NotificationType.postComment:
        return settings['post_comments'] ?? true;
      case NotificationType.commentLike:
        return settings['comment_likes'] ?? true;
      case NotificationType.commentReply:
        return settings['comment_replies'] ?? true;
      case NotificationType.follow:
        return settings['follows'] ?? true;
      case NotificationType.mention:
        return settings['mentions'] ?? true;
      case NotificationType.systemNotification:
        return settings['push_notifications'] ?? true;
      case NotificationType.pushNotification:
        return settings['push_notifications'] ?? true;
    }
  }

  // Send push notification via Supabase Edge Function
  Future<void> sendPushNotification({
    required String userId,
    required String title,
    required String body,
  }) async {
    try {
      // Fetch device token from Supabase
      final tokens = await _supabase
          .from('device_tokens')
          .select('token')
          .eq('user_id', userId)
          .limit(1);
      if (tokens == null || tokens.isEmpty) {
        return;
      }
      final token = tokens[0]['token'];
      // Call the Edge Function
      final response = await _supabase.functions.invoke('send-push-notification',
        body: {
          'token': token,
          'title': title,
          'body': body,
        },
      );
    } catch (e) {
      // Handle error silently
    }
  }
} 