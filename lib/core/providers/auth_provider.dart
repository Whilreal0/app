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
      final isAvailable = await _authService.isUsernameAvailable(username);
      if (!isAvailable) {
        throw Exception('Username already taken');
      }
      final response = await _authService.signUp(email, password, fullname, username);
      print('Sign up successful');
      state = state.copyWith(isLoading: false, error: 'Registration successful! Please check your email and confirm your account before signing in.');
    } catch (e) {
      print('Sign up error: $e');
      String errorMessage = e.toString();
      if (errorMessage.contains('Invalid login credentials')) {
        errorMessage = 'Invalid login credentials';
      } else if (errorMessage.contains('Email not confirmed')) {
        errorMessage = 'Email not confirmed';
      } else if (errorMessage.contains('Too many requests')) {
        errorMessage = 'Too many requests';
      } else if (errorMessage.contains('Email confirmation required')) {
        errorMessage = 'Registration successful! Please check your email and confirm your account before signing in.';
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