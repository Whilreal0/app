import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/post_service.dart';
import '../models/post.dart';
import '../../../core/providers/auth_provider.dart';

final postsProvider = StateNotifierProvider.autoDispose<PostsNotifier, List<Post>>((ref) {
  final userId = ref.watch(userIdProvider);
  return PostsNotifier(ref);
});

class PostsNotifier extends StateNotifier<List<Post>> {
  final Ref ref;
  PostsNotifier(this.ref) : super([]) {
    loadPosts();
  }

  Future<void> loadPosts() async {
    final userId = ref.read(userIdProvider);
    final posts = await PostService().fetchPostsWithLikeState(userId);
    state = posts;
  }

  Future<void> likePost(Post post) async {
    // Optimistically update UI
    state = [
      for (final p in state)
        if (p.id == post.id)
          p.copyWith(isLikedByMe: true, likesCount: p.likesCount + 1)
        else
          p
    ];
    // Call server
    final userId = ref.read(userIdProvider);
    await PostService().likePost(post.id, userId);
    // Optionally, refresh from server in background
    // await loadPosts();
  }

  Future<void> unlikePost(Post post) async {
    // Optimistically update UI
    state = [
      for (final p in state)
        if (p.id == post.id)
          p.copyWith(isLikedByMe: false, likesCount: (p.likesCount > 0) ? p.likesCount - 1 : 0)
        else
          p
    ];
    // Call server
    final userId = ref.read(userIdProvider);
    await PostService().unlikePost(post.id, userId);
    // Optionally, refresh from server in background
    // await loadPosts();
  }
}
