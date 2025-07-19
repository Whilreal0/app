class PostReport {
  final String id;
  final String postId;
  final String reporterId;
  final String postOwnerId;
  final String reason;
  final DateTime createdAt;
  final bool isResolved;
  final String? resolvedBy;
  final DateTime? resolvedAt;
  final String? resolution;

  PostReport({
    required this.id,
    required this.postId,
    required this.reporterId,
    required this.postOwnerId,
    required this.reason,
    required this.createdAt,
    required this.isResolved,
    this.resolvedBy,
    this.resolvedAt,
    this.resolution,
  });

  factory PostReport.fromMap(Map<String, dynamic> map) {
    return PostReport(
      id: map['id']?.toString() ?? '',
      postId: map['post_id']?.toString() ?? '',
      reporterId: map['reporter_id']?.toString() ?? '',
      postOwnerId: map['post_owner_id']?.toString() ?? '',
      reason: map['reason']?.toString() ?? '',
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'].toString())
          : DateTime.now(),
      isResolved: map['is_resolved'] ?? false,
      resolvedBy: map['resolved_by']?.toString(),
      resolvedAt: map['resolved_at'] != null
          ? DateTime.parse(map['resolved_at'].toString())
          : null,
      resolution: map['resolution']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'post_id': postId,
      'reporter_id': reporterId,
      'post_owner_id': postOwnerId,
      'reason': reason,
      'created_at': createdAt.toIso8601String(),
      'is_resolved': isResolved,
      'resolved_by': resolvedBy,
      'resolved_at': resolvedAt?.toIso8601String(),
      'resolution': resolution,
    };
  }

  PostReport copyWith({
    String? id,
    String? postId,
    String? reporterId,
    String? postOwnerId,
    String? reason,
    DateTime? createdAt,
    bool? isResolved,
    String? resolvedBy,
    DateTime? resolvedAt,
    String? resolution,
  }) {
    return PostReport(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      reporterId: reporterId ?? this.reporterId,
      postOwnerId: postOwnerId ?? this.postOwnerId,
      reason: reason ?? this.reason,
      createdAt: createdAt ?? this.createdAt,
      isResolved: isResolved ?? this.isResolved,
      resolvedBy: resolvedBy ?? this.resolvedBy,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolution: resolution ?? this.resolution,
    );
  }
} 