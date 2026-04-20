import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase Auth 기반 인증 서비스
class AuthService {
  SupabaseClient get _supabase => Supabase.instance.client;

  User? get currentUser => _supabase.auth.currentUser;
  bool get isLoggedIn => _supabase.auth.currentUser != null;

  Stream<AuthState> get authStateChanges =>
      _supabase.auth.onAuthStateChange;

  // ---------- Google ----------
  Future<void> signInWithGoogle() async {
    final webClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? '';

    final googleSignIn = GoogleSignIn(
      serverClientId: webClientId.isNotEmpty ? webClientId : null,
    );
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) throw Exception('Google 로그인이 취소되었습니다');

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;

    if (idToken == null) throw Exception('Google ID 토큰을 가져올 수 없습니다');

    await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  // ---------- Kakao ----------
  Future<void> signInWithKakao() async {
    await _supabase.auth.signInWithOAuth(
      OAuthProvider.kakao,
      redirectTo: 'io.booknet.booknet://login-callback',
      scopes: 'profile_nickname',
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
  }

  // ---------- Naver ----------
  Future<void> signInWithNaver() async {
    final clientId = dotenv.env['NAVER_CLIENT_ID'] ?? '';
    final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
    final callbackUrl = '$supabaseUrl/functions/v1/auth-naver-callback';
    final redirectUri = Uri.encodeComponent(callbackUrl);
    final state = DateTime.now().millisecondsSinceEpoch.toString();

    final authUrl =
        'https://nid.naver.com/oauth2.0/authorize'
        '?response_type=code'
        '&client_id=$clientId'
        '&redirect_uri=$redirectUri'
        '&state=$state';

    // ASWebAuthenticationSession으로 OAuth 처리
    // Edge Function이 io.booknet.booknet:// 으로 리다이렉트하면 자동 캡처
    final resultUrl = await FlutterWebAuth2.authenticate(
      url: authUrl,
      callbackUrlScheme: 'io.booknet.booknet',
    );

    final uri = Uri.parse(resultUrl);
    final error = uri.queryParameters['error'];
    if (error != null) {
      throw Exception('네이버 로그인 실패: $error');
    }

    final naverToken = uri.queryParameters['naver_token'];
    if (naverToken == null) {
      throw Exception('네이버 로그인에 실패했습니다');
    }

    // Edge Function으로 세션 즉시 생성
    final res = await _supabase.functions.invoke(
      'auth-naver',
      body: {'access_token': naverToken},
    );

    if (res.status != 200) {
      throw Exception(res.data['error'] ?? '네이버 로그인 처리에 실패했습니다');
    }

    final refreshToken = res.data['refresh_token'] as String;
    await _supabase.auth.setSession(refreshToken);
  }

  // ---------- Sign Out ----------
  Future<void> signOut() async {
    await _supabase.auth.signOut();
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
  }

  /// 프로필 존재 여부 확인 (첫 로그인 판단)
  Future<bool> hasProfile() async {
    final uid = currentUser?.id;
    if (uid == null) return false;
    try {
      final rows = await _supabase.from('profiles').select('id').eq('id', uid);
      return (rows as List).isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
