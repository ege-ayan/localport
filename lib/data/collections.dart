import 'package:isar_community/isar.dart';

part 'collections.g.dart';

@collection
class TransferRecord {
  Id id = Isar.autoIncrement;

  @Index()
  late String transferId;

  late String peerId;
  late String peerName;
  late String fileName;
  late int fileSize;
  late String direction;
  late String status;
  late DateTime createdAt;
}

@collection
class TrustedDevice {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String deviceId;

  late String name;
  late DateTime lastSeen;
}

@collection
class AppLog {
  Id id = Isar.autoIncrement;

  late String level;
  late String message;
  late DateTime createdAt;
}
