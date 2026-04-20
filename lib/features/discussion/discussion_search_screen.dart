import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/discussion.dart';
import '../../providers.dart';
import 'region_picker.dart';

final myDiscussionsProvider = FutureProvider<List<Discussion>>((ref) async {
  ref.watch(authStateProvider);
  return ref.read(discussionRepoProvider).myDiscussions();
});

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
  bool? _isOnline;
  List<Discussion> _results = [];
  bool _loading = false;

  Future<void> _search() async {
    setState(() => _loading = true);
    final list = await ref.read(discussionRepoProvider).searchDiscussions(
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
      appBar: AppBar(
        title: const Text('독서토론 검색'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '모임 만들기',
            onPressed: () => context.push('/discussion/create'),
          ),
        ],
      ),
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
                InkWell(
                  onTap: () async {
                    final picked = await showRegionPicker(context,
                        initial: _regionCtl.text);
                    if (picked != null) {
                      setState(() => _regionCtl.text = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: '지역 (시/구)',
                      border: const OutlineInputBorder(),
                      suffixIcon: _regionCtl.text.isEmpty
                          ? const Icon(Icons.chevron_right)
                          : IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () =>
                                  setState(() => _regionCtl.text = ''),
                            ),
                    ),
                    child: Text(
                      _regionCtl.text.isEmpty
                          ? '시/군/구 또는 동/읍/면 선택'
                          : _regionCtl.text,
                      style: TextStyle(
                        color: _regionCtl.text.isEmpty
                            ? Theme.of(context).hintColor
                            : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('형식:'),
                      ChoiceChip(
                        label: const Text('전체'),
                        selected: _isOnline == null,
                        onSelected: (_) => setState(() => _isOnline = null),
                      ),
                      ChoiceChip(
                        label: const Text('온라인'),
                        selected: _isOnline == true,
                        onSelected: (_) => setState(() => _isOnline = true),
                      ),
                      ChoiceChip(
                        label: const Text('오프라인'),
                        selected: _isOnline == false,
                        onSelected: (_) => setState(() => _isOnline = false),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _search,
                    icon: const Icon(Icons.search),
                    label: const Text('검색'),
                  ),
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
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/discussion/${d.id}'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
