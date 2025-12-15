import 'package:drift/drift.dart';
import '../app_database.dart';

part 'sync_queue_dao.g.dart';

@DriftAccessor(tables: [SyncQueue])
class SyncQueueDao extends DatabaseAccessor<AppDatabase> with _$SyncQueueDaoMixin {
  SyncQueueDao(super.db);

  Future<void> queueItem(String entityType, String entityId, String action, String data) async {
    await into(syncQueue).insert(SyncQueueCompanion.insert(
      entityType: entityType,
      entityId: entityId,
      action: action,
      data: Value(data),
      createdAt: DateTime.now().toIso8601String(),
    ));
  }

  Future<void> removeItem(String entityType, String entityId) async {
    await (delete(syncQueue)
      ..where((s) => s.entityType.equals(entityType) & s.entityId.equals(entityId)))
      .go();
  }

  Future<bool> isQueued(String entityType, String entityId) async {
    final result = await (select(syncQueue)
      ..where((s) => s.entityType.equals(entityType) & s.entityId.equals(entityId))
      ..limit(1))
      .get();
    return result.isNotEmpty;
  }
}
