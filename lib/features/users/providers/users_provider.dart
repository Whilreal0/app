import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/providers/auth_provider.dart';

enum DateFilter {
  any,
  last7days,
  last30days,
  custom,
}

final usersProvider = FutureProvider<List<UserProfile>>((ref) async {
  final authService = ref.watch(authServiceProvider);
  return await authService.getAllUsers();
});

final usersNotifierProvider = StateNotifierProvider<UsersNotifier, AsyncValue<List<UserProfile>>>((ref) {
  final authService = ref.watch(authServiceProvider);
  return UsersNotifier(authService);
});

class UsersNotifier extends StateNotifier<AsyncValue<List<UserProfile>>> {
  final dynamic _authService;
  List<UserProfile> _allUsers = [];
  String _searchQuery = '';
  DateFilter _dateFilter = DateFilter.any;
  DateTimeRange? _customRange;

  UsersNotifier(this._authService) : super(const AsyncValue.loading()) {
    loadUsers();
  }

  String get searchQuery => _searchQuery;
  DateFilter get dateFilter => _dateFilter;
  DateTimeRange? get customRange => _customRange;

  Future<void> loadUsers() async {
    try {
      state = const AsyncValue.loading();
      _allUsers = await _authService.getAllUsers();
      _applyFilters();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _applyFilters();
  }

  void setDateFilter(DateFilter filter, {DateTimeRange? customRange}) {
    _dateFilter = filter;
    _customRange = customRange;
    _applyFilters();
  }

  void _applyFilters() {
    List<UserProfile> filtered = _allUsers;
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((u) =>
        (u.email.toLowerCase().contains(query)) ||
        (u.username != null && u.username!.toLowerCase().contains(query)) ||
        (u.fullName != null && u.fullName!.toLowerCase().contains(query))
      ).toList();
    }
    final now = DateTime.now();
    if (_dateFilter == DateFilter.last7days) {
      filtered = filtered.where((u) => u.createdAt.isAfter(now.subtract(const Duration(days: 7)))).toList();
    } else if (_dateFilter == DateFilter.last30days) {
      filtered = filtered.where((u) => u.createdAt.isAfter(now.subtract(const Duration(days: 30)))).toList();
    } else if (_dateFilter == DateFilter.custom && _customRange != null) {
      filtered = filtered.where((u) => u.createdAt.isAfter(_customRange!.start) && u.createdAt.isBefore(_customRange!.end)).toList();
    }
    state = AsyncValue.data(filtered);
  }

  Future<void> updateUserRole(String userId, String newRole) async {
    try {
      await _authService.updateUserRole(userId, newRole);
      await loadUsers(); // Refresh the list so UI updates
    } catch (e) {
      // Handle error
      rethrow;
    }
  }

  // Refresh users
  Future<void> refresh() async {
    await loadUsers();
  }
}