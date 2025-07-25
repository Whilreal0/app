class UserProfile {
  final String id;
  final String email;
  final String role;
  final DateTime createdAt;
  final String? fullName;
  final String? username;
  final String? avatarUrl;

  UserProfile({
    required this.id,
    required this.email,
    required this.role,
    required this.createdAt,
    this.fullName,
    this.username,
    this.avatarUrl,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      fullName: json['fullname'] as String?,
      username: json['username'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'role': role,
      'created_at': createdAt.toIso8601String(),
      if (fullName != null) 'fullname': fullName,
      if (username != null) 'username': username,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    };
  }

  UserProfile copyWith({
    String? id,
    String? email,
    String? role,
    DateTime? createdAt,
    String? fullName,
    String? username,
    String? avatarUrl,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      fullName: fullName ?? this.fullName,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  bool get isSuperAdmin => role == 'superadmin';
  bool get isAdmin => role == 'admin';
  bool get isModerator => role == 'moderator';
  bool get isUser => role == 'user';

  bool canManageUsers() => isSuperAdmin || isAdmin;
  bool canAccessSettings() => isSuperAdmin || isAdmin || isModerator;
  bool canModerateContent() => isSuperAdmin || isAdmin || isModerator;
}