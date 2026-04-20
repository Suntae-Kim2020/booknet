import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/memo.dart';
import '../../providers.dart';

final bookMemosProvider =
    FutureProvider.family<List<Memo>, String>((ref, bookId) async {
  return ref.read(memoRepoProvider).memosForBook(bookId);
});

class MemoListScreen extends ConsumerWidget {
  const MemoListScreen({super.key, required this.bookId, this.bookTitle});

  final String bookId;
  final String? bookTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memos = ref.watch(bookMemosProvider(bookId));
    final tts = ref.read(ttsServiceProvider);
    final df = DateFormat('yyyy-MM-dd HH:mm');
    final myUid = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(bookTitle != null ? '$bookTitle 메모' : '메모'),
        actions: [
          memos.maybeWhen(
            data: (list) => list.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.play_circle_outline),
                    tooltip: '전체 듣기',
                    onPressed: () => tts.speakAll(
                        list.map((m) => m.content).toList()),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/book/$bookId/memo/edit'),
        child: const Icon(Icons.add),
      ),
      body: memos.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('메모가 없습니다.\n아래 + 버튼으로 추가하세요.',
                textAlign: TextAlign.center));
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, i) {
              final m = list[i];
              final isMine = myUid != null && m.userId == myUid;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: InkWell(
                  onTap: isMine
                      ? () => context.push('/book/$bookId/memo/edit', extra: m)
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (m.pageNumber != null)
                              Chip(
                                label: Text('p.${m.pageNumber}'),
                                visualDensity: VisualDensity.compact,
                              ),
                            if (m.pageNumber != null) const SizedBox(width: 8),
                            Icon(
                              m.isShared ? Icons.public : Icons.lock,
                              size: 16,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                            const Spacer(),
                            Text(df.format(m.createdAt),
                                style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(m.content),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.volume_up, size: 20),
                              tooltip: '읽어주기',
                              onPressed: () => tts.speak(m.content),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              tooltip: isMine ? '삭제' : '본인 메모만 삭제할 수 있어요',
                              color: isMine ? null : Colors.grey,
                              onPressed: () async {
                                if (!isMine) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text('본인이 작성한 메모만 삭제할 수 있습니다.')));
                                  return;
                                }
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('메모 삭제'),
                                    content: const Text('이 메모를 삭제할까요?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('취소'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('삭제'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true) {
                                  try {
                                    await ref
                                        .read(memoRepoProvider)
                                        .deleteMemo(m.id);
                                    ref.invalidate(
                                        bookMemosProvider(bookId));
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                              content: Text('삭제 실패: $e')));
                                    }
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
