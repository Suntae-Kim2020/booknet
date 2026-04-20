import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/profile.dart';
import '../../providers.dart';
import '../discussion/region_picker.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _nicknameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _regionCtrl = TextEditingController();
  String? _gender;
  int? _birthYear;
  bool _saving = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    try {
      final profile = await ref.read(profileRepoProvider).myProfile();
      if (!mounted) return;
      if (profile != null) {
        _nicknameCtrl.text = profile.nickname ?? '';
        _phoneCtrl.text = profile.phone ?? '';
        _regionCtrl.text = profile.region ?? '';
        _gender = profile.gender;
        _birthYear = profile.birthYear;
      }
    } catch (_) {
      // 프로필이 아직 없는 경우 무시
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _phoneCtrl.dispose();
    _regionCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nickname = _nicknameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    if (nickname.isEmpty) {
      setState(() => _error = '닉네임을 입력해주세요.');
      return;
    }
    if (phone.isEmpty) {
      setState(() => _error = '전화번호를 입력해주세요.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
    if (uid.isEmpty) {
      setState(() {
        _error = '로그인 세션이 없습니다. 다시 로그인해주세요.';
        _saving = false;
      });
      return;
    }
    final consent =
        GoRouterState.of(context).extra as Map<String, dynamic>? ?? {};
    final now = DateTime.now();

    final profile = Profile(
      id: uid,
      nickname: nickname,
      phone: phone,
      region: _regionCtrl.text.trim().isEmpty ? null : _regionCtrl.text.trim(),
      gender: _gender,
      birthYear: _birthYear,
      agreedTerms: consent['agreedTerms'] as bool? ?? true,
      agreedPrivacy: consent['agreedPrivacy'] as bool? ?? true,
      agreedMarketing: consent['agreedMarketing'] as bool? ?? false,
      agreedAt: now,
      createdAt: now,
      updatedAt: now,
    );

    try {
      await ref.read(profileRepoProvider).upsertProfile(profile);
      if (mounted) context.go('/library');
    } catch (e) {
      setState(() => _error = '저장 실패: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('프로필 설정')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('프로필 설정')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('거의 다 됐어요!',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('서비스 이용에 필요한 정보를 입력해주세요.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 24),
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_error!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer)),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _nicknameCtrl,
            decoration: const InputDecoration(
              labelText: '닉네임 *',
              hintText: '다른 사용자에게 보여질 이름',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: '전화번호 *',
              hintText: '010-1234-5678',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () async {
              final picked = await showRegionPicker(context,
                  initial: _regionCtrl.text);
              if (picked != null) {
                setState(() => _regionCtrl.text = picked);
              }
            },
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: '지역 (선택)',
                border: const OutlineInputBorder(),
                suffixIcon: _regionCtrl.text.isEmpty
                    ? const Icon(Icons.chevron_right)
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () =>
                            setState(() => _regionCtrl.text = ''),
                      ),
              ),
              child: Text(
                _regionCtrl.text.isEmpty
                    ? '시/군/구 또는 동/읍/면 선택'
                    : _regionCtrl.text,
                style: TextStyle(
                  color: _regionCtrl.text.isEmpty
                      ? Theme.of(context).hintColor
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _gender,
            decoration: const InputDecoration(
              labelText: '성별 (선택)',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'male', child: Text('남성')),
              DropdownMenuItem(value: 'female', child: Text('여성')),
            ],
            onChanged: (v) => setState(() => _gender = v),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _birthYear,
            decoration: const InputDecoration(
              labelText: '출생년도 (선택)',
              border: OutlineInputBorder(),
            ),
            items: [
              for (int y = DateTime.now().year - 10;
                  y >= DateTime.now().year - 80;
                  y--)
                DropdownMenuItem(value: y, child: Text('$y년')),
            ],
            onChanged: (v) => setState(() => _birthYear = v),
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('시작하기', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
