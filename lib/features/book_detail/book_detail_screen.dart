import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/review.dart';
import '../../models/sale_bundle.dart';
import '../../providers.dart';
import '../library/library_screen.dart';
import '../marketplace/marketplace_screen.dart';
import '../memo/memo_list_screen.dart';
import '../reviews/reviews_screen.dart';

final bookReviewsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, bookId) async {
  final reviews = await ref.read(reviewRepoProvider).reviewsForBook(bookId);
  final db = Supabase.instance.client;
  final nickCache = <String, String>{};
  final result = <Map<String, dynamic>>[];
  for (final r in reviews) {
    if (!nickCache.containsKey(r.userId)) {
      final p = await db.from('profiles').select('nickname').eq('id', r.userId).maybeSingle();
      nickCache[r.userId] = (p?['nickname'] as String?) ?? '알 수 없음';
    }
    result.add({'review': r, 'nickname': nickCache[r.userId]});
  }
  return result;
});

/// 특정 책이 포함된 꾸러미 목록
final bundlesForBookProvider =
    FutureProvider.family<List<SaleBundle>, String>((ref, bookId) async {
  ref.watch(authStateProvider);
  return ref.read(bundleRepoProvider).bundlesContainingBook(bookId);
});

class BookDetailScreen extends ConsumerWidget {
  const BookDetailScreen({super.key, required this.bookId});

  final String bookId;

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, String bookId) async {
    final repo = ref.read(bookRepoProvider);

    // 연관 데이터 조회
    final warnings = await repo.deletionWarnings(bookId);
    final bundleCount = warnings['bundleCount'] as int;
    final bundleList =
        (warnings['bundles'] as List).cast<Map<String, dynamic>>();
    final discussions =
        (warnings['discussions'] as List).cast<Map<String, dynamic>>();
    final hasParticipants = warnings['hasParticipants'] as bool;

    final msgs = <String>[];
    final removable = bundleList
        .where((b) => b['status'] == 'listed' || b['status'] == 'hidden')
        .toList();
    final kept = bundleList
        .where((b) => b['status'] == 'sold' || b['status'] == 'reserved')
        .toList();
    if (removable.isNotEmpty) {
      final names = removable.map((b) => b['title']).join(', ');
      msgs.add('꾸러미에서 제거됩니다: $names');
    }
    if (kept.isNotEmpty) {
      final names = kept.map((b) => '${b['title']}(${b['status'] == 'sold' ? '판매완료' : '예약중'})').join(', ');
      msgs.add('판매/예약 꾸러미는 유지됩니다: $names');
    }
    for (final d in discussions) {
      final status = d['status'] as String? ?? '';
      final title = d['title'] as String? ?? '';
      if (status == 'open') {
        msgs.add('진행 중인 토론방: "$title"');
      } else if (status == 'completed') {
        msgs.add('완료된 토론방: "$title"');
      } else {
        msgs.add('토론방: "$title" ($status)');
      }
    }
    if (hasParticipants) {
      msgs.add('참가자가 있는 토론방이 포함되어 있습니다.');
    }

    if (!context.mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('서재에서 삭제'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (msgs.isEmpty)
              const Text('이 책을 서재에서 삭제할까요?')
            else ...[
              const Text('이 책을 삭제하면 다음 항목에 영향이 있습니다:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ...msgs.map((m) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• '),
                        Expanded(child: Text(m)),
                      ],
                    ),
                  )),
              const SizedBox(height: 12),
              const Text(
                '서재 목록에서 사라지며, 미판매 꾸러미에서 제거됩니다.\n판매완료/예약 꾸러미와 토론 데이터는 유지됩니다.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await repo.softDelete(bookId);
      ref.invalidate(myBooksProvider);
      ref.invalidate(bundlesForBookProvider(bookId));
      ref.invalidate(myBundlesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('서재에서 삭제되었습니다.')));
        Navigator.of(context).pop();
      }
    }
  }

  void _showAddReview(BuildContext context, WidgetRef ref, String bookId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AddReviewSheet(bookId: bookId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(myBooksProvider);
    final memos = ref.watch(bookMemosProvider(bookId));
    final bundles = ref.watch(bundlesForBookProvider(bookId));
    final reviewsAsync = ref.watch(bookReviewsProvider(bookId));
    final tts = ref.read(ttsServiceProvider);
    final uid = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('책 정보'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '서재에서 삭제',
            onPressed: () => _confirmDelete(context, ref, bookId),
          ),
        ],
      ),
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
              if (b.description != null) ...[
                const SizedBox(height: 12),
                Text(b.description!),
              ],
              const Divider(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('읽기 상태',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'unread',
                          label: Text('안 읽음'),
                          icon: Icon(Icons.circle_outlined),
                        ),
                        ButtonSegment(
                          value: 'reading',
                          label: Text('읽는 중'),
                          icon: Icon(Icons.book),
                        ),
                        ButtonSegment(
                          value: 'read',
                          label: Text('읽음'),
                          icon: Icon(Icons.check_circle),
                        ),
                      ],
                      selected: {
                        b.isRead
                            ? 'read'
                            : (b.readAt != null ? 'reading' : 'unread')
                      },
                      onSelectionChanged: (s) async {
                        await repo.setReadStatus(b.id, s.first);
                        ref.invalidate(myBooksProvider);
                      },
                    ),
                  ],
                ),
              ),
              SwitchListTile(
                title: const Text('독서토론 희망'),
                value: b.wantsDiscussion,
                onChanged: (v) async {
                  await repo.setWantsDiscussion(b.id, v);
                  ref.invalidate(myBooksProvider);
                },
              ),
              // --- 한줄평 섹션 ---
              const Divider(height: 32),
              Row(
                children: [
                  const Icon(Icons.rate_review, size: 20),
                  const SizedBox(width: 8),
                  Text('한줄평', style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _showAddReview(context, ref, b.id),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('작성'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              reviewsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(8),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text('$e'),
                data: (reviewList) {
                  if (reviewList.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('아직 한줄평이 없습니다.',
                          style: TextStyle(color: Colors.grey)),
                    );
                  }
                  final df = DateFormat('MM-dd');
                  return Column(
                    children: reviewList.take(5).map((item) {
                      final r = item['review'] as Review;
                      final nick = item['nickname'] as String? ?? '';
                      final isMine = uid != null && r.userId == uid;
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(nick, style: const TextStyle(
                                      fontWeight: FontWeight.w600, fontSize: 13)),
                                  const Spacer(),
                                  if (r.rating != null)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: List.generate(5, (s) => Icon(
                                        s < r.rating! ? Icons.star : Icons.star_border,
                                        size: 14, color: Colors.amber,
                                      )),
                                    ),
                                  const SizedBox(width: 8),
                                  Text(df.format(r.createdAt),
                                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(r.content),
                              if (isMine)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18),
                                    onPressed: () async {
                                      await ref.read(reviewRepoProvider).deleteReview(r.id);
                                      ref.invalidate(bookReviewsProvider(b.id));
                                      ref.invalidate(recentReviewsProvider);
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              // --- 판매 꾸러미 섹션 ---
              const Divider(height: 32),
              Row(
                children: [
                  const Icon(Icons.local_offer, size: 20),
                  const SizedBox(width: 8),
                  Text('포함된 꾸러미',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  bundles.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (list) => list.isNotEmpty
                        ? TextButton.icon(
                            icon: const Icon(Icons.delete_sweep, size: 18),
                            label: const Text('전체 제거'),
                            onPressed: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('전체 제거'),
                                  content: Text(
                                      '이 책을 ${list.length}개 꾸러미 모두에서 제거하시겠습니까?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('취소'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('제거'),
                                    ),
                                  ],
                                ),
                              );
                              if (ok == true) {
                                await ref
                                    .read(bundleRepoProvider)
                                    .removeBookFromAllBundles(b.id);
                                ref.invalidate(
                                    bundlesForBookProvider(b.id));
                                ref.invalidate(myBooksProvider);
                              }
                            },
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              bundles.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(8),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text('$e'),
                data: (list) {
                  if (list.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('어떤 꾸러미에도 포함되어 있지 않습니다.',
                          style: TextStyle(color: Colors.grey)),
                    );
                  }
                  return Column(
                    children: list.map((bundle) {
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.inventory_2),
                          title: Text(bundle.title),
                          subtitle: Text(bundle.statusLabel),
                          onTap: () => context.push('/bundle/${bundle.id}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: '이 꾸러미에서 제외',
                            onPressed: () async {
                              await ref
                                  .read(bundleRepoProvider)
                                  .removeBookFromBundle(bundle.id, b.id);
                              ref.invalidate(
                                  bundlesForBookProvider(b.id));
                              ref.invalidate(myBooksProvider);
                            },
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),

              // --- 메모 섹션 ---
              const Divider(height: 32),
              Row(
                children: [
                  Text('메모',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  memos.maybeWhen(
                    data: (list) => list.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.play_circle_outline),
                            tooltip: '모두 듣기',
                            onPressed: () => tts.speakAll(
                                list.map((m) => m.content).toList()),
                          )
                        : const SizedBox.shrink(),
                    orElse: () => const SizedBox.shrink(),
                  ),
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
                          onTap: () => context.push(
                              '/book/$bookId/memo/edit',
                              extra: m),
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

class _AddReviewSheet extends ConsumerStatefulWidget {
  final String bookId;
  const _AddReviewSheet({required this.bookId});

  @override
  ConsumerState<_AddReviewSheet> createState() => _AddReviewSheetState();
}

class _AddReviewSheetState extends ConsumerState<_AddReviewSheet> {
  final _contentCtrl = TextEditingController();
  final _speech = SpeechToText();
  int _rating = 0;
  bool _saving = false;
  bool _listening = false;
  bool _sttAvailable = false;
  String _prefix = '';
  String _suffix = '';

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _sttAvailable = await _speech.initialize(
      onStatus: (s) {
        if ((s == 'done' || s == 'notListening') && mounted) {
          setState(() => _listening = false);
        }
      },
      onError: (_) {
        if (mounted) setState(() => _listening = false);
      },
    );
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _speech.stop();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleVoice() async {
    if (!_sttAvailable) return;
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }
    final sel = _contentCtrl.selection;
    final pos = (sel.isValid && sel.start >= 0) ? sel.start : _contentCtrl.text.length;
    _prefix = _contentCtrl.text.substring(0, pos);
    _suffix = _contentCtrl.text.substring(pos);
    if (_prefix.isNotEmpty && !_prefix.endsWith(' ') && !_prefix.endsWith('\n')) {
      _prefix = '$_prefix ';
    }
    setState(() => _listening = true);
    await _speech.listen(
      localeId: 'ko_KR',
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        partialResults: true,
      ),
      onResult: (r) {
        _contentCtrl.value = TextEditingValue(
          text: _prefix + r.recognizedWords + _suffix,
          selection: TextSelection.collapsed(
              offset: _prefix.length + r.recognizedWords.length),
        );
        setState(() {});
      },
    );
  }

  Future<void> _save() async {
    final text = _contentCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _saving = true);
    final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
    final review = Review(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      bookId: widget.bookId,
      userId: uid,
      content: text,
      rating: _rating > 0 ? _rating : null,
      createdAt: DateTime.now(),
    );
    try {
      await ref.read(reviewRepoProvider).addReview(review);
      ref.invalidate(bookReviewsProvider(widget.bookId));
      ref.invalidate(recentReviewsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('오류: $e')));
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
        children: [
          const Text('한줄평 작성',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) => GestureDetector(
              onTap: () => setState(() => _rating = _rating == i + 1 ? 0 : i + 1),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Icon(
                  i < _rating ? Icons.star : Icons.star_border,
                  size: 36, color: Colors.amber,
                ),
              ),
            )),
          ),
          const SizedBox(height: 12),
          Stack(
            children: [
              TextField(
                controller: _contentCtrl,
                maxLength: 140,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: '책에 대한 한줄평을 남겨보세요',
                  border: OutlineInputBorder(),
                ),
              ),
              Positioned(
                right: 4,
                bottom: 24,
                child: GestureDetector(
                  onTap: _toggleVoice,
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: _listening ? Colors.red : Colors.blue,
                    child: Icon(
                      _listening ? Icons.stop : Icons.mic,
                      color: Colors.white, size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_listening)
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 8),
                  Text('듣고 있습니다...', style: TextStyle(fontSize: 12, color: Colors.red)),
                ],
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? '저장 중...' : '등록'),
            ),
          ),
        ],
      ),
    );
  }
}
