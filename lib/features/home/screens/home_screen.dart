import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/post.dart'; // adjust the import path as needed
import '../../../core/services/post_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/posts_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posts = ref.watch(postsProvider);

    if (posts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: ListView.builder(
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
                              post.createdAt.toString().substring(0, 10), // Format timestamp
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_vert),
                        onPressed: () {},
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
                            ref.read(postsProvider.notifier).unlikePost(post);
                          } else {
                            ref.read(postsProvider.notifier).likePost(post);
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.mode_comment_outlined),
                        onPressed: () {},
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
                // Likes summary
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  child: Text(
                    'Liked by ${post.likesCount} others',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }
}

final userIdProvider = Provider<String>((ref) {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) throw Exception('User not logged in');
  return user.id;
});

Future<List<Post>> fetchPosts() async {
  final response = await Supabase.instance.client
      .from('posts')
      .select()
      .order('created_at', ascending: false);

  return (response as List)
      .map((item) => Post.fromMap(item as Map<String, dynamic>))
      .toList();
} 