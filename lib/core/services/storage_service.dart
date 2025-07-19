import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Test if storage is properly configured
  Future<bool> testStorageConnection() async {
    try {
      final user = _supabase.auth.currentUser;
      
      if (user == null) {
        return false;
      }
      
      final buckets = await _supabase.storage.listBuckets();
      final postImagesBucket = buckets.where((b) => b.id == 'post-images').firstOrNull;
      
      return postImagesBucket != null;
    } catch (e) {
      return false;
    }
  }

  /// Upload an image to the post-images bucket
  Future<String?> uploadPostImage(File imageFile) async {
    try {
      final isConnected = await testStorageConnection();
      if (!isConnected) {
        return null;
      }

      if (!await imageFile.exists()) {
        return null;
      }

      final fileName = const Uuid().v4();
      
      String fileExtension = 'jpg';
      final path = imageFile.path.toLowerCase();
      if (path.endsWith('.jpg') || path.endsWith('.jpeg')) {
        fileExtension = 'jpg';
      } else if (path.endsWith('.png')) {
        fileExtension = 'png';
      } else if (path.endsWith('.gif')) {
        fileExtension = 'gif';
      } else if (path.endsWith('.webp')) {
        fileExtension = 'webp';
      }
      
      final validExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
      if (!validExtensions.contains(fileExtension)) {
        return null;
      }
      
      final filePath = 'posts/$fileName.$fileExtension';
      final fileSize = await imageFile.length();
      
      if (fileSize == 0 || fileSize > 10 * 1024 * 1024) {
        return null;
      }
      
      await _supabase.storage.from('post-images').upload(
        filePath, 
        imageFile,
        fileOptions: const FileOptions(
          cacheControl: '3600',
          upsert: false,
        ),
      );
      
      return _supabase.storage.from('post-images').getPublicUrl(filePath);
    } catch (e) {
      return null;
    }
  }

  /// Upload image bytes (for web platform)
  Future<String?> uploadPostImageBytes(Uint8List imageBytes, String fileName) async {
    try {
      final isConnected = await testStorageConnection();
      if (!isConnected) {
        return null;
      }

      final uuid = const Uuid().v4();
      final fileExtension = fileName.split('.').last.toLowerCase();
      final validExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
      
      if (!validExtensions.contains(fileExtension)) {
        return null;
      }
      
      final filePath = 'posts/$uuid.$fileExtension';
      final fileSize = imageBytes.length;
      
      if (fileSize == 0 || fileSize > 10 * 1024 * 1024) {
        return null;
      }
      
      await _supabase.storage.from('post-images').uploadBinary(
        filePath, 
        imageBytes,
        fileOptions: const FileOptions(
          cacheControl: '3600',
          upsert: false,
        ),
      );
      
      return _supabase.storage.from('post-images').getPublicUrl(filePath);
    } catch (e) {
      return null;
    }
  }

  /// Delete an image from storage
  Future<bool> deletePostImage(String imageUrl) async {
    try {
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;
      
      final bucketIndex = pathSegments.indexOf('post-images');
      if (bucketIndex == -1 || bucketIndex == pathSegments.length - 1) {
        return false;
      }
      
      final filePath = pathSegments.sublist(bucketIndex + 1).join('/');
      await _supabase.storage.from('post-images').remove([filePath]);
      
      return true;
    } catch (e) {
      return false;
    }
  }
} 