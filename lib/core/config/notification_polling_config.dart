// Configuration for notification polling intervals
class NotificationPollingConfig {
  static const Duration defaultPollingInterval = Duration(seconds: 120); // 2 minutes
  static const Duration fastPollingInterval = Duration(seconds: 60); // 1 minute for active screens
  static const Duration slowPollingInterval = Duration(seconds: 300); // 5 minutes for background
} 