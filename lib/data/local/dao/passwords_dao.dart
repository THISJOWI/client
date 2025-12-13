import 'package:drift/drift.dart';
import '../app_database.dart';
import '../secure_storage_service.dart';

part 'passwords_dao.g.dart';

@DriftAccessor(tables: [Passwords])
class PasswordsDao extends DatabaseAccessor<AppDatabase> with _$PasswordsDaoMixin {
  PasswordsDao(AppDatabase db) : super(db);

  Future<String?> _getCurrentUserEmail() async {
    final secureStorage = SecureStorageService();
    return await secureStorage.getValue('cached_email');
  }

  Future<List<Map<String, dynamic>>> getAllPasswords({bool includeDeleted = false}) async {
    final userEmail = await _getCurrentUserEmail();
    
    if (userEmail == null) {
      print('⚠️ No user logged in, returning empty passwords list');
      return [];
    }
    
    final query = select(passwords)
      ..where((p) => p.userId.equals(userEmail));
      
    if (!includeDeleted) {
      query.where((p) => p.syncStatus.isNotValue('deleted'));
    }
      
    query.orderBy([(p) => OrderingTerm.desc(p.updatedAt)]);
    
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

  Future<Map<String, dynamic>?> getPasswordById(String id) async {
    final query = select(passwords)
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

  Future<Map<String, dynamic>?> getPasswordByServerId(String serverId) async {
    final query = select(passwords)
      ..where((p) => p.serverId.equals(serverId))
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

  Future<int> insertPassword(Map<String, dynamic> password) async {
    final userEmail = await _getCurrentUserEmail();
    
    if (userEmail == null) {
      throw Exception('No user logged in. Cannot create password.');
    }
    
    return await into(passwords).insert(PasswordsCompanion.insert(
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

  Future<int> updatePassword(String id, Map<String, dynamic> password) async {
    return await (update(passwords)
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

  Future<int> deletePassword(String id) async {
    final entry = await (select(passwords)..where((p) => p.id.equals(id))).getSingleOrNull();
    if (entry == null) return 0;

    // Always soft delete to allow sync to catch up
    return await (update(passwords)..where((p) => p.id.equals(id))).write(
      PasswordsCompanion(
        syncStatus: const Value('deleted'),
        lastSyncedAt: Value(DateTime.now().toIso8601String()),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> getDeletedPasswords() async {
    final query = select(passwords)
      ..where((p) => p.syncStatus.equals('deleted'));
    
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

  Future<List<Map<String, dynamic>>> getUnsyncedPasswords() async {
    final query = select(passwords)
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

  Future<int> hardDeletePassword(String id) async {
    return await (delete(passwords)..where((p) => p.id.equals(id))).go();
  }

  Future<int> updatePasswordSyncStatus(
    String id,
    String status, {
    String? serverId,
  }) async {
    return await (update(passwords)
      ..where((p) => p.id.equals(id)))
      .write(PasswordsCompanion(
        syncStatus: Value(status),
        lastSyncedAt: Value(DateTime.now().toIso8601String()),
        serverId: serverId != null ? Value(serverId) : const Value.absent(),
      ));
  }

  Future<List<Map<String, dynamic>>> searchPasswords(String queryStr) async {
    final userEmail = await _getCurrentUserEmail();
    if (userEmail == null) return [];

    final query = select(passwords)
      ..where((p) => p.userId.equals(userEmail) & (p.title.contains(queryStr) | p.username.contains(queryStr)))
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

  Future<void> deletePasswordsByUser(String email) async {
    await (delete(passwords)..where((p) => p.userId.equals(email))).go();
  }
}
