import 'package:shared_preferences/shared_preferences.dart';
import '../backend/service/database_service.dart';
import '../backend/service/secure_storage_service.dart';
import '../backend/service/sync_service.dart';

/// Helper service to manage user logout
/// 
/// Handles:
/// - Clearing local database
/// - Clearing secure storage
/// - Clearing authentication tokens
/// - Stopping sync service
class LogoutService {
  static final LogoutService _instance = LogoutService._internal();
  
  factory LogoutService() => _instance;
  
  LogoutService._internal();

  /// Perform complete logout
  /// 
  /// This will:
  /// 1. Stop sync service
  /// 2. Clear all local data
  /// 3. Clear authentication tokens
  /// 4. Clear encryption keys
  /// 5. Close database connection
  Future<void> logout() async {
    try {
      // 1. Stop sync service
      final syncService = SyncService();
      syncService.dispose();

      // 2. Clear local database
      final dbService = DatabaseService();
      await dbService.clearAllData();
      await dbService.close();

      // 3. Clear authentication tokens
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
      await prefs.remove('email');

      // 4. Clear secure storage (encryption keys)
      final secureStorage = SecureStorageService();
      await secureStorage.clearSecureData();

      print('✅ Logout completed successfully');
    } catch (e) {
      print('⚠️ Error during logout: $e');
      rethrow;
    }
  }

  /// Logout without clearing encryption key
  /// 
  /// Use this if you want to keep the database for the next login
  /// of the same user
  Future<void> logoutKeepDatabase() async {
    try {
      // Stop sync service
      final syncService = SyncService();
      syncService.dispose();

      // Clear authentication tokens only
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
      await prefs.remove('email');

      print('✅ Logout completed (database kept)');
    } catch (e) {
      print('⚠️ Error during logout: $e');
      rethrow;
    }
  }
}
