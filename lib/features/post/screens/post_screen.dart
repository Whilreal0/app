import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../core/services/post_service.dart';
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
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _captionController = TextEditingController();
  File? _imageFile;
  bool _isLoading = false;

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      
      // Show source selection dialog
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
        maxWidth: 1920, // Limit image size for better performance
        maxHeight: 1920,
        imageQuality: 85, // Compress image
      );
      
      if (pickedFile != null) {
        final file = File(pickedFile.path);
        final fileSize = await file.length();
        final maxSize = 10 * 1024 * 1024; // 10MB limit
        
        if (fileSize > maxSize) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Image too large. Please select an image smaller than 10MB.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
        
        setState(() {
          _imageFile = file;
        });
        
        print('Image selected: ${pickedFile.path}');
        print('File size: ${fileSize} bytes');
      }
    } catch (e) {
      print('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _uploadImage(File image) async {
    try {
      final storage = Supabase.instance.client.storage;
      final fileName = const Uuid().v4();
      
      // Get file extension from the original file
      final fileExtension = image.path.split('.').last.toLowerCase();
      final validExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
      
      if (!validExtensions.contains(fileExtension)) {
        print('Invalid file extension: $fileExtension');
        return null;
      }
      
      final filePath = 'posts/$fileName.$fileExtension';
      
      print('Uploading image: $filePath');
      print('File size: ${await image.length()} bytes');
      
      // Upload the file
      final uploadedPath = await storage.from('post-images').upload(
        filePath, 
        image,
        fileOptions: const FileOptions(
          cacheControl: '3600',
          upsert: false,
        ),
      );
      
      print('Upload successful: $uploadedPath');
      
      // Get the public URL
      final publicUrl = storage.from('post-images').getPublicUrl(filePath);
      print('Public URL: $publicUrl');
      
      return publicUrl;
    } catch (e) {
      print('Error uploading image: $e');
      print('Error type: ${e.runtimeType}');
      
      // More specific error handling
      if (e.toString().contains('bucket')) {
        print('Storage bucket issue - check if "post-images" bucket exists');
      } else if (e.toString().contains('permission')) {
        print('Permission issue - check RLS policies');
      } else if (e.toString().contains('size')) {
        print('File size issue - image might be too large');
      }
      
      return null;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() { _isLoading = true; });
    
    String? imageUrl;
    if (_imageFile != null) {
      // Show upload progress
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Uploading image...'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      print('Starting image upload...');
      imageUrl = await _uploadImage(_imageFile!);
      
      if (imageUrl == null) {
        setState(() { _isLoading = false; });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image upload failed. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      print('Image upload successful: $imageUrl');
    }
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User not logged in')));
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
      avatarUrl: '', // No avatar available, leave empty or use a default
      imageUrl: imageUrl ?? '',
      caption: _captionController.text,
      likesCount: 0,
      commentsCount: 0,
      createdAt: DateTime.now(),
      isLikedByMe: false, // New post is not liked by the user
    );
    try {
      await PostService().addPost(post);

      // Refresh the posts provider to include the new post
      ref.invalidate(postsProvider(user.id));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post added!')),
      );

      _captionController.clear();
      setState(() { _imageFile = null; });

      // Schedule navigation for the next frame (most robust)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(bottomNavProvider.notifier).state = 0; // Set index to home
        context.go('/home'); // Always go to home
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error:  ${e.toString()}')),
      );
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Post')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _captionController,
                decoration: const InputDecoration(labelText: 'Caption'),
                validator: (value) {
                  if ((_imageFile == null) && (value == null || value.isEmpty)) {
                    return 'Enter a caption or pick an image';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _imageFile != null
                  ? Image.file(_imageFile!, height: 200)
                  : const SizedBox(height: 200, child: Center(child: Text('No image selected'))),
              TextButton.icon(
                icon: const Icon(Icons.image),
                label: const Text('Pick Image'),
                onPressed: _pickImage,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading ? const CircularProgressIndicator() : const Text('Add Post'),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 