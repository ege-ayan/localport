import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'identity_name.dart';

class DeviceIdentity {
  const DeviceIdentity({required this.id, required this.name});

  final String id;
  final String name;

  static const _idKey = 'device_id';
  static const _nameKey = 'device_name';

  static Future<DeviceIdentity> load() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_idKey);
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await prefs.setString(_idKey, id);
    }
    var name = prefs.getString(_nameKey);
    if (name == null || name.isEmpty) {
      name = _defaultName();
      await prefs.setString(_nameKey, name);
    }
    return DeviceIdentity(id: id, name: name);
  }

  static Future<void> saveName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, name.trim());
  }

  static String _defaultName() => defaultDeviceName();
}
