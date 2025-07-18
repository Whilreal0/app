class Comment {
  final String id;
  final String postId;
  final String userId;
  final String username;
  final String avatarUrl;
  final String content;
  final DateTime createdAt;
  final int likesCount;
  final bool isLikedByMe;
  final String? parentCommentId; // For nested replies
  final List<Comment> replies; // For nested replies
  final int nestingLevel; // Track nesting depth
  final bool isPosting; // Track if comment is being posted

  Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.username,
    required this.avatarUrl,
    required this.content,
    required this.createdAt,
    required this.likesCount,
    required this.isLikedByMe,
    this.parentCommentId,
    this.replies = const [],
    this.nestingLevel = 0,
    this.isPosting = false,
  });

  factory Comment.fromMap(Map<String, dynamic> map, {int nestingLevel = 0}) {
    // Handle timestamp parsing more robustly
    DateTime createdAt;
    try {
      final timestamp = map['created_at'];
      if (timestamp is String) {
        createdAt = DateTime.parse(timestamp).toLocal();
      } else if (timestamp is DateTime) {
        createdAt = timestamp.toLocal();
      } else {
        createdAt = DateTime.now();
      }
    } catch (e) {
      createdAt = DateTime.now();
    }

    return Comment(
      id: map['id'],
      postId: map['post_id'],
      userId: map['user_id'],
      username: map['username'],
      avatarUrl: map['avatar_url'] ?? '',
      content: map['content'],
      createdAt: createdAt,
      likesCount: map['likes_count'] ?? 0,
      isLikedByMe: map['is_liked_by_me'] ?? false,
      parentCommentId: map['parent_comment_id'],
      replies: [], // Will be populated separately
      nestingLevel: nestingLevel,
      isPosting: false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'post_id': postId,
      'user_id': userId,
      'username': username,
      'avatar_url': avatarUrl,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'likes_count': likesCount,
      'parent_comment_id': parentCommentId,
    };
  }

  Comment copyWith({
    String? id,
    String? postId,
    String? userId,
    String? username,
    String? avatarUrl,
    String? content,
    DateTime? createdAt,
    int? likesCount,
    bool? isLikedByMe,
    String? parentCommentId,
    List<Comment>? replies,
    int? nestingLevel,
    bool? isPosting,
  }) {
    return Comment(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      likesCount: likesCount ?? this.likesCount,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
      parentCommentId: parentCommentId ?? this.parentCommentId,
      replies: replies ?? this.replies,
      nestingLevel: nestingLevel ?? this.nestingLevel,
      isPosting: isPosting ?? this.isPosting,
    );
  }
} 