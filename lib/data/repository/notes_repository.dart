import 'package:uuid/uuid.dart';
import '../models/note.dart' as models;
import '../local/app_database.dart';
import '../../services/notes_service.dart';
import '../../services/auth_service.dart';
import '../../services/connectivity_service.dart';

/// Repository for managing notes with offline-first approach
/// 
/// All operations go through local database first, then sync with backend
/// when connection is available
class NotesRepository {
  final AppDatabase _db = AppDatabase.instance();
  final Uuid _uuid = const Uuid();
  final NotesService _notesService = NotesService(AuthService());
  final ConnectivityService _connectivityService = ConnectivityService();

  NotesRepository();

  /// Get all notes from local database
  Future<Map<String, dynamic>> getAllNotes() async {
    try {
      // Trigger background sync if online
      if (_connectivityService.isOnline) {
        _syncFromServer();
      }

      final localNotes = await _db.notesDao.getAllNotes();
      final notes = localNotes.map((data) => models.Note.fromJson(data)).toList();

      return {
        'success': true,
        'data': notes,
        'message': 'Notes loaded from local storage'
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to load notes: $e',
        'data': <models.Note>[]
      };
    }
  }

  /// Sync notes from server to local database
  Future<void> _syncFromServer() async {
    try {
      final result = await _notesService.getAllNotes();
      
      if (result['success'] == true && result['data'] != null) {
        final serverNotes = result['data'] as List<models.Note>;
        final allLocalNotes = await _db.notesDao.getAllNotes();
        
        for (final serverNote in serverNotes) {
          if (serverNote.id == null) continue;
          
          // Check if exists locally by serverId
          final existingLocal = allLocalNotes.firstWhere(
            (n) => n['serverId'] == serverNote.id,
            orElse: () => {},
          );
          
          if (existingLocal.isNotEmpty) {
            // Update existing
            await _db.notesDao.updateNote(existingLocal['localId'], {
              'title': serverNote.title,
              'content': serverNote.content,
              'updatedAt': DateTime.now().toIso8601String(),
              'syncStatus': 'synced',
              'lastSyncedAt': DateTime.now().toIso8601String(),
            });
          } else {
            // Check for pending match to avoid duplicates
            final pendingMatch = allLocalNotes.firstWhere(
              (n) => n['syncStatus'] == 'pending' && 
                     n['title'] == serverNote.title && 
                     n['content'] == serverNote.content,
              orElse: () => {},
            );

            if (pendingMatch.isNotEmpty) {
               // Found a pending note that matches content. Link it!
               await _db.notesDao.updateNote(pendingMatch['localId'], {
                 'serverId': serverNote.id,
                 'syncStatus': 'synced',
                 'lastSyncedAt': DateTime.now().toIso8601String(),
               });
            } else {
              // Insert new from server
              final localId = _uuid.v4();
              await _db.notesDao.insertNote({
                'localId': localId,
                'title': serverNote.title,
                'content': serverNote.content,
                'createdAt': serverNote.createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
                'updatedAt': serverNote.updatedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
                'serverId': serverNote.id,
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

  /// Create a new note (FAST - saved locally, synced in background)
  Future<Map<String, dynamic>> createNote(models.Note note) async {
    try {
      final localId = _uuid.v4();
      final now = DateTime.now();

      final noteData = {
        'title': note.title,
        'content': note.content,
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
        'syncStatus': 'pending',
        'localId': localId,
      };

      // Save to local database first (FAST)
      await _db.notesDao.insertNote(noteData);

      final createdNote = note.copyWith(
        localId: localId,
        createdAt: now,
        updatedAt: now,
        syncStatus: 'pending',
      );

      // Sync with backend in BACKGROUND (non-blocking)
      if (_connectivityService.isOnline) {
        _syncNoteInBackground(localId, createdNote);
      }

      return {
        'success': true,
        'data': createdNote,
        'message': 'Note created successfully'
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to create note: $e'
      };
    }
  }

  /// Sync a newly created note with backend
  Future<void> _syncNoteInBackground(String localId, models.Note note) async {
    try {
      final result = await _notesService.createNote(note);
      
      if (result['success'] == true && result['data'] != null) {
        final serverNote = result['data'] as models.Note;
        
        // Update local record with server ID and synced status
        await _db.notesDao.updateNote(localId, {
          'serverId': serverNote.id,
          'syncStatus': 'synced',
          'lastSyncedAt': DateTime.now().toIso8601String(),
        });
      } else {
        // Mark as error if sync failed
        await _db.notesDao.updateNote(localId, {
          'syncStatus': 'error',
        });
      }
    } catch (e) {
      print('Background sync failed: $e');
      // Mark as error
      await _db.notesDao.updateNote(localId, {
        'syncStatus': 'error',
      });
    }
  }

  /// Update a note (FAST - saved locally, synced in background)
  Future<Map<String, dynamic>> updateNote(String localId, models.Note note) async {
    try {
      final now = DateTime.now();

      final noteData = {
        'title': note.title,
        'content': note.content,
        'updatedAt': now.toIso8601String(),
        'syncStatus': 'pending',
      };

      // Update in local database first (FAST)
      await _db.notesDao.updateNote(localId, noteData);

      final updatedNote = note.copyWith(
        updatedAt: now,
        syncStatus: 'pending',
      );

      // Sync with backend in BACKGROUND (non-blocking)
      if (_connectivityService.isOnline) {
        _syncNoteUpdateInBackground(localId, updatedNote);
      }

      return {
        'success': true,
        'data': updatedNote,
        'message': 'Note updated successfully'
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to update note: $e'
      };
    }
  }

  /// Sync a note update with backend
  Future<void> _syncNoteUpdateInBackground(String localId, models.Note note) async {
    // If note doesn't have server ID, we can't update it on server yet
    // It will be handled by the create sync or a full sync
    if (note.serverId == null) return;

    try {
      final result = await _notesService.updateNote(note.title, note);
      
      if (result['success'] == true) {
        // Update local record as synced
        await _db.notesDao.updateNote(localId, {
          'syncStatus': 'synced',
          'lastSyncedAt': DateTime.now().toIso8601String(),
        });
      } else {
        await _db.notesDao.updateNote(localId, {
          'syncStatus': 'error',
        });
      }
    } catch (e) {
      print('Background update sync failed: $e');
      await _db.notesDao.updateNote(localId, {
        'syncStatus': 'error',
      });
    }
  }

  /// Delete a note (FAST - deleted locally, synced in background)
  Future<Map<String, dynamic>> deleteNote(String localId, {String? serverId}) async {
    try {
      // Delete from local database first (FAST)
      await _db.notesDao.deleteNote(localId);

      // Sync with backend in BACKGROUND (non-blocking)
      if (serverId != null && _connectivityService.isOnline) {
        _syncNoteDeletionInBackground(serverId);
      }

      return {
        'success': true,
        'message': 'Note deleted successfully'
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to delete note: $e'
      };
    }
  }

  /// Sync a note deletion with backend
  Future<void> _syncNoteDeletionInBackground(String serverId) async {
    try {
      // We don't need to update local DB as the record is already deleted
      // Just try to delete from server
      await _notesService.deleteNote(int.parse(serverId));
    } catch (e) {
      print('Background deletion sync failed: $e');
      // In a real app, we might want to store this deletion in a "deleted_queue" table
      // to retry later. For now, we just log it.
    }
  }

  /// Search notes locally
  Future<Map<String, dynamic>> searchNotes(String query) async {
    try {
      final localNotes = await _db.notesDao.searchNotes(query);
      final notes = localNotes.map((data) => models.Note.fromJson(data)).toList();

      return {
        'success': true,
        'data': notes,
        'message': 'Search results'
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to search notes: $e',
        'data': <models.Note>[]
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
