import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/post_service.dart';
import '../models/post.dart';
import '../../../core/providers/auth_provider.dart';

// Family provider that depends on userId
final postsProvider = StateNotifierProvider.family<PostsNotifier, AsyncValue<List<Post>>, String>((ref, userId) {
  return PostsNotifier(ref, userId);
});

// Convenience provider that automatically gets the current user's posts
final currentUserPostsProvider = Provider<AsyncValue<List<Post>>>((ref) {
  final authState = ref.watch(authStateProvider);
  
  return authState.when(
    data: (user) {
      if (user == null) return const AsyncValue.data([]);
      return ref.watch(postsProvider(user.id));
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

class PostsNotifier extends StateNotifier<AsyncValue<List<Post>>> {
  final Ref ref;
  final String userId;
  
  PostsNotifier(this.ref, this.userId) : super(const AsyncValue.loading()) {
    loadPosts();
  }

  Future<void> loadPosts() async {
    try {
      state = const AsyncValue.loading();
      final posts = await PostService().fetchPostsWithLikeState(userId);
      state = AsyncValue.data(posts);
    } catch (e) {
      // Handle error - set error state
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> likePost(Post post) async {
    // Optimistically update UI
    state.whenData((posts) {
      final updatedPosts = [
        for (final p in posts)
          if (p.id == post.id)
            p.copyWith(isLikedByMe: true, likesCount: p.likesCount + 1)
          else
            p
      ];
      state = AsyncValue.data(updatedPosts);
    });
    
    // Call server
    try {
      await PostService().likePost(post.id, userId, ref: ref);
    } catch (e) {
      // Revert optimistic update on error
      await loadPosts();
    }
  }

  Future<void> unlikePost(Post post) async {
    // Optimistically update UI
    state.whenData((posts) {
      final updatedPosts = [
        for (final p in posts)
          if (p.id == post.id)
            p.copyWith(isLikedByMe: false, likesCount: (p.likesCount > 0) ? p.likesCount - 1 : 0)
          else
            p
      ];
      state = AsyncValue.data(updatedPosts);
    });
    
    // Call server
    try {
      await PostService().unlikePost(post.id, userId);
    } catch (e) {
      // Revert optimistic update on error
      await loadPosts();
    }
  }

  Future<void> deletePost(Post post) async {
    // Only allow deletion if user owns the post
    if (post.userId != userId) {
      throw Exception('You can only delete your own posts');
    }

    // Optimistically remove from UI
    state.whenData((posts) {
      final updatedPosts = posts.where((p) => p.id != post.id).toList();
      state = AsyncValue.data(updatedPosts);
    });
    
    // Call server
    try {
      await PostService().deletePost(post.id, userId);
    } catch (e) {
      // Revert optimistic update on error
      await loadPosts();
      rethrow;
    }
  }

  // Refresh posts
  Future<void> refresh() async {
    await loadPosts();
  }
}
