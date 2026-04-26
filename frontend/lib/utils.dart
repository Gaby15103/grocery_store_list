import 'package:hive/hive.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class Utils {
  final Box<String> _metaBox = Hive.box<String>('metadata');

  Future<String> getUniqueDeviceId() async {
    String? existingId = _metaBox.get('deviceId');
    if (existingId != null) return existingId;

    var deviceInfo = DeviceInfoPlugin();
    String id = 'unknown';

    try {
      if (kIsWeb) {
        var webInfo = await deviceInfo.webBrowserInfo;
        id = 'web_${webInfo.vendor}_${webInfo.userAgent.hashCode}';
      } else {
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
      }
    } catch (e) {
      print("Error getting device info: $e");
      id = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    }

    await _metaBox.put('deviceId', id);
    return id;
  }
}