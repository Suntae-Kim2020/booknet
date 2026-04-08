import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/book.dart';
import '../../providers.dart';

final myBooksProvider = FutureProvider<List<Book>>((ref) async {
  return ref.read(supabaseRepoProvider).myBooks();
});

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(myBooksProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('내 책장'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'ISBN 스캔',
            onPressed: () => context.push('/scan'),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '도서 검색',
            onPressed: () => context.push('/search'),
          ),
        ],
      ),
      body: books.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Text('등록된 책이 없습니다.\n오른쪽 위에서 검색/스캔으로 등록하세요.',
                  textAlign: TextAlign.center),
            );
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final b = list[i];
              return ListTile(
                leading: b.coverUrl != null
                    ? Image.network(b.coverUrl!, width: 40, fit: BoxFit.cover)
                    : const Icon(Icons.book),
                title: Text(b.title),
                subtitle: Text('${b.author} · ${b.publisher}'),
                trailing: Wrap(spacing: 4, children: [
                  if (b.isRead) const Icon(Icons.check_circle, size: 18),
                  if (b.isForSale)
                    const Icon(Icons.local_offer, size: 18),
                  if (b.wantsDiscussion)
                    const Icon(Icons.forum, size: 18),
                ]),
                onTap: () => context.push('/book/${b.id}'),
              );
            },
          );
        },
      ),
    );
  }
}
