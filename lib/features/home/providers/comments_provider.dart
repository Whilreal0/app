import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/comment_service.dart';
import '../models/comment.dart';
import '../../../core/providers/auth_provider.dart';

// Family provider for comments of a specific post
final commentsProvider = StateNotifierProvider.family<CommentsNotifier, AsyncValue<List<Comment>>, String>((ref, postId) {
  final authState = ref.watch(authStateProvider);
  
  return authState.when(
    data: (user) {
      if (user == null) return CommentsNotifier(ref, postId, null);
      return CommentsNotifier(ref, postId, user.id);
    },
    loading: () => CommentsNotifier(ref, postId, null),
    error: (_, __) => CommentsNotifier(ref, postId, null),
  );
});

class CommentsNotifier extends StateNotifier<AsyncValue<List<Comment>>> {
  final Ref ref;
  final String postId;
  final String? userId;
  
  CommentsNotifier(this.ref, this.postId, this.userId) : super(const AsyncValue.loading()) {
    if (userId != null) {
      loadComments();
    }
  }

  Future<void> loadComments() async {
    if (userId == null) {
      print('Cannot load comments: userId is null');
      return;
    }
    
    try {
      
      state = const AsyncValue.loading();
      final comments = await CommentService().fetchCommentsForPost(postId, userId!);
      
      state = AsyncValue.data(comments);
    } catch (e) {
      
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> addComment(String content, {String? parentCommentId}) async {
    if (userId == null) return;

    // Store original state for rollback
    final originalState = state;

    try {
      // Optimistically add the comment to UI
      state.whenData((comments) {
        final newComment = Comment(
          id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
          postId: postId,
          userId: userId!,
          username: 'You', // Will be updated when we get the real data
          avatarUrl: '',
          content: content,
          createdAt: DateTime.now(),
          likesCount: 0,
          isLikedByMe: false,
          parentCommentId: parentCommentId,
          replies: [],
          nestingLevel: parentCommentId != null ? 1 : 0,
          isPosting: true, // Mark as posting
        );

        List<Comment> updatedComments;
        if (parentCommentId != null) {
          // Add as reply to existing comment
          updatedComments = [
            for (final comment in comments)
              if (comment.id == parentCommentId)
                comment.copyWith(
                  replies: [...comment.replies, newComment],
                )
              else
                comment
          ];
        } else {
          // Add as main comment
          updatedComments = [newComment, ...comments];
        }

        state = AsyncValue.data(updatedComments);
      });

      // Call the service to actually add the comment
      final newComment = await CommentService().addComment(
        postId: postId,
        userId: userId!,
        content: content,
        parentCommentId: parentCommentId,
        ref: ref,
      );

      if (newComment != null) {
        // Update with the real comment data (including proper ID, username, etc.)
        state.whenData((comments) {
          List<Comment> updatedComments;
          if (parentCommentId != null) {
            // Replace the temp reply with the real one
            updatedComments = [
              for (final comment in comments)
                if (comment.id == parentCommentId)
                  comment.copyWith(
                                         replies: comment.replies.map((reply) {
                       if (reply.id.startsWith('temp_')) {
                         return newComment.copyWith(nestingLevel: 1, isPosting: false);
                       }
                       return reply;
                     }).toList(),
                  )
                else
                  comment
            ];
          } else {
            // Replace the temp main comment with the real one
                         updatedComments = comments.map((comment) {
               if (comment.id.startsWith('temp_')) {
                 return newComment.copyWith(isPosting: false);
               }
               return comment;
             }).toList();
          }

          state = AsyncValue.data(updatedComments);
        });
      }
    } catch (e) {
      print('Error adding comment: $e');
      // Revert to original state on error
      state = originalState;
    }
  }

  Future<void> likeComment(String commentId) async {
    if (userId == null) return;

    // Store original state for rollback
    final originalState = state;

    try {
      print('Provider: Liking comment: $commentId');
      
      // Optimistically update UI
      state.whenData((comments) {
        final updatedComments = _updateCommentInState(comments, commentId, (comment) {
          print('Provider: Updating comment ${comment.id} - isLikedByMe: true, likesCount: ${comment.likesCount + 1}');
          return comment.copyWith(
            isLikedByMe: true,
            likesCount: comment.likesCount + 1,
          );
        });
        state = AsyncValue.data(updatedComments);
      });

      // Call the service
      await CommentService().likeComment(commentId, userId!, ref: ref);
      print('Provider: Comment liked successfully');
    } catch (e) {
      print('Provider: Error liking comment: $e');
      // Revert to original state on error
      state = originalState;
    }
  }

  Future<void> unlikeComment(String commentId) async {
    if (userId == null) return;

    // Store original state for rollback
    final originalState = state;

    try {
      print('Provider: Unliking comment: $commentId');
      
      // Optimistically update UI
      state.whenData((comments) {
        final updatedComments = _updateCommentInState(comments, commentId, (comment) {
          print('Provider: Updating comment ${comment.id} - isLikedByMe: false, likesCount: ${(comment.likesCount > 0) ? comment.likesCount - 1 : 0}');
          return comment.copyWith(
            isLikedByMe: false,
            likesCount: (comment.likesCount > 0) ? comment.likesCount - 1 : 0,
          );
        });
        state = AsyncValue.data(updatedComments);
      });

      // Call the service
      await CommentService().unlikeComment(commentId, userId!);
      print('Provider: Comment unliked successfully');
    } catch (e) {
      print('Provider: Error unliking comment: $e');
      // Revert to original state on error
      state = originalState;
    }
  }

  Future<void> editComment(String commentId, String newContent) async {
    if (userId == null) return;

    // Store original state for rollback
    final originalState = state;

    try {
      // Optimistically update UI
      state.whenData((comments) {
        final updatedComments = _updateCommentInState(comments, commentId, (comment) {
          return comment.copyWith(
            content: newContent,
            isEditing: false, // Exit edit mode
          );
        });
        state = AsyncValue.data(updatedComments);
      });

      // Call the service
      final updatedComment = await CommentService().editComment(commentId, newContent);
      
      if (updatedComment != null) {
        // Update with the real comment data
        state.whenData((comments) {
          final updatedComments = _updateCommentInState(comments, commentId, (comment) {
            return updatedComment.copyWith(
              isLikedByMe: comment.isLikedByMe, // Preserve like state
              replies: comment.replies, // Preserve replies
              nestingLevel: comment.nestingLevel, // Preserve nesting
            );
          });
          state = AsyncValue.data(updatedComments);
        });
      }
    } catch (e) {
      print('Error editing comment: $e');
      // Revert to original state on error
      state = originalState;
    }
  }

  Future<void> deleteComment(String commentId) async {
    if (userId == null) return;

    try {
      // Remove from state optimistically
      state.whenData((comments) {
        final updatedComments = comments.where((comment) => comment.id != commentId).toList();
        state = AsyncValue.data(updatedComments);
      });

      // Call the service
      await CommentService().deleteComment(commentId, postId);
    } catch (e) {
      // Revert on error
      await loadComments();
    }
  }

  // Helper method to update a comment in the state (including in replies)
  List<Comment> _updateCommentInState(List<Comment> comments, String commentId, Comment Function(Comment) update) {
    return [
      for (final comment in comments)
        if (comment.id == commentId)
          update(comment)
        else
          comment.copyWith(
            replies: _updateCommentInState(comment.replies, commentId, update),
          )
    ];
  }

  // Refresh comments
  Future<void> refresh() async {
    await loadComments();
  }
} 