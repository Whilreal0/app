import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';
import '../../features/home/models/post.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Stream<User?> get authStateChanges => _supabase.auth.onAuthStateChange.map(
    (data) => data.session?.user,
  );

  User? get currentUser => _supabase.auth.currentUser;

  Future<void> signIn(String email, String password) async {
    final response = await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
    
    if (response.user == null) {
      throw Exception('Sign in failed');
    }
  }

  Future<bool> isUsernameAvailable(String username, {String? currentUserId}) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('id')
          .ilike('username', username)
          .maybeSingle();
      // If no user found, username is available
      if (response == null) return true;
      // If the only user with this username is the current user, it's available
      if (currentUserId != null && response['id'] == currentUserId) return true;
      // Otherwise, not available
      return false;
    } catch (e) {
      // If there's an error, assume username is not available
      return false;
    }
  }

  Future<bool> isEmailAvailable(String email, {String? currentUserId}) async {
    final response = await _supabase
        .from('profiles')
        .select('id')
        .eq('email', email)
        .maybeSingle();
    // If no user found, email is available
    if (response == null) return true;
    // If the only user with this email is the current user, it's available
    if (currentUserId != null && response['id'] == currentUserId) return true;
    // Otherwise, not available
    return false;
  }

  Future<void> signUp(String email, String password, String fullname, String username) async {
    // Check if username is already taken
    final isAvailable = await isUsernameAvailable(username);
    if (!isAvailable) {
      throw Exception('Username already taken');
    }

    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {
          'fullname': fullname,
          'username': username,
        },
      );

      final user = response.user;
      if (user == null) {
        throw Exception('Sign up failed');
      }

      await Supabase.instance.client
          .from('profiles')
          .update({
            'fullname': fullname,
            'username': username,
          })
          .eq('id', user.id);
    } on AuthException catch (e) {
      if (e.message.contains('User already registered') || e.message.contains('user_already_exists') || e.message.contains('Email address already exists')) {
        throw Exception('Email already taken');
      }
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('id, email, role, created_at, fullname, username, avatar_url')
          .eq('id', userId)
          .single();

      return UserProfile.fromJson(response);
    } catch (e) {
      // If profile doesn't exist, create one with default role
      if (e.toString().contains('PGRST116')) {
        final user = currentUser;
        if (user != null) {
          final newProfile = {
            'id': userId,
            'email': user.email,
            'role': 'user',
          };

          final response = await _supabase
              .from('profiles')
              .insert(newProfile)
              .select()
              .single();

          return UserProfile.fromJson(response);
        }
      }
      return null;
    }
  }

  Future<List<UserProfile>> getAllUsers() async {
    final response = await _supabase
        .from('profiles')
        .select()
        .order('created_at', ascending: false);

    return (response as List)
        .map((user) => UserProfile.fromJson(user))
        .toList();
  }

  Future<void> updateUserRole(String userId, String newRole) async {
    final response = await _supabase
        .from('profiles')
        .update({'role': newRole})
        .eq('id', userId)
        .select();

    // Supabase returns a List if successful, or throws if error. But if RLS blocks, it returns an empty list.
    if (response == null || (response is List && response.isEmpty)) {
      throw Exception('Failed to update role: You may not have permission or user not found.');
    }
  }

  Future<void> deleteAccountWithEdgeFunction(String userId) async {
    final response = await Supabase.instance.client.functions.invoke(
      'delete-user',
      body: {'user_id': userId},
    );
    // Check for error in response
    if (response.status != 200) {
      throw Exception('Failed to delete user: ${response.data}');
    }
    if (response.data != null && response.data is Map && response.data['error'] != null) {
      throw Exception('Failed to delete user: ${response.data['error']}');
    }
  }

  Future<void> updateProfile({
    required String userId,
    required String newUsername,
    required String newEmail,
  }) async {
    // Check if username is available
    final usernameAvailable = await isUsernameAvailable(newUsername, currentUserId: userId);
    if (!usernameAvailable) {
      throw Exception('Username already taken');
    }
    // Check if email is available
    final emailAvailable = await isEmailAvailable(newEmail, currentUserId: userId);
    if (!emailAvailable) {
      throw Exception('Email already taken');
    }
    // Update email in auth.users (current user only)
    final response = await _supabase.auth.updateUser(
      UserAttributes(email: newEmail),
    );
    if (response.user == null) {
      throw Exception('Failed to update email');
    }
    // Update username and email in profiles
    final profileResponse = await _supabase
        .from('profiles')
        .update({
          'username': newUsername,
          'email': newEmail,
        })
        .eq('id', userId)
        .select();
    if (profileResponse == null || (profileResponse is List && profileResponse.isEmpty)) {
      throw Exception('Failed to update profile');
    }
  }

  Future<void> updateFullName(String userId, String newFullName) async {
    final response = await _supabase
        .from('profiles')
        .update({'fullname': newFullName})
        .eq('id', userId)
        .select();
  }
}

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