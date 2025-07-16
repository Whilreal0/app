// lib/features/auth/screens/register_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:project/features/auth/screens/register_screen.dart';
// ...Paste the RegisterScreen code here...// Example: In your login screen or auth_screen.dart

TextButton(
  onPressed: () {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  },
  child: const Text('Don\'t have an account? Register'),
)