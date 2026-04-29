import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';

class AppConfig {
  static late String apiUrl;

  static Future<void> init() async {
    if (kIsWeb) {
      apiUrl = kReleaseMode ? "https://api-grocery.gaby15103.org" : "http://localhost:3000";
      return;
    }

    if (kReleaseMode) {
      apiUrl = "https://api-grocery.gaby15103.org";
      return;
    }

    if (Platform.isAndroid) {
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;

      if (androidInfo.isPhysicalDevice) {
        apiUrl = "https://api-grocery.gaby15103.org";
      } else {
        apiUrl = "http://10.0.2.2:3000";
      }
    } else {
      apiUrl = "http://localhost:3000";
    }
  }
}
