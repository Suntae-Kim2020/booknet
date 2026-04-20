import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _handleLogin(Future<void> Function() loginFn) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await loginFn();
      // OAuth는 브라우저를 열고 바로 리턴됨.
      // 로그인 완료 후 authStateChanges → router redirect가 자동 처리.
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.read(authServiceProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.menu_book, size: 80, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text('Booknet',
                  style: theme.textTheme.headlineLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('나만의 서재를 만들어보세요',
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 48),
              if (_error != null) ...[
                Text(_error!,
                    style: TextStyle(color: theme.colorScheme.error),
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
              ],
              if (_loading)
                const CircularProgressIndicator()
              else ...[
                _SocialLoginButton(
                  label: '카카오로 시작하기',
                  color: const Color(0xFFFEE500),
                  textColor: const Color(0xFF191919),
                  icon: Icons.chat_bubble,
                  onPressed: () => _handleLogin(auth.signInWithKakao),
                ),
                const SizedBox(height: 12),
                _SocialLoginButton(
                  label: '네이버로 시작하기',
                  color: const Color(0xFF03C75A),
                  textColor: Colors.white,
                  icon: Icons.north_east,
                  onPressed: () => _handleLogin(auth.signInWithNaver),
                ),
                const SizedBox(height: 12),
                _SocialLoginButton(
                  label: 'Google로 시작하기',
                  color: Colors.white,
                  textColor: Colors.black87,
                  icon: Icons.g_mobiledata,
                  onPressed: () => _handleLogin(auth.signInWithGoogle),
                  border: true,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialLoginButton extends StatelessWidget {
  const _SocialLoginButton({
    required this.label,
    required this.color,
    required this.textColor,
    required this.icon,
    required this.onPressed,
    this.border = false,
  });

  final String label;
  final Color color;
  final Color textColor;
  final IconData icon;
  final VoidCallback onPressed;
  final bool border;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: textColor),
        label: Text(label, style: TextStyle(color: textColor, fontSize: 16)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          elevation: border ? 0 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: border
                ? const BorderSide(color: Colors.black26)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}
