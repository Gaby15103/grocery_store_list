import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';

class AppConfig {
  static late String apiUrl;

  static Future<void> init() async {
    // 1. Web Configuration
    if (kIsWeb) {
      apiUrl = kReleaseMode ? "https://apigrocery.gaby15103.org" : "http://localhost:3000";
      return;
    }

    // 2. Production / Release Mode (Universal for iOS & Android)
    if (kReleaseMode) {
      apiUrl = "https://apigrocery.gaby15103.org";
      return;
    }

    // 3. Development Mode
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      // 10.0.2.2 is the special alias for the Android Emulator to reach your Mac
      apiUrl = androidInfo.isPhysicalDevice 
          ? "https://apigrocery.gaby15103.org" 
          : "http://10.0.2.2:3000";
    } 
    else if (Platform.isIOS) {
      IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      
      if (iosInfo.isPhysicalDevice) {
        // IMPORTANT: Change this to your Mac's Local IP (e.g., 192.168.x.x) 
        // to test on a real iPhone, or use your production URL.
        apiUrl = "https://apigrocery.gaby15103.org"; 
      } else {
        // iOS Simulators can use localhost
        apiUrl = "http://localhost:3000";
      }
    } else {
      apiUrl = "http://localhost:3000";
    }
  }
}