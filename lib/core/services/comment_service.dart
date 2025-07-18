import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../features/home/models/comment.dart';

class CommentService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Fetch comments for a specific post
  Future<List<Comment>> fetchCommentsForPost(String postId, String currentUserId) async {
    try {
      print('Fetching comments for post: $postId');
      
      // Fetch all comments for the post (without join)
      final response = await _supabase
          .from('comments')
          .select('*')
          .eq('post_id', postId)
          .order('created_at', ascending: false);

      print('Raw response from comments: $response');
      print('Number of comments found: ${response.length}');

      if (response.isEmpty) return [];

      // Get all unique user IDs from comments and replies
      final userIds = <String>{};
      for (final commentData in response) {
        userIds.add(commentData['user_id']);
      }

      // Fetch user profiles individually (fallback since in_ doesn't exist)
      final userProfilesMap = <String, Map<String, dynamic>>{};
      for (final userId in userIds) {
        try {
          final userProfile = await _supabase
              .from('profiles')
              .select('id, username, avatar_url')
              .eq('id', userId)
              .single();
          userProfilesMap[userId] = userProfile;
        } catch (e) {
          print('Error fetching profile for user $userId: $e');
        }
      }

      final comments = <Comment>[];
      
      for (final commentData in response) {
        print('Processing comment: $commentData');
        
        // Only process main comments (parent_comment_id is null)
        if (commentData['parent_comment_id'] == null) {
          print('This is a main comment, processing...');
          
          final userProfile = userProfilesMap[commentData['user_id']];
          if (userProfile == null) {
            print('User profile not found for user: ${commentData['user_id']}');
            continue;
          }
          
          print('User profile for comment: $userProfile');
          
          final comment = Comment.fromMap({
            ...commentData,
            'username': userProfile['username'],
            'avatar_url': userProfile['avatar_url'] ?? '',
          }, nestingLevel: 0);

          // Fetch replies for this comment recursively
          final replies = await _fetchRepliesRecursively(comment.id, currentUserId, userProfilesMap, 1);
          
          // Check if current user liked this comment
          final isLiked = await _checkIfCommentLiked(comment.id, currentUserId);
          
          comments.add(comment.copyWith(
            replies: replies,
            isLikedByMe: isLiked,
          ));
          
          print('Added comment: ${comment.username} - ${comment.content}');
        } else {
          print('Skipping reply comment with parent_id: ${commentData['parent_comment_id']}');
        }
      }

      print('Final comments list length: ${comments.length}');
      return comments;
    } catch (e) {
      print('Error fetching comments: $e');
      return [];
    }
  }

  // Fetch replies for Facebook-style comments (only Level 1)
  Future<List<Comment>> _fetchRepliesRecursively(String commentId, String currentUserId, Map<String, Map<String, dynamic>> userProfilesMap, int level) async {
    try {
      // Only fetch Level 1 replies (Facebook-style)
      if (level > 1) {
        return [];
      }

      final response = await _supabase
          .from('comments')
          .select('*')
          .eq('parent_comment_id', commentId)
          .order('created_at', ascending: true);

      final replies = <Comment>[];
      
      for (final replyData in response) {
        final userProfile = userProfilesMap[replyData['user_id']];
        if (userProfile == null) {
          print('User profile not found for reply user: ${replyData['user_id']}');
          continue;
        }

        final reply = Comment.fromMap({
          ...replyData,
          'username': userProfile['username'],
          'avatar_url': userProfile['avatar_url'] ?? '',
        }, nestingLevel: 1); // All replies are Level 1

        print('Reply data: $replyData');
        print('Reply likes count: ${reply.likesCount}');

        // Check if current user liked this reply
        final isLiked = await _checkIfCommentLiked(reply.id, currentUserId);
        
        replies.add(reply.copyWith(
          isLikedByMe: isLiked,
          replies: [], // No nested replies in Facebook-style
        ));
      }

      return replies;
    } catch (e) {
      print('Error fetching replies: $e');
      return [];
    }
  }

  // Check if a comment is liked by the current user
  Future<bool> _checkIfCommentLiked(String commentId, String userId) async {
    try {
      final response = await _supabase
          .from('comment_likes')
          .select('id')
          .eq('comment_id', commentId)
          .eq('user_id', userId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  // Add a new comment
  Future<Comment?> addComment({
    required String postId,
    required String userId,
    required String content,
    String? parentCommentId,
  }) async {
    try {
      print('Adding comment - PostId: $postId, UserId: $userId, Content: $content, ParentId: $parentCommentId');
      
      // Get user profile for username and avatar
      final userProfile = await _supabase
          .from('profiles')
          .select('username, avatar_url')
          .eq('id', userId)
          .single();

      print('User profile: $userProfile');

      final commentData = {
        'id': const Uuid().v4(),
        'post_id': postId,
        'user_id': userId,
        'content': content,
        'parent_comment_id': parentCommentId,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };

      print('Comment data to insert: $commentData');

      final response = await _supabase
          .from('comments')
          .insert(commentData)
          .select()
          .single();

      print('Comment inserted successfully: $response');

      // Update post comment count
      await _updatePostCommentCount(postId, 1);
      print('Updated post comment count');

      return Comment.fromMap({
        ...response,
        'username': userProfile['username'],
        'avatar_url': userProfile['avatar_url'] ?? '',
        'is_liked_by_me': false,
      });
    } catch (e) {
      print('Error adding comment: $e');
      return null;
    }
  }

  // Like a comment
  Future<void> likeComment(String commentId, String userId) async {
    try {
      print('Liking comment: $commentId by user: $userId');
      
      await _supabase
          .from('comment_likes')
          .insert({
            'comment_id': commentId,
            'user_id': userId,
            'created_at': DateTime.now().toIso8601String(),
          });

      print('Comment like inserted successfully');

      // Update comment like count
      await _updateCommentLikeCount(commentId, 1);
      print('Comment like count updated');
    } catch (e) {
      print('Error liking comment: $e');
      rethrow;
    }
  }

  // Unlike a comment
  Future<void> unlikeComment(String commentId, String userId) async {
    try {
      print('Unliking comment: $commentId by user: $userId');
      
      await _supabase
          .from('comment_likes')
          .delete()
          .eq('comment_id', commentId)
          .eq('user_id', userId);

      print('Comment like deleted successfully');

      // Update comment like count
      await _updateCommentLikeCount(commentId, -1);
      print('Comment like count updated');
    } catch (e) {
      print('Error unliking comment: $e');
      rethrow;
    }
  }

  // Delete a comment
  Future<void> deleteComment(String commentId, String postId) async {
    try {
      // Delete comment likes first
      await _supabase
          .from('comment_likes')
          .delete()
          .eq('comment_id', commentId);

      // Delete replies first
      await _supabase
          .from('comments')
          .delete()
          .eq('parent_comment_id', commentId);

      // Delete the comment
      await _supabase
          .from('comments')
          .delete()
          .eq('id', commentId);

      // Update post comment count
      await _updatePostCommentCount(postId, -1);
    } catch (e) {
      print('Error deleting comment: $e');
    }
  }

  // Update comment like count
  Future<void> _updateCommentLikeCount(String commentId, int increment) async {
    try {
      print('Updating comment like count for comment: $commentId, increment: $increment');
      
      await _supabase.rpc('update_comment_like_count', params: {
        'comment_id': commentId,
        'increment': increment,
      });
      
      print('Comment like count updated successfully');
    } catch (e) {
      print('Error updating comment like count: $e');
      rethrow;
    }
  }

  // Update post comment count
  Future<void> _updatePostCommentCount(String postId, int increment) async {
    try {
      await _supabase.rpc('update_post_comment_count', params: {
        'post_id': postId,
        'increment': increment,
      });
    } catch (e) {
      print('Error updating post comment count: $e');
    }
  }
} 