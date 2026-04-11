import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/profile.dart';
import '../../providers.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _nicknameCtrl = TextEditingController();
  final _regionCtrl = TextEditingController();
  String? _gender;
  int? _birthYear;
  bool _saving = false;

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _regionCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nickname = _nicknameCtrl.text.trim();
    if (nickname.isEmpty) return;

    setState(() => _saving = true);
    final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
    final now = DateTime.now();
    final profile = Profile(
      id: uid,
      nickname: nickname,
      region: _regionCtrl.text.trim().isEmpty ? null : _regionCtrl.text.trim(),
      gender: _gender,
      birthYear: _birthYear,
      createdAt: now,
      updatedAt: now,
    );
    await ref.read(profileRepoProvider).upsertProfile(profile);
    if (mounted) context.go('/library');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('프로필 설정')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            controller: _nicknameCtrl,
            decoration: const InputDecoration(
              labelText: '닉네임 *',
              hintText: '다른 사용자에게 보여질 이름',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _regionCtrl,
            decoration: const InputDecoration(
              labelText: '지역',
              hintText: '예: 서울 강남구',
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _gender,
            decoration: const InputDecoration(labelText: '성별'),
            items: const [
              DropdownMenuItem(value: 'male', child: Text('남성')),
              DropdownMenuItem(value: 'female', child: Text('여성')),
            ],
            onChanged: (v) => setState(() => _gender = v),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _birthYear,
            decoration: const InputDecoration(labelText: '출생년도'),
            items: [
              for (int y = DateTime.now().year - 10;
                  y >= DateTime.now().year - 80;
                  y--)
                DropdownMenuItem(value: y, child: Text('$y년')),
            ],
            onChanged: (v) => setState(() => _birthYear = v),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('시작하기'),
          ),
        ],
      ),
    );
  }
}
