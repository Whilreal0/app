import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/post.dart'; // adjust the import path as needed
import '../../../core/services/post_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/posts_provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/widgets/notification_bell_icon.dart';
import '../../../core/providers/post_report_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 59) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '${minutes}m';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '${hours}h';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      final remainingHours = difference.inHours % 24;
      if (remainingHours > 0) {
        return '${days}d${remainingHours}h';
      } else {
        return '${days}d';
      }
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '${weeks}w';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '${months}mo';
    } else {
      final years = (difference.inDays / 365).floor();
      return '${years}y';
    }
  }

  void _showPostOptions(BuildContext context, Post post, User user) {
    final isOwner = post.userId == user.id;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              
              if (isOwner) ...[
                // Owner options
                ListTile(
                  leading: const Icon(Icons.edit, color: Colors.blue),
                  title: const Text('Edit Post'),
                  onTap: () {
                    Navigator.pop(context);
                    _editPost(context, post);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Delete Post'),
                  onTap: () {
                    Navigator.pop(context);
                    _deletePost(context, post, user);
                  },
                ),
              ] else ...[
                // Non-owner options
                ListTile(
                  leading: const Icon(Icons.report, color: Colors.orange),
                  title: const Text('Report to Admin'),
                  onTap: () {
                    Navigator.pop(context);
                    _reportPost(context, post, user);
                  },
                ),
              ],
              
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _editPost(BuildContext context, Post post) {
    // TODO: Navigate to edit post screen
    _scaffoldMessengerKey.currentState?.showSnackBar(
      const SnackBar(
        content: Text('Edit post feature coming soon!'),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _deletePost(BuildContext context, Post post, User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // Show snackbar immediately when button is pressed
              _scaffoldMessengerKey.currentState?.showSnackBar(
                const SnackBar(
                  content: Text('Deleting post...'),
                  backgroundColor: Colors.blue,
                  duration: Duration(seconds: 1),
                ),
              );
              
              try {
                await ref.read(postsProvider(user.id).notifier).deletePost(post);
                
                // Show success snackbar
                _scaffoldMessengerKey.currentState?.showSnackBar(
                  const SnackBar(
                    content: Text('Post deleted successfully'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 1),
                  ),
                );
              } catch (e) {
                _scaffoldMessengerKey.currentState?.showSnackBar(
                  SnackBar(
                    content: Text('Error deleting post: $e'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _reportPost(BuildContext context, Post post, User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Post'),
        content: const Text('Are you sure you want to report this post to admin? This will be reviewed by our moderation team.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // Show snackbar immediately when button is pressed
              _scaffoldMessengerKey.currentState?.showSnackBar(
                const SnackBar(
                  content: Text('Reporting post...'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 1),
                ),
              );
              
              try {
                await ref.read(postReportProvider.notifier).reportPost(
                  postId: post.id,
                  reporterId: user.id,
                  postOwnerId: post.userId,
                  reason: 'User reported',
                );
                
                // Show success snackbar
                _scaffoldMessengerKey.currentState?.showSnackBar(
                  const SnackBar(
                    content: Text('Post reported successfully. Thank you for helping keep our community safe.'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 1),
                  ),
                );
              } catch (e) {
                _scaffoldMessengerKey.currentState?.showSnackBar(
                  SnackBar(
                    content: Text('Error reporting post: $e'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Report'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final posts = ref.watch(currentUserPostsProvider);
    final authState = ref.watch(authStateProvider);

    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: authState.when(
        data: (user) {
          if (user == null) {
            return Scaffold(
              body: Center(child: Text('Please log in')),
            );
          }

          if (posts.isEmpty) {
            return Scaffold(
              appBar: AppBar(title: const Text('Home'), actions: [NotificationBellIcon()]),
              body: const Center(child: CircularProgressIndicator()),
            );
          }

          return Scaffold(
            appBar: AppBar(title: const Text('Home'), actions: [NotificationBellIcon()]),
            body: RefreshIndicator(
              onRefresh: () async {
                // Refresh posts when user pulls down
                try {
                  final authState = ref.read(authStateProvider);
                  authState.whenData((user) {
                    if (user != null) {
                      ref.read(postsProvider(user.id).notifier).refresh();
                    }
                  });
                } catch (e) {
                  // Handle error silently
                }
              },
              child: ListView.builder(
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  final post = posts[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: Avatar, Username, Timestamp
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundImage: post.avatarUrl != null && post.avatarUrl.isNotEmpty
                                    ? NetworkImage(post.avatarUrl)
                                    : null,
                                backgroundColor: Colors.grey,
                                radius: 20,
                                child: (post.avatarUrl == null || post.avatarUrl.isEmpty)
                                    ? Icon(Icons.person)
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      post.username,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    Text(
                                      _formatTimestamp(post.createdAt),
                                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.more_vert),
                                onPressed: () {
                                  _showPostOptions(context, post, user);
                                },
                              ),
                            ],
                          ),
                        ),
                        // Caption
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text(
                            post.caption,
                            style: const TextStyle(fontSize: 15),
                          ),
                        ),
                        
                        // Only show the image if imageUrl is not empty
                        if (post.imageUrl.isNotEmpty)
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(0), bottom: Radius.circular(0)),
                            child: Image.network(
                              post.imageUrl,
                              width: double.infinity,
                              height: 300,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const SizedBox(
                                height: 100,
                                child: Center(child: Text('Image failed to load')),
                              ),
                            ),
                          ),
                        // Action Row
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  post.isLikedByMe ? Icons.favorite : Icons.favorite_border,
                                  color: post.isLikedByMe ? Colors.red : null,
                                ),
                                onPressed: () {
                                  if (post.isLikedByMe) {
                                    ref.read(postsProvider(user.id).notifier).unlikePost(post);
                                  } else {
                                    ref.read(postsProvider(user.id).notifier).likePost(post);
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.mode_comment_outlined),
                                onPressed: () {
                                  // Navigate to comments screen
                                  context.push('/comments/${post.id}');
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.send_outlined),
                                onPressed: () {},
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.bookmark_border),
                                onPressed: () {},
                              ),
                            ],
                          ),
                        ),
                        // Likes and comments summary
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (post.likesCount > 0)
                                Text(
                                  'Liked by ${post.likesCount} ${post.likesCount == 1 ? 'other' : 'others'}',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                ),
                              if (post.commentsCount > 0)
                                GestureDetector(
                                  onTap: () {
                                    // Navigate to comments screen
                                    context.push('/comments/${post.id}');
                                  },
                                  child: Text(
                                    'View all ${post.commentsCount} comments',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
        loading: () => Scaffold(
          appBar: AppBar(title: const Text('Home'), actions: [NotificationBellIcon()]),
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (error, stack) => Scaffold(
          appBar: AppBar(title: const Text('Home'), actions: [NotificationBellIcon()]),
          body: Center(child: Text('Error: $error')),
        ),
      ),
    );
  }
}

Future<List<Post>> fetchPosts() async {
  final response = await Supabase.instance.client
      .from('posts')
      .select()
      .order('created_at', ascending: false);

  return (response as List)
      .map((item) => Post.fromMap(item as Map<String, dynamic>))
      .toList();
} 