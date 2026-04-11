import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers.dart';
import '../library/library_screen.dart';
import '../memo/memo_list_screen.dart';

class BookDetailScreen extends ConsumerWidget {
  const BookDetailScreen({super.key, required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(myBooksProvider);
    final memos = ref.watch(bookMemosProvider(bookId));
    final tts = ref.read(ttsServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('책 정보')),
      body: books.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          final b = list.where((x) => x.id == bookId).firstOrNull;
          if (b == null) return const Center(child: Text('찾을 수 없음'));
          final repo = ref.read(bookRepoProvider);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (b.coverUrl != null)
                Center(child: Image.network(b.coverUrl!, height: 200)),
              const SizedBox(height: 12),
              Text(b.title, style: Theme.of(context).textTheme.titleLarge),
              Text('${b.author} · ${b.publisher}'),
              const Divider(height: 32),
              SwitchListTile(
                title: const Text('읽음 표시'),
                value: b.isRead,
                onChanged: (v) async {
                  await repo.markRead(b.id, v);
                  ref.invalidate(myBooksProvider);
                },
              ),
              SwitchListTile(
                title: const Text('판매 중'),
                value: b.isForSale,
                onChanged: (v) async {
                  await repo.setForSale(b.id, v);
                  ref.invalidate(myBooksProvider);
                },
              ),
              SwitchListTile(
                title: const Text('독서토론 희망'),
                value: b.wantsDiscussion,
                onChanged: (v) async {
                  await repo.setWantsDiscussion(b.id, v);
                  ref.invalidate(myBooksProvider);
                },
              ),
              if (b.description != null) ...[
                const SizedBox(height: 16),
                Text(b.description!),
              ],

              // --- 메모 섹션 ---
              const Divider(height: 32),
              Row(
                children: [
                  Text('메모',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => context.push('/book/$bookId/memos',
                        extra: b.title),
                    icon: const Icon(Icons.list, size: 18),
                    label: const Text('전체보기'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: '메모 추가',
                    onPressed: () =>
                        context.push('/book/$bookId/memo/edit'),
                  ),
                ],
              ),
              memos.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text('$e'),
                data: (memoList) {
                  if (memoList.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('아직 메모가 없습니다.',
                          style: TextStyle(color: Colors.grey)),
                    );
                  }
                  // 최근 3개만 미리보기
                  final preview = memoList.take(3).toList();
                  return Column(
                    children: preview.map((m) {
                      return Card(
                        child: ListTile(
                          title: Text(m.content,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          subtitle: m.pageNumber != null
                              ? Text('p.${m.pageNumber}')
                              : null,
                          trailing: IconButton(
                            icon: const Icon(Icons.volume_up, size: 20),
                            onPressed: () => tts.speak(m.content),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
