import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/book.dart';
import '../../providers.dart';

final myBooksProvider = FutureProvider<List<Book>>((ref) async {
  return ref.read(bookRepoProvider).myBooks();
});

enum BookFilter { all, reading, read, unread }

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  BookFilter _filter = BookFilter.all;

  List<Book> _applyFilter(List<Book> books) {
    switch (_filter) {
      case BookFilter.all:
        return books;
      case BookFilter.read:
        return books.where((b) => b.isRead).toList();
      case BookFilter.unread:
        return books.where((b) => !b.isRead).toList();
      case BookFilter.reading:
        return books.where((b) => !b.isRead && b.readAt != null).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final books = ref.watch(myBooksProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('내 책장'),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt),
            tooltip: '표지 촬영',
            onPressed: () => context.push('/photo'),
          ),
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
      body: Column(
        children: [
          // 필터 탭
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: BookFilter.values.map((f) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_filterLabel(f)),
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
                  ),
                );
              }).toList(),
            ),
          ),
          // 책 목록
          Expanded(
            child: books.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('오류: $e')),
              data: (allBooks) {
                final list = _applyFilter(allBooks);
                if (list.isEmpty) {
                  return Center(
                    child: Text(
                      allBooks.isEmpty
                          ? '등록된 책이 없습니다.\n오른쪽 위에서 검색/스캔으로 등록하세요.'
                          : '이 필터에 해당하는 책이 없습니다.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final b = list[i];
                    return ListTile(
                      leading: b.coverUrl != null
                          ? Image.network(b.coverUrl!,
                              width: 40, fit: BoxFit.cover)
                          : const Icon(Icons.book),
                      title: Text(b.title),
                      subtitle: Text('${b.author} · ${b.publisher}'),
                      trailing: Wrap(spacing: 4, children: [
                        if (b.isRead)
                          const Icon(Icons.check_circle, size: 18),
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
          ),
        ],
      ),
    );
  }

  String _filterLabel(BookFilter f) {
    switch (f) {
      case BookFilter.all:
        return '전체';
      case BookFilter.reading:
        return '읽는 중';
      case BookFilter.read:
        return '읽음';
      case BookFilter.unread:
        return '안읽음';
    }
  }
}
