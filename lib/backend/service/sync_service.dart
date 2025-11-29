import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;
import 'package:thisjowi/i18n/translations.dart';
import 'database_service.dart';
import 'connectivity_service.dart';
import 'package:thisjowi/services/auth_service.dart';
import 'package:thisjowi/core/api_config.dart';

/// Service to synchronize local data with backend
/// 
/// This service handles:
/// - Automatic sync when connection is available
/// - Manual sync trigger
/// - Conflict resolution
/// - Retry logic for failed syncs
class SyncService {
  static final SyncService _instance = SyncService._internal();
  
  final DatabaseService _dbService = DatabaseService();
  final ConnectivityService _connectivityService = ConnectivityService();
  final AuthService _authService = AuthService();
  
  Timer? _syncTimer;
  bool _isSyncing = false;
  
  // � CONTROL: Auto-sync activado para sincronizar con el backend en la red
  final bool _autoSyncEnabled = true;
  
  factory SyncService() => _instance;
  
  SyncService._internal() {
    _initAutoSync();
  }

  /// Initialize automatic synchronization
  void _initAutoSync() {
    if (!_autoSyncEnabled) {
      print('⚠️ AUTO-SYNC DESACTIVADO - Trabajando 100% offline');
      print('💡 Para activar: Cambia _autoSyncEnabled = true en sync_service.dart');
      return;
    }
    
    print('✅ Auto-sync ACTIVADO');
    
    // Listen to connectivity changes and sync when online
    _connectivityService.connectionStatus.listen((isOnline) {
      if (isOnline && !_isSyncing) {
        syncAll();
      }
    });

    // Periodic sync every 5 minutes when online
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (_connectivityService.isOnline && !_isSyncing) {
        syncAll();
      }
    });
  }

  /// Sync all pending data (notes, passwords, and registrations)
  Future<Map<String, dynamic>> syncAll() async {
    if (_isSyncing) {
      return {'success': false, 'message': 'Sync already in progress'};
    }

    if (!_connectivityService.isOnline) {
      print('⚠️ SYNC: Sin conexión a internet');
      return {'success': false, 'message': 'No internet connection'};
    }

    print('🔄 SYNC: Iniciando sincronización...');
    _isSyncing = true;

    try {
      // Sync registrations first (they need to complete before other syncs)
      final registrationsResult = await syncRegistrations();
      final notesResult = await syncNotes();
      final passwordsResult = await syncPasswords();

      _isSyncing = false;
      
      print('✅ SYNC COMPLETADO:'.i18n);
      print('   - Registros: ${registrationsResult['synced'] ?? 0} sync, ${registrationsResult['failed'] ?? 0} fail');
      print('   - Notas: ${notesResult['synced'] ?? 0} sync, ${notesResult['failed'] ?? 0} fail');
      print('   - Passwords: ${passwordsResult['synced'] ?? 0} sync, ${passwordsResult['failed'] ?? 0} fail');

      return {
        'success': registrationsResult['success'] && notesResult['success'] && passwordsResult['success'],
        'registrations': registrationsResult,
        'notes': notesResult,
        'passwords': passwordsResult,
      };
    } catch (e) {
      _isSyncing = false;
      print('❌ SYNC ERROR: $e');
      return {'success': false, 'message': 'Sync failed: $e'};
    }
  }

  /// Sync notes with backend
  Future<Map<String, dynamic>> syncNotes() async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      // First, fetch all notes from server to check for updates
      final serverNotes = await _fetchNotesFromServer(headers);
      
      // Get local notes that need syncing
      final unsyncedNotes = await _dbService.getUnsyncedNotes();
      
      int synced = 0;
      int failed = 0;

      // Sync local changes to server
      for (final localNote in unsyncedNotes) {
        try {
          final success = await _syncNoteToServer(localNote, headers);
          if (success) {
            synced++;
          } else {
            failed++;
          }
        } catch (e) {
          failed++;
          print('Failed to sync note: $e');
        }
      }

      // Update local database with server changes
      await _updateLocalNotesFromServer(serverNotes);

      return {
        'success': failed == 0,
        'synced': synced,
        'failed': failed,
        'message': 'Notes sync completed'
      };
    } catch (e) {
      return {'success': false, 'message': 'Failed to sync notes: $e'};
    }
  }

  /// Fetch notes from server
  Future<List<Map<String, dynamic>>> _fetchNotesFromServer(
    Map<String, String> headers,
  ) async {
    try {
      final uri = Uri.parse(ApiConfig.notesUrl);
      final res = await http.get(uri, headers: headers)
          .timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body is List) {
          return body.map((e) => e as Map<String, dynamic>).toList();
        }
      }
      return [];
    } catch (e) {
      print('Failed to fetch notes from server: $e');
      return [];
    }
  }

  /// Sync a single note to server
  Future<bool> _syncNoteToServer(
    Map<String, dynamic> localNote,
    Map<String, String> headers,
  ) async {
    try {
      final serverId = localNote['serverId'] as int?;
      final localId = localNote['localId'] as String;

      final noteData = {
        'title': localNote['title'],
        'content': localNote['content'],
      };

      http.Response res;
      
      if (serverId != null) {
        // Update existing note on server
        final uri = Uri.parse('${ApiConfig.notesUrl}/${localNote['title']}');
        res = await http.put(
          uri,
          headers: headers,
          body: jsonEncode(noteData),
        ).timeout(const Duration(seconds: 30));
      } else {
        // Create new note on server
        final uri = Uri.parse(ApiConfig.notesUrl);
        res = await http.post(
          uri,
          headers: headers,
          body: jsonEncode(noteData),
        ).timeout(const Duration(seconds: 30));
      }

      if (res.statusCode == 200 || res.statusCode == 201) {
        final responseBody = jsonDecode(res.body);
        final newServerId = responseBody['id'] as int?;
        
        await _dbService.updateNoteSyncStatus(
          localId,
          'synced',
          serverId: newServerId ?? serverId,
        );
        return true;
      }
      
      return false;
    } catch (e) {
      print('Failed to sync note to server: $e');
      return false;
    }
  }

  /// Update local notes from server data
  Future<void> _updateLocalNotesFromServer(
    List<Map<String, dynamic>> serverNotes,
  ) async {
    for (final serverNote in serverNotes) {
      try {
        final serverId = serverNote['id'] as int?;
        if (serverId == null) continue;

        final existingNote = await _dbService.getNoteByServerId(serverId);
        
        final noteData = {
          'title': serverNote['title'],
          'content': serverNote['content'],
          'createdAt': serverNote['createdAt'],
          'updatedAt': serverNote['updatedAt'],
          'syncStatus': 'synced',
          'lastSyncedAt': DateTime.now().toIso8601String(),
          'serverId': serverId,
        };

        if (existingNote == null) {
          // Insert new note from server
          noteData['localId'] = 'server_$serverId';
          await _dbService.insertNote(noteData);
        } else {
          // Update existing note if server version is newer
          final localUpdatedAt = DateTime.tryParse(
            existingNote['updatedAt'] ?? '',
          );
          final serverUpdatedAt = DateTime.tryParse(
            serverNote['updatedAt'] ?? '',
          );

          if (serverUpdatedAt != null && 
              (localUpdatedAt == null || 
               serverUpdatedAt.isAfter(localUpdatedAt))) {
            await _dbService.updateNote(
              existingNote['localId'],
              noteData,
            );
          }
        }
      } catch (e) {
        print('Failed to update local note from server: $e');
      }
    }
  }

  /// Sync passwords with backend
  Future<Map<String, dynamic>> syncPasswords() async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      // Fetch passwords from server
      final serverPasswords = await _fetchPasswordsFromServer(headers);
      
      // Get local passwords that need syncing
      final unsyncedPasswords = await _dbService.getUnsyncedPasswords();
      
      int synced = 0;
      int failed = 0;

      // Sync local changes to server
      for (final localPassword in unsyncedPasswords) {
        try {
          final success = await _syncPasswordToServer(localPassword, headers);
          if (success) {
            synced++;
          } else {
            failed++;
          }
        } catch (e) {
          failed++;
          print('Failed to sync password: $e');
        }
      }

      // Update local database with server changes
      await _updateLocalPasswordsFromServer(serverPasswords);

      return {
        'success': failed == 0,
        'synced': synced,
        'failed': failed,
        'message': 'Passwords sync completed'
      };
    } catch (e) {
      return {'success': false, 'message': 'Failed to sync passwords: $e'};
    }
  }

  /// Fetch passwords from server
  Future<List<Map<String, dynamic>>> _fetchPasswordsFromServer(
    Map<String, String> headers,
  ) async {
    try {
      final uri = Uri.parse(ApiConfig.passwordsUrl);
      final res = await http.get(uri, headers: headers)
          .timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body is List) {
          return body.map((e) => e as Map<String, dynamic>).toList();
        }
      }
      return [];
    } catch (e) {
      print('Failed to fetch passwords from server: $e');
      return [];
    }
  }

  /// Sync a single password to server
  Future<bool> _syncPasswordToServer(
    Map<String, dynamic> localPassword,
    Map<String, String> headers,
  ) async {
    try {
      final serverId = localPassword['serverId'] as String?;
      final localId = localPassword['id'] as String;

      final passwordData = {
        'title': localPassword['title'],
        'username': localPassword['username'],
        'password': localPassword['password'],
        'website': localPassword['website'],
        'notes': localPassword['notes'],
      };

      http.Response res;
      
      if (serverId != null) {
        // Update existing password on server
        final uri = Uri.parse('${ApiConfig.passwordsUrl}/$serverId');
        res = await http.put(
          uri,
          headers: headers,
          body: jsonEncode(passwordData),
        ).timeout(const Duration(seconds: 30));
      } else {
        // Create new password on server
        final uri = Uri.parse(ApiConfig.passwordsUrl);
        res = await http.post(
          uri,
          headers: headers,
          body: jsonEncode(passwordData),
        ).timeout(const Duration(seconds: 30));
      }

      if (res.statusCode == 200 || res.statusCode == 201) {
        final responseBody = jsonDecode(res.body);
        final newServerId = responseBody['id']?.toString();
        
        await _dbService.updatePasswordSyncStatus(
          localId,
          'synced',
          serverId: newServerId ?? serverId,
        );
        return true;
      }
      
      return false;
    } catch (e) {
      print('Failed to sync password to server: $e');
      return false;
    }
  }

  /// Update local passwords from server data
  Future<void> _updateLocalPasswordsFromServer(
    List<Map<String, dynamic>> serverPasswords,
  ) async {
    for (final serverPassword in serverPasswords) {
      try {
        final serverId = serverPassword['id']?.toString();
        if (serverId == null) continue;

        final existingPassword = await _dbService.getPasswordById(serverId);
        
        final passwordData = {
          'id': serverId,
          'title': serverPassword['title'],
          'username': serverPassword['username'],
          'password': serverPassword['password'],
          'website': serverPassword['website'] ?? '',
          'notes': serverPassword['notes'] ?? '',
          'userId': serverPassword['userId'] ?? '',
          'createdAt': serverPassword['createdAt'] ?? DateTime.now().toIso8601String(),
          'updatedAt': serverPassword['updatedAt'] ?? DateTime.now().toIso8601String(),
          'syncStatus': 'synced',
          'lastSyncedAt': DateTime.now().toIso8601String(),
          'serverId': serverId,
        };

        if (existingPassword == null) {
          // Insert new password from server
          await _dbService.insertPassword(passwordData);
        } else {
          // Update existing password if server version is newer
          final localUpdatedAt = DateTime.tryParse(
            existingPassword['updatedAt'] ?? '',
          );
          final serverUpdatedAt = DateTime.tryParse(
            serverPassword['updatedAt'] ?? '',
          );

          if (serverUpdatedAt != null && 
              (localUpdatedAt == null || 
               serverUpdatedAt.isAfter(localUpdatedAt))) {
            await _dbService.updatePassword(serverId, passwordData);
          }
        }
      } catch (e) {
        print('Failed to update local password from server: $e');
      }
    }
  }

  /// Sync queued registrations
  Future<Map<String, dynamic>> syncRegistrations() async {
    try {
      final db = await _dbService.database;
      
      // Get all pending registrations from sync queue
      final query = db.select(db.syncQueue)
        ..where((s) => s.entityType.equals('registration') & s.action.equals('create'));
      final registrations = await query.get();

      if (registrations.isEmpty) {
        return {'success': true, 'message': 'No pending registrations'};
      }

      int successCount = 0;
      int failCount = 0;

      for (final registration in registrations) {
        final data = jsonDecode(registration.data ?? '{}');
        final email = data['email'] as String;
        final username = data['username'] as String;
        final password = data['password'] as String;

        try {
          // Attempt registration
          final result = await _authService.register(email, username, password);
          
          if (result['success'] == true) {
            // Update users table with real token from backend
            final token = result['data']?['token'];
            if (token != null) {
              await (db.update(db.users)
                ..where((u) => u.email.equals(email)))
                .write(UsersCompanion(
                  token: Value(token),
                ));
              print('✅ Registration synced for $email - Updated with backend token');
            }
            
            // Remove from sync queue
            await (db.delete(db.syncQueue)
              ..where((s) => s.id.equals(registration.id)))
              .go();
            successCount++;
          } else {
            failCount++;
            print('❌ Failed to sync registration for $email: ${result['message']}');
          }
        } catch (e) {
          failCount++;
          print('❌ Error syncing registration for $email: $e');
        }
      }

      return {
        'success': failCount == 0,
        'message': 'Synced $successCount registrations, $failCount failed',
        'synced': successCount,
        'failed': failCount,
      };
    } catch (e) {
      return {'success': false, 'message': 'Failed to sync registrations: $e'};
    }
  }

  /// Dispose resources
  void dispose() {
    _syncTimer?.cancel();
  }
}

