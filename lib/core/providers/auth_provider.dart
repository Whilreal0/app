import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';

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

class AuthState {
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;

  AuthState({
    this.isLoading = false,
    this.error,
    this.isAuthenticated = false,
  });

  AuthState copyWith({
    bool? isLoading,
    String? error,
    bool? isAuthenticated,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(AuthState());

  void clearError() {
    state = state.copyWith(error: null);
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
      await _authService.signUp(email, password, fullname, username);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      String errorMessage = e.toString();
      if (errorMessage.contains('User already registered')) {
        errorMessage = 'User already registered';
      } else if (errorMessage.contains('Username already taken')) {
        errorMessage = 'Username already taken';
      } else if (errorMessage.contains('Password should be at least')) {
        errorMessage = 'Password should be at least 6 characters';
      } else if (errorMessage.contains('Invalid email')) {
        errorMessage = 'Invalid email';
      }
      state = state.copyWith(isLoading: false, error: errorMessage);
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
}