import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../library/library_screen.dart';

class BookDetailScreen extends ConsumerWidget {
  const BookDetailScreen({super.key, required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(myBooksProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('책 정보')),
      body: books.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          final b = list.where((x) => x.id == bookId).firstOrNull;
          if (b == null) return const Center(child: Text('찾을 수 없음'));
          final repo = ref.read(supabaseRepoProvider);
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
            ],
          );
        },
      ),
    );
  }
}
