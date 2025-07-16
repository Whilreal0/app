import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthForm extends ConsumerStatefulWidget {
  const AuthForm({super.key});

  @override
  ConsumerState<AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends ConsumerState<AuthForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailOrUsernameController = TextEditingController(); // For sign in
  final _emailController = TextEditingController();           // For sign up
  final _usernameController = TextEditingController();        // For sign up
  final _fullnameController = TextEditingController();        // For sign up
  final _passwordController = TextEditingController();
  bool _isSignUp = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _fullnameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleSubmit() async {
    if (_formKey.currentState!.validate()) {
      final authNotifier = ref.read(authNotifierProvider.notifier);
      
      if (_isSignUp) {
        authNotifier.signUp(
          _emailController.text,
          _passwordController.text,
          _fullnameController.text,
          _usernameController.text,
        );
      } else {
        // Username or email sign in logic
        String input = _emailOrUsernameController.text.trim();
        String password = _passwordController.text;

        String email = input;
        if (!input.contains('@')) {
          print('Looking up email for username: "$input"');
          final response = await Supabase.instance.client
              .from('profiles')
              .select('email')
              .ilike('username', input) // case-insensitive
              .maybeSingle();

          print('Lookup result: $response');

          if (response == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Username not found')),
            );
            return;
          }
          email = response['email'] as String;
        }

        print('Attempting login with email: "$email" and password: "$password"');
        authNotifier.signIn(email, password);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    return Form(
      key: _formKey,
      child: Column(
        children: [
          if (_isSignUp) ...[
            // Full Name
            TextFormField(
              controller: _fullnameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Enter your full name' : null,
            ),
            const SizedBox(height: 16),

            // Username
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                prefixIcon: Icon(Icons.account_circle),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Enter a username' : null,
            ),
            const SizedBox(height: 16),

            // Email (Sign Up only)
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email';
                }
                if (!value.contains('@')) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
          ] else ...[
            // Email or Username (Sign In only)
            TextFormField(
              controller: _emailOrUsernameController,
              decoration: const InputDecoration(
                labelText: 'Email or Username',
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email or username';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
          ],

          // Password (for both)
          TextFormField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            obscureText: _obscurePassword,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: authState.isLoading ? null : _handleSubmit,
              child: authState.isLoading
                  ? const CircularProgressIndicator()
                  : Text(_isSignUp ? 'Sign Up' : 'Sign In'),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => setState(() => _isSignUp = !_isSignUp),
            child: Text(
              _isSignUp
                  ? 'Already have an account? Sign In'
                  : "Don't have an account? Sign Up",
            ),
          ),
        ],
      ),
    );
  }
}