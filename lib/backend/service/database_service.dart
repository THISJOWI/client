import 'dart:async';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path/path.dart' as path_pkg;
import 'package:path_provider/path_provider.dart';
import 'secure_storage_service.dart';

part 'database_service.g.dart';

/// Table definitions for drift
class Notes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get content => text()();
  TextColumn get userEmail => text().named('user_email')();
  TextColumn get createdAt => text().nullable()();
  TextColumn get updatedAt => text().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  TextColumn get lastSyncedAt => text().nullable()();
  TextColumn get localId => text().unique().nullable()();
  IntColumn get serverId => integer().nullable()();
}

class Passwords extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get username => text()();
  TextColumn get password => text()();
  TextColumn get website => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get userId => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  TextColumn get lastSyncedAt => text().nullable()();
  TextColumn get serverId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class SyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityType => text().named('entity_type')();
  TextColumn get entityId => text().named('entity_id')();
  TextColumn get action => text()();
  TextColumn get data => text().nullable()();
  TextColumn get createdAt => text()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
}

class Users extends Table {
  TextColumn get email => text()();
  TextColumn get passwordHash => text().named('password_hash')();
  TextColumn get token => text().nullable()();
  TextColumn get lastLogin => text().nullable().named('last_login')();

  @override
  Set<Column> get primaryKey => {email};
}

/// Database class using Drift - compatible with all platforms
@DriftDatabase(tables: [Notes, Passwords, SyncQueue, Users])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.createTable(users);
        }
        if (from < 3) {
          await m.addColumn(notes, notes.userEmail);
          await customStatement(
            "UPDATE notes SET user_email = 'unknown@local' WHERE user_email IS NULL",
          );
        }
      },
    );
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'thisjowi_encrypted',
      native: const DriftNativeOptions(
        databaseDirectory: getApplicationSupportDirectory,
      ),
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    );
  }
}

/// Service to manage local database using Drift
/// Compatible with iOS, Android, macOS, Windows, Linux, and Web
/// 
/// This service handles:
/// - Database initialization
/// - CRUD operations for notes and passwords
/// - Sync status management
/// - Data persistence for offline mode
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static AppDatabase? _database;
  
  factory DatabaseService() => _instance;
  
  DatabaseService._internal();

  /// Get the database instance, initializing if needed
  Future<AppDatabase> get database async {
    if (_database != null) return _database!;
    _database = AppDatabase();
    return _database!;
  }

  /// Get current logged-in user email
  Future<String?> getCurrentUserEmail() async {
    final secureStorage = SecureStorageService();
    return await secureStorage.getValue('cached_email');
  }

  // ============ NOTES OPERATIONS ============

  /// Get all notes from local database (filtered by current user)
  Future<List<Map<String, dynamic>>> getAllNotes() async {
    final db = await database;
    final userEmail = await getCurrentUserEmail();
    
    if (userEmail == null) {
      print('⚠️ No user logged in, returning empty notes list');
      return [];
    }
    
    final query = db.select(db.notes)
      ..where((n) => n.userEmail.equals(userEmail))
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

  /// Get a note by local ID
  Future<Map<String, dynamic>?> getNoteByLocalId(String localId) async {
    final db = await database;
    final query = db.select(db.notes)
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

  /// Get a note by server ID
  Future<Map<String, dynamic>?> getNoteByServerId(int serverId) async {
    final db = await database;
    final query = db.select(db.notes)
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

  /// Insert a new note
  Future<int> insertNote(Map<String, dynamic> note) async {
    final db = await database;
    final userEmail = await getCurrentUserEmail();
    
    if (userEmail == null) {
      throw Exception('No user logged in. Cannot create note.');
    }
    
    return await db.into(db.notes).insert(NotesCompanion.insert(
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

  /// Update a note
  Future<int> updateNote(String localId, Map<String, dynamic> note) async {
    final db = await database;
    
    return await (db.update(db.notes)
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

  /// Delete a note
  Future<int> deleteNote(String localId) async {
    final db = await database;
    return await (db.delete(db.notes)
      ..where((n) => n.localId.equals(localId)))
      .go();
  }

  /// Get notes that need to be synced
  Future<List<Map<String, dynamic>>> getUnsyncedNotes() async {
    final db = await database;
    final query = db.select(db.notes)
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

  /// Update note sync status
  Future<int> updateNoteSyncStatus(
    String localId, 
    String status, {
    int? serverId,
  }) async {
    final db = await database;
    
    return await (db.update(db.notes)
      ..where((n) => n.localId.equals(localId)))
      .write(NotesCompanion(
        syncStatus: Value(status),
        lastSyncedAt: Value(DateTime.now().toIso8601String()),
        serverId: serverId != null ? Value(serverId) : const Value.absent(),
      ));
  }

  // ============ PASSWORDS OPERATIONS ============

  /// Get all passwords from local database (filtered by current user)
  Future<List<Map<String, dynamic>>> getAllPasswords() async {
    final db = await database;
    final userEmail = await getCurrentUserEmail();
    
    if (userEmail == null) {
      print('⚠️ No user logged in, returning empty passwords list');
      return [];
    }
    
    final query = db.select(db.passwords)
      ..where((p) => p.userId.equals(userEmail))
      ..orderBy([(p) => OrderingTerm.desc(p.updatedAt)]);
    
    final results = await query.get();
    return results.map((pwd) => {
      'id': pwd.id,
      'title': pwd.title,
      'username': pwd.username,
      'password': pwd.password,
      'website': pwd.website,
      'notes': pwd.notes,
      'userId': pwd.userId,
      'createdAt': pwd.createdAt,
      'updatedAt': pwd.updatedAt,
      'syncStatus': pwd.syncStatus,
      'lastSyncedAt': pwd.lastSyncedAt,
      'serverId': pwd.serverId,
    }).toList();
  }

  /// Get a password by ID
  Future<Map<String, dynamic>?> getPasswordById(String id) async {
    final db = await database;
    final query = db.select(db.passwords)
      ..where((p) => p.id.equals(id))
      ..limit(1);
    
    final results = await query.get();
    if (results.isEmpty) return null;
    
    final pwd = results.first;
    return {
      'id': pwd.id,
      'title': pwd.title,
      'username': pwd.username,
      'password': pwd.password,
      'website': pwd.website,
      'notes': pwd.notes,
      'userId': pwd.userId,
      'createdAt': pwd.createdAt,
      'updatedAt': pwd.updatedAt,
      'syncStatus': pwd.syncStatus,
      'lastSyncedAt': pwd.lastSyncedAt,
      'serverId': pwd.serverId,
    };
  }

  /// Insert a new password
  Future<int> insertPassword(Map<String, dynamic> password) async {
    final db = await database;
    final userEmail = await getCurrentUserEmail();
    
    if (userEmail == null) {
      throw Exception('No user logged in. Cannot create password.');
    }
    
    return await db.into(db.passwords).insert(PasswordsCompanion.insert(
      id: password['id'] ?? '',
      title: password['title'] ?? '',
      username: password['username'] ?? '',
      password: password['password'] ?? '',
      website: Value(password['website']),
      notes: Value(password['notes']),
      userId: Value(userEmail),
      createdAt: password['createdAt'] ?? DateTime.now().toIso8601String(),
      updatedAt: password['updatedAt'] ?? DateTime.now().toIso8601String(),
      syncStatus: Value(password['syncStatus'] ?? 'pending'),
      lastSyncedAt: Value(password['lastSyncedAt']),
      serverId: Value(password['serverId']),
    ));
  }

  /// Update a password
  Future<int> updatePassword(String id, Map<String, dynamic> password) async {
    final db = await database;
    
    return await (db.update(db.passwords)
      ..where((p) => p.id.equals(id)))
      .write(PasswordsCompanion(
        title: password.containsKey('title') ? Value(password['title']) : const Value.absent(),
        username: password.containsKey('username') ? Value(password['username']) : const Value.absent(),
        password: password.containsKey('password') ? Value(password['password']) : const Value.absent(),
        website: password.containsKey('website') ? Value(password['website']) : const Value.absent(),
        notes: password.containsKey('notes') ? Value(password['notes']) : const Value.absent(),
        updatedAt: password.containsKey('updatedAt') ? Value(password['updatedAt']) : const Value.absent(),
        syncStatus: password.containsKey('syncStatus') ? Value(password['syncStatus']) : const Value.absent(),
        lastSyncedAt: password.containsKey('lastSyncedAt') ? Value(password['lastSyncedAt']) : const Value.absent(),
        serverId: password.containsKey('serverId') ? Value(password['serverId']) : const Value.absent(),
      ));
  }

  /// Delete a password
  Future<int> deletePassword(String id) async {
    final db = await database;
    return await (db.delete(db.passwords)
      ..where((p) => p.id.equals(id)))
      .go();
  }

  /// Get passwords that need to be synced
  Future<List<Map<String, dynamic>>> getUnsyncedPasswords() async {
    final db = await database;
    final query = db.select(db.passwords)
      ..where((p) => p.syncStatus.isIn(['pending', 'error']));
    
    final results = await query.get();
    return results.map((pwd) => {
      'id': pwd.id,
      'title': pwd.title,
      'username': pwd.username,
      'password': pwd.password,
      'website': pwd.website,
      'notes': pwd.notes,
      'userId': pwd.userId,
      'createdAt': pwd.createdAt,
      'updatedAt': pwd.updatedAt,
      'syncStatus': pwd.syncStatus,
      'lastSyncedAt': pwd.lastSyncedAt,
      'serverId': pwd.serverId,
    }).toList();
  }

  /// Update password sync status
  Future<int> updatePasswordSyncStatus(
    String id,
    String status, {
    String? serverId,
  }) async {
    final db = await database;
    
    return await (db.update(db.passwords)
      ..where((p) => p.id.equals(id)))
      .write(PasswordsCompanion(
        syncStatus: Value(status),
        lastSyncedAt: Value(DateTime.now().toIso8601String()),
        serverId: serverId != null ? Value(serverId) : const Value.absent(),
      ));
  }

  // ============ SYNC QUEUE OPERATIONS ============

  /// Add an item to the sync queue
  Future<int> addToSyncQueue({
    required String entityType,
    required String entityId,
    required String action,
    String? data,
  }) async {
    final db = await database;
    return await db.into(db.syncQueue).insert(SyncQueueCompanion.insert(
      entityType: entityType,
      entityId: entityId,
      action: action,
      data: Value(data),
      createdAt: DateTime.now().toIso8601String(),
      attempts: const Value(0),
    ));
  }

  /// Get all items in the sync queue
  Future<List<Map<String, dynamic>>> getSyncQueue() async {
    final db = await database;
    final query = db.select(db.syncQueue)
      ..orderBy([(s) => OrderingTerm.asc(s.createdAt)]);
    
    final results = await query.get();
    return results.map((item) => {
      'id': item.id,
      'entity_type': item.entityType,
      'entity_id': item.entityId,
      'action': item.action,
      'data': item.data,
      'createdAt': item.createdAt,
      'attempts': item.attempts,
    }).toList();
  }

  /// Remove an item from the sync queue
  Future<int> removeFromSyncQueue(int id) async {
    final db = await database;
    return await (db.delete(db.syncQueue)
      ..where((s) => s.id.equals(id)))
      .go();
  }

  /// Increment sync attempts
  Future<int> incrementSyncAttempts(int id) async {
    final db = await database;
    final current = await (db.select(db.syncQueue)
      ..where((s) => s.id.equals(id)))
      .getSingleOrNull();
    
    if (current == null) return 0;
    
    return await (db.update(db.syncQueue)
      ..where((s) => s.id.equals(id)))
      .write(SyncQueueCompanion(
        attempts: Value(current.attempts + 1),
      ));
  }

  // ============ UTILITY OPERATIONS ============

  /// Clear all data (for logout)
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete(db.notes).go();
    await db.delete(db.passwords).go();
    await db.delete(db.syncQueue).go();
    await db.delete(db.users).go();
  }

  /// Close database connection
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  /// Delete the database (for testing purposes)
  Future<void> deleteDatabaseFile() async {
    // Close existing connection first
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    
    try {
      final directory = await getApplicationSupportDirectory();
      final path = path_pkg.join(directory.path, 'thisjowi_encrypted.sqlite');
      
      final dbFile = File(path);
      if (await dbFile.exists()) {
        await dbFile.delete();
        print('🗑️ Database deleted: $path');
      } else {
        print('⚠️ Database file not found: $path');
      }
      
      // Also delete journal file if exists
      final journalFile = File('$path-journal');
      if (await journalFile.exists()) {
        await journalFile.delete();
        print('🗑️ Journal file deleted');
      }
    } catch (e) {
      print('⚠️ Could not delete database file: $e');
    }
  }

  /// Check if database needs migration (for debugging)
  Future<bool> needsMigration() async {
    try {
      final db = await database;
      final userEmail = await getCurrentUserEmail();
      
      if (userEmail == null) return false;
      
      // Try to query with user_email filter
      final query = db.select(db.notes)
        ..where((n) => n.userEmail.equals(userEmail))
        ..limit(1);
      await query.get();
      
      return false; // Migration not needed
    } catch (e) {
      return true; // Migration needed
    }
  }
}
