import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/home/models/post.dart';
import 'notification_service.dart';
import '../providers/notification_provider.dart';
import '../providers/auth_provider.dart';

class PostService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final NotificationService _notificationService = NotificationService();

  Future<void> addPost(Post post) async {
    await _supabase.from('posts').insert(post.toMap()).select().single();
    // Optionally, you can return the created Post or handle errors here
    // return Post.fromMap(response);
  }

  Future<List<Post>> fetchPostsWithLikeState(String userId) async {
    // 1. Fetch all posts with comment counts
    final postsResponse = await _supabase
        .from('posts')
        .select('*, comments_count')
        .order('created_at', ascending: false);

    final posts = (postsResponse as List)
        .map((e) => Post.fromMap(e))
        .toList();

    // 2. Fetch all post_likes for current user
    final likesResponse = await _supabase
        .from('post_likes')
        .select('post_id')
        .eq('user_id', userId); // <--- THIS IS CRITICAL

    final likedPostIds = (likesResponse as List)
        .map((e) => e['post_id'] as String)
        .toSet();

    // 3. Merge: set isLikedByMe for each post
    return posts
        .map((post) => post.copyWith(isLikedByMe: likedPostIds.contains(post.id)))
        .toList();
  }

  Future<void> likePost(String postId, String userId, {Ref? ref}) async {
    try {
      print('PostService: Liking post: $postId by user: $userId');
      await _supabase.from('post_likes').insert({
        'post_id': postId,
        'user_id': userId,
      });

      // Get the post to get the owner
      final post = await _supabase
          .from('posts')
          .select('user_id')
          .eq('id', postId)
          .single();
      final postOwnerId = post['user_id'];
      print('PostService: Post owner: $postOwnerId, current user: $userId');
      
      // Create notification if not liking own post
      if (postOwnerId != userId) {
        print('PostService: Creating post like notification');
        await _notificationService.createPostLikeNotification(
          postId: postId,
          fromUserId: userId,
          postOwnerId: postOwnerId,
        );
        
        // Note: UI updates should be handled by the calling widget, not the service
        print('PostService: Post like notification created - UI will update on next poll');
      } else {
        print('PostService: Skipping post like notification - user is liking their own post');
      }
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        print('PostService: Post already liked by user');
        // Duplicate key error - already liked
      } else {
        print('PostService: Error liking post: $e');
        rethrow;
      }
    }
  }

  Future<void> unlikePost(String postId, String userId) async {
    await _supabase.from('post_likes')
      .delete()
      .eq('post_id', postId)
      .eq('user_id', userId);
  }

  Future<void> deletePost(String postId, String userId) async {
    // First verify the user owns the post
    final post = await _supabase
        .from('posts')
        .select('user_id')
        .eq('id', postId)
        .single();
    
    if (post['user_id'] != userId) {
      throw Exception('You can only delete your own posts');
    }

    // Delete related data first (likes, comments, etc.)
    await _supabase.from('post_likes').delete().eq('post_id', postId);
    await _supabase.from('comments').delete().eq('post_id', postId);
    
    // Finally delete the post
    await _supabase.from('posts').delete().eq('id', postId);
  }
} 