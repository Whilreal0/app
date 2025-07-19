// Configuration for notification polling intervals
class NotificationPollingConfig {
  static const Duration defaultPollingInterval = Duration(seconds: 10); // 10 seconds for fallback
  static const Duration fastPollingInterval = Duration(seconds: 5); // 5 seconds for active screens
  static const Duration slowPollingInterval = Duration(seconds: 30); // 30 seconds for background
  static const Duration realtimePollingInterval = Duration(seconds: 3); // 3 seconds for real-time feel
} 