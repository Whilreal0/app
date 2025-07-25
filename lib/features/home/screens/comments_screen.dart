import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/comment.dart';
import '../providers/comments_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

class CommentsScreen extends ConsumerStatefulWidget {
  final String postId;
  
  const CommentsScreen({Key? key, required this.postId}) : super(key: key);

  @override
  ConsumerState<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends ConsumerState<CommentsScreen> {
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _replyController = TextEditingController();
  final TextEditingController _editController = TextEditingController();
  String? _replyingToCommentId;
  String? _replyingToUsername;
  String? _parentCommentId; // Store the main comment ID for Facebook-style replies
  String? _editingCommentId; // Store the comment being edited

  // Getter for auth state
  AsyncValue<User?> get authState => ref.watch(authStateProvider);

  @override
  void dispose() {
    _commentController.dispose();
    _replyController.dispose();
    _editController.dispose();
    super.dispose();
  }

  void _startReply(Comment comment) {
    if (!mounted) return;
    setState(() {
      // In Facebook-style, all replies go to the main comment (Level 0)
      if (comment.nestingLevel == 1) {
        // This is a reply, so we need to reply to the main comment
        // We'll find the parent comment ID when submitting
        _parentCommentId = comment.parentCommentId;
        _replyingToUsername = comment.username; // Show who we're replying to
      } else {
        // This is a main comment (Level 0)
        _parentCommentId = comment.id;
        _replyingToUsername = comment.username;
      }
      _replyingToCommentId = _parentCommentId;
    });
    _replyController.clear();
  }

  void _cancelReply() {
    if (!mounted) return;
    setState(() {
      _replyingToCommentId = null;
      _replyingToUsername = null;
      _parentCommentId = null;
    });
    _replyController.clear();
  }

  void _startEdit(Comment comment) {
    if (!mounted) return;
    setState(() {
      _editingCommentId = comment.id;
      _editController.text = comment.content;
    });
  }

  void _cancelEdit() {
    if (!mounted) return;
    setState(() {
      _editingCommentId = null;
    });
    _editController.clear();
  }

  Future<void> _submitEdit() async {
    if (_editController.text.trim().isEmpty || _editingCommentId == null) return;

    final newContent = _editController.text.trim();
    _editController.clear();

    await ref.read(commentsProvider(widget.postId).notifier).editComment(
      _editingCommentId!,
      newContent,
    );

    _cancelEdit();
  }

  Future<void> _deleteComment(Comment comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(commentsProvider(widget.postId).notifier).deleteComment(comment.id);
    }
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty) return;

    final content = _commentController.text.trim();
    _commentController.clear();

    await ref.read(commentsProvider(widget.postId).notifier).addComment(content);

    if (!mounted) return;
    setState(() {
      // any state update after async
    });
  }

  Future<void> _submitReply() async {
    if (_replyController.text.trim().isEmpty || _parentCommentId == null) return;

    final content = _replyController.text.trim();
    _replyController.clear();

    await ref.read(commentsProvider(widget.postId).notifier).addComment(
      content,
      parentCommentId: _parentCommentId,
    );

    _cancelReply();
  }

  void _showCommentOptions(Comment comment) {
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
              
              // Menu options
              if (comment.userId == authState.value?.id) ...[
                // Edit option
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.edit,
                      color: Colors.black,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Edit comment',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _startEdit(comment);
                  },
                ),
                
                // Delete option
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.delete,
                      color: Colors.black,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Delete comment',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteComment(comment);
                  },
                ),
              ] else ...[
                // For non-owners, show a message
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'You can only edit your own comments',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
              
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(commentsProvider(widget.postId));
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comments'),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Comments List
          Expanded(
            child: commentsAsync.when(
              data: (comments) {
                if (comments.isEmpty) {
                  return const Center(
                    child: Text(
                      'No comments yet. Be the first to comment!',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }
                
                return RefreshIndicator(
                  onRefresh: () async {
                    try {
                      await ref.read(commentsProvider(widget.postId).notifier).refresh();
                    } catch (e) {
                      // Handle error silently
                    }
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: comments.length,
                    itemBuilder: (context, index) {
                      final comment = comments[index];
                      return _buildCommentWidget(comment);
                    },
                  ),
                );
              },
              loading: () => const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Loading comments...',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading comments',
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Reply input (if replying)
          if (_replyingToCommentId != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade800.withOpacity(0.5)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.reply,
                          size: 16,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Replying to $_replyingToUsername',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _cancelReply,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade800.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.grey,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.grey.shade800.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _replyController,
                            decoration: const InputDecoration(
                              hintText: 'Write a reply...',
                              border: InputBorder.none,
                              hintStyle: TextStyle(color: Colors.grey),
                            ),
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            maxLines: null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _submitReply,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.send,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          
          // Main comment input (only show when not replying)
          if (_replyingToCommentId == null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade800.withOpacity(0.5)),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: Colors.grey.shade800.withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        decoration: const InputDecoration(
                          hintText: 'Add a comment...',
                          border: InputBorder.none,
                          hintStyle: TextStyle(color: Colors.grey),
                        ),
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        maxLines: null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _submitComment,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.send,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCommentWidget(Comment comment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main comment
          GestureDetector(
            onLongPress: () => _showCommentOptions(comment),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade900.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey.shade800.withOpacity(0.5),
                  width: 0.5,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundImage: comment.avatarUrl.isNotEmpty
                          ? NetworkImage(comment.avatarUrl)
                          : null,
                      backgroundColor: Colors.grey.shade700,
                      child: comment.avatarUrl.isEmpty
                          ? const Icon(Icons.person, size: 18, color: Colors.white)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                
                  // Comment content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Username and timestamp
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                comment.username,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                if (comment.isPosting) ...[
                                  const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Text(
                                  _formatTimestamp(comment.createdAt, isPosting: comment.isPosting),
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        
                        // Comment text or edit input
                        if (_editingCommentId == comment.id)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade900.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppTheme.primaryColor.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: TextField(
                                    controller: _editController,
                                    decoration: const InputDecoration(
                                      hintText: 'Edit your comment...',
                                      border: InputBorder.none,
                                      hintStyle: TextStyle(color: Colors.grey),
                                    ),
                                    style: const TextStyle(color: Colors.white, fontSize: 14),
                                    maxLines: null,
                                    autofocus: true,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: _cancelEdit,
                                      child: const Text(
                                        'Cancel',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: _submitEdit,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryColor,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      ),
                                      child: const Text(
                                        'Save',
                                        style: TextStyle(color: Colors.white, fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
                            child: Text(
                              comment.content,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        
                        // Actions row
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade900.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              // Like button
                              GestureDetector(
                                onTap: () {
                                  if (comment.isLikedByMe) {
                                    ref.read(commentsProvider(widget.postId).notifier)
                                        .unlikeComment(comment.id);
                                  } else {
                                    ref.read(commentsProvider(widget.postId).notifier)
                                        .likeComment(comment.id);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        comment.isLikedByMe
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        size: 18,
                                        color: comment.isLikedByMe ? Colors.red.shade400 : Colors.grey.shade400,
                                      ),
                                      if (comment.likesCount > 0) ...[
                                        const SizedBox(width: 6),
                                        Text(
                                          '${comment.likesCount}',
                                          style: TextStyle(
                                            color: comment.isLikedByMe ? Colors.red.shade400 : Colors.grey.shade400,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              
                              // Reply button
                              GestureDetector(
                                onTap: () => _startReply(comment),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.reply,
                                        size: 18,
                                        color: Colors.grey.shade400,
                                      ),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'Reply',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              
                              // Spacer to push buttons to the left
                              const Spacer(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Replies (Facebook-style - only Level 1)
          if (comment.replies.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 12, left: 44),
              child: Column(
                children: comment.replies.map((reply) => _buildNestedCommentWidget(reply)).toList(),
              ),
            ),
          
          // Divider with better styling
          Container(
            margin: const EdgeInsets.only(top: 16),
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.grey.shade800.withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNestedCommentWidget(Comment comment) {
    return GestureDetector(
      onLongPress: () => _showCommentOptions(comment),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade900.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.grey.shade800.withOpacity(0.3),
            width: 0.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: CircleAvatar(
                radius: 14,
                backgroundImage: comment.avatarUrl.isNotEmpty
                    ? NetworkImage(comment.avatarUrl)
                    : null,
                backgroundColor: Colors.grey.shade700,
                child: comment.avatarUrl.isEmpty
                    ? const Icon(Icons.person, size: 14, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            
            // Comment content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Username and timestamp
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          comment.username,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          if (comment.isPosting) ...[
                            const SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            _formatTimestamp(comment.createdAt, isPosting: comment.isPosting),
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  
                  // Comment text or edit input
                  if (_editingCommentId == comment.id)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade900.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: AppTheme.primaryColor.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: TextField(
                              controller: _editController,
                              decoration: const InputDecoration(
                                hintText: 'Edit your reply...',
                                border: InputBorder.none,
                                hintStyle: TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                              maxLines: null,
                              autofocus: true,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: _cancelEdit,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: Size.zero,
                                ),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(color: Colors.grey, fontSize: 11),
                                ),
                              ),
                              const SizedBox(width: 6),
                              ElevatedButton(
                                onPressed: _submitEdit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  minimumSize: Size.zero,
                                ),
                                child: const Text(
                                  'Save',
                                  style: TextStyle(color: Colors.white, fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                      child: Text(
                        comment.content,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  
                  // Actions row
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    child: Row(
                      children: [
                        // Like button
                        GestureDetector(
                          onTap: () {
                            if (comment.isLikedByMe) {
                              ref.read(commentsProvider(widget.postId).notifier)
                                  .unlikeComment(comment.id);
                            } else {
                              ref.read(commentsProvider(widget.postId).notifier)
                                  .likeComment(comment.id);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  comment.isLikedByMe
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  size: 16,
                                  color: comment.isLikedByMe ? Colors.red.shade400 : Colors.grey.shade400,
                                ),
                                if (comment.likesCount > 0) ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    '${comment.likesCount}',
                                    style: TextStyle(
                                      color: comment.isLikedByMe ? Colors.red.shade400 : Colors.grey.shade400,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        
                        // Reply button (always show for Facebook-style)
                        GestureDetector(
                          onTap: () => _startReply(comment),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.reply,
                                  size: 16,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  'Reply',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        // Spacer to push buttons to the left
                        const Spacer(),
                      ],
                    ),
                  ),
                  
                  // No nested replies in Facebook-style
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp, {bool isPosting = false}) {
    // Show "Posting..." if comment is being posted
    if (isPosting) {
      return 'Posting...';
    }

    final now = DateTime.now();
    final difference = now.difference(timestamp);

    // Handle future timestamps (shouldn't happen but just in case)
    if (difference.isNegative) {
      return 'Just now';
    }

    // Less than 1 minute
    if (difference.inMinutes < 1) {
      return 'Just now';
    }
    
    // Less than 1 hour
    if (difference.inHours < 1) {
      final minutes = difference.inMinutes;
      return '${minutes}m ago';
    }
    
    // Less than 1 day
    if (difference.inDays < 1) {
      final hours = difference.inHours;
      return '${hours}h ago';
    }
    
    // Less than 7 days
    if (difference.inDays < 7) {
      final days = difference.inDays;
      return '${days}d ago';
    }
    
    // Less than 30 days
    if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '${weeks}w ago';
    }
    
    // Less than 365 days
    if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '${months}mo ago';
    }
    
    // More than 1 year
    final years = (difference.inDays / 365).floor();
    return '${years}y ago';
  }
} 