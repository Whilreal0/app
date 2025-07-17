import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../core/services/post_service.dart';
import '../../home/models/post.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PostScreen extends StatefulWidget {
  const PostScreen({Key? key}) : super(key: key);

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _captionController = TextEditingController();
  File? _imageFile;
  bool _isLoading = false;

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImage(File image) async {
    final storage = Supabase.instance.client.storage;
    final fileName = const Uuid().v4();
    final filePath = 'posts/$fileName.jpg';
    try {
      final String uploadedPath = await storage.from('post-images').upload(filePath, image);
      // If upload is successful, get the public URL
      final publicUrl = storage.from('post-images').getPublicUrl(filePath);
      return publicUrl;
    } catch (e) {
      // If upload fails, return null
      return null;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; });
    String? imageUrl;
    if (_imageFile != null) {
      imageUrl = await _uploadImage(_imageFile!);
      if (imageUrl == null) {
        setState(() { _isLoading = false; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image upload failed')));
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
      avatarUrl: '', // No avatar available, leave empty or use a default
      imageUrl: imageUrl ?? '',
      caption: _captionController.text,
      likesCount: 0,
      createdAt: DateTime.now(),
    );
    try {
      await PostService().addPost(post);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post added!')));
      _captionController.clear();
      setState(() { _imageFile = null; });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error:  ${e.toString()}')));
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Post')),
      body: Padding(
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