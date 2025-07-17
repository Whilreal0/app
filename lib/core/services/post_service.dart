import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/home/models/post.dart';

class PostService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> addPost(Post post) async {
    await _supabase.from('posts').insert(post.toMap()).select().single();
    // Optionally, you can return the created Post or handle errors here
    // return Post.fromMap(response);
  }
} 