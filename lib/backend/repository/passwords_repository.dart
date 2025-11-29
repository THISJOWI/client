import 'package:uuid/uuid.dart';
import '../models/password_entry.dart';
import '../service/database_service.dart';
import '../service/connectivity_service.dart';
import '../service/sync_service.dart';
import '../../services/password_service.dart';

/// Repository for managing passwords with offline-first approach
/// 
/// All operations go through local database first, then sync with backend
/// when connection is available
class PasswordsRepository {
  final DatabaseService _dbService = DatabaseService();
  final ConnectivityService _connectivityService = ConnectivityService();
  final SyncService _syncService = SyncService();
  final PasswordService _passwordService;
  final Uuid _uuid = const Uuid();

  PasswordsRepository(this._passwordService);

  /// Get all passwords from local database
  Future<Map<String, dynamic>> getAllPasswords() async {
    try {
      final localPasswords = await _dbService.getAllPasswords();
      final passwords = localPasswords
          .map((data) => PasswordEntry.fromJson(data))
          .toList();

      // Trigger background sync if online
      if (_connectivityService.isOnline) {
        _syncService.syncPasswords();
      }

      return {
        'success': true,
        'data': passwords,
        'message': 'Passwords loaded from local storage'
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to load passwords: $e',
        'data': <PasswordEntry>[]
      };
    }
  }

  /// Create a new password (FAST - saved locally, synced in background)
  Future<Map<String, dynamic>> addPassword(
    Map<String, dynamic> passwordData,
  ) async {
    try {
      final localId = _uuid.v4();
      final now = DateTime.now();

      final dataToSave = {
        'id': localId,
        'title': passwordData['title'] ?? '',
        'username': passwordData['username'] ?? '',
        'password': passwordData['password'] ?? '',
        'website': passwordData['website'] ?? '',
        'notes': passwordData['notes'] ?? '',
        'userId': passwordData['userId'] ?? '',
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
        'syncStatus': 'pending',
      };

      // Save to local database first (FAST)
      await _dbService.insertPassword(dataToSave);

      // Sync with backend in BACKGROUND (non-blocking)
      _syncPasswordInBackground(localId, passwordData);

      return {
        'success': true,
        'data': {'id': localId},
        'message': 'Password created successfully'
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to create password: $e'
      };
    }
  }

  /// Sync password creation with backend in background
  void _syncPasswordInBackground(String localId, Map<String, dynamic> passwordData) {
    Future(() async {
      if (!_connectivityService.isOnline) {
        print('🔐 Password queued for sync: $localId');
        return;
      }

      try {
        final result = await _passwordService.addPassword(passwordData);
        if (result['success']) {
          await _dbService.updatePasswordSyncStatus(localId, 'synced');
          print('✅ Password synced: $localId');
        } else {
          print('⚠️ Password sync failed, will retry: $localId');
        }
      } catch (e) {
        print('❌ Password sync error: $localId - $e');
      }
    });
  }

  /// Update a password (FAST - saved locally, synced in background)
  Future<Map<String, dynamic>> updatePassword(
    String id,
    Map<String, dynamic> passwordData,
  ) async {
    try {
      final now = DateTime.now();

      final dataToUpdate = {
        'title': passwordData['title'],
        'username': passwordData['username'],
        'password': passwordData['password'],
        'website': passwordData['website'] ?? '',
        'notes': passwordData['notes'] ?? '',
        'updatedAt': now.toIso8601String(),
        'syncStatus': 'pending',
      };

      // Update in local database first (FAST)
      await _dbService.updatePassword(id, dataToUpdate);

      // Sync with backend in BACKGROUND (non-blocking)
      _syncPasswordUpdateInBackground(id, passwordData);

      return {
        'success': true,
        'message': 'Password updated successfully'
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to update password: $e'
      };
    }
  }

  /// Sync password update with backend in background
  void _syncPasswordUpdateInBackground(String id, Map<String, dynamic> passwordData) {
    Future(() async {
      final localPassword = await _dbService.getPasswordById(id);
      final serverId = localPassword?['serverId'] as String?;

      if (!_connectivityService.isOnline || serverId == null) {
        print('🔐 Password update queued: $id');
        return;
      }

      try {
        final result = await _passwordService.updatePassword(serverId, passwordData);
        if (result['success']) {
          await _dbService.updatePasswordSyncStatus(id, 'synced', serverId: serverId);
          print('✅ Password update synced: $id');
        } else {
          print('⚠️ Password update sync failed: $id');
        }
      } catch (e) {
        print('❌ Password update sync error: $id - $e');
      }
    });
  }

  /// Delete a password (FAST - deleted locally, synced in background)
  Future<Map<String, dynamic>> deletePassword(String id) async {
    try {
      // Get the password to find server ID before deleting
      final localPassword = await _dbService.getPasswordById(id);
      final serverId = localPassword?['serverId'] as String?;

      // Delete from local database first (FAST)
      await _dbService.deletePassword(id);

      // Sync deletion with backend in BACKGROUND (non-blocking)
      _syncPasswordDeletionInBackground(id, serverId);

      return {
        'success': true,
        'message': 'Password deleted successfully'
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to delete password: $e'
      };
    }
  }

  /// Sync password deletion with backend in background
  void _syncPasswordDeletionInBackground(String localId, String? serverId) {
    Future(() async {
      if (serverId == null) return;

      if (!_connectivityService.isOnline) {
        // Queue for later deletion
        await _dbService.addToSyncQueue(
          entityType: 'password',
          entityId: serverId,
          action: 'delete',
        );
        print('🔐 Password deletion queued: $localId');
        return;
      }

      try {
        await _passwordService.deletePassword(serverId);
        print('✅ Password deletion synced: $localId');
      } catch (e) {
        // Queue for retry
        await _dbService.addToSyncQueue(
          entityType: 'password',
          entityId: serverId,
          action: 'delete',
        );
        print('❌ Password deletion failed, queued: $localId - $e');
      }
    });
  }

  /// Force sync with backend
  Future<Map<String, dynamic>> forceSync() async {
    if (!_connectivityService.isOnline) {
      return {
        'success': false,
        'message': 'No internet connection available'
      };
    }

    return await _syncService.syncPasswords();
  }

  /// Get sync status
  Future<Map<String, dynamic>> getSyncStatus() async {
    try {
      final unsyncedPasswords = await _dbService.getUnsyncedPasswords();
      return {
        'success': true,
        'pendingSync': unsyncedPasswords.length,
        'isOnline': _connectivityService.isOnline,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to get sync status: $e'
      };
    }
  }
}
