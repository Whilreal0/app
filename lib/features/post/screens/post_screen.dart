import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../../../core/services/post_service.dart';
import '../../../core/services/storage_service.dart';
import '../../home/models/post.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../home/providers/posts_provider.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/providers/bottom_nav_provider.dart';
import '../../../core/providers/auth_provider.dart';

class PostScreen extends ConsumerStatefulWidget {
  const PostScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends ConsumerState<PostScreen> {
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _captionController = TextEditingController();
  final StorageService _storageService = StorageService();
  File? _imageFile;
  Uint8List? _imageBytes;
  String? _imageFileName;
  bool _isLoading = false;

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final bool isWeb = kIsWeb;
      
      if (isWeb) {
        final XFile? pickedFile = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85,
        );
        
        if (pickedFile != null) {
          try {
            final bytes = await pickedFile.readAsBytes();
            final fileSize = bytes.length;
            final maxSize = 10 * 1024 * 1024;
            
            if (fileSize > maxSize) {
              if (mounted) {
                _scaffoldMessengerKey.currentState?.showSnackBar(
                  const SnackBar(
                    content: Text('Image too large. Please select an image smaller than 10MB.'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
              return;
            }
            
            setState(() {
              _imageFile = null;
              _imageBytes = bytes;
              _imageFileName = pickedFile.name;
            });
          } catch (e) {
            if (mounted) {
              _scaffoldMessengerKey.currentState?.showSnackBar(
                SnackBar(
                  content: Text('Error processing image: $e'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          }
        }
      } else {
        final ImageSource? source = await showDialog<ImageSource>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Select Image Source'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.photo_library),
                    title: const Text('Gallery'),
                    onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                  ),
                  ListTile(
                    leading: const Icon(Icons.camera_alt),
                    title: const Text('Camera'),
                    onTap: () => Navigator.of(context).pop(ImageSource.camera),
                  ),
                ],
              ),
            );
          },
        );
        
        if (source == null) return;
        
        final XFile? pickedFile = await picker.pickImage(
          source: source,
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85,
        );
        
        if (pickedFile != null) {
          final file = File(pickedFile.path);
          final fileSize = await file.length();
          final maxSize = 10 * 1024 * 1024;
          
          if (fileSize > maxSize) {
            if (mounted) {
              _scaffoldMessengerKey.currentState?.showSnackBar(
                const SnackBar(
                  content: Text('Image too large. Please select an image smaller than 10MB.'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 2),
                ),
              );
            }
            return;
          }
          
          setState(() {
            _imageFile = file;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('Error selecting image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _uploadImage(dynamic image) async {
    if (image is File) {
      return await _storageService.uploadPostImage(image);
    } else if (image is Uint8List && _imageFileName != null) {
      return await _storageService.uploadPostImageBytes(image, _imageFileName!);
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() { _isLoading = true; });
    
    String? imageUrl;
    if (_imageFile != null || _imageBytes != null) {
      if (kIsWeb && _imageBytes != null) {
        imageUrl = await _uploadImage(_imageBytes!);
      } else if (_imageFile != null) {
        imageUrl = await _uploadImage(_imageFile!);
      }
      
      if (imageUrl == null) {
        setState(() { _isLoading = false; });
        _scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('Image upload failed. Please try again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('User not logged in'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      setState(() { _isLoading = false; });
      return;
    }

    final userProfile = await Supabase.instance.client
        .from('profiles')
        .select('username')
        .eq('id', user.id)
        .single();

    final post = Post(
      id: const Uuid().v4(),
      userId: user.id,
      username: userProfile['username'] ?? '',
      avatarUrl: '',
      imageUrl: imageUrl ?? '',
      caption: _captionController.text,
      likesCount: 0,
      commentsCount: 0,
      createdAt: DateTime.now(), // This will be overridden by database
      isLikedByMe: false,
    );

    try {
      print('DEBUG: Starting post creation...');
      final createdPost = await PostService().addPost(post);
      print('DEBUG: Post created successfully: ${createdPost.id}');
      
      // Invalidate both the specific user's posts and the current user posts provider
      ref.invalidate(postsProvider(user.id));
      ref.invalidate(currentUserPostsProvider);
      print('DEBUG: Providers invalidated');

      // Show success snackbar
      _scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Post added'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );

      _captionController.clear();
      setState(() { 
        _imageFile = null; 
        _imageBytes = null;
        _imageFileName = null;
      });

      // Add delay so user can see the snackbar before navigation
      await Future.delayed(const Duration(milliseconds: 800));

      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(bottomNavProvider.notifier).state = 0;
        context.go('/home');
      });
    } catch (e) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Error creating post: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A1A),
        appBar: AppBar(
          title: const Text(
            'Create Post',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: const Color(0xFF232A36),
          elevation: 0,
          automaticallyImplyLeading: false,
          actions: [
            TextButton(
              onPressed: _isLoading ? null : _submit,
              child: _isLoading 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Post',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Status update bar
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.grey[800]!),
                  ),
                  child: Row(
                    children: [
                      // User avatar
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.grey[700],
                        child: const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // Text input field
                      Expanded(
                        child: TextFormField(
                          controller: _captionController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Post a status update',
                            hintStyle: TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                          validator: (value) {
                            if ((_imageFile == null) && (value == null || value.isEmpty)) {
                              return 'Enter a caption or pick an image';
                            }
                            return null;
                          },
                        ),
                      ),
                      
                      // Image attachment icon
                      IconButton(
                        onPressed: _pickImage,
                        icon: const Icon(
                          Icons.image_outlined,
                          color: Colors.grey,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                
                // Image preview (only show if image is selected)
                if (_imageFile != null || _imageBytes != null)
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.grey[800]!),
                    ),
                    child: Column(
                      children: [
                        // Image preview
                        Container(
                          height: 200,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(15),
                            ),
                            color: Colors.grey[900],
                          ),
                          child: Stack(
                            children: [
                              // Image
                              if (_imageFile != null)
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(15),
                                  ),
                                  child: Image.file(
                                    _imageFile!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                  ),
                                )
                              else if (_imageBytes != null)
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(15),
                                  ),
                                  child: Image.memory(
                                    _imageBytes!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                  ),
                                ),
                              
                              // Trash can icon overlay
                              Positioned(
                                top: 10,
                                right: 10,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _imageFile = null;
                                        _imageBytes = null;
                                        _imageFileName = null;
                                      });
                                    },
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    style: IconButton.styleFrom(
                                      padding: const EdgeInsets.all(8),
                                    ),
                                  ),
                                ),
                              ),
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
      ),
    );
  }
} 