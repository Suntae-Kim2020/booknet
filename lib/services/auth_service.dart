import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;
import 'package:flutter_naver_login/flutter_naver_login.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Firebase Auth + Supabase 세션 동기화
class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final Dio _dio = Dio();

  supa.SupabaseClient get _supabase => supa.Supabase.instance.client;

  User? get currentUser => _firebaseAuth.currentUser;
  bool get isLoggedIn => _firebaseAuth.currentUser != null;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // ---------- Google ----------
  Future<void> signInWithGoogle() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return;
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    await _firebaseAuth.signInWithCredential(credential);
    await _syncSupabaseSession();
  }

  // ---------- Kakao ----------
  Future<void> signInWithKakao() async {
    kakao.OAuthToken token;
    if (await kakao.isKakaoTalkInstalled()) {
      token = await kakao.UserApi.instance.loginWithKakaoTalk();
    } else {
      token = await kakao.UserApi.instance.loginWithKakaoAccount();
    }
    // Firebase Custom Token 발급 (Supabase Edge Function)
    final firebaseToken = await _exchangeKakaoToken(token.accessToken);
    await _firebaseAuth.signInWithCustomToken(firebaseToken);
    await _syncSupabaseSession();
  }

  // ---------- Naver ----------
  Future<void> signInWithNaver() async {
    final result = await FlutterNaverLogin.logIn();
    if (result.status != NaverLoginStatus.loggedIn) return;
    final accessToken = result.accessToken.accessToken;
    // Firebase Custom Token 발급 (Supabase Edge Function)
    final firebaseToken = await _exchangeNaverToken(accessToken);
    await _firebaseAuth.signInWithCustomToken(firebaseToken);
    await _syncSupabaseSession();
  }

  // ---------- Sign Out ----------
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    await _supabase.auth.signOut();
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    try {
      await FlutterNaverLogin.logOut();
    } catch (_) {}
  }

  // ---------- Internal ----------

  /// Firebase ID 토큰 → Supabase Edge Function → Supabase 세션
  Future<void> _syncSupabaseSession() async {
    final idToken = await _firebaseAuth.currentUser?.getIdToken();
    if (idToken == null) return;

    final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
    final res = await _dio.post(
      '$supabaseUrl/functions/v1/auth-firebase',
      data: {'id_token': idToken},
    );

    final accessToken = res.data['access_token'] as String;
    await _supabase.auth.setSession(accessToken);
  }

  Future<String> _exchangeKakaoToken(String kakaoAccessToken) async {
    final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
    final res = await _dio.post(
      '$supabaseUrl/functions/v1/auth-kakao',
      data: {'access_token': kakaoAccessToken},
    );
    return res.data['firebase_token'] as String;
  }

  Future<String> _exchangeNaverToken(String naverAccessToken) async {
    final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
    final res = await _dio.post(
      '$supabaseUrl/functions/v1/auth-naver',
      data: {'access_token': naverAccessToken},
    );
    return res.data['firebase_token'] as String;
  }
}
