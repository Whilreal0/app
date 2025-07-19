// lib/features/post/screens/post_details_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../home/models/post.dart';
import '../../home/providers/posts_provider.dart';

class PostDetailsScreen extends ConsumerWidget {
  final String postId;
  const PostDetailsScreen({Key? key, required this.postId}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Find the post in all posts (for demo; ideally fetch by ID)
    final allPostsAsync = ref.watch(currentUserPostsProvider);
    
    return allPostsAsync.when(
      data: (allPosts) {
        final post = allPosts.firstWhere(
          (p) => p.id == postId,
          orElse: () => Post(
            id: postId,
            userId: '',
            username: 'Unknown',
            avatarUrl: '',
            imageUrl: '',
            caption: 'Post not found',
            likesCount: 0,
            commentsCount: 0,
            createdAt: DateTime.now(),
            isLikedByMe: false,
          ),
        );

            return Scaffold(
          appBar: AppBar(title: const Text('Post Details')),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundImage: post.avatarUrl.isNotEmpty ? NetworkImage(post.avatarUrl) : null,
                      child: post.avatarUrl.isEmpty ? const Icon(Icons.person) : null,
                    ),
                    const SizedBox(width: 12),
                    Text(post.username, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text(post.createdAt.toString().substring(0, 10), style: const TextStyle(color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 16),
                Text(post.caption, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 16),
                if (post.imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(post.imageUrl, width: double.infinity, fit: BoxFit.cover),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.favorite, color: post.isLikedByMe ? Colors.red : Colors.grey),
                    const SizedBox(width: 4),
                    Text('${post.likesCount} likes'),
                    const SizedBox(width: 16),
                    Icon(Icons.mode_comment_outlined, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('${post.commentsCount} comments'),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(child: Text('Error: $error')),
      ),
    );
  }
}