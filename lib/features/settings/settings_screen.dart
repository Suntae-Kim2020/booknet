import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/profile.dart';
import '../../providers.dart';

final myProfileProvider = FutureProvider<Profile?>((ref) async {
  return ref.read(profileRepoProvider).myProfile();
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('더보기')),
      body: ListView(
        children: [
          // 프로필 헤더
          profile.when(
            loading: () => const SizedBox(height: 80),
            error: (_, __) => const SizedBox.shrink(),
            data: (p) => ListTile(
              leading: CircleAvatar(
                child: Text(p?.nickname?.isNotEmpty == true
                    ? p!.nickname![0]
                    : '?'),
              ),
              title: Text(p?.nickname ?? '닉네임 없음'),
              subtitle: Text(p?.region ?? ''),
              trailing: const Icon(Icons.edit),
              onTap: () => context.push('/profile/setup'),
            ),
          ),
          const Divider(),
          // 메뉴 항목들
          ListTile(
            leading: const Icon(Icons.rate_review),
            title: const Text('한줄평'),
            onTap: () => context.push('/reviews'),
          ),
          ListTile(
            leading: const Icon(Icons.note),
            title: const Text('메모 검색'),
            onTap: () => context.push('/memos/search'),
          ),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('알림'),
            onTap: () => context.push('/notifications'),
          ),
          const Divider(),
          // 공유 설정
          profile.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (p) {
              final current = p?.sharingDefault ?? 'all';
              return ListTile(
                leading: const Icon(Icons.share),
                title: const Text('기본 공유 설정'),
                subtitle: Text(_sharingLabel(current)),
                onTap: () => _showSharingDialog(context, ref, p),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title:
                const Text('로그아웃', style: TextStyle(color: Colors.red)),
            onTap: () async {
              await ref.read(authServiceProvider).signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
    );
  }

  String _sharingLabel(String value) {
    switch (value) {
      case 'all':
        return '모두 공개';
      case 'friends':
        return '친구에게만';
      case 'none':
        return '비공개';
      default:
        return value;
    }
  }

  void _showSharingDialog(
      BuildContext context, WidgetRef ref, Profile? profile) {
    if (profile == null) return;
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('기본 공유 설정'),
        children: [
          for (final opt in ['all', 'friends', 'none'])
            SimpleDialogOption(
              onPressed: () async {
                Navigator.pop(ctx);
                final updated =
                    profile.copyWith(sharingDefault: opt);
                await ref.read(profileRepoProvider).upsertProfile(updated);
                ref.invalidate(myProfileProvider);
              },
              child: Text(_sharingLabel(opt)),
            ),
        ],
      ),
    );
  }
}
