import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/book.dart';
import '../../models/review.dart';
import '../../providers.dart';
import '../library/library_screen.dart';

final recentReviewsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final reviews = await ref.read(reviewRepoProvider).recentReviews();
  final db = Supabase.instance.client;
  final result = <Map<String, dynamic>>[];
  final nickCache = <String, String>{};
  final bookCache = <String, Map<String, dynamic>?>{};

  for (final r in reviews) {
    if (!nickCache.containsKey(r.userId)) {
      final p = await db.from('profiles').select('nickname').eq('id', r.userId).maybeSingle();
      nickCache[r.userId] = (p?['nickname'] as String?) ?? '알 수 없음';
    }
    if (r.bookId.isNotEmpty && !bookCache.containsKey(r.bookId)) {
      final b = await db.from('books').select('title, author, cover_url').eq('id', r.bookId).maybeSingle();
      bookCache[r.bookId] = b;
    }
    result.add({
      'review': r,
      'nickname': nickCache[r.userId],
      'book': bookCache[r.bookId],
    });
  }
  return result;
});

class ReviewsScreen extends ConsumerWidget {
  const ReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(recentReviewsProvider);
    final tts = ref.read(ttsServiceProvider);
    final df = DateFormat('MM-dd HH:mm');
    final uid = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('한줄평')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSheet(context, ref),
        child: const Icon(Icons.rate_review),
      ),
      body: reviews.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Text('아직 한줄평이 없습니다.\n우측 하단 버튼으로 작성해보세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey)),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final item = list[i];
              final r = item['review'] as Review;
              final nick = item['nickname'] as String? ?? '';
              final book = item['book'] as Map<String, dynamic>?;
              final isMine = uid != null && r.userId == uid;

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 상단: 닉네임 + 날짜
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            child: Text(nick.isNotEmpty ? nick[0] : '?',
                                style: const TextStyle(fontSize: 12)),
                          ),
                          const SizedBox(width: 8),
                          Text(nick, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          const Spacer(),
                          Text(df.format(r.createdAt),
                              style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // 책 정보
                      if (book != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.book, size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  '${book['title']} · ${book['author'] ?? ''}',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (book != null) const SizedBox(height: 8),
                      // 별점
                      if (r.rating != null)
                        Row(
                          children: List.generate(5, (s) => Icon(
                            s < r.rating! ? Icons.star : Icons.star_border,
                            size: 18,
                            color: Colors.amber,
                          )),
                        ),
                      if (r.rating != null) const SizedBox(height: 6),
                      // 내용
                      Text(r.content, style: const TextStyle(fontSize: 15)),
                      const SizedBox(height: 8),
                      // 하단 액션
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.volume_up, size: 20),
                            tooltip: '읽어주기',
                            onPressed: () => tts.speak(r.content),
                            visualDensity: VisualDensity.compact,
                          ),
                          if (isMine)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              tooltip: '삭제',
                              visualDensity: VisualDensity.compact,
                              onPressed: () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('한줄평 삭제'),
                                    content: const Text('이 한줄평을 삭제할까요?'),
                                    actions: [
                                      TextButton(
                                          onPressed: () => Navigator.pop(context, false),
                                          child: const Text('취소')),
                                      FilledButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          child: const Text('삭제')),
                                    ],
                                  ),
                                );
                                if (ok == true) {
                                  await ref.read(reviewRepoProvider).deleteReview(r.id);
                                  ref.invalidate(recentReviewsProvider);
                                }
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AddReviewSheet(),
    );
  }
}

class _AddReviewSheet extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AddReviewSheet> createState() => _AddReviewSheetState();
}

class _AddReviewSheetState extends ConsumerState<_AddReviewSheet> {
  final _contentCtrl = TextEditingController();
  int _rating = 0;
  Book? _selectedBook;
  bool _saving = false;

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickBook() async {
    final books = await ref.read(bookRepoProvider).myBooks();
    if (!mounted) return;
    final selected = await showModalBottomSheet<Book>(
      context: context,
      builder: (ctx) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('책 선택', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (books.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('서재에 등록된 책이 없습니다.', style: TextStyle(color: Colors.grey)),
            ),
          ...books.map((b) => ListTile(
                leading: b.coverUrl != null
                    ? Image.network(b.coverUrl!, width: 36)
                    : const Icon(Icons.book),
                title: Text(b.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(b.author),
                onTap: () => Navigator.pop(ctx, b),
              )),
        ],
      ),
    );
    if (selected != null) setState(() => _selectedBook = selected);
  }

  Future<void> _save() async {
    final text = _contentCtrl.text.trim();
    if (text.isEmpty) return;
    if (_selectedBook == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('책을 선택해주세요.')));
      return;
    }
    setState(() => _saving = true);
    final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
    final review = Review(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      bookId: _selectedBook!.id,
      userId: uid,
      content: text,
      rating: _rating > 0 ? _rating : null,
      createdAt: DateTime.now(),
    );
    try {
      await ref.read(reviewRepoProvider).addReview(review);
      ref.invalidate(recentReviewsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('오류: $e')));
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('한줄평 작성',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          // 책 선택
          InkWell(
            onTap: _pickBook,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: '책 선택 *',
                border: const OutlineInputBorder(),
                suffixIcon: const Icon(Icons.chevron_right),
                prefixIcon: _selectedBook?.coverUrl != null
                    ? Padding(
                        padding: const EdgeInsets.all(8),
                        child: Image.network(_selectedBook!.coverUrl!, width: 24),
                      )
                    : const Icon(Icons.book),
              ),
              child: Text(
                _selectedBook?.title ?? '서재에서 책을 선택하세요',
                style: TextStyle(
                  color: _selectedBook == null ? Theme.of(context).hintColor : null,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 별점
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('별점  ', style: TextStyle(fontSize: 14)),
              ...List.generate(5, (i) => GestureDetector(
                    onTap: () => setState(() => _rating = _rating == i + 1 ? 0 : i + 1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Icon(
                        i < _rating ? Icons.star : Icons.star_border,
                        size: 32,
                        color: Colors.amber,
                      ),
                    ),
                  )),
              if (_rating > 0)
                TextButton(
                  onPressed: () => setState(() => _rating = 0),
                  child: const Text('초기화', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // 내용
          TextField(
            controller: _contentCtrl,
            maxLength: 140,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: '책에 대한 한줄평을 남겨보세요',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '저장 중...' : '등록'),
          ),
        ],
      ),
    );
  }
}
