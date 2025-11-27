/// Configuration for offline mode behavior
/// 
/// This allows you to control how the app behaves when backend is unavailable
class OfflineModeConfig {
  /// Disable automatic sync attempts (useful when backend is not available)
  /// Set to true to work completely offline without sync errors
  static const bool disableAutoSync = false;
  
  /// Retry attempts for failed syncs
  static const int maxSyncRetries = 3;
  
  /// Time to wait between sync retries (in seconds)
  static const int retryDelay = 60;
  
  /// Enable verbose sync logging
  static const bool verboseSyncLogs = true;
  
  /// Suppress sync error messages in UI
  /// If true, sync errors only appear in console, not in snackbars
  static const bool suppressSyncErrors = true;
}
