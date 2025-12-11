import 'package:uuid/uuid.dart';
import '../models/otp_entry.dart' as model;
import '../local/app_database.dart';
import '../../services/otp_api_service.dart';
import '../../services/auth_service.dart';
import '../../services/connectivity_service.dart';
import '../local/secure_storage_service.dart';

/// Repository para gestionar las entradas OTP con enfoque offline-first
/// 
/// All operations go through local database first
class OtpRepository {
  final AppDatabase _db = AppDatabase.instance();
  final Uuid _uuid = const Uuid();
  final OtpApiService _otpApiService = OtpApiService(AuthService());
  final ConnectivityService _connectivityService = ConnectivityService();
  final SecureStorageService _secureStorageService = SecureStorageService();

  OtpRepository();

  /// Obtener todas las entradas OTP
  Future<Map<String, dynamic>> getAllOtpEntries() async {
    try {
      // Trigger background sync if online
      if (_connectivityService.isOnline) {
        _syncFromServer();
      }

      final localEntries = await _db.otpDao.getAllOtpEntries();
      final entries = localEntries.map((e) => model.OtpEntry.fromJson(e)).toList();
      return {
        'success': true,
        'data': entries,
        'message': 'OTP entries loaded'
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to load OTP entries: $e',
        'data': <model.OtpEntry>[]
      };
    }
  }

  /// Sync OTP entries from server to local database
  Future<void> _syncFromServer() async {
    try {
      final result = await _otpApiService.getAllOtpEntries();
      
      if (result['success'] == true && result['data'] != null) {
        final serverEntries = result['data'] as List<model.OtpEntry>;
        
        // Get current user email to associate with synced entries
        final userEmail = await _secureStorageService.getValue('cached_email');
        if (userEmail == null) return;

        for (final serverEntry in serverEntries) {
          if (serverEntry.id.isEmpty) continue;
          
          // Check if exists locally by serverId
          final existingLocal = await _db.otpDao.getOtpEntryByServerId(serverEntry.id);
          
          if (existingLocal != null) {
            // Update existing
            await _db.otpDao.updateOtpEntry(existingLocal['id'], {
              'name': serverEntry.name,
              'issuer': serverEntry.issuer,
              'secret': serverEntry.secret,
              'digits': serverEntry.digits,
              'period': serverEntry.period,
              'algorithm': serverEntry.algorithm,
              'type': serverEntry.type,
              'updatedAt': DateTime.now().toIso8601String(),
              'syncStatus': 'synced',
              'lastSyncedAt': DateTime.now().toIso8601String(),
            });
          } else {
            // Insert new from server
            final localId = _uuid.v4();
            await _db.otpDao.insertOtpEntry({
              'id': localId,
              'name': serverEntry.name,
              'issuer': serverEntry.issuer,
              'secret': serverEntry.secret,
              'digits': serverEntry.digits,
              'period': serverEntry.period,
              'algorithm': serverEntry.algorithm,
              'type': serverEntry.type,
              'userId': userEmail, // Use local email instead of server ID
              'createdAt': serverEntry.createdAt.toIso8601String(),
              'updatedAt': serverEntry.updatedAt.toIso8601String(),
              'serverId': serverEntry.id,
              'syncStatus': 'synced',
              'lastSyncedAt': DateTime.now().toIso8601String(),
            });
          }
        }
      }
    } catch (e) {
      print('Server sync failed: $e');
    }
  }

  /// Crear una nueva entrada OTP (FAST - saved locally)
  Future<Map<String, dynamic>> addOtpEntry(Map<String, dynamic> entryData) async {
    try {
      final id = _uuid.v4();
      final now = DateTime.now().toIso8601String();
      
      final entry = {
        ...entryData,
        'id': id,
        'createdAt': now,
        'updatedAt': now,
        'syncStatus': 'pending',
      };
      
      await _db.otpDao.insertOtpEntry(entry);
      
      final createdEntry = model.OtpEntry.fromJson(entry);

      // Sync with backend in BACKGROUND (non-blocking)
      if (_connectivityService.isOnline) {
        _syncOtpInBackground(id, createdEntry);
      }
      
      return {
        'success': true,
        'data': createdEntry,
        'message': 'OTP entry created'
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to create OTP entry: $e'
      };
    }
  }

  /// Sync a newly created OTP entry with backend
  Future<void> _syncOtpInBackground(String localId, model.OtpEntry entry) async {
    try {
      final result = await _otpApiService.createOtpEntry(entry);
      
      if (result['success'] == true && result['data'] != null) {
        final serverEntry = result['data'] as model.OtpEntry;
        
        // Update local record with server ID and synced status
        await _db.otpDao.updateOtpEntry(localId, {
          'serverId': serverEntry.id,
          'syncStatus': 'synced',
          'lastSyncedAt': DateTime.now().toIso8601String(),
        });
      } else {
        // Mark as error if sync failed
        await _db.otpDao.updateOtpEntry(localId, {
          'syncStatus': 'error',
        });
      }
    } catch (e) {
      print('Background sync failed: $e');
      // Mark as error
      await _db.otpDao.updateOtpEntry(localId, {
        'syncStatus': 'error',
      });
    }
  }

  /// Agregar OTP desde URI (otpauth://...) - FAST
  Future<Map<String, dynamic>> addOtpFromUri(String uriString, String userId) async {
    try {
      final uri = Uri.parse(uriString);
      if (uri.scheme != 'otpauth') {
        return {'success': false, 'message': 'Invalid URI scheme'};
      }

      final type = uri.host; // totp or hotp
      final path = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
      // path usually is "Issuer:Account" or just "Account"
      
      String issuer = '';
      String account = path;
      
      if (path.contains(':')) {
        final parts = path.split(':');
        issuer = parts[0];
        account = parts.sublist(1).join(':');
      }

      final queryParams = uri.queryParameters;
      final secret = queryParams['secret'];
      final issuerParam = queryParams['issuer'];
      if (issuerParam != null && issuerParam.isNotEmpty) {
        issuer = issuerParam;
      }
      
      final algorithm = queryParams['algorithm'] ?? 'SHA1';
      final digits = int.tryParse(queryParams['digits'] ?? '6') ?? 6;
      final period = int.tryParse(queryParams['period'] ?? '30') ?? 30;

      if (secret == null) {
        return {'success': false, 'message': 'Missing secret in URI'};
      }

      final entryData = {
        'name': account,
        'issuer': issuer,
        'secret': secret,
        'type': type,
        'algorithm': algorithm,
        'digits': digits,
        'period': period,
        'userId': userId,
      };

      return await addOtpEntry(entryData);
    } catch (e) {
      return {'success': false, 'message': 'Failed to import URI: $e'};
    }
  }

  /// Actualizar una entrada OTP
  Future<Map<String, dynamic>> updateOtpEntry(
    String id,
    Map<String, dynamic> entryData,
  ) async {
    try {
      final now = DateTime.now().toIso8601String();
      final updateData = {
        ...entryData,
        'updatedAt': now,
        'syncStatus': 'pending',
      };
      
      await _db.otpDao.updateOtpEntry(id, updateData);
      
      // Fetch updated
      final updated = await _db.otpDao.getOtpEntryById(id);
      
      if (updated != null) {
        final updatedEntry = model.OtpEntry.fromJson(updated);
        
        // Sync with backend in BACKGROUND (non-blocking)
        if (_connectivityService.isOnline) {
          _syncOtpUpdateInBackground(id, updatedEntry);
        }
        
        return {
          'success': true,
          'data': updatedEntry,
          'message': 'OTP entry updated'
        };
      }
      
      return {
        'success': false,
        'message': 'Failed to fetch updated entry'
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to update OTP entry: $e'
      };
    }
  }

  /// Sync an OTP update with backend
  Future<void> _syncOtpUpdateInBackground(String localId, model.OtpEntry entry) async {
    // If entry doesn't have server ID, we can't update it on server yet
    if (entry.serverId == null) return;

    try {
      final result = await _otpApiService.updateOtpEntry(entry.serverId!, entry);
      
      if (result['success'] == true) {
        // Update local record as synced
        await _db.otpDao.updateOtpEntry(localId, {
          'syncStatus': 'synced',
          'lastSyncedAt': DateTime.now().toIso8601String(),
        });
      } else {
        await _db.otpDao.updateOtpEntry(localId, {
          'syncStatus': 'error',
        });
      }
    } catch (e) {
      print('Background update sync failed: $e');
      await _db.otpDao.updateOtpEntry(localId, {
        'syncStatus': 'error',
      });
    }
  }

  /// Eliminar una entrada OTP (FAST - deleted locally)
  Future<Map<String, dynamic>> deleteOtpEntry(String id, {String? serverId}) async {
    try {
      // Delete from local database first (FAST)
      await _db.otpDao.deleteOtpEntry(id);

      // Sync with backend in BACKGROUND (non-blocking)
      if (serverId != null && _connectivityService.isOnline) {
        _syncOtpDeletionInBackground(serverId);
      }

      return {
        'success': true,
        'message': 'OTP entry deleted'
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to delete OTP entry: $e'
      };
    }
  }

  /// Sync an OTP deletion with backend
  Future<void> _syncOtpDeletionInBackground(String serverId) async {
    try {
      await _otpApiService.deleteOtpEntry(serverId);
    } catch (e) {
      print('Background deletion sync failed: $e');
    }
  }

  /// Buscar entradas OTP
  Future<Map<String, dynamic>> searchOtpEntries(String query) async {
    try {
      final localEntries = await _db.otpDao.searchOtpEntries(query);
      final entries = localEntries.map((e) => model.OtpEntry.fromJson(e)).toList();

      return {
        'success': true,
        'data': entries,
        'message': 'Search completed'
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Search failed: $e',
        'data': <model.OtpEntry>[]
      };
    }
  }

  /// Get a single OTP entry by ID
  Future<Map<String, dynamic>> getOtpEntry(String id) async {
    try {
      final entry = await _db.otpDao.getOtpEntryById(id);
      if (entry == null) {
        return {'success': false, 'message': 'Entry not found'};
      }
      return {
        'success': true,
        'data': model.OtpEntry.fromJson(entry)
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Force a manual sync with the backend
  Future<Map<String, dynamic>> forceSync() async {
    if (!_connectivityService.isOnline) {
      return {'success': false, 'message': 'No internet connection'};
    }
    
    await _syncFromServer();
    // Also sync pending changes (not implemented fully here, but could iterate pending items)
    
    return {'success': true, 'message': 'Sync completed'};
  }

  /// Get sync status for an OTP entry
  Future<String> getSyncStatus(String id) async {
    final entry = await _db.otpDao.getOtpEntryById(id);
    return entry?['syncStatus'] ?? 'unknown';
  }

  /// Get all pending sync entries count
  Future<int> getPendingSyncCount() async {
    final unsynced = await _db.otpDao.getUnsyncedOtpEntries();
    final deleted = await _db.otpDao.getDeletedOtpEntries();
    return unsynced.length + deleted.length;
  }

  /// Check if there are pending changes to sync
  Future<bool> hasPendingChanges() async {
    return (await getPendingSyncCount()) > 0;
  }

  /// Export OTP entry as URI
  String exportToUri(model.OtpEntry entry) {
    final label = entry.issuer.isNotEmpty 
        ? '${Uri.encodeComponent(entry.issuer)}:${Uri.encodeComponent(entry.name)}'
        : Uri.encodeComponent(entry.name);
        
    var uri = 'otpauth://${entry.type}/$label?secret=${entry.secret}';
    
    if (entry.issuer.isNotEmpty) {
      uri += '&issuer=${Uri.encodeComponent(entry.issuer)}';
    }
    
    if (entry.algorithm != 'SHA1') {
      uri += '&algorithm=${entry.algorithm}';
    }
    
    if (entry.digits != 6) {
      uri += '&digits=${entry.digits}';
    }
    
    if (entry.period != 30) {
      uri += '&period=${entry.period}';
    }
    
    return uri;
  }
}
