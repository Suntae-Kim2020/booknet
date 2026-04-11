import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/review.dart';
import '../../providers.dart';

final recentReviewsProvider = FutureProvider<List<Review>>((ref) async {
  return ref.read(reviewRepoProvider).recentReviews();
});

class ReviewsScreen extends ConsumerWidget {
  const ReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(recentReviewsProvider);
    final tts = ref.read(ttsServiceProvider);
    final df = DateFormat('MM-dd HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('한 줄 평'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddSheet(context, ref),
          ),
        ],
      ),
      body: reviews.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('한 줄 평이 없습니다.'));
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final r = list[i];
              return ListTile(
                title: Text(r.content),
                subtitle: Text(df.format(r.createdAt)),
                trailing: IconButton(
                  icon: const Icon(Icons.volume_up),
                  tooltip: '읽어주기',
                  onPressed: () => tts.speak(r.content),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    final ctl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('한 줄 평 작성'),
            const SizedBox(height: 8),
            TextField(
              controller: ctl,
              maxLength: 140,
              decoration: const InputDecoration(
                hintText: '책에 대한 한 줄을 남겨보세요',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () async {
                final text = ctl.text.trim();
                if (text.isEmpty) return;
                final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
                final review = Review(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  bookId: '', // TODO: 책 선택 UI 추가
                  userId: uid,
                  content: text,
                  createdAt: DateTime.now(),
                );
                await ref.read(reviewRepoProvider).addReview(review);
                ref.invalidate(recentReviewsProvider);
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('등록'),
            ),
          ],
        ),
      ),
    );
  }
}
