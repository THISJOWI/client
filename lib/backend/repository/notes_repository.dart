import 'package:uuid/uuid.dart';
import '../models/note.dart' as models;
import '../service/database_service.dart';
import '../service/connectivity_service.dart';
import '../service/sync_service.dart';
import '../../services/notes_service.dart';

/// Repository for managing notes with offline-first approach
/// 
/// All operations go through local database first, then sync with backend
/// when connection is available
class NotesRepository {
  final DatabaseService _dbService = DatabaseService();
  final ConnectivityService _connectivityService = ConnectivityService();
  final SyncService _syncService = SyncService();
  final NotesService _notesService;
  final Uuid _uuid = const Uuid();

  NotesRepository(this._notesService);

  /// Get all notes from local database
  Future<Map<String, dynamic>> getAllNotes() async {
    try {
      final localNotes = await _dbService.getAllNotes();
      final notes = localNotes.map((data) => models.Note.fromJson(data)).toList();

      // Trigger background sync if online
      if (_connectivityService.isOnline) {
        _syncService.syncNotes();
      }

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
      await _dbService.insertNote(noteData);

      final createdNote = note.copyWith(
        localId: localId,
        createdAt: now,
        updatedAt: now,
        syncStatus: 'pending',
      );

      // Sync with backend in BACKGROUND (non-blocking)
      _syncNoteInBackground(localId, note);

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

  /// Sync note creation with backend in background
  void _syncNoteInBackground(String localId, models.Note note) {
    Future(() async {
      if (!_connectivityService.isOnline) {
        print('📝 Note queued for sync: $localId');
        return;
      }

      try {
        final result = await _notesService.createNote(note);
        if (result['success']) {
          final serverNote = result['data'] as models.Note?;
          if (serverNote?.id != null) {
            await _dbService.updateNoteSyncStatus(
              localId,
              'synced',
              serverId: serverNote!.id,
            );
            print('✅ Note synced: $localId');
          }
        } else {
          print('⚠️ Note sync failed, will retry: $localId');
        }
      } catch (e) {
        print('❌ Note sync error: $localId - $e');
      }
    });
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
      await _dbService.updateNote(localId, noteData);

      final updatedNote = note.copyWith(
        updatedAt: now,
        syncStatus: 'pending',
      );

      // Sync with backend in BACKGROUND (non-blocking)
      _syncNoteUpdateInBackground(localId, note);

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

  /// Sync note update with backend in background
  void _syncNoteUpdateInBackground(String localId, models.Note note) {
    Future(() async {
      if (!_connectivityService.isOnline || note.serverId == null) {
        print('📝 Note update queued: $localId');
        return;
      }

      try {
        final result = await _notesService.updateNote(note.title, note);
        if (result['success']) {
          await _dbService.updateNoteSyncStatus(
            localId,
            'synced',
            serverId: note.serverId,
          );
          print('✅ Note update synced: $localId');
        } else {
          print('⚠️ Note update sync failed: $localId');
        }
      } catch (e) {
        print('❌ Note update sync error: $localId - $e');
      }
    });
  }

  /// Delete a note (FAST - deleted locally, synced in background)
  Future<Map<String, dynamic>> deleteNote(String localId, int? serverId) async {
    try {
      // Delete from local database first (FAST)
      await _dbService.deleteNote(localId);

      // Sync deletion with backend in BACKGROUND (non-blocking)
      _syncNoteDeletionInBackground(localId, serverId);

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

  /// Sync note deletion with backend in background
  void _syncNoteDeletionInBackground(String localId, int? serverId) {
    Future(() async {
      if (serverId == null) return;

      if (!_connectivityService.isOnline) {
        // Queue for later deletion
        await _dbService.addToSyncQueue(
          entityType: 'note',
          entityId: serverId.toString(),
          action: 'delete',
        );
        print('📝 Note deletion queued: $localId');
        return;
      }

      try {
        await _notesService.deleteNote(serverId);
        print('✅ Note deletion synced: $localId');
      } catch (e) {
        // Queue for retry
        await _dbService.addToSyncQueue(
          entityType: 'note',
          entityId: serverId.toString(),
          action: 'delete',
        );
        print('❌ Note deletion failed, queued: $localId - $e');
      }
    });
  }

  /// Search notes locally
  Future<Map<String, dynamic>> searchNotes(String query) async {
    try {
      final allNotes = await _dbService.getAllNotes();
      final filteredNotes = allNotes.where((noteData) {
        final title = noteData['title']?.toString().toLowerCase() ?? '';
        final content = noteData['content']?.toString().toLowerCase() ?? '';
        final searchQuery = query.toLowerCase();
        return title.contains(searchQuery) || content.contains(searchQuery);
      }).toList();

      final notes = filteredNotes.map((data) => models.Note.fromJson(data)).toList();

      return {
        'success': true,
        'data': notes,
        'message': 'Search completed'
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to search notes: $e',
        'data': <models.Note>[]
      };
    }
  }

  /// Force sync with backend
  Future<Map<String, dynamic>> forceSync() async {
    if (!_connectivityService.isOnline) {
      return {
        'success': false,
        'message': 'No internet connection available'
      };
    }

    return await _syncService.syncNotes();
  }

  /// Get sync status
  Future<Map<String, dynamic>> getSyncStatus() async {
    try {
      final unsyncedNotes = await _dbService.getUnsyncedNotes();
      return {
        'success': true,
        'pendingSync': unsyncedNotes.length,
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
