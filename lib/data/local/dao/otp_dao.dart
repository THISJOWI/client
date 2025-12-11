import 'package:drift/drift.dart';
import '../app_database.dart';
import '../secure_storage_service.dart';

part 'otp_dao.g.dart';

@DriftAccessor(tables: [OtpEntries])
class OtpDao extends DatabaseAccessor<AppDatabase> with _$OtpDaoMixin {
  OtpDao(AppDatabase db) : super(db);

  Future<String?> _getCurrentUserEmail() async {
    final secureStorage = SecureStorageService();
    return await secureStorage.getValue('cached_email');
  }

  Future<List<Map<String, dynamic>>> getAllOtpEntries() async {
    final userEmail = await _getCurrentUserEmail();
    
    if (userEmail == null) {
      print('⚠️ No user logged in, returning empty OTP entries list');
      return [];
    }
    
    final query = select(otpEntries)
      ..where((o) => o.userId.equals(userEmail))
      ..orderBy([(o) => OrderingTerm.asc(o.name)]);
    
    final results = await query.get();
    return results.map((otp) => {
      'id': otp.id,
      'name': otp.name,
      'issuer': otp.issuer,
      'secret': otp.secret,
      'digits': otp.digits,
      'period': otp.period,
      'algorithm': otp.algorithm,
      'type': otp.type,
      'userId': otp.userId,
      'createdAt': otp.createdAt,
      'updatedAt': otp.updatedAt,
      'syncStatus': otp.syncStatus,
      'lastSyncedAt': otp.lastSyncedAt,
      'serverId': otp.serverId,
    }).toList();
  }

  Future<Map<String, dynamic>?> getOtpEntryById(String id) async {
    final query = select(otpEntries)
      ..where((o) => o.id.equals(id))
      ..limit(1);
    
    final results = await query.get();
    if (results.isEmpty) return null;
    
    final otp = results.first;
    return {
      'id': otp.id,
      'name': otp.name,
      'issuer': otp.issuer,
      'secret': otp.secret,
      'digits': otp.digits,
      'period': otp.period,
      'algorithm': otp.algorithm,
      'type': otp.type,
      'userId': otp.userId,
      'createdAt': otp.createdAt,
      'updatedAt': otp.updatedAt,
      'syncStatus': otp.syncStatus,
      'lastSyncedAt': otp.lastSyncedAt,
      'serverId': otp.serverId,
    };
  }

  Future<Map<String, dynamic>?> getOtpEntryByServerId(String serverId) async {
    final query = select(otpEntries)
      ..where((o) => o.serverId.equals(serverId))
      ..limit(1);
    
    final results = await query.get();
    if (results.isEmpty) return null;
    
    final otp = results.first;
    return {
      'id': otp.id,
      'name': otp.name,
      'issuer': otp.issuer,
      'secret': otp.secret,
      'digits': otp.digits,
      'period': otp.period,
      'algorithm': otp.algorithm,
      'type': otp.type,
      'userId': otp.userId,
      'createdAt': otp.createdAt,
      'updatedAt': otp.updatedAt,
      'syncStatus': otp.syncStatus,
      'lastSyncedAt': otp.lastSyncedAt,
      'serverId': otp.serverId,
    };
  }

  Future<int> insertOtpEntry(Map<String, dynamic> entry) async {
    final userEmail = await _getCurrentUserEmail();
    
    if (userEmail == null) {
      throw Exception('No user logged in. Cannot create OTP entry.');
    }
    
    return await into(otpEntries).insert(OtpEntriesCompanion.insert(
      id: entry['id'],
      name: entry['name'],
      issuer: Value(entry['issuer']),
      secret: entry['secret'],
      digits: Value(entry['digits'] ?? 6),
      period: Value(entry['period'] ?? 30),
      algorithm: Value(entry['algorithm'] ?? 'SHA1'),
      type: Value(entry['type'] ?? 'totp'),
      userId: Value(userEmail),
      createdAt: entry['createdAt'] ?? DateTime.now().toIso8601String(),
      updatedAt: entry['updatedAt'] ?? DateTime.now().toIso8601String(),
      syncStatus: Value(entry['syncStatus'] ?? 'pending'),
      lastSyncedAt: Value(entry['lastSyncedAt']),
      serverId: Value(entry['serverId']),
    ));
  }

  Future<int> updateOtpEntry(String id, Map<String, dynamic> entry) async {
    return await (update(otpEntries)
      ..where((o) => o.id.equals(id)))
      .write(OtpEntriesCompanion(
        name: entry.containsKey('name') ? Value(entry['name']) : const Value.absent(),
        issuer: entry.containsKey('issuer') ? Value(entry['issuer']) : const Value.absent(),
        secret: entry.containsKey('secret') ? Value(entry['secret']) : const Value.absent(),
        digits: entry.containsKey('digits') ? Value(entry['digits']) : const Value.absent(),
        period: entry.containsKey('period') ? Value(entry['period']) : const Value.absent(),
        algorithm: entry.containsKey('algorithm') ? Value(entry['algorithm']) : const Value.absent(),
        type: entry.containsKey('type') ? Value(entry['type']) : const Value.absent(),
        updatedAt: entry.containsKey('updatedAt') ? Value(entry['updatedAt']) : const Value.absent(),
        syncStatus: entry.containsKey('syncStatus') ? Value(entry['syncStatus']) : const Value.absent(),
        lastSyncedAt: entry.containsKey('lastSyncedAt') ? Value(entry['lastSyncedAt']) : const Value.absent(),
        serverId: entry.containsKey('serverId') ? Value(entry['serverId']) : const Value.absent(),
      ));
  }

  Future<int> deleteOtpEntry(String id) async {
    return await (delete(otpEntries)
      ..where((o) => o.id.equals(id)))
      .go();
  }

  Future<List<Map<String, dynamic>>> getUnsyncedOtpEntries() async {
    final query = select(otpEntries)
      ..where((o) => o.syncStatus.isIn(['pending', 'error']));
    
    final results = await query.get();
    return results.map((otp) => {
      'id': otp.id,
      'name': otp.name,
      'issuer': otp.issuer,
      'secret': otp.secret,
      'digits': otp.digits,
      'period': otp.period,
      'algorithm': otp.algorithm,
      'type': otp.type,
      'userId': otp.userId,
      'createdAt': otp.createdAt,
      'updatedAt': otp.updatedAt,
      'syncStatus': otp.syncStatus,
      'lastSyncedAt': otp.lastSyncedAt,
      'serverId': otp.serverId,
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getDeletedOtpEntries() async {
    final query = select(otpEntries)
      ..where((o) => o.syncStatus.equals('deleted'));
    
    final results = await query.get();
    return results.map((otp) => {
      'id': otp.id,
      'name': otp.name,
      'issuer': otp.issuer,
      'secret': otp.secret,
      'digits': otp.digits,
      'period': otp.period,
      'algorithm': otp.algorithm,
      'type': otp.type,
      'userId': otp.userId,
      'createdAt': otp.createdAt,
      'updatedAt': otp.updatedAt,
      'syncStatus': otp.syncStatus,
      'lastSyncedAt': otp.lastSyncedAt,
      'serverId': otp.serverId,
    }).toList();
  }

  Future<List<Map<String, dynamic>>> searchOtpEntries(String queryStr) async {
    final userEmail = await _getCurrentUserEmail();
    if (userEmail == null) return [];

    final query = select(otpEntries)
      ..where((o) => o.userId.equals(userEmail) & (o.name.contains(queryStr) | o.issuer.contains(queryStr)))
      ..orderBy([(o) => OrderingTerm.desc(o.updatedAt)]);

    final results = await query.get();
    return results.map((otp) => {
      'id': otp.id,
      'name': otp.name,
      'issuer': otp.issuer,
      'secret': otp.secret,
      'digits': otp.digits,
      'period': otp.period,
      'algorithm': otp.algorithm,
      'type': otp.type,
      'userId': otp.userId,
      'createdAt': otp.createdAt,
      'updatedAt': otp.updatedAt,
      'syncStatus': otp.syncStatus,
      'lastSyncedAt': otp.lastSyncedAt,
      'serverId': otp.serverId,
    }).toList();
  }
}
