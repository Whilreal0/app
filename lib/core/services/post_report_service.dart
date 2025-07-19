import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/post_report.dart';

class PostReportService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> reportPost({
    required String postId,
    required String reporterId,
    required String postOwnerId,
    required String reason,
  }) async {
    // Check if user has already reported this post
    final existingReport = await _supabase
        .from('post_reports')
        .select('id')
        .eq('post_id', postId)
        .eq('reporter_id', reporterId)
        .maybeSingle();

    if (existingReport != null) {
      throw Exception('You have already reported this post');
    }

    // Create the report
    await _supabase.from('post_reports').insert({
      'post_id': postId,
      'reporter_id': reporterId,
      'post_owner_id': postOwnerId,
      'reason': reason,
      'created_at': DateTime.now().toIso8601String(),
      'is_resolved': false,
    });
  }

  Future<List<PostReport>> getReportedPosts() async {
    final response = await _supabase
        .from('post_reports')
        .select('''
          *,
          post:post_id(
            id,
            caption,
            image_url,
            user_id,
            created_at
          ),
          reporter:reporter_id(
            id,
            email,
            username
          ),
          post_owner:post_owner_id(
            id,
            email,
            username
          )
        ''')
        .eq('is_resolved', false)
        .order('created_at', ascending: false);

    return (response as List).map((e) => PostReport.fromMap(e)).toList();
  }

  Future<void> resolveReport({
    required String reportId,
    required String resolvedBy,
    required String resolution,
  }) async {
    await _supabase
        .from('post_reports')
        .update({
          'is_resolved': true,
          'resolved_by': resolvedBy,
          'resolved_at': DateTime.now().toIso8601String(),
          'resolution': resolution,
        })
        .eq('id', reportId);
  }

  Future<void> deleteReportedPost(String postId) async {
    // Delete related data first
    await _supabase.from('post_likes').delete().eq('post_id', postId);
    await _supabase.from('comments').delete().eq('post_id', postId);
    await _supabase.from('post_reports').delete().eq('post_id', postId);
    
    // Finally delete the post
    await _supabase.from('posts').delete().eq('id', postId);
  }
} 