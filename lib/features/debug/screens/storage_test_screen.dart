import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/theme/app_theme.dart';

class StorageTestScreen extends ConsumerStatefulWidget {
  const StorageTestScreen({super.key});

  @override
  ConsumerState<StorageTestScreen> createState() => _StorageTestScreenState();
}

class _StorageTestScreenState extends ConsumerState<StorageTestScreen> {
  final StorageService _storageService = StorageService();
  bool _isTesting = false;
  String _testResult = '';

  Future<void> _testStorageConnection() async {
    setState(() {
      _isTesting = true;
      _testResult = 'Testing storage connection...\n';
    });

    try {
      final isConnected = await _storageService.testStorageConnection();
      
      setState(() {
        _testResult += isConnected 
          ? '✅ Storage connection successful!\n'
          : '❌ Storage connection failed!\n';
      });
    } catch (e) {
      setState(() {
        _testResult += '❌ Error testing storage: $e\n';
      });
    } finally {
      setState(() {
        _isTesting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Storage Test'),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Storage Configuration Test',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This will test if your Supabase storage is properly configured for image uploads.',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isTesting ? null : _testStorageConnection,
                      child: _isTesting 
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 8),
                              Text('Testing...'),
                            ],
                          )
                        : const Text('Test Storage Connection'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_testResult.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Test Results',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _testResult,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Troubleshooting Steps',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'If the test fails, follow these steps:',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1. Run the storage_setup.sql script in your Supabase SQL editor\n'
                      '2. Check that the "post-images" bucket exists in Storage\n'
                      '3. Verify RLS policies are enabled\n'
                      '4. Ensure your environment variables are correct\n'
                      '5. Check the console logs for detailed error messages',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 