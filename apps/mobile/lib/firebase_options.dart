// File generated for Flutter Firebase options.
// NEVER put Firebase Service Account keys or Private Keys in this file.
// Only client-side public identifiers (apiKey, appId, messagingSenderId, projectId) belong here.

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
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_API_KEY', defaultValue: 'AIzaSy_Placeholder_Key_For_Gen_Lang_Client'),
    appId: String.fromEnvironment('FIREBASE_WEB_APP_ID', defaultValue: '1:239423034:web:qyranyotla00000000'),
    messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID', defaultValue: '239423034'),
    projectId: String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: 'gen-lang-client-0239423034'),
    authDomain: String.fromEnvironment('FIREBASE_AUTH_DOMAIN', defaultValue: 'gen-lang-client-0239423034.firebaseapp.com'),
    storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET', defaultValue: 'gen-lang-client-0239423034.appspot.com'),
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_API_KEY', defaultValue: 'AIzaSy_Placeholder_Key_For_Gen_Lang_Client'),
    appId: String.fromEnvironment('FIREBASE_ANDROID_APP_ID', defaultValue: '1:239423034:android:qyranyotla00000000'),
    messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID', defaultValue: '239423034'),
    projectId: String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: 'gen-lang-client-0239423034'),
    storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET', defaultValue: 'gen-lang-client-0239423034.appspot.com'),
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_API_KEY', defaultValue: 'AIzaSy_Placeholder_Key_For_Gen_Lang_Client'),
    appId: String.fromEnvironment('FIREBASE_IOS_APP_ID', defaultValue: '1:239423034:ios:qyranyotla00000000'),
    messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID', defaultValue: '239423034'),
    projectId: String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: 'gen-lang-client-0239423034'),
    storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET', defaultValue: 'gen-lang-client-0239423034.appspot.com'),
    iosBundleId: String.fromEnvironment('IOS_BUNDLE_ID', defaultValue: 'app.quranyutla'),
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_API_KEY', defaultValue: 'AIzaSy_Placeholder_Key_For_Gen_Lang_Client'),
    appId: String.fromEnvironment('FIREBASE_IOS_APP_ID', defaultValue: '1:239423034:ios:qyranyotla00000000'),
    messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID', defaultValue: '239423034'),
    projectId: String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: 'gen-lang-client-0239423034'),
    storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET', defaultValue: 'gen-lang-client-0239423034.appspot.com'),
    iosBundleId: String.fromEnvironment('IOS_BUNDLE_ID', defaultValue: 'app.quranyutla'),
  );
}
