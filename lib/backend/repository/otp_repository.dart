import 'package:uuid/uuid.dart';
import '../models/otp_entry.dart' as model;
import '../service/database_service.dart';
import '../service/connectivity_service.dart';
import '../service/sync_service.dart';
import '../../services/otp_backend_service.dart';

/// Repository para gestionar las entradas OTP con enfoque offline-first
/// 
/// All operations go through local database first, then sync with backend
/// when connection is available
class OtpRepository {
  final DatabaseService _dbService = DatabaseService();
  final ConnectivityService _connectivityService = ConnectivityService();
  final SyncService _syncService = SyncService();
  final OtpBackendService _otpBackendService;
  final Uuid _uuid = const Uuid();

  OtpRepository(this._otpBackendService);

  /// Obtener todas las entradas OTP
  Future<Map<String, dynamic>> getAllOtpEntries() async {
    try {
      final localEntries = await _dbService.getAllOtpEntries();
        final entries = localEntries
          .map((data) => model.OtpEntry.fromJson(data))
          .toList();

      // Trigger background sync if online
      if (_connectivityService.isOnline) {
        // Sync in background (non-blocking)
        _syncOtpEntriesInBackground();
      }

      return {
        'success': true,
        'data': entries,
        'message': 'OTP entries loaded from local storage'
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to load OTP entries: $e',
        'data': <model.OtpEntry>[]
      };
    }
  }

  /// Sync OTP entries with backend in background
  void _syncOtpEntriesInBackground() {
    Future(() async {
      try {
        final result = await _otpBackendService.getAllOtpEntries();
        if (result['success'] && result['data'] != null) {
          final serverEntries = result['data'] as List<model.OtpEntry>;
          // Update local database with server data if needed
          // TODO: Implement merge logic
          print('✅ OTP entries synced from server: ${serverEntries.length}');
        }
      } catch (e) {
        print('⚠️ Failed to sync OTP entries from server: $e');
      }
    });
  }

  /// Crear una nueva entrada OTP (FAST - saved locally, synced in background)
  Future<Map<String, dynamic>> addOtpEntry(Map<String, dynamic> entryData) async {
    try {
      final localId = _uuid.v4();
      final now = DateTime.now();

      final dataToSave = {
        'id': localId,
        'name': entryData['name'] ?? '',
        'issuer': entryData['issuer'] ?? '',
        'secret': entryData['secret'] ?? '',
        'digits': entryData['digits'] ?? 6,
        'period': entryData['period'] ?? 30,
        'algorithm': entryData['algorithm'] ?? 'SHA1',
        'userId': entryData['userId'] ?? '',
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
        'syncStatus': 'pending',
      };

      // Save to local database first (FAST)
      await _dbService.insertOtpEntry(dataToSave);

      // Sync with backend in BACKGROUND (non-blocking)
      _syncOtpCreationInBackground(localId, dataToSave);

      return {
        'success': true,
        'data': {'id': localId},
        'message': 'OTP entry created successfully'
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to create OTP entry: $e'
      };
    }
  }

  /// Sync OTP creation with backend in background
  void _syncOtpCreationInBackground(String localId, Map<String, dynamic> entryData) {
    Future(() async {
      if (!_connectivityService.isOnline) {
        print('📝 OTP entry queued for sync: $localId');
        return;
      }

      try {
        final result = await _otpBackendService.createOtpEntry(entryData);
        if (result['success']) {
          final serverEntry = result['data'] as model.OtpEntry?;
          if (serverEntry?.id != null) {
            // Update local entry with server ID
            await _dbService.updateOtpEntry(localId, {
              'serverId': serverEntry!.id,
              'syncStatus': 'synced',
            });
            print('✅ OTP entry synced: $localId');
          }
        } else {
          print('⚠️ OTP entry sync failed, will retry: $localId');
        }
      } catch (e) {
        print('❌ OTP entry sync error: $localId - $e');
      }
    });
  }

  /// Agregar OTP desde URI (otpauth://...) - FAST with background sync
  Future<Map<String, dynamic>> addOtpFromUri(String uri, String userId) async {
    try {
      final entry = model.OtpEntry.fromUri(uri, userId);
      final localId = _uuid.v4();
      
      final dataToSave = {
        ...entry.toJson(),
        'id': localId,
        'syncStatus': 'pending',
      };

      // Save to local database first (FAST)
      await _dbService.insertOtpEntry(dataToSave);

      // Sync with backend in BACKGROUND (non-blocking)
      _syncOtpCreationInBackground(localId, dataToSave);

      return {
        'success': true,
        'data': {'id': localId},
        'message': 'OTP entry imported successfully'
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to import OTP: $e'
      };
    }
  }

  /// Actualizar una entrada OTP
  Future<Map<String, dynamic>> updateOtpEntry(
    String id,
    Map<String, dynamic> entryData,
  ) async {
    try {
      final now = DateTime.now();
      
      final dataToUpdate = {
        ...entryData,
        'updatedAt': now.toIso8601String(),
        'syncStatus': 'pending',
      };

      await _dbService.updateOtpEntry(id, dataToUpdate);

      return {
        'success': true,
        'message': 'OTP entry updated successfully'
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to update OTP entry: $e'
      };
    }
  }

  /// Eliminar una entrada OTP (FAST - deleted locally, synced in background)
  Future<Map<String, dynamic>> deleteOtpEntry(String id, {String? serverId}) async {
    try {
      // Delete from local database first (FAST)
      await _dbService.deleteOtpEntry(id);

      // Sync deletion with backend in BACKGROUND (non-blocking)
      if (serverId != null) {
        _syncOtpDeletionInBackground(id, serverId);
      }

      return {
        'success': true,
        'message': 'OTP entry deleted successfully'
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to delete OTP entry: $e'
      };
    }
  }

  /// Sync OTP deletion with backend in background
  void _syncOtpDeletionInBackground(String localId, String serverId) {
    Future(() async {
      if (!_connectivityService.isOnline) {
        print('📝 OTP deletion queued: $localId');
        return;
      }

      try {
        await _otpBackendService.deleteOtpEntry(serverId);
        print('✅ OTP deletion synced: $localId');
      } catch (e) {
        print('❌ OTP deletion sync error: $localId - $e');
      }
    });
  }

  /// Buscar entradas OTP
  Future<Map<String, dynamic>> searchOtpEntries(String query) async {
    try {
      final allEntries = await _dbService.getAllOtpEntries();
        final entries = allEntries
          .map((data) => model.OtpEntry.fromJson(data))
            .where((entry) =>
              entry.name.toLowerCase().contains(query.toLowerCase()) ||
              entry.issuer.toLowerCase().contains(query.toLowerCase())
            )
          .toList();

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
}
