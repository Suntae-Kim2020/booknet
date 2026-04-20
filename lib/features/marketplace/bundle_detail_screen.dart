import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/sale_bundle.dart';
import '../../providers.dart';
import '../book_detail/book_detail_screen.dart';
import '../library/library_screen.dart';
import 'marketplace_screen.dart';

final bundleDetailProvider =
    FutureProvider.family<SaleBundle?, String>((ref, bundleId) async {
  ref.watch(authStateProvider);
  ref.watch(myBundlesProvider);
  return ref.read(bundleRepoProvider).getBundle(bundleId);
});

class BundleDetailScreen extends ConsumerWidget {
  const BundleDetailScreen({super.key, required this.bundleId});

  final String bundleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundle = ref.watch(bundleDetailProvider(bundleId));
    final fmt = NumberFormat.decimalPattern();

    return Scaffold(
      appBar: AppBar(
        title: const Text('꾸러미 상세'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: '꾸러미 삭제',
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('꾸러미 삭제'),
                  content: const Text('이 꾸러미를 삭제하시겠습니까?\n포함된 책들은 서재에 남습니다.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('취소'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('삭제'),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                await ref.read(bundleRepoProvider).deleteBundle(bundleId);
                ref.invalidate(myBundlesProvider);
                ref.invalidate(myBooksProvider);
                if (context.mounted) context.pop();
              }
            },
          ),
        ],
      ),
      body: bundle.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (b) {
          if (b == null) return const Center(child: Text('꾸러미를 찾을 수 없습니다'));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(b.title,
                  style: Theme.of(context).textTheme.titleLarge),
              if (b.description != null) ...[
                const SizedBox(height: 4),
                Text(b.description!),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Chip(label: Text(b.statusLabel)),
                  const SizedBox(width: 8),
                  Text('${b.books.length}권',
                      style: Theme.of(context).textTheme.bodyMedium),
                  const Spacer(),
                  Text('합계 ${fmt.format(b.totalPriceWon)}원',
                      style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
              const Divider(height: 32),
              Row(
                children: [
                  Text('포함된 책',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  FilledButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('책 추가'),
                    onPressed: () => _showAddBookSheet(
                      context,
                      ref,
                      bundleId: b.id,
                      existingBookIds:
                          b.books.map((x) => x.bookId).toSet(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (b.books.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('포함된 책이 없습니다.',
                      style: TextStyle(color: Colors.grey)),
                )
              else
                ...b.books.map((bb) {
                  return _BundleBookRow(
                    bundleId: b.id,
                    bookId: bb.bookId,
                    title: bb.bookTitle ?? bb.bookId,
                    subtitle: bb.bookAuthor != null
                        ? '${bb.bookAuthor} · ${bb.bookPublisher ?? ''}'
                        : '',
                    coverUrl: bb.bookCoverUrl,
                    priceWon: bb.priceWon,
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

Future<void> _showAddBookSheet(
  BuildContext context,
  WidgetRef ref, {
  required String bundleId,
  required Set<String> existingBookIds,
}) async {
  final books = await ref.read(bookRepoProvider).myBooks();
  final candidates =
      books.where((b) => !existingBookIds.contains(b.id)).toList();

  if (!context.mounted) return;

  if (candidates.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('추가 가능한 책이 없습니다.')),
    );
    return;
  }

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (_, scroll) {
          return ListView(
            controller: scroll,
            padding: const EdgeInsets.all(16),
            children: [
              Text('꾸러미에 추가할 책 선택',
                  style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 12),
              ...candidates.map((book) => _AddBookTile(
                    book: book,
                    bundleId: bundleId,
                    onAdded: () {
                      Navigator.of(ctx).pop();
                      ref.invalidate(bundleDetailProvider(bundleId));
                      ref.invalidate(myBundlesProvider);
                      ref.invalidate(myBooksProvider);
                      ref.invalidate(bundlesForBookProvider(book.id));
                    },
                  )),
            ],
          );
        },
      );
    },
  );
}

class _AddBookTile extends ConsumerStatefulWidget {
  const _AddBookTile({
    required this.book,
    required this.bundleId,
    required this.onAdded,
  });

  final dynamic book;
  final String bundleId;
  final VoidCallback onAdded;

  @override
  ConsumerState<_AddBookTile> createState() => _AddBookTileState();
}

class _AddBookTileState extends ConsumerState<_AddBookTile> {
  final _price = TextEditingController(text: '0');

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final v = int.tryParse(_price.text.trim()) ?? 0;
    try {
      await ref
          .read(bundleRepoProvider)
          .addBookToBundle(widget.bundleId, widget.book.id, v);
      widget.onAdded();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.book;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            b.coverUrl != null
                ? Image.network(b.coverUrl!, width: 40, height: 56, fit: BoxFit.cover)
                : const SizedBox(width: 40, child: Icon(Icons.book)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(b.title,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  Text('${b.author}',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 90,
              child: TextField(
                controller: _price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  isDense: true,
                  suffixText: '원',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.green),
              onPressed: _add,
            ),
          ],
        ),
      ),
    );
  }
}

class _BundleBookRow extends ConsumerStatefulWidget {
  const _BundleBookRow({
    required this.bundleId,
    required this.bookId,
    required this.title,
    required this.subtitle,
    required this.coverUrl,
    required this.priceWon,
  });

  final String bundleId;
  final String bookId;
  final String title;
  final String subtitle;
  final String? coverUrl;
  final int priceWon;

  @override
  ConsumerState<_BundleBookRow> createState() => _BundleBookRowState();
}

class _BundleBookRowState extends ConsumerState<_BundleBookRow> {
  late final TextEditingController _price;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _price = TextEditingController(text: widget.priceWon.toString());
  }

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  Future<void> _savePrice() async {
    final v = int.tryParse(_price.text.trim()) ?? 0;
    try {
      await ref
          .read(bundleRepoProvider)
          .updateBookPrice(widget.bundleId, widget.bookId, v);
      ref.invalidate(bundleDetailProvider(widget.bundleId));
      ref.invalidate(myBundlesProvider);
      setState(() => _editing = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('가격 수정됨')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _remove() async {
    await ref
        .read(bundleRepoProvider)
        .removeBookFromBundle(widget.bundleId, widget.bookId);
    ref.invalidate(bundleDetailProvider(widget.bundleId));
    ref.invalidate(myBundlesProvider);
    ref.invalidate(myBooksProvider);
    ref.invalidate(bundlesForBookProvider(widget.bookId));
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            widget.coverUrl != null
                ? Image.network(widget.coverUrl!, width: 44, height: 60, fit: BoxFit.cover)
                : const SizedBox(width: 44, child: Icon(Icons.book)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  if (widget.subtitle.isNotEmpty)
                    Text(widget.subtitle,
                        style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  _editing
                      ? SizedBox(
                          height: 36,
                          child: TextField(
                            controller: _price,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              isDense: true,
                              suffixText: '원',
                              contentPadding:
                                  EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (_) => _savePrice(),
                          ),
                        )
                      : Text('${fmt.format(widget.priceWon)}원',
                          style: Theme.of(context).textTheme.titleSmall),
                ],
              ),
            ),
            IconButton(
              icon: Icon(_editing ? Icons.check : Icons.edit, size: 20),
              tooltip: _editing ? '저장' : '가격 수정',
              onPressed: () {
                if (_editing) {
                  _savePrice();
                } else {
                  setState(() => _editing = true);
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              tooltip: '꾸러미에서 제외',
              onPressed: _remove,
            ),
          ],
        ),
      ),
    );
  }
}
