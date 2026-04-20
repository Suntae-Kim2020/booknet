import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/profile.dart';
import '../../providers.dart';
import '../../services/csv_export_service.dart';

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
            loading: () => const SizedBox(height: 100),
            error: (_, __) => const SizedBox.shrink(),
            data: (p) => Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Text(
                      p?.nickname?.isNotEmpty == true ? p!.nickname![0] : '?',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p?.nickname ?? '닉네임 없음',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        if ((p?.region ?? '').isNotEmpty)
                          Text(p!.region!, style: const TextStyle(color: Colors.grey)),
                        if (p?.gender != null || p?.birthYear != null)
                          Text(
                            [
                              if (p?.gender == 'male') '남성',
                              if (p?.gender == 'female') '여성',
                              if (p?.birthYear != null) '${p!.birthYear}년생',
                            ].join(' · '),
                            style: const TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                      ],
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      await context.push('/profile/setup');
                      ref.invalidate(myProfileProvider);
                    },
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('수정'),
                  ),
                ],
              ),
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
          ListTile(
            leading: const Icon(Icons.sports_esports),
            title: const Text('게임'),
            subtitle: const Text('룰렛, 주사위, 사다리타기'),
            onTap: () => context.push('/games'),
          ),
          ListTile(
            leading: const Icon(Icons.file_download),
            title: const Text('데이터 내보내기'),
            subtitle: const Text('독서기록, 메모, 한줄평 CSV'),
            onTap: () => _showExportSheet(context),
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

  void _showExportSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('데이터 내보내기 (CSV)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.book),
              title: const Text('내 독서기록'),
              subtitle: const Text('읽은 책 목록, 읽기 상태, 날짜'),
              onTap: () async {
                Navigator.pop(ctx);
                _exportWithLoading(context, '독서기록', CsvExportService.exportMyBooks);
              },
            ),
            ListTile(
              leading: const Icon(Icons.note),
              title: const Text('내 메모'),
              subtitle: const Text('책별 메모 내용, 페이지, 날짜'),
              onTap: () async {
                Navigator.pop(ctx);
                _exportWithLoading(context, '메모', CsvExportService.exportMyMemos);
              },
            ),
            ListTile(
              leading: const Icon(Icons.star),
              title: const Text('내 한줄평'),
              subtitle: const Text('별점, 한줄평 내용, 날짜'),
              onTap: () async {
                Navigator.pop(ctx);
                _exportWithLoading(context, '한줄평', CsvExportService.exportMyReviews);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _exportWithLoading(
      BuildContext context, String name, Future<dynamic> Function() export) async {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$name 내보내기 중...')));
    try {
      final file = await export();
      if (context.mounted) {
        await CsvExportService.shareFile(file, context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('내보내기 실패: $e')));
      }
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
