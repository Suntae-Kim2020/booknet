import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/memo.dart';
import '../../providers.dart';

class MemoSearchScreen extends ConsumerStatefulWidget {
  const MemoSearchScreen({super.key});

  @override
  ConsumerState<MemoSearchScreen> createState() => _MemoSearchScreenState();
}

class _MemoSearchScreenState extends ConsumerState<MemoSearchScreen> {
  final _queryCtrl = TextEditingController();
  List<Memo> _results = [];
  bool _loading = false;

  Future<void> _search() async {
    final q = _queryCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() => _loading = true);
    final list = await ref.read(memoRepoProvider).searchMemos(q);
    setState(() {
      _results = list;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tts = ref.read(ttsServiceProvider);
    final df = DateFormat('yyyy-MM-dd');

    return Scaffold(
      appBar: AppBar(title: const Text('메모 검색')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _queryCtrl,
              decoration: InputDecoration(
                hintText: '메모 내용으로 검색',
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
          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, i) {
                final m = _results[i];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                    title: Text(m.content,
                        maxLines: 3, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      '${m.pageNumber != null ? "p.${m.pageNumber} · " : ""}${df.format(m.createdAt)}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.volume_up),
                      onPressed: () => tts.speak(m.content),
                    ),
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
