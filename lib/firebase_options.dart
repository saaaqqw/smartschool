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
    apiKey: 'AIzaSyAZrmpoyXpxQesLhwCfwkYpowNNLd7F_FQ',
    appId: '1:662993550710:android:bac1abbaca7edf7a014e57',
    messagingSenderId: '662993550710',
    projectId: 'saqer-b5e7d',
    storageBucket: 'saqer-b5e7d.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAZrmpoyXpxQesLhwCfwkYpowNNLd7F_FQ',
    appId: '1:662993550710:ios:placeholder', // Placeholder as not in json
    messagingSenderId: '662993550710',
    projectId: 'saqer-b5e7d',
    storageBucket: 'saqer-b5e7d.firebasestorage.app',
    iosBundleId: 'com.example.smart_school1',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAZrmpoyXpxQesLhwCfwkYpowNNLd7F_FQ',
    appId: '1:662993550710:web:placeholder', // Placeholder
    messagingSenderId: '662993550710',
    projectId: 'saqer-b5e7d',
    storageBucket: 'saqer-b5e7d.firebasestorage.app',
  );
}
