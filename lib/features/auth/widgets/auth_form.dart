import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

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
  String? _customError;
  Timer? _errorTimer;
  bool _isCheckingUsername = false;
  bool _isUsernameAvailable = true;
  Timer? _usernameCheckTimer;

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _fullnameController.dispose();
    _passwordController.dispose();
    _errorTimer?.cancel();
    _usernameCheckTimer?.cancel();
    super.dispose();
  }

  void _clearError() {
    _errorTimer?.cancel();
    setState(() {
      _customError = null;
    });
  }

  void _setErrorWithTimeout(String error) {
    _errorTimer?.cancel();
    setState(() {
      _customError = error;
    });
    
    _errorTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _customError = null;
        });
      }
    });
  }

  void _checkUsernameAvailability(String username) {
    _usernameCheckTimer?.cancel();
    
    if (username.isEmpty) {
      setState(() {
        _isCheckingUsername = false;
        _isUsernameAvailable = true;
      });
      return;
    }

    if (username.length < 5) {
      setState(() {
        _isCheckingUsername = false;
        _isUsernameAvailable = true; // Changed from false to true for short usernames
      });
      return;
    }

    setState(() {
      _isCheckingUsername = true;
    });

    _usernameCheckTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final authService = ref.read(authServiceProvider);
        final isAvailable = await authService.isUsernameAvailable(username);
        
        if (mounted) {
          setState(() {
            _isCheckingUsername = false;
            _isUsernameAvailable = isAvailable;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isCheckingUsername = false;
            _isUsernameAvailable = false;
          });
        }
      }
    });
  }

  String _getErrorMessage(String error) {
    if (error.contains('Invalid login credentials')) {
      return 'Invalid email/username or password. Please check your credentials and try again.';
    } else if (error.contains('Username not found')) {
      return 'Username not found. Please check your username or try signing in with your email.';
    } else if (error.contains('Email not confirmed')) {
      return 'Please check your email and confirm your account before signing in.';
    } else if (error.contains('Too many requests')) {
      return 'Too many login attempts. Please wait a moment before trying again.';
    } else if (error.contains('User already registered')) {
      return 'An account with this email already exists. Please sign in instead.';
    } else if (error.contains('Username already taken')) {
      return 'This username is already taken. Please choose a different username.';
    } else if (error.contains('Password should be at least')) {
      return 'Password must be at least 6 characters long.';
    } else if (error.contains('Username must be at least')) {
      return 'Username must be at least 5 characters long.';
    } else if (error.contains('Username must be 25 characters or less')) {
      return 'Username must be 25 characters or less.';
    } else if (error.contains('Invalid email')) {
      return 'Please enter a valid email address.';
    } else {
      return 'An error occurred. Please try again.';
    }
  }

  void _handleSubmit() async {
    _clearError();
    
    if (_formKey.currentState!.validate()) {
      final authNotifier = ref.read(authNotifierProvider.notifier);
      authNotifier.clearError(); // Clear any existing provider errors
      
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
          try {
            final response = await Supabase.instance.client
                .from('profiles')
                .select('email')
                .ilike('username', input) // case-insensitive
                .maybeSingle();

            if (response == null) {
              _setErrorWithTimeout('Username not found. Please check your username or try signing in with your email.');
              return;
            }
            email = response['email'] as String;
          } catch (e) {
            _setErrorWithTimeout('Unable to verify username. Please try again.');
            return;
          }
        }

        authNotifier.signIn(email, password);
      }
    }
  }

  Widget _buildErrorWidget(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFECACA),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFFEE2E2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline,
              color: Color(0xFFDC2626),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Authentication Error',
                  style: TextStyle(
                    color: Color(0xFF991B1B),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFF7F1D1D),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _clearError,
            icon: const Icon(
              Icons.close,
              color: Color(0xFFDC2626),
              size: 18,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 24,
              minHeight: 24,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    
    // Handle provider errors with timeout
    if (authState.error != null && _customError == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _setErrorWithTimeout(_getErrorMessage(authState.error!));
      });
    }
    
    final errorMessage = _customError;

    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Error message display
          if (errorMessage != null) ...[
            _buildErrorWidget(_getErrorMessage(errorMessage)),
          ],

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
              maxLength: 25,
              buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
              decoration: InputDecoration(
                labelText: 'Username',
                prefixIcon: const Icon(Icons.account_circle),
                suffixIcon: _isCheckingUsername
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _usernameController.text.isNotEmpty && _usernameController.text.length >= 5
                        ? Icon(
                            _isUsernameAvailable ? Icons.check_circle : Icons.error,
                            color: _isUsernameAvailable ? Colors.green : Colors.red,
                          )
                        : null,
                helperText: _usernameController.text.isNotEmpty && _usernameController.text.length >= 5 && !_isCheckingUsername
                    ? (_isUsernameAvailable ? 'Username is available' : 'Username is already taken')
                    : null,
                helperStyle: TextStyle(
                  color: _isUsernameAvailable ? Colors.green : Colors.red,
                ),
              ),
              onChanged: _checkUsernameAvailability,
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'Enter a username';
                }
                if (v.length < 5) {
                  return 'Username must be at least 5 characters';
                }
                if (v.length > 25) {
                  return 'Username must be 25 characters or less';
                }
                if (!_isUsernameAvailable && v.isNotEmpty && v.length >= 5) {
                  return 'Username is already taken';
                }
                return null;
              },
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
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: authState.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _isSignUp ? 'Sign Up' : 'Sign In',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              _clearError();
              setState(() => _isSignUp = !_isSignUp);
            },
            child: Text(
              _isSignUp
                  ? 'Already have an account? Sign In'
                  : "Don't have an account? Sign Up",
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}