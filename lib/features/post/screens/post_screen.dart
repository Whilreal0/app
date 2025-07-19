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
              _imageFile = null;
              _imageBytes = bytes;
              _imageFileName = pickedFile.name;
            });
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error processing image: $e'),
                  backgroundColor: Colors.red,
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
        }
      }
    } catch (e) {
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Uploading image...'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      if (kIsWeb && _imageBytes != null) {
        imageUrl = await _uploadImage(_imageBytes!);
      } else if (_imageFile != null) {
        imageUrl = await _uploadImage(_imageFile!);
      }
      
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
      avatarUrl: '',
      imageUrl: imageUrl ?? '',
      caption: _captionController.text,
      likesCount: 0,
      commentsCount: 0,
      createdAt: DateTime.now(),
      isLikedByMe: false,
    );

    try {
      await PostService().addPost(post);
      ref.invalidate(postsProvider(user.id));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post added!')),
      );

      _captionController.clear();
      setState(() { 
        _imageFile = null; 
        _imageBytes = null;
        _imageFileName = null;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(bottomNavProvider.notifier).state = 0;
        context.go('/home');
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
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
                  : _imageBytes != null
                      ? Image.memory(_imageBytes!, height: 200)
                      : const SizedBox(height: 200, child: Center(child: Text('No image selected'))),
              TextButton.icon(
                icon: const Icon(Icons.image),
                label: Text(kIsWeb ? 'Select Image' : 'Pick Image'),
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