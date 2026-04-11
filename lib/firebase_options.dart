// Firebase 설정 파일
// `flutterfire configure` 명령으로 자동 생성됩니다.
// 아래는 플레이스홀더이며, 실제 Firebase 프로젝트 생성 후 교체해야 합니다.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions: $defaultTargetPlatform 미지원',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBvxEqkzQF9qYtfWLmrSP2tR6rVXRwu0Ig',
    appId: '1:253436970513:android:07653307ef279b2a02d3b0',
    messagingSenderId: '253436970513',
    projectId: 'booknet-suntae',
    storageBucket: 'booknet-suntae.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCzkh97WrZTqufDdi78VvXf36cbPCVw91s',
    appId: '1:253436970513:ios:46fe8b0a250e8ee302d3b0',
    messagingSenderId: '253436970513',
    projectId: 'booknet-suntae',
    storageBucket: 'booknet-suntae.firebasestorage.app',
    iosBundleId: 'io.booknet.booknet',
  );

}