import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import 'package:flutter/foundation.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final authState = ref.watch(authStateProvider);
  
  return authState.when(
    data: (user) async {
      if (user == null) return null;
      final authService = ref.watch(authServiceProvider);
      return await authService.getUserProfile(user.id);
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthNotifier(authService);
});

final userIdProvider = Provider<String>((ref) {
  final authState = ref.watch(authStateProvider);
  
  return authState.when(
    data: (user) {
  if (user == null) throw Exception('User not logged in');
  return user.id;
    },
    loading: () => throw Exception('User not logged in'),
    error: (_, __) => throw Exception('User not logged in'),
  );
});

final authChangeNotifierProvider = Provider<AuthChangeNotifier>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthChangeNotifier(authService.authStateChanges);
});

class AuthState {
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;
  final String? success; // <-- Add this

  AuthState({
    this.isLoading = false,
    this.error,
    this.isAuthenticated = false,
    this.success, // <-- Add this
  });

  AuthState copyWith({
    bool? isLoading,
    String? error,
    bool? isAuthenticated,
    String? success, // <-- Add this
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      success: success ?? this.success, // <-- Add this
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(AuthState());

  void clearError() {
    state = state.copyWith(error: null);
  }

  void clearSuccess() {
    state = state.copyWith(success: null);
  }

  Future<void> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      await _authService.signIn(email, password);
      state = state.copyWith(isLoading: false, isAuthenticated: true);
    } catch (e) {
      String errorMessage = e.toString();
      if (errorMessage.contains('Invalid login credentials')) {
        errorMessage = 'Invalid login credentials';
      } else if (errorMessage.contains('Email not confirmed')) {
        errorMessage = 'Email not confirmed';
      } else if (errorMessage.contains('Too many requests')) {
        errorMessage = 'Too many requests';
      }
      state = state.copyWith(isLoading: false, error: errorMessage);
    }
  }

  Future<void> signUp(String email, String password, String fullname, String username) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final isAvailable = await _authService.isUsernameAvailable(username);
      if (!isAvailable) {
        throw Exception('Username already taken');
      }
      final response = await _authService.signUp(email, password, fullname, username);
      print('Sign up successful');
      state = state.copyWith(isLoading: false, error: null, success: 'Registration successful! Please check your email and confirm your account before signing in.');
    } catch (e) {
      print('Sign up error: $e');
      String errorMessage = e.toString();
      if (errorMessage.contains('Username already taken')) {
        errorMessage = 'This username is already taken. Please choose a different username.';
      } else if (errorMessage.contains('Email already taken')) {
        errorMessage = 'An account with this email already exists. Please sign in instead.';
      }
      state = state.copyWith(isLoading: false, error: errorMessage, success: null);
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    
    try {
      await _authService.signOut();
      state = state.copyWith(isLoading: false, isAuthenticated: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> isEmailAvailable(String email) async {
    return await _authService.isEmailAvailable(email);
  }

  Future<void> deleteAccount(String userId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _authService.deleteAccountWithEdgeFunction(userId);
      state = state.copyWith(isLoading: false, isAuthenticated: false, success: 'Account deleted');
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> updateProfile({
    required String userId,
    required String newUsername,
    required String newFullName,
    required String newEmail,
    String? newPassword,
  }) async {
    state = state.copyWith(isLoading: true, error: null, success: null);
    try {
      await _authService.updateProfile(
        userId: userId,
        newUsername: newUsername,
        newEmail: newEmail,
      );
      // TODO: Add password update logic if needed
      // Update full name in profiles
      await _authService.updateFullName(userId, newFullName);
      state = state.copyWith(isLoading: false, success: 'Profile updated successfully');
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

class AuthChangeNotifier extends ChangeNotifier {
  User? _user;
  AuthChangeNotifier(Stream<User?> authStream) {
    authStream.listen((user) {
      if (_user != user) {
        _user = user;
        notifyListeners();
      }
    });
  }
}

Future<bool> isEmailAvailable(String email) async {
  final response = await Supabase.instance.client
      .from('auth.users')
      .select('id')
      .eq('email', email)
      .maybeSingle();
  return response == null;
}