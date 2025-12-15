import 'package:drift/drift.dart';
import '../app_database.dart';
import '../secure_storage_service.dart';

part 'notes_dao.g.dart';

@DriftAccessor(tables: [Notes])
class NotesDao extends DatabaseAccessor<AppDatabase> with _$NotesDaoMixin {
  NotesDao(super.db);

  Future<String?> _getCurrentUserEmail() async {
    final secureStorage = SecureStorageService();
    return await secureStorage.getValue('cached_email');
  }

  Future<List<Map<String, dynamic>>> getAllNotes({bool includeDeleted = false}) async {
    final userEmail = await _getCurrentUserEmail();
    
    if (userEmail == null) {
      print('⚠️ No user logged in, returning empty notes list');
      return [];
    }
    
    final query = select(notes)
      ..where((n) => n.userEmail.equals(userEmail));
      
    if (!includeDeleted) {
      query.where((n) => n.syncStatus.isNotValue('deleted'));
    }
      
    query.orderBy([(n) => OrderingTerm.desc(n.updatedAt)]);
    
    final results = await query.get();
    return results.map((note) => {
      'id': note.id,
      'title': note.title,
      'content': note.content,
      'user_email': note.userEmail,
      'createdAt': note.createdAt,
      'updatedAt': note.updatedAt,
      'syncStatus': note.syncStatus,
      'lastSyncedAt': note.lastSyncedAt,
      'localId': note.localId,
      'serverId': note.serverId,
    }).toList();
  }

  Future<Map<String, dynamic>?> getNoteByLocalId(String localId) async {
    final query = select(notes)
      ..where((n) => n.localId.equals(localId))
      ..limit(1);
    
    final results = await query.get();
    if (results.isEmpty) return null;
    
    final note = results.first;
    return {
      'id': note.id,
      'title': note.title,
      'content': note.content,
      'user_email': note.userEmail,
      'createdAt': note.createdAt,
      'updatedAt': note.updatedAt,
      'syncStatus': note.syncStatus,
      'lastSyncedAt': note.lastSyncedAt,
      'localId': note.localId,
      'serverId': note.serverId,
    };
  }

  Future<Map<String, dynamic>?> getNoteByServerId(int serverId) async {
    final query = select(notes)
      ..where((n) => n.serverId.equals(serverId))
      ..limit(1);
    
    final results = await query.get();
    if (results.isEmpty) return null;
    
    final note = results.first;
    return {
      'id': note.id,
      'title': note.title,
      'content': note.content,
      'user_email': note.userEmail,
      'createdAt': note.createdAt,
      'updatedAt': note.updatedAt,
      'syncStatus': note.syncStatus,
      'lastSyncedAt': note.lastSyncedAt,
      'localId': note.localId,
      'serverId': note.serverId,
    };
  }

  Future<int> insertNote(Map<String, dynamic> note) async {
    final userEmail = await _getCurrentUserEmail();
    
    if (userEmail == null) {
      throw Exception('No user logged in. Cannot create note.');
    }
    
    return await into(notes).insert(NotesCompanion.insert(
      title: note['title'] ?? '',
      content: note['content'] ?? '',
      userEmail: userEmail,
      createdAt: Value(note['createdAt']),
      updatedAt: Value(note['updatedAt']),
      syncStatus: Value(note['syncStatus'] ?? 'pending'),
      lastSyncedAt: Value(note['lastSyncedAt']),
      localId: Value(note['localId']),
      serverId: Value(note['serverId']),
    ));
  }

  Future<int> updateNote(String localId, Map<String, dynamic> note) async {
    return await (update(notes)
      ..where((n) => n.localId.equals(localId)))
      .write(NotesCompanion(
        title: note.containsKey('title') ? Value(note['title']) : const Value.absent(),
        content: note.containsKey('content') ? Value(note['content']) : const Value.absent(),
        updatedAt: note.containsKey('updatedAt') ? Value(note['updatedAt']) : const Value.absent(),
        syncStatus: note.containsKey('syncStatus') ? Value(note['syncStatus']) : const Value.absent(),
        lastSyncedAt: note.containsKey('lastSyncedAt') ? Value(note['lastSyncedAt']) : const Value.absent(),
        serverId: note.containsKey('serverId') ? Value(note['serverId']) : const Value.absent(),
      ));
  }

  Future<int> deleteNote(String localId) async {
    final entry = await (select(notes)..where((n) => n.localId.equals(localId))).getSingleOrNull();
    if (entry == null) return 0;

    // Always soft delete to allow sync to catch up
    return await (update(notes)..where((n) => n.localId.equals(localId))).write(
      NotesCompanion(
        syncStatus: const Value('deleted'),
        lastSyncedAt: Value(DateTime.now().toIso8601String()),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> getDeletedNotes() async {
    final query = select(notes)
      ..where((n) => n.syncStatus.equals('deleted'));
    
    final results = await query.get();
    return results.map((note) => {
      'id': note.id,
      'title': note.title,
      'content': note.content,
      'user_email': note.userEmail,
      'createdAt': note.createdAt,
      'updatedAt': note.updatedAt,
      'syncStatus': note.syncStatus,
      'lastSyncedAt': note.lastSyncedAt,
      'localId': note.localId,
      'serverId': note.serverId,
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getUnsyncedNotes() async {
    final query = select(notes)
      ..where((n) => n.syncStatus.isIn(['pending', 'error']));
    
    final results = await query.get();
    return results.map((note) => {
      'id': note.id,
      'title': note.title,
      'content': note.content,
      'user_email': note.userEmail,
      'createdAt': note.createdAt,
      'updatedAt': note.updatedAt,
      'syncStatus': note.syncStatus,
      'lastSyncedAt': note.lastSyncedAt,
      'localId': note.localId,
      'serverId': note.serverId,
    }).toList();
  }

  Future<int> hardDeleteNote(String localId) async {
    return await (delete(notes)..where((n) => n.localId.equals(localId))).go();
  }

  Future<int> updateNoteSyncStatus(
    String localId, 
    String status, {
    int? serverId,
  }) async {
    return await (update(notes)
      ..where((n) => n.localId.equals(localId)))
      .write(NotesCompanion(
        syncStatus: Value(status),
        lastSyncedAt: Value(DateTime.now().toIso8601String()),
        serverId: serverId != null ? Value(serverId) : const Value.absent(),
      ));
  }

  Future<List<Map<String, dynamic>>> searchNotes(String queryStr) async {
    final userEmail = await _getCurrentUserEmail();
    if (userEmail == null) return [];

    final query = select(notes)
      ..where((n) => n.userEmail.equals(userEmail) & (n.title.contains(queryStr) | n.content.contains(queryStr)))
      ..orderBy([(n) => OrderingTerm.desc(n.updatedAt)]);

    final results = await query.get();
    return results.map((note) => {
      'id': note.id,
      'title': note.title,
      'content': note.content,
      'user_email': note.userEmail,
      'createdAt': note.createdAt,
      'updatedAt': note.updatedAt,
      'syncStatus': note.syncStatus,
      'lastSyncedAt': note.lastSyncedAt,
      'localId': note.localId,
      'serverId': note.serverId,
    }).toList();
  }

  Future<void> deleteNotesByUser(String email) async {
    await (delete(notes)..where((n) => n.userEmail.equals(email))).go();
  }
}
