import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/post_report.dart';
import '../services/post_report_service.dart';

final postReportServiceProvider = Provider<PostReportService>((ref) {
  return PostReportService();
});

final postReportProvider = StateNotifierProvider<PostReportNotifier, AsyncValue<List<PostReport>>>((ref) {
  final service = ref.watch(postReportServiceProvider);
  return PostReportNotifier(service);
});

class PostReportNotifier extends StateNotifier<AsyncValue<List<PostReport>>> {
  final PostReportService _service;

  PostReportNotifier(this._service) : super(const AsyncValue.loading()) {
    loadReports();
  }

  Future<void> loadReports() async {
    try {
      state = const AsyncValue.loading();
      final reports = await _service.getReportedPosts();
      state = AsyncValue.data(reports);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> reportPost({
    required String postId,
    required String reporterId,
    required String postOwnerId,
    required String reason,
  }) async {
    try {
      await _service.reportPost(
        postId: postId,
        reporterId: reporterId,
        postOwnerId: postOwnerId,
        reason: reason,
      );
      // Refresh the reports list
      await loadReports();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> resolveReport({
    required String reportId,
    required String resolvedBy,
    required String resolution,
  }) async {
    try {
      await _service.resolveReport(
        reportId: reportId,
        resolvedBy: resolvedBy,
        resolution: resolution,
      );
      // Refresh the reports list
      await loadReports();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteReportedPost(String postId) async {
    try {
      await _service.deleteReportedPost(postId);
      // Refresh the reports list
      await loadReports();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> refresh() async {
    await loadReports();
  }
} 