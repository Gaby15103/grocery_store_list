import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError('DefaultFirebaseOptions are not supported for this platform.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDDEehP_JQhcBISrpw7_UnKAund5SF8h-A',
    appId: '1:795185183313:web:2ca88543749649c2429670',
    messagingSenderId: '795185183313',
    projectId: 'grocery-master-98f71',
    authDomain: 'grocery-master-98f71.firebaseapp.com',
    storageBucket: 'grocery-master-98f71.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDuWR6eNF6C9NZgzLBkHD18p3-Bb3G3xfo',
    appId: '1:795185183313:android:8185c8eeabff8a7b429670',
    messagingSenderId: 'XXXXXXXX',
    projectId: 'grocery-master-98f71',
    storageBucket: 'grocery-master-98f71.firebasestorage.app',
  );
}