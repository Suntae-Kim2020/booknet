import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/discussion.dart';
import '../../providers.dart';
import 'discussion_search_screen.dart';

final _detailProvider =
    FutureProvider.family<Discussion?, String>((ref, id) async {
  return ref.read(discussionRepoProvider).getDiscussion(id);
});

final _membershipProvider =
    FutureProvider.family<String, String>((ref, id) async {
  return ref.read(discussionRepoProvider).myMembershipStatus(id);
});

final _bookProvider = FutureProvider.family<Map<String, dynamic>?, String>(
    (ref, bookId) async {
  return Supabase.instance.client
      .from('books')
      .select('id, title, author, publisher, cover_url')
      .eq('id', bookId)
      .maybeSingle();
});

class DiscussionDetailScreen extends ConsumerWidget {
  final String discussionId;
  const DiscussionDetailScreen({super.key, required this.discussionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(_detailProvider(discussionId));
    return Scaffold(
      appBar: AppBar(title: const Text('토론방 상세')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (d) {
          if (d == null) {
            return const Center(child: Text('토론방을 찾을 수 없습니다.'));
          }
          return _DetailBody(discussion: d);
        },
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  final Discussion discussion;
  const _DetailBody({required this.discussion});

  Future<void> _join(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(discussionRepoProvider);
    final manual = discussion.approvalMode == 'manual';
    try {
      if (manual) {
        final msg = await _askMessage(context);
        if (msg == null) return;
        await repo.requestJoin(discussion.id, message: msg);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('가입 신청을 보냈습니다. 호스트 승인 후 참여됩니다.')));
        }
      } else {
        await repo.joinDiscussion(discussion.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('모임에 참여했습니다.')));
        }
      }
      ref.invalidate(_membershipProvider(discussion.id));
      ref.invalidate(myDiscussionsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('오류: $e')));
      }
    }
  }

  Future<String?> _askMessage(BuildContext context) async {
    final ctl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('가입 신청 메시지'),
        content: TextField(
          controller: ctl,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: '호스트에게 전할 메시지 (선택)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctl.text.trim()),
              child: const Text('신청')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = discussion;
    final df = DateFormat('yyyy-MM-dd HH:mm');
    final membership = ref.watch(_membershipProvider(d.id));
    final book = d.currentBookId != null
        ? ref.watch(_bookProvider(d.currentBookId!))
        : (d.bookId != null ? ref.watch(_bookProvider(d.bookId!)) : null);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(d.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            Chip(
              avatar: Icon(d.isOnline ? Icons.videocam : Icons.place, size: 18),
              label: Text(d.isOnline ? '온라인' : (d.region.isEmpty ? '오프라인' : d.region)),
            ),
            Chip(label: Text(d.recurrenceLabel)),
            Chip(label: Text(d.genderLabel)),
            Chip(
                label: Text(d.approvalMode == 'manual' ? '호스트 승인' : '즉시 가입')),
          ],
        ),
        const SizedBox(height: 16),
        if (book != null)
          book.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (b) {
              if (b == null) return const SizedBox.shrink();
              return Card(
                child: ListTile(
                  leading: b['cover_url'] != null
                      ? Image.network(b['cover_url'] as String, width: 40)
                      : const Icon(Icons.book),
                  title: Text(b['title'] as String? ?? ''),
                  subtitle: Text(
                      '${b['author'] ?? ''} · ${b['publisher'] ?? ''}'),
                ),
              );
            },
          ),
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.event),
          title: Text(df.format(d.scheduledAt)),
          subtitle: const Text('첫 모임 일시'),
        ),
        ListTile(
          leading: const Icon(Icons.group),
          title: Text('${d.currentParticipants} / ${d.maxParticipants} 명'),
          subtitle: Text(
              '연령: ${d.minAge ?? '제한 없음'} ~ ${d.maxAge ?? '제한 없음'}'),
        ),
        if (d.isOnline && (d.onlineUrl ?? '').isNotEmpty)
          ListTile(
            leading: const Icon(Icons.link),
            title: Text(d.onlineUrl!),
            subtitle: const Text('온라인 링크'),
          ),
        if ((d.description ?? '').isNotEmpty) ...[
          const Divider(height: 32),
          Text('소개', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(d.description!),
        ],
        if ((d.rules ?? '').isNotEmpty) ...[
          const Divider(height: 32),
          Text('규칙/공지', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(d.rules!),
        ],
        const SizedBox(height: 24),
        membership.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('오류: $e'),
          data: (status) {
            switch (status) {
              case 'host':
                return FilledButton.icon(
                  onPressed: () =>
                      context.push('/discussion/${d.id}/home'),
                  icon: const Icon(Icons.star),
                  label: const Text('모임방 입장'),
                );
              case 'joined':
                return FilledButton.icon(
                  onPressed: () =>
                      context.push('/discussion/${d.id}/home'),
                  icon: const Icon(Icons.login),
                  label: const Text('모임방 입장'),
                );
              case 'pending':
                return FilledButton.tonalIcon(
                  onPressed: null,
                  icon: const Icon(Icons.hourglass_top),
                  label: const Text('승인 대기 중'),
                );
              default:
                final full = d.currentParticipants >= d.maxParticipants;
                return FilledButton.icon(
                  onPressed: full ? null : () => _join(context, ref),
                  icon: Icon(d.approvalMode == 'manual'
                      ? Icons.send
                      : Icons.person_add),
                  label: Text(full
                      ? '정원이 가득 찼습니다'
                      : (d.approvalMode == 'manual' ? '가입 신청' : '참여하기')),
                );
            }
          },
        ),
      ],
    );
  }
}
