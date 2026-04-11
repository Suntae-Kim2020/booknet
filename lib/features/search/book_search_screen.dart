import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/book.dart';
import '../../providers.dart';

class BookSearchScreen extends ConsumerStatefulWidget {
  const BookSearchScreen({super.key});

  @override
  ConsumerState<BookSearchScreen> createState() => _BookSearchScreenState();
}

class _BookSearchScreenState extends ConsumerState<BookSearchScreen> {
  final _controller = TextEditingController();
  List<Book> _results = [];
  bool _loading = false;
  String? _error;

  Future<void> _search() async {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(naverBookApiProvider);
      final list = await api.searchByKeyword(q);
      setState(() => _results = list);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _register(Book b) async {
    final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
    final bookWithOwner = Book(
      id: b.id,
      ownerId: uid,
      isbn: b.isbn,
      title: b.title,
      author: b.author,
      publisher: b.publisher,
      coverUrl: b.coverUrl,
      description: b.description,
      publishedAt: b.publishedAt,
    );
    await ref.read(bookRepoProvider).upsertBook(bookWithOwner);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('등록: ${b.title}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('도서 검색')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: '책 제목, 저자, 출판사',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _search,
                ),
              ),
              onSubmitted: (_) => _search(),
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(padding: const EdgeInsets.all(8), child: Text(_error!)),
          Expanded(
            child: ListView.separated(
              itemCount: _results.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final b = _results[i];
                return ListTile(
                  leading: b.coverUrl != null
                      ? Image.network(b.coverUrl!, width: 40)
                      : const Icon(Icons.book),
                  title: Text(b.title),
                  subtitle: Text('${b.author} · ${b.publisher}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _register(b),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
