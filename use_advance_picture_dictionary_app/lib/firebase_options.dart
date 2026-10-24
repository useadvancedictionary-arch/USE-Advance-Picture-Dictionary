// File generated for USE Advance Picture Dictionary (Dedicated Firebase Project).
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return ios;
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return windows;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCdb5Br9FDQkl3DPWV0raSNBnuK0zpOk60',
    appId: '1:105971080286:android:e2f08d09652f842ca068cf',
    messagingSenderId: '105971080286',
    projectId: 'use-advance-picture-dict-1861e',
    storageBucket: 'use-advance-picture-dict-1861e.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD186vZ2z804uKW9fyuyk5kIJDw--YDfzc',
    appId: '1:105971080286:web:387599eb7c2243bfa068cf',
    messagingSenderId: '105971080286',
    projectId: 'use-advance-picture-dict-1861e',
    authDomain: 'use-advance-picture-dict-1861e.firebaseapp.com',
    storageBucket: 'use-advance-picture-dict-1861e.firebasestorage.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCdb5Br9FDQkl3DPWV0raSNBnuK0zpOk60',
    appId: '1:105971080286:android:e2f08d09652f842ca068cf',
    messagingSenderId: '105971080286',
    projectId: 'use-advance-picture-dict-1861e',
    storageBucket: 'use-advance-picture-dict-1861e.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCdb5Br9FDQkl3DPWV0raSNBnuK0zpOk60',
    appId: '1:105971080286:android:e2f08d09652f842ca068cf',
    messagingSenderId: '105971080286',
    projectId: 'use-advance-picture-dict-1861e',
    storageBucket: 'use-advance-picture-dict-1861e.firebasestorage.app',
  );
}
