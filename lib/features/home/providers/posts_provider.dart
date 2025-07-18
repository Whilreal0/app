import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/post_service.dart';
import '../models/post.dart';
import '../../../core/providers/auth_provider.dart';

// Family provider that depends on userId
final postsProvider = StateNotifierProvider.family<PostsNotifier, List<Post>, String>((ref, userId) {
  return PostsNotifier(ref, userId);
});

// Convenience provider that automatically gets the current user's posts
final currentUserPostsProvider = Provider<List<Post>>((ref) {
  final authState = ref.watch(authStateProvider);
  
  return authState.when(
    data: (user) {
      if (user == null) return [];
      return ref.watch(postsProvider(user.id));
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

class PostsNotifier extends StateNotifier<List<Post>> {
  final Ref ref;
  final String userId;
  
  PostsNotifier(this.ref, this.userId) : super([]) {
    loadPosts();
  }

  Future<void> loadPosts() async {
    try {
      final posts = await PostService().fetchPostsWithLikeState(userId);
      state = posts;
    } catch (e) {
      // Handle error - set empty state or show error
      state = [];
    }
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
    try {
      await PostService().likePost(post.id, userId);
    } catch (e) {
      // Revert optimistic update on error
      await loadPosts();
    }
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
    try {
      await PostService().unlikePost(post.id, userId);
    } catch (e) {
      // Revert optimistic update on error
      await loadPosts();
    }
  }
}
