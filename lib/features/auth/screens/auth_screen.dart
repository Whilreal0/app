import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';
import '../widgets/auth_form.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

Future<void> signInWithUsernameOrEmail(String usernameOrEmail, String password) async {
  String email = usernameOrEmail;

  // If input does not contain '@', treat as username and look up email
  if (!usernameOrEmail.contains('@')) {
    final response = await supabase
        .from('profiles')
        .select('email')
        .eq('username', usernameOrEmail)
        .maybeSingle();

    if (response == null) {
      throw Exception('Username not found');
    }
    email = response['email'] as String;
  }

  final authResponse = await supabase.auth.signInWithPassword(
    email: email,
    password: password,
  );

  if (authResponse.user == null) {
    throw Exception('Login failed');
  }
}

Future<void> signInAndUpdateProfile(String email, String password, String username, String fullname) async {
  final response = await supabase.auth.signInWithPassword(email: email, password: password);
  final user = supabase.auth.currentUser;
  if (user != null) {
    await supabase.from('profiles').update({
      'username': username,
      'fullname': fullname,
    }).eq('id', user.id);
  }
}

class AuthScreen extends ConsumerWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Welcome',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sign in to continue',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 40),
                const AuthForm(),
                const SizedBox(height: 40),
                const DemoAccountsCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DemoAccountsCard extends StatelessWidget {
  const DemoAccountsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Demo Accounts:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            _buildDemoAccount('Superadmin', 'admin@demo.com', 'password123'),
            _buildDemoAccount('Moderator', 'mod@demo.com', 'password123'),
            _buildDemoAccount('User', 'user@demo.com', 'password123'),
          ],
        ),
      ),
    );
  }

  Widget _buildDemoAccount(String role, String email, String password) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        '$role: $email / $password',
        style: const TextStyle(
          fontSize: 12,
          color: Colors.grey,
        ),
      ),
    );
  }
}