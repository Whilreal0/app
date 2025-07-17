import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/home/models/post.dart';

class PostService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> addPost(Post post) async {
    await _supabase.from('posts').insert(post.toMap()).select().single();
    // Optionally, you can return the created Post or handle errors here
    // return Post.fromMap(response);
  }

  Future<List<Post>> fetchPostsWithLikeState(String userId) async {
    // 1. Fetch all posts
    final postsResponse = await _supabase
        .from('posts')
        .select()
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

  Future<void> likePost(String postId, String userId) async {
    try {
      await _supabase.from('post_likes').insert({
        'post_id': postId,
        'user_id': userId,
      });
    } on PostgrestException catch (e) {
      if (e.code == '23505') { // Unique violation
        // Already liked, ignore or log
        print('User already liked this post.');
      } else {
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
} 