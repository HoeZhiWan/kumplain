// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBNPRGEgkgYsWlJQt6XlT16GENFerB0B2I',
    appId: '1:475117397868:web:4dc586fa052cfde0aaf549',
    messagingSenderId: '475117397868',
    projectId: 'kumplain-9c47a',
    authDomain: 'kumplain-9c47a.firebaseapp.com',
    storageBucket: 'kumplain-9c47a.firebasestorage.app',
    measurementId: 'G-9N8RHTL78H',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA_3nyMclqwESPa5IZ-op5lSRTAZifXQUs',
    appId: '1:475117397868:android:bfcea913739f0c06aaf549',
    messagingSenderId: '475117397868',
    projectId: 'kumplain-9c47a',
    storageBucket: 'kumplain-9c47a.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyB7xeYc8ysyP8IJlQQdmsbx7v7L2DBVh_c',
    appId: '1:475117397868:ios:3a8935026e837fb5aaf549',
    messagingSenderId: '475117397868',
    projectId: 'kumplain-9c47a',
    storageBucket: 'kumplain-9c47a.firebasestorage.app',
    iosBundleId: 'com.example.kumplainV1',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyB7xeYc8ysyP8IJlQQdmsbx7v7L2DBVh_c',
    appId: '1:475117397868:ios:3a8935026e837fb5aaf549',
    messagingSenderId: '475117397868',
    projectId: 'kumplain-9c47a',
    storageBucket: 'kumplain-9c47a.firebasestorage.app',
    iosBundleId: 'com.example.kumplainV1',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBNPRGEgkgYsWlJQt6XlT16GENFerB0B2I',
    appId: '1:475117397868:web:1edaaebe25129839aaf549',
    messagingSenderId: '475117397868',
    projectId: 'kumplain-9c47a',
    authDomain: 'kumplain-9c47a.firebaseapp.com',
    storageBucket: 'kumplain-9c47a.firebasestorage.app',
    measurementId: 'G-HB342EHNJ3',
  );
}
