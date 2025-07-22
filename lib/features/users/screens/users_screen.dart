import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';
import '../providers/users_provider.dart';
import '../widgets/user_card.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import '../../../shared/providers/bottom_nav_provider.dart';

class UsersScreen extends ConsumerWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(userProfileProvider);
    final usersAsync = ref.watch(usersNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            ref.read(bottomNavProvider.notifier).state = 0; // 0 = Home
            context.go('/');
          },
        ),
      ),
      body: userProfileAsync.when(
        data: (profile) {
          if (profile == null || !profile.canManageUsers()) {
            return const Center(
              child: Text(
                'Access Denied',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
            );
          }

          return usersAsync.when(
            data: (users) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Total count row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'Total: ${users.length}',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Search and filter row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Search bar (takes most space)
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: Consumer(
                                builder: (context, ref, _) {
                                  final usersNotifier = ref.read(usersNotifierProvider.notifier);
                                  final searchQuery = ref.watch(usersNotifierProvider.notifier).searchQuery;
                                  return TextField(
                                    decoration: InputDecoration(
                                      hintText: 'Search User',
                                      prefixIcon: Icon(Icons.search),
                                      filled: true,
                                      fillColor: Colors.white10,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                                    ),
                                    style: const TextStyle(color: Colors.white),
                                    onChanged: (value) => usersNotifier.setSearchQuery(value),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Filter dropdown
                          SizedBox(
                            height: 48,
                            child: Consumer(
                              builder: (context, ref, _) {
                                final usersNotifier = ref.read(usersNotifierProvider.notifier);
                                final dateFilter = ref.watch(usersNotifierProvider.notifier).dateFilter;
                                return DropdownButtonHideUnderline(
                                  child: DropdownButton2<DateFilter>(
                                    isExpanded: false,
                                    customButton: Container(
                                      height: 48,
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      decoration: BoxDecoration(
                                        color: Colors.white10,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            dateFilter == DateFilter.any
                                                ? 'ALL TIME'
                                                : dateFilter == DateFilter.last7days
                                                    ? 'LAST 7 DAYS'
                                                    : 'LAST 30 DAYS',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
                                        ],
                                      ),
                                    ),
                                    dropdownStyleData: DropdownStyleData(
                                      width: null, // This will make the menu the same width as the button
                                      decoration: BoxDecoration(
                                        color: AppTheme.surfaceColor,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      offset: const Offset(0, -8), // Try -8 or adjust as needed
                                    ),
                                    value: dateFilter,
                                    items: [
                                      
                                      DropdownMenuItem(
                                        value: DateFilter.any,
                                        child: Text('ALL TIME', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                                      ),
                                      DropdownMenuItem(
                                        value: DateFilter.last7days,
                                        child: Text('LAST 7 DAYS', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                                      ),
                                      DropdownMenuItem(
                                        value: DateFilter.last30days,
                                        child: Text('LAST 30 DAYS', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                                      ),
                                    ],
                                    onChanged: (filter) {
                                      if (filter != null) {
                                        usersNotifier.setDateFilter(filter);
                                      }
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: users.isEmpty
                      ? Center(
                          child: Text(
                            'No user found',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () async {
                            try {
                              await ref.read(usersNotifierProvider.notifier).refresh();
                            } catch (e) {
                              // Handle error silently
                            }
                          },
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: users.length,
                            itemBuilder: (context, index) {
                              final user = users[index];
                              final canEdit = profile.isSuperAdmin ||
                                  (profile.isAdmin && !user.isSuperAdmin);

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: UserCard(
                                  user: user,
                                  canEdit: canEdit,
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Text('Error: $error'),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error: $error'),
        ),
      ),
    );
  }
}