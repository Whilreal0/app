class Post {
  final String id;
  final String userId;
  final String username;
  final String avatarUrl;
  final String imageUrl;
  final String caption;
  final int likesCount;
  final DateTime createdAt;

  Post({
    required this.id,
    required this.userId,
    required this.username,
    required this.avatarUrl,
    required this.imageUrl,
    required this.caption,
    required this.likesCount,
    required this.createdAt,
  });

  factory Post.fromMap(Map<String, dynamic> map) {
    return Post(
      id: map['id'],
      userId: map['user_id'],
      username: map['username'],
      avatarUrl: map['avatar_url'] ?? '',
      imageUrl: map['image_url'],
      caption: map['caption'] ?? '',
      likesCount: map['likes_count'] ?? 0,
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}