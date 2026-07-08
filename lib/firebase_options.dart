// This file is a placeholder. 
// You should generate this file using the FlutterFire CLI:
// flutterfire configure

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
        'you can reconfigure this by running the FlutterFire CLI again.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.windows:
        return windows;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBWJPKtuVV9Sz0slgjQmmvtcIz3Uxmd9uc',
    appId: '1:33603645555:android:473ae584c497a4e185ba06',
    messagingSenderId: '33603645555',
    projectId: 'saqer1-448ea',
    storageBucket: 'saqer1-448ea.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBWJPKtuVV9Sz0slgjQmmvtcIz3Uxmd9uc',
    appId: '1:33603645555:ios:placeholder', // Placeholder as not in json
    messagingSenderId: '33603645555',
    projectId: 'saqer1-448ea',
    storageBucket: 'saqer1-448ea.firebasestorage.app',
    iosBundleId: 'com.example.smart_school1',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBWJPKtuVV9Sz0slgjQmmvtcIz3Uxmd9uc',
    appId: '1:33603645555:web:placeholder', // Placeholder
    messagingSenderId: '33603645555',
    projectId: 'saqer1-448ea',
    storageBucket: 'saqer1-448ea.firebasestorage.app',
  );
}
