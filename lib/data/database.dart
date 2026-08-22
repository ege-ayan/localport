import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'collections.dart';

class AppDatabase {
  AppDatabase(this.isar);

  final Isar isar;

  static Future<AppDatabase> open() async {
    final dir = await getApplicationSupportDirectory();
    final isar = await Isar.open(
      [TransferRecordSchema, TrustedDeviceSchema, AppLogSchema],
      directory: dir.path,
      name: 'localport',
    );
    return AppDatabase(isar);
  }

  Future<void> upsertTrusted(String deviceId, String name) async {
    await isar.writeTxn(() async {
      final existing = await isar.trustedDevices
          .filter()
          .deviceIdEqualTo(deviceId)
          .findFirst();
      final row = existing ?? TrustedDevice()
        ..deviceId = deviceId;
      row
        ..name = name
        ..lastSeen = DateTime.now().toUtc();
      await isar.trustedDevices.put(row);
    });
  }

  Future<Set<String>> trustedIds() async {
    final rows = await isar.trustedDevices.where().findAll();
    return rows.map((e) => e.deviceId).toSet();
  }

  Future<void> addTransfer(TransferRecord record) async {
    await isar.writeTxn(() async {
      await isar.transferRecords.put(record);
    });
  }

  Future<List<TransferRecord>> recentTransfers({int limit = 50}) {
    return isar.transferRecords
        .where()
        .sortByCreatedAtDesc()
        .limit(limit)
        .findAll();
  }

  Future<void> log(String level, String message) async {
    await isar.writeTxn(() async {
      await isar.appLogs.put(
        AppLog()
          ..level = level
          ..message = message
          ..createdAt = DateTime.now().toUtc(),
      );
    });
  }
}
