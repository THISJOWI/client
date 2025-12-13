import 'package:crypto/crypto.dart';
import 'package:i18n_extension/default.i18n.dart';
import 'dart:convert';
import '../../services/auth_service.dart';
import '../local/app_database.dart';
import '../../services/connectivity_service.dart';
import '../local/secure_storage_service.dart';

/// Repository for authentication that supports offline mode.
///
/// Flow (Offline-First):
/// - Login: ALWAYS verify against local cache first, then sync with backend if online
/// - Register: Save locally first, then sync with backend if online
/// - All operations pass through local database before hitting the backend
class AuthRepository {
  final AuthService _authService;
  final AppDatabase _db = AppDatabase.instance();
  final ConnectivityService _connectivityService;
  final SecureStorageService _secureStorageService;

  AuthRepository({
    required AuthService authService,
    required ConnectivityService connectivityService,
    required SecureStorageService secureStorageService,
  })  : _authService = authService,
        _connectivityService = connectivityService,
        _secureStorageService = secureStorageService;

  /// Login with offline-first support.
  Future<Map<String, dynamic>> login(String email, String password) async {
    final isOnline = _connectivityService.isOnline;

    // Step 1: ALWAYS check local cache first
    final cachedUser = await _db.authDao.getUserByEmail(email);
    
    if (cachedUser != null) {
      // User exists in local cache
      final passwordHash = _hashPassword(password);
      
      if (cachedUser.passwordHash == passwordHash) {
        // Valid credentials in cache
        final token = cachedUser.token;
        
        // Restore token to SharedPreferences
        if (token != null) {
          await _secureStorageService.saveValue('cached_token', token);
          await _secureStorageService.saveValue('cached_email', email);
        }
        
        // Update last login timestamp in local DB
        await _db.authDao.updateLastLogin(email, DateTime.now().toIso8601String());
        
        // If online, sync with backend in background (don't block UI)
        if (isOnline) {
          _syncLoginWithBackend(email, password, token);
        }
        
        return {
          'success': true,
          'data': {'token': token, 'offline': !isOnline},
          'message': isOnline ? 'Logged in successfully' : 'Logged in offline mode',
        };
      } else if (!isOnline) {
        // Invalid password and offline
        return {
          'success': false,
          'message': 'Invalid credentials',
        };
      }
      // If online and password mismatch, fall through to backend login
    }
    
    // No cached credentials OR local password mismatch + online
    // Need backend
    if (!isOnline) {
      return {
        'success': false,
        'message': 'No internet connection. You need to login online at least once.',
      };
    }
    
    // Try backend login
    try {
      final result = await _authService.login(email, password);
      
      if (result['success'] == true) {
        // Cache credentials for future offline use
        await _cacheUserCredentials(email, password, result['data']?['token']);
      }
      
      return result;
    } catch (e) {
      return {
        'success': false,
        'message': 'Login failed: $e',
      };
    }
  }

  /// Register with offline-first support.
  Future<Map<String, dynamic>> register(String email, String username, String password) async {
    // Step 1: Check if user already exists locally
    final existingUser = await _db.authDao.getUserByEmail(email);
    if (existingUser != null) {
      return {
        'success': false,
        'message': 'This user already exists. Please sign in.'.i18n,
      };
    }

    // Step 2: Check if registration is already queued
    final isQueued = await _db.syncQueueDao.isQueued('registration', email);
    if (isQueued) {
      return {
        'success': false,
        'message': 'This user is already in the sync queue. Please wait for it to complete.',
      };
    }

    // Step 3: ALWAYS save to local database first (FAST)
    final token = 'local_temp_token_${DateTime.now().millisecondsSinceEpoch}';
    await _cacheUserCredentials(email, password, token);
    
    // Save token for immediate use
    await _secureStorageService.saveValue('cached_token', token);
    await _secureStorageService.saveValue('cached_email', email);

    // Step 4: Sync with backend in BACKGROUND (non-blocking)
    _syncRegistrationInBackground(email, username, password);

    // Return success immediately - user can start using the app
    return {
      'success': true,
      'message': 'Account created successfully',
      'data': {'token': token},
    };
  }

  /// Sync registration with backend in background (non-blocking)
  void _syncRegistrationInBackground(String email, String username, String password) {
    // Fire and forget - don't await
    Future(() async {
      final isOnline = _connectivityService.isOnline;
      
      if (!isOnline) {
        // Queue for later sync when connection is restored
        await _queueRegistration(email, username, password);
        print('📝 Registration queued for later sync: $email');
        return;
      }

      try {
        final result = await _authService.register(email, username, password);
        
        if (result['success'] == true) {
          // Backend registration successful - update with real token
          if (result['data']?['token'] != null) {
            await _cacheUserCredentials(email, password, result['data']['token']);
            await _secureStorageService.saveValue('cached_token', result['data']['token']);
          }
          // Remove from sync queue if it was queued
          await _db.syncQueueDao.removeItem('registration', email);
          print('✅ Registration synced successfully: $email');
        } else {
          // Backend registration failed - queue for retry
          await _queueRegistration(email, username, password);
          print('⚠️ Registration queued for retry: $email - ${result['message']}');
        }
      } catch (e) {
        // Network error - queue for retry
        await _queueRegistration(email, username, password);
        print('❌ Registration sync failed, queued for retry: $email - $e');
      }
    });
  }

  /// Logout and optionally clear cached credentials.
  Future<void> logout({bool clearCache = false}) async {
    await _authService.logout();
    await _secureStorageService.deleteValue('cached_token');
    await _secureStorageService.deleteValue('cached_email');
    
    if (clearCache) {
      await _clearCachedCredentials();
    }
  }

  /// Change password with offline-first support.
  Future<Map<String, dynamic>> changePassword(String currentPassword, String newPassword) async {
    // Get the current user email
    final email = await _secureStorageService.getValue('cached_email');
    if (email == null) {
      return {
        'success': false,
        'message': 'No user session found. Please login again.',
      };
    }

    // Verify current password
    final cachedUser = await _db.authDao.getUserByEmail(email);
    if (cachedUser == null) {
      return {
        'success': false,
        'message': 'User not found in local cache.',
      };
    }

    final currentPasswordHash = _hashPassword(currentPassword);
    if (cachedUser.passwordHash != currentPasswordHash) {
      return {
        'success': false,
        'message': 'Current password is incorrect.',
      };
    }

    // Update password locally immediately
    final token = cachedUser.token;
    await _cacheUserCredentials(email, newPassword, token);

    // Sync with backend in background (non-blocking)
    _syncPasswordChangeInBackground(email, currentPassword, newPassword);

    return {
      'success': true,
      'message': 'Password changed successfully',
    };
  }

  /// Change password directly without requiring current password (offline-first).
  Future<Map<String, dynamic>> changePasswordDirect(String newPassword) async {
    // Get the current user email
    final email = await _secureStorageService.getValue('cached_email');
    if (email == null) {
      return {
        'success': false,
        'message': 'No user session found. Please login again.',
      };
    }

    // Get current user data
    final cachedUser = await _db.authDao.getUserByEmail(email);
    if (cachedUser == null) {
      return {
        'success': false,
        'message': 'User not found in local cache.',
      };
    }

    // Update password locally immediately
    final token = cachedUser.token;
    await _cacheUserCredentials(email, newPassword, token);

    // Sync with backend in background (non-blocking)
    _syncPasswordChangeDirectInBackground(email, newPassword);

    return {
      'success': true,
      'message': 'Password changed successfully',
    };
  }

  /// Sync password change with backend in background
  void _syncPasswordChangeInBackground(String email, String currentPassword, String newPassword) {
    Future(() async {
      if (!_connectivityService.isOnline) {
        // Queue for later sync
        await _queuePasswordChange(email, newPassword);
        print('🔐 Password change queued for later sync');
        return;
      }

      try {
        final result = await _authService.changePassword(currentPassword, newPassword, newPassword);
        
        if (result['success'] == true) {
          // Remove from queue if it was queued
          await _db.syncQueueDao.removeItem('password_change', email);
          print('✅ Password change synced with backend');
        } else {
          // Queue for retry
          await _queuePasswordChange(email, newPassword);
          print('⚠️ Password change queued for retry: ${result['message']}');
        }
      } catch (e) {
        // Queue for retry
        await _queuePasswordChange(email, newPassword);
        print('❌ Password change sync failed, queued: $e');
      }
    });
  }

  /// Sync direct password change with backend in background
  void _syncPasswordChangeDirectInBackground(String email, String newPassword) {
    Future(() async {
      if (!_connectivityService.isOnline) {
        // Queue for later sync
        await _queuePasswordChange(email, newPassword);
        print('🔐 Password change queued for later sync');
        return;
      }

      try {
        // Send empty current password - backend should handle this for authenticated users
        final result = await _authService.changePassword('', newPassword, newPassword);
        
        if (result['success'] == true) {
          // Remove from queue if it was queued
          await _db.syncQueueDao.removeItem('password_change', email);
          print('✅ Password change synced with backend');
        } else {
          // Queue for retry
          await _queuePasswordChange(email, newPassword);
          print('⚠️ Password change queued for retry: ${result['message']}');
        }
      } catch (e) {
        // Queue for retry
        await _queuePasswordChange(email, newPassword);
        print('❌ Password change sync failed, queued: $e');
      }
    });
  }

  /// Delete account (Offline-first)
  Future<Map<String, dynamic>> deleteAccount() async {
    final isOnline = _connectivityService.isOnline;
    final email = await getCachedEmail();
    
    if (email == null) {
      return {'success': false, 'message': 'No user logged in'};
    }

    if (!isOnline) {
      return {
        'success': false, 
        'message': 'You must be online to delete your account.'
      };
    }

    try {
      final result = await _authService.deleteAccount();
      
      if (result['success'] == true) {
        print('✅ Account deleted on server. Cleaning up local data for: $email');
        
        // Delete user data first
        await _db.notesDao.deleteNotesByUser(email);
        await _db.passwordsDao.deletePasswordsByUser(email);
        await _db.otpDao.deleteOtpEntriesByUser(email);
        
        // Delete user record
        await _db.authDao.deleteUser(email);
        print('✅ Local user data deleted');
        
        // Clear cached credentials
        await _secureStorageService.clearCachedCredentials();
        
        // Clear shared prefs (via AuthService logout)
        await _authService.logout();
      } else {
        print('❌ Server failed to delete account: ${result['message']}');
      }
      
      return result;
    } catch (e) {
      print('❌ Exception during account deletion: $e');
      return {'success': false, 'message': 'Failed to delete account: $e'};
    }
  }

  /// Queue password change for later sync
  Future<void> _queuePasswordChange(String email, String newPassword) async {
    // Remove any existing password change in queue
    await _db.syncQueueDao.removeItem('password_change', email);
    
    // Add new entry
    await _db.syncQueueDao.queueItem(
      'password_change',
      email,
      'update',
      jsonEncode({
        'email': email,
        'new_password': newPassword,
      }),
    );
  }

  /// Check if user has cached credentials (can login offline).
  Future<bool> hasCachedCredentials(String email) async {
    final user = await _db.authDao.getUserByEmail(email);
    return user != null;
  }

  /// Get cached email if exists.
  Future<String?> getCachedEmail() async {
    return await _secureStorageService.getValue('cached_email');
  }

  /// Remove registration from sync queue (used after successful sync).
  Future<void> removeFromSyncQueue(String email) async {
    await _db.syncQueueDao.removeItem('registration', email);
  }

  // ==================== PRIVATE METHODS ====================

  /// Cache user credentials for offline login.
  Future<void> _cacheUserCredentials(String email, String password, String? token) async {
    final passwordHash = _hashPassword(password);
    
    await _db.authDao.insertOrUpdateUser(User(
      email: email,
      passwordHash: passwordHash,
      token: token,
      lastLogin: DateTime.now().toIso8601String(),
    ));
  }

  /// Clear all cached credentials.
  Future<void> _clearCachedCredentials() async {
    // Drift doesn't have a clearAll for a table in DAO unless I add it.
    // I'll use delete(users).go() via DAO if I add it, or just custom statement.
    // Or I can add `deleteAllUsers` to AuthDao.
    // For now I'll assume I can access `delete` via `_db.authDao`? No, `AuthDao` encapsulates it.
    // I need to add `deleteAllUsers` to `AuthDao`.
    // Or I can use `_db.delete(_db.users).go()`.
    await _db.delete(_db.users).go();
  }

  /// Queue registration for later sync.
  Future<void> _queueRegistration(String email, String username, String password) async {
    await _db.syncQueueDao.queueItem(
      'registration',
      email,
      'create',
      jsonEncode({
        'email': email,
        'username': username,
        'password': password,
      }),
    );
  }

  /// Sync login with backend (background, non-blocking)
  Future<void> _syncLoginWithBackend(String email, String password, String? cachedToken) async {
    try {
      final result = await _authService.login(email, password);
      
      if (result['success'] == true) {
        final newToken = result['data']?['token'];
        
        // Update cached token if it changed
        if (newToken != null && newToken != cachedToken) {
          await _cacheUserCredentials(email, password, newToken);
        }
      }
    } catch (e) {
      // Sync failed, but user is already logged in with cache
      print('Background login sync failed: $e');
    }
  }

  /// Hash password using SHA-256.
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
