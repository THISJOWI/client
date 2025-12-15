import 'package:drift/drift.dart';
import '../app_database.dart';

part 'auth_dao.g.dart';

@DriftAccessor(tables: [Users])
class AuthDao extends DatabaseAccessor<AppDatabase> with _$AuthDaoMixin {
  AuthDao(super.db);

  Future<User?> getUserByEmail(String email) async {
    return (select(users)..where((u) => u.email.equals(email))).getSingleOrNull();
  }

  Future<void> insertOrUpdateUser(User user) async {
    await into(users).insertOnConflictUpdate(user);
  }

  Future<void> updateLastLogin(String email, String timestamp) async {
    await (update(users)..where((u) => u.email.equals(email))).write(
      UsersCompanion(lastLogin: Value(timestamp)),
    );
  }
  
  Future<void> updateToken(String email, String token) async {
    await (update(users)..where((u) => u.email.equals(email))).write(
      UsersCompanion(token: Value(token)),
    );
  }

  Future<int> deleteUser(String email) async {
    return await (delete(users)..where((u) => u.email.equals(email))).go();
  }
}
