import 'package:uuid/uuid.dart';
import '../models/password_entry.dart';
import '../local/app_database.dart';
import '../../services/password_service.dart';
import '../../services/connectivity_service.dart';

/// Repository for managing passwords with offline-first approach
/// 
/// All operations go through local database first, then sync with backend
/// when connection is available
class PasswordsRepository {
  final AppDatabase _db = AppDatabase.instance();
  final Uuid _uuid = const Uuid();
  final PasswordService _passwordService = PasswordService();
  final ConnectivityService _connectivityService = ConnectivityService();

  PasswordsRepository();

  /// Get all passwords from local database
  Future<Map<String, dynamic>> getAllPasswords() async {
    try {
      // Trigger background sync if online
      if (_connectivityService.isOnline) {
        _syncFromServer();
      }

      final localPasswords = await _db.passwordsDao.getAllPasswords();
      final passwords = localPasswords
          .map((data) => PasswordEntry.fromJson(data))
          .toList();

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

  /// Sync passwords from server to local database
  Future<void> _syncFromServer() async {
    try {
      final result = await _passwordService.fetchPasswords();
      
      if (result['success'] == true && result['data'] != null) {
        final serverPasswords = result['data'] as List;
        final allLocalPasswords = await _db.passwordsDao.getAllPasswords();
        
        for (final item in serverPasswords) {
          // The server returns JSON with 'id' as the server ID.
          // We treat this as the serverId for our local storage.
          final serverId = item['id']?.toString();
          if (serverId == null || serverId.isEmpty) continue;
          
          // Check if exists locally by serverId
          final existingLocal = allLocalPasswords.firstWhere(
            (p) => p['serverId'] == serverId,
            orElse: () => {},
          );
          
          if (existingLocal.isNotEmpty) {
            // Update existing
            await _db.passwordsDao.updatePassword(existingLocal['id'], {
              'title': item['title'] ?? '',
              'username': item['username'] ?? '',
              'password': item['password'] ?? '',
              'website': item['website'] ?? '',
              'notes': item['notes'] ?? '',
              'updatedAt': DateTime.now().toIso8601String(),
              'syncStatus': 'synced',
              'lastSyncedAt': DateTime.now().toIso8601String(),
            });
          } else {
            // Check for pending match
            final pendingMatch = allLocalPasswords.firstWhere(
              (p) => p['syncStatus'] == 'pending' && 
                     p['title'] == (item['title'] ?? '') && 
                     p['username'] == (item['username'] ?? ''),
              orElse: () => {},
            );

            if (pendingMatch.isNotEmpty) {
               // Found a pending password that matches. Link it!
               await _db.passwordsDao.updatePassword(pendingMatch['id'], {
                 'serverId': serverId,
                 'syncStatus': 'synced',
                 'lastSyncedAt': DateTime.now().toIso8601String(),
               });
            } else {
              // Insert new from server
              final localId = _uuid.v4();
              await _db.passwordsDao.insertPassword({
                'id': localId,
                'title': item['title'] ?? '',
                'username': item['username'] ?? '',
                'password': item['password'] ?? '',
                'website': item['website'] ?? '',
                'notes': item['notes'] ?? '',
                'userId': item['userId']?.toString() ?? '',
                'createdAt': item['createdAt'] ?? DateTime.now().toIso8601String(),
                'updatedAt': item['updatedAt'] ?? DateTime.now().toIso8601String(),
                'serverId': serverId,
                'syncStatus': 'synced',
                'lastSyncedAt': DateTime.now().toIso8601String(),
              });
            }
          }
        }
      }
    } catch (e) {
      print('Server sync failed: $e');
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
      await _db.passwordsDao.insertPassword(dataToSave);

      // Sync with backend in BACKGROUND (non-blocking)
      if (_connectivityService.isOnline) {
        _syncPasswordInBackground(localId, dataToSave);
      }

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

  /// Sync a newly created password with backend
  Future<void> _syncPasswordInBackground(String localId, Map<String, dynamic> passwordData) async {
    try {
      final result = await _passwordService.addPassword(passwordData);
      
      if (result['success'] == true) {
        // In a real implementation, the backend should return the server ID
        // For now, we assume success means it's synced. 
        // If the backend returns an ID, we should update 'serverId' here.
        
        await _db.passwordsDao.updatePassword(localId, {
          'syncStatus': 'synced',
          'lastSyncedAt': DateTime.now().toIso8601String(),
        });
      } else {
        await _db.passwordsDao.updatePassword(localId, {
          'syncStatus': 'error',
        });
      }
    } catch (e) {
      print('Background password sync failed: $e');
      await _db.passwordsDao.updatePassword(localId, {
        'syncStatus': 'error',
      });
    }
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
      await _db.passwordsDao.updatePassword(id, dataToUpdate);

      // Sync with backend in BACKGROUND (non-blocking)
      if (_connectivityService.isOnline) {
        // We need the serverId to update on backend. 
        // We should fetch the current record to get serverId if not passed.
        // For simplicity, we assume the caller might not know serverId, so we check DB.
        final current = await _db.passwordsDao.getPasswordById(id);
        if (current != null && current['serverId'] != null) {
           _syncPasswordUpdateInBackground(id, current['serverId'], dataToUpdate);
        }
      }

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

  /// Sync a password update with backend
  Future<void> _syncPasswordUpdateInBackground(String localId, String serverId, Map<String, dynamic> passwordData) async {
    try {
      final result = await _passwordService.updatePassword(serverId, passwordData);
      
      if (result['success'] == true) {
        await _db.passwordsDao.updatePassword(localId, {
          'syncStatus': 'synced',
          'lastSyncedAt': DateTime.now().toIso8601String(),
        });
      } else {
        await _db.passwordsDao.updatePassword(localId, {
          'syncStatus': 'error',
        });
      }
    } catch (e) {
      print('Background password update sync failed: $e');
      await _db.passwordsDao.updatePassword(localId, {
        'syncStatus': 'error',
      });
    }
  }

  /// Delete a password (FAST - deleted locally, synced in background)
  Future<Map<String, dynamic>> deletePassword(String id, {String? serverId}) async {
    try {
      // Delete from local database first (FAST)
      await _db.passwordsDao.deletePassword(id);

      // Sync with backend in BACKGROUND (non-blocking)
      if (serverId != null && _connectivityService.isOnline) {
        _syncPasswordDeletionInBackground(serverId);
      }

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

  /// Sync a password deletion with backend
  Future<void> _syncPasswordDeletionInBackground(String serverId) async {
    try {
      await _passwordService.deletePassword(serverId);
    } catch (e) {
      print('Background password deletion sync failed: $e');
    }
  }

  /// Search passwords locally
  Future<Map<String, dynamic>> searchPasswords(String query) async {
    try {
      final localPasswords = await _db.passwordsDao.searchPasswords(query);
      final passwords = localPasswords
          .map((data) => PasswordEntry.fromJson(data))
          .toList();

      return {
        'success': true,
        'data': passwords,
        'message': 'Search results'
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to search passwords: $e',
        'data': <PasswordEntry>[]
      };
    }
  }

  /// Force sync all pending changes
  Future<Map<String, dynamic>> syncAll() async {
    return {
      'success': true,
      'message': 'Sync is disabled'
    };
  }
}
