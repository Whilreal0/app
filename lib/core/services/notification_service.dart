import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification.dart';

class NotificationService {
  final SupabaseClient _supabase = Supabase.instance.client;

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
        await _supabase.rpc('mark_notifications_read', params: {
          'user_uuid': userId,
          'notification_ids': notificationIds,
        });
      } else {
        await _supabase.rpc('mark_notifications_read', params: {
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
  }) async {
    try {
      // Check if user has notifications enabled for this type
      final settings = await _getNotificationSettings(userId);
      if (!_isNotificationEnabled(settings, type)) {
        return;
      }

      // Get from user's profile
      final fromUserProfile = await _supabase
          .from('profiles')
          .select('username, avatar_url')
          .eq('id', fromUserId)
          .single();

      final notificationData = {
        'user_id': userId,
        'from_user_id': fromUserId,
        'type': type.value,
        'title': title,
        'message': message,
        'post_id': postId,
        'comment_id': commentId,
        'is_read': false,
      };

      await _supabase
          .from('notifications')
          .insert(notificationData)
          .select()
          .single();
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

  // Get notification settings
  Future<Map<String, dynamic>?> _getNotificationSettings(String userId) async {
    try {
      final response = await _supabase
          .from('notification_settings')
          .select('*')
          .eq('user_id', userId)
          .maybeSingle();

      return response;
    } catch (e) {
      return null;
    }
  }

  // Check if notification type is enabled
  bool _isNotificationEnabled(Map<String, dynamic>? settings, NotificationType type) {
    if (settings == null) return true; // Default to enabled if no settings

    switch (type) {
      case NotificationType.commentLike:
        return settings['comment_likes'] ?? true;
      case NotificationType.commentReply:
        return settings['comment_replies'] ?? true;
      case NotificationType.postLike:
        return settings['post_likes'] ?? true;
      case NotificationType.postComment:
        return settings['post_comments'] ?? true;
      case NotificationType.follow:
        return settings['follows'] ?? true;
      case NotificationType.mention:
        return settings['mentions'] ?? true;
    }
  }

  // Initialize notification settings for a user
  Future<void> initializeNotificationSettings(String userId) async {
    try {
      await _supabase
          .from('notification_settings')
          .upsert({
            'user_id': userId,
            'comment_likes': true,
            'comment_replies': true,
            'post_likes': true,
            'follows': true,
            'mentions': true,
            'push_notifications': true,
            'email_notifications': false,
          });
    } catch (e) {
      // Handle error silently
    }
  }

  // Update notification settings
  Future<void> updateNotificationSettings(String userId, Map<String, bool> settings) async {
    try {
      await _supabase
          .from('notification_settings')
          .upsert({
            'user_id': userId,
            ...settings,
          });
    } catch (e) {
      // Handle error silently
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