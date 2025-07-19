import 'package:flutter/material.dart';

enum NotificationType {
  commentLike('comment_like'),
  commentReply('comment_reply'),
  postLike('post_like'),
  postComment('post_comment'),
  follow('follow'),
  mention('mention');

  const NotificationType(this.value);
  final String value;

  static NotificationType fromString(String value) {
    return NotificationType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => NotificationType.commentLike,
    );
  }
}

class Notification {
  final String id;
  final String userId;
  final String? fromUserId;
  final String? fromUsername;
  final String? fromAvatarUrl;
  final NotificationType type;
  final String title;
  final String message;
  final String? postId;
  final String? commentId;
  final bool isRead;
  final DateTime createdAt;

  Notification({
    required this.id,
    required this.userId,
    this.fromUserId,
    this.fromUsername,
    this.fromAvatarUrl,
    required this.type,
    required this.title,
    required this.message,
    this.postId,
    this.commentId,
    required this.isRead,
    required this.createdAt,
  });

  factory Notification.fromMap(Map<String, dynamic> map) {
    return Notification(
      id: map['id'],
      userId: map['user_id'],
      fromUserId: map['from_user_id'],
      fromUsername: map['from_username'],
      fromAvatarUrl: map['from_avatar_url'],
      type: NotificationType.fromString(map['type']),
      title: map['title'],
      message: map['message'],
      postId: map['post_id'],
      commentId: map['comment_id'],
      isRead: map['is_read'] ?? false,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at']).toLocal()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'from_user_id': fromUserId,
      'from_username': fromUsername,
      'from_avatar_url': fromAvatarUrl,
      'type': type.value,
      'title': title,
      'message': message,
      'post_id': postId,
      'comment_id': commentId,
      'is_read': isRead,
    };
  }

  Notification copyWith({
    String? id,
    String? userId,
    String? fromUserId,
    String? fromUsername,
    String? fromAvatarUrl,
    NotificationType? type,
    String? title,
    String? message,
    String? postId,
    String? commentId,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return Notification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      fromUserId: fromUserId ?? this.fromUserId,
      fromUsername: fromUsername ?? this.fromUsername,
      fromAvatarUrl: fromAvatarUrl ?? this.fromAvatarUrl,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      postId: postId ?? this.postId,
      commentId: commentId ?? this.commentId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get displayTitle {
    switch (type) {
      case NotificationType.commentLike:
        return '${fromUsername ?? 'Someone'} liked your comment';
      case NotificationType.commentReply:
        return '${fromUsername ?? 'Someone'} replied to your comment';
      case NotificationType.postLike:
        return '${fromUsername ?? 'Someone'} liked your post';
      case NotificationType.postComment:
        return '${fromUsername ?? 'Someone'} commented on your post';
      case NotificationType.follow:
        return '${fromUsername ?? 'Someone'} started following you';
      case NotificationType.mention:
        return '${fromUsername ?? 'Someone'} mentioned you';
    }
  }

  String get displayMessage {
    switch (type) {
      case NotificationType.commentLike:
        return 'Tap to view the comment';
      case NotificationType.commentReply:
        return 'Tap to view the reply';
      case NotificationType.postLike:
        return 'Tap to view the post';
      case NotificationType.postComment:
        return 'Tap to view the comment';
      case NotificationType.follow:
        return 'Tap to view their profile';
      case NotificationType.mention:
        return 'Tap to view the post';
    }
  }

  IconData get icon {
    switch (type) {
      case NotificationType.commentLike:
      case NotificationType.postLike:
        return Icons.favorite;
      case NotificationType.commentReply:
      case NotificationType.postComment:
        return Icons.comment;
      case NotificationType.follow:
        return Icons.person_add;
      case NotificationType.mention:
        return Icons.alternate_email;
    }
  }

  Color get iconColor {
    switch (type) {
      case NotificationType.commentLike:
      case NotificationType.postLike:
        return Colors.red;
      case NotificationType.commentReply:
      case NotificationType.postComment:
        return Colors.blue;
      case NotificationType.follow:
        return Colors.green;
      case NotificationType.mention:
        return Colors.orange;
    }
  }
} 