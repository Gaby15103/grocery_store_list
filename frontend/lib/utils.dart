import 'package:hive/hive.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

class Utils {
  final Box<String> _metaBox = Hive.box<String>('metadata');
  Future<String> getUniqueDeviceId() async {
    String? existingId = _metaBox.get('deviceId');
    if (existingId != null) return existingId;

    var deviceInfo = DeviceInfoPlugin();
    String id = 'unknown';


    if (Platform.isLinux) {
      var linuxInfo = await deviceInfo.linuxInfo;
      id = linuxInfo.machineId ?? 'linux_unknown';
    } else if (Platform.isAndroid) {
      var androidInfo = await deviceInfo.androidInfo;
      id = androidInfo.id;
    } else if (Platform.isIOS) {
      var iosInfo = await deviceInfo.iosInfo;
      id = iosInfo.identifierForVendor ?? 'ios_unknown';
    }

    await _metaBox.put('deviceId', id);
    return id;
  }
}