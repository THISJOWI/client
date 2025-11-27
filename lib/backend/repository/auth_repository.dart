import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'dart:convert';
import '../../services/auth_service.dart';
import '../service/database_service.dart';
import '../service/connectivity_service.dart';
import '../service/secure_storage_service.dart';

/// Repository for authentication that supports offline mode.
///
/// Flow (Offline-First):
/// - Login: ALWAYS verify against local cache first, then sync with backend if online
/// - Register: Save locally first, then sync with backend if online
/// - All operations pass through local database before hitting the backend
class AuthRepository {
  final AuthService _authService;
  final DatabaseService _databaseService;
  final ConnectivityService _connectivityService;
  final SecureStorageService _secureStorageService;

  AuthRepository({
    required AuthService authService,
    required DatabaseService databaseService,
    required ConnectivityService connectivityService,
    required SecureStorageService secureStorageService,
  })  : _authService = authService,
        _databaseService = databaseService,
        _connectivityService = connectivityService,
        _secureStorageService = secureStorageService;

  /// Login with offline-first support.
  ///
  /// Strategy (OFFLINE-FIRST):
  /// 1. Check local database for cached credentials
  /// 2. If found: Verify password hash
  ///    - If valid: Login with cached token
  ///    - If online: Sync with backend in background
  /// 3. If NOT found and online: Try backend login
  ///    - If successful: Cache credentials
  /// 4. If NOT found and offline: Error
  Future<Map<String, dynamic>> login(String email, String password) async {
    final isOnline = _connectivityService.isOnline;

    // Step 1: ALWAYS check local cache first
    final cachedUser = await _getCachedUser(email);
    
    if (cachedUser != null) {
      // User exists in local cache
      final passwordHash = _hashPassword(password);
      
      if (cachedUser['password_hash'] == passwordHash) {
        // Valid credentials in cache
        final token = cachedUser['token'] as String?;
        
        // Restore token to SharedPreferences
        if (token != null) {
          await _secureStorageService.saveValue('cached_token', token);
          await _secureStorageService.saveValue('cached_email', email);
        }
        
        // Update last login timestamp in local DB
        await _updateLastLogin(email);
        
        // If online, sync with backend in background (don't block UI)
        if (isOnline) {
          _syncLoginWithBackend(email, password, token);
        }
        
        return {
          'success': true,
          'data': {'token': token, 'offline': !isOnline},
          'message': isOnline ? 'Logged in successfully' : 'Logged in offline mode',
        };
      } else {
        // Invalid password
        return {
          'success': false,
          'message': 'Invalid credentials',
        };
      }
    } else {
      // No cached credentials - need backend
      if (!isOnline) {
        return {
          'success': false,
          'message': 'No internet connection. You need to login online at least once.',
        };
      }
      
      // Try backend login
      final result = await _authService.login(email, password);
      
      if (result['success'] == true) {
        // Cache credentials for future offline use
        await _cacheUserCredentials(email, password, result['data']?['token']);
      }
      
      return result;
    }
  }

  /// Register with offline-first support.
  ///
  /// Strategy (FAST OFFLINE-FIRST):
  /// 1. Check if user already exists locally or in sync queue
  /// 2. Save credentials to local database immediately
  /// 3. Return success immediately (user can start using the app)
  /// 4. Sync with backend in BACKGROUND (non-blocking)
  Future<Map<String, dynamic>> register(String email, String username, String password) async {
    // Step 1: Check if user already exists locally
    final existingUser = await _getCachedUser(email);
    if (existingUser != null) {
      return {
        'success': false,
        'message': 'This user already exists locally. Please sign in.',
      };
    }

    // Step 2: Check if registration is already queued
    final isQueued = await _isRegistrationQueued(email);
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
    // This runs asynchronously without waiting
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
          await removeFromSyncQueue(email);
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
  ///
  /// Strategy:
  /// 1. Verify current password against local cache
  /// 2. Update password in local database immediately
  /// 3. Sync with backend in background if online
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
    final cachedUser = await _getCachedUser(email);
    if (cachedUser == null) {
      return {
        'success': false,
        'message': 'User not found in local cache.',
      };
    }

    final currentPasswordHash = _hashPassword(currentPassword);
    if (cachedUser['password_hash'] != currentPasswordHash) {
      return {
        'success': false,
        'message': 'Current password is incorrect.',
      };
    }

    // Update password locally immediately
    final token = cachedUser['token'] as String?;
    await _cacheUserCredentials(email, newPassword, token);

    // Sync with backend in background (non-blocking)
    _syncPasswordChangeInBackground(email, currentPassword, newPassword);

    return {
      'success': true,
      'message': 'Password changed successfully',
    };
  }

  /// Change password directly without requiring current password (offline-first).
  ///
  /// Strategy:
  /// 1. Update password in local database immediately
  /// 2. Sync with backend in background if online
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
    final cachedUser = await _getCachedUser(email);
    if (cachedUser == null) {
      return {
        'success': false,
        'message': 'User not found in local cache.',
      };
    }

    // Update password locally immediately
    final token = cachedUser['token'] as String?;
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
          await _removePasswordChangeFromQueue(email);
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
          await _removePasswordChangeFromQueue(email);
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

  /// Queue password change for later sync
  Future<void> _queuePasswordChange(String email, String newPassword) async {
    final db = await _databaseService.database;
    
    // Remove any existing password change in queue
    await (db.delete(db.syncQueue)
      ..where((s) => s.entityType.equals('password_change') & s.entityId.equals(email)))
      .go();
    
    // Add new entry
    await db.into(db.syncQueue).insert(SyncQueueCompanion.insert(
      entityType: 'password_change',
      entityId: email,
      action: 'update',
      data: Value(jsonEncode({
        'email': email,
        'new_password': newPassword,
      })),
      createdAt: DateTime.now().toIso8601String(),
    ));
  }

  /// Remove password change from sync queue
  Future<void> _removePasswordChangeFromQueue(String email) async {
    final db = await _databaseService.database;
    await (db.delete(db.syncQueue)
      ..where((s) => s.entityType.equals('password_change') & s.entityId.equals(email)))
      .go();
  }

  /// Check if user has cached credentials (can login offline).
  Future<bool> hasCachedCredentials(String email) async {
    final user = await _getCachedUser(email);
    return user != null;
  }

  /// Get cached email if exists.
  Future<String?> getCachedEmail() async {
    return await _secureStorageService.getValue('cached_email');
  }

  /// Remove registration from sync queue (used after successful sync).
  Future<void> removeFromSyncQueue(String email) async {
    final db = await _databaseService.database;
    await (db.delete(db.syncQueue)
      ..where((s) => s.entityType.equals('registration') & s.entityId.equals(email)))
      .go();
  }

  // ==================== PRIVATE METHODS ====================

  /// Cache user credentials for offline login.
  Future<void> _cacheUserCredentials(String email, String password, String? token) async {
    final db = await _databaseService.database;
    final passwordHash = _hashPassword(password);
    
    await db.into(db.users).insertOnConflictUpdate(UsersCompanion.insert(
      email: email,
      passwordHash: passwordHash,
      token: Value(token),
      lastLogin: Value(DateTime.now().toIso8601String()),
    ));
  }

  /// Get cached user from local database.
  Future<Map<String, dynamic>?> _getCachedUser(String email) async {
    final db = await _databaseService.database;
    final query = db.select(db.users)
      ..where((u) => u.email.equals(email))
      ..limit(1);
    
    final results = await query.get();
    if (results.isEmpty) return null;
    
    final user = results.first;
    return {
      'email': user.email,
      'password_hash': user.passwordHash,
      'token': user.token,
      'last_login': user.lastLogin,
    };
  }

  /// Clear all cached credentials.
  Future<void> _clearCachedCredentials() async {
    final db = await _databaseService.database;
    await db.delete(db.users).go();
  }

  /// Queue registration for later sync.
  Future<void> _queueRegistration(String email, String username, String password) async {
    final db = await _databaseService.database;
    await db.into(db.syncQueue).insert(SyncQueueCompanion.insert(
      entityType: 'registration',
      entityId: email,
      action: 'create',
      data: Value(jsonEncode({
        'email': email,
        'username': username,
        'password': password,
      })),
      createdAt: DateTime.now().toIso8601String(),
    ));
  }

  /// Check if a registration is already queued for the given email.
  Future<bool> _isRegistrationQueued(String email) async {
    final db = await _databaseService.database;
    final query = db.select(db.syncQueue)
      ..where((s) => s.entityType.equals('registration') & s.entityId.equals(email))
      ..limit(1);
    
    final results = await query.get();
    return results.isNotEmpty;
  }

  /// Update last login timestamp in local database
  Future<void> _updateLastLogin(String email) async {
    final db = await _databaseService.database;
    await (db.update(db.users)
      ..where((u) => u.email.equals(email)))
      .write(UsersCompanion(
        lastLogin: Value(DateTime.now().toIso8601String()),
      ));
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
