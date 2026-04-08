import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/discussion.dart';
import '../../providers.dart';

class DiscussionSearchScreen extends ConsumerStatefulWidget {
  const DiscussionSearchScreen({super.key});

  @override
  ConsumerState<DiscussionSearchScreen> createState() =>
      _DiscussionSearchScreenState();
}

class _DiscussionSearchScreenState
    extends ConsumerState<DiscussionSearchScreen> {
  final _bookCtl = TextEditingController();
  final _regionCtl = TextEditingController();
  bool? _isOnline; // null = both
  List<Discussion> _results = [];
  bool _loading = false;

  Future<void> _search() async {
    setState(() => _loading = true);
    final list = await ref.read(supabaseRepoProvider).searchDiscussions(
          bookQuery: _bookCtl.text.trim(),
          region: _regionCtl.text.trim(),
          isOnline: _isOnline,
        );
    setState(() {
      _results = list;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy-MM-dd HH:mm');
    return Scaffold(
      appBar: AppBar(title: const Text('독서토론 검색')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  controller: _bookCtl,
                  decoration: const InputDecoration(
                    labelText: '책 제목',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _regionCtl,
                  decoration: const InputDecoration(
                    labelText: '지역 (시/구)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('형식:'),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('전체'),
                      selected: _isOnline == null,
                      onSelected: (_) => setState(() => _isOnline = null),
                    ),
                    const SizedBox(width: 4),
                    ChoiceChip(
                      label: const Text('온라인'),
                      selected: _isOnline == true,
                      onSelected: (_) => setState(() => _isOnline = true),
                    ),
                    const SizedBox(width: 4),
                    ChoiceChip(
                      label: const Text('오프라인'),
                      selected: _isOnline == false,
                      onSelected: (_) => setState(() => _isOnline = false),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _search,
                      icon: const Icon(Icons.search),
                      label: const Text('검색'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: ListView.separated(
              itemCount: _results.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final d = _results[i];
                return ListTile(
                  leading: Icon(d.isOnline ? Icons.videocam : Icons.place),
                  title: Text(d.title),
                  subtitle: Text(
                      '${d.region} · ${df.format(d.scheduledAt)} · ${d.currentParticipants}/${d.maxParticipants}'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
