import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:go_router/go_router.dart';

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
  bool _isEmailTaken = false;
  Timer? _emailCheckTimer;
  int _redirectCountdown = 5;
  Timer? _redirectTimer;
  bool _hasStartedRedirect = false;
  String? _lastSuccess;
  bool _showSuccess = false;

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _fullnameController.dispose();
    _passwordController.dispose();
    _errorTimer?.cancel();
    _usernameCheckTimer?.cancel();
    _emailCheckTimer?.cancel();
    _redirectTimer?.cancel();
    super.dispose();
  }

  void _clearError() {
    _errorTimer?.cancel();
    if (_customError != null) {
      setState(() {
        _customError = null;
      });
      // Also clear the provider error
      ref.read(authNotifierProvider.notifier).clearError();
    }
  }

  void _setErrorWithTimeout(String error) {
    _errorTimer?.cancel();
    setState(() {
      _customError = error;
    });

    _errorTimer = Timer(const Duration(seconds: 10), () { // <-- 10 seconds now
      if (mounted) {
        setState(() {
          _customError = null;
          // Clear input fields after error disappears
          if (_isSignUp) {
            _emailController.clear();
            _usernameController.clear();
            _fullnameController.clear();
            _passwordController.clear();
          } else {
            _emailOrUsernameController.clear();
            _passwordController.clear();
          }
        });
        // Clear the provider error as well!
        ref.read(authNotifierProvider.notifier).clearError();
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

  void _checkEmailAvailability(String email) {
    _emailCheckTimer?.cancel();
    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _isEmailTaken = false;
      });
      return;
    }
    _emailCheckTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final authNotifier = ref.read(authNotifierProvider.notifier);
        final isAvailable = await authNotifier.isEmailAvailable(email);
        if (mounted) {
          setState(() {
            _isEmailTaken = !isAvailable;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isEmailTaken = false;
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
    } else if (error.contains('Email already taken')) {
      return 'An account with this email already exists. Please sign in instead.';
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
          _passwordController.text.trim(), // Trim whitespace from password
          _fullnameController.text,
          _usernameController.text.trim(),
        );
      } else {
        // Username or email sign in logic
        String input = _emailOrUsernameController.text.trim();
        String password = _passwordController.text.trim(); // Trim whitespace from password

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

  Widget _buildSuccessWidget(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFBBF7D0),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFBBF7D0),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline,
              color: Color(0xFF22C55E),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF166534),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _formIsPristine =>
  _fullnameController.text.isEmpty &&
  _usernameController.text.isEmpty &&
  _emailController.text.isEmpty &&
  _passwordController.text.isEmpty;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    // Reset local state when a new registration is successful
    if (_isSignUp && authState.success != null && authState.success != _lastSuccess) {
      _lastSuccess = authState.success;
      _showSuccess = true; // Only show after real registration
      _hasStartedRedirect = false;
      _redirectCountdown = 5;
      _redirectTimer?.cancel();
      _redirectTimer = null;
    }

    // Start redirect timer only once per new success event
    if (_isSignUp && authState.success != null && !_hasStartedRedirect && _redirectTimer == null && _redirectCountdown == 5) {
      _hasStartedRedirect = true;
      _redirectTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() {
          _redirectCountdown--;
        });
        if (_redirectCountdown == 0) {
          timer.cancel();
          _redirectTimer = null;
          _hasStartedRedirect = false;
          _redirectCountdown = 5;
          ref.read(authNotifierProvider.notifier).clearSuccess();
          if (mounted) {
            setState(() {
              _isSignUp = false;
              _emailOrUsernameController.clear();
              _emailController.clear();
              _usernameController.clear();
              _fullnameController.clear();
              _passwordController.clear();
            });
            context.go('/auth');
          }
        }
      });
    }
    
    // Clear success state when switching to login form
    if (!_isSignUp && authState.success != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(authNotifierProvider.notifier).clearSuccess();
      });
    }
    
    // Handle provider errors with timeout
    if (authState.error != null && _customError == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _setErrorWithTimeout(_getErrorMessage(authState.error!));
        setState(() {
          _isEmailTaken = authState.error!.contains('Email already taken');
        });
      });
    }
    
    final errorMessage = _customError;

    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Success message display (only in sign up mode)
          if (_isSignUp && authState.success != null && authState.success == _lastSuccess && _showSuccess && !_formIsPristine) ...[
            _buildSuccessWidget(
              '${authState.success!}\nRedirecting to login in $_redirectCountdown seconds...'
            ),
          ],
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
              decoration: InputDecoration(
                labelText: 'Email',
                prefixIcon: const Icon(Icons.email),
                suffixIcon: _isEmailTaken
                    ? const Icon(Icons.error, color: Colors.red)
                    : null,
                helperText: _isEmailTaken
                    ? 'Email is already taken'
                    : null,
                helperStyle: const TextStyle(color: Colors.red),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email';
                }
                if (!value.contains('@')) {
                  return 'Please enter a valid email';
                }
                if (_isEmailTaken) {
                  return 'Email is already taken';
                }
                return null;
              },
              onChanged: (value) {
                _checkEmailAvailability(value);
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
              onChanged: (_) => _clearError(), // <-- Add this line
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
            onChanged: (_) => _clearError(), // <-- Add this line
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
              setState(() {
                _isSignUp = true;
                _showSuccess = false; // Hide success message on mode switch
                _hasStartedRedirect = false;
                _redirectCountdown = 5;
                _redirectTimer?.cancel();
                _redirectTimer = null;
                _lastSuccess = null;
                _emailOrUsernameController.clear();
                _emailController.clear();
                _usernameController.clear();
                _fullnameController.clear();
                _passwordController.clear();
              });
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ref.read(authNotifierProvider.notifier).clearSuccess();
              });
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