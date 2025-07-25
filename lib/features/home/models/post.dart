class Post {
  final String id;
  final String userId;
  final String username;
  final String avatarUrl;
  final String imageUrl;
  final String caption;
  final int likesCount;
  final int commentsCount;
  final DateTime createdAt;
  final bool isLikedByMe;

 
  Post({
    required this.id,
    required this.userId,
    required this.username,
    required this.avatarUrl,
    required this.imageUrl,
    required this.caption,
    required this.likesCount,
    required this.commentsCount,
    required this.createdAt,
    required this.isLikedByMe,
  });

  factory Post.fromMap(Map<String, dynamic> map) {
    // Parse timestamp and convert to local time if it's in UTC
    DateTime parseTimestamp(dynamic timestamp) {
      if (timestamp is String) {
        final parsed = DateTime.parse(timestamp);
        // If the timestamp ends with 'Z', it's UTC, convert to local
        if (timestamp.endsWith('Z')) {
          return parsed.toLocal();
        }
        return parsed;
      }
      return DateTime.now(); // fallback
    }

    return Post(
      id: map['id'],
      userId: map['user_id'],
      username: map['username'],
      avatarUrl: map['avatar_url'] ?? '',
      imageUrl: map['image_url'],
      caption: map['caption'] ?? '',
      likesCount: map['likes_count'] ?? 0,
      commentsCount: map['comments_count'] ?? 0,
      createdAt: parseTimestamp(map['created_at']),
      isLikedByMe: map['is_liked_by_me'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'username': username,
      'avatar_url': avatarUrl,
      'image_url': imageUrl,
      'caption': caption,
      'likes_count': likesCount,
      'comments_count': commentsCount,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Post copyWith({
    String? id,
    String? userId,
    String? username,
    String? avatarUrl,
    String? imageUrl,
    String? caption,
    int? likesCount,
    int? commentsCount,
    DateTime? createdAt,
    bool? isLikedByMe,
  }) {
    return Post(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      caption: caption ?? this.caption,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      createdAt: createdAt ?? this.createdAt,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
    );
  }
}