import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/memo.dart';
import '../../providers.dart';
import 'memo_list_screen.dart';

class MemoEditScreen extends ConsumerStatefulWidget {
  const MemoEditScreen({
    super.key,
    required this.bookId,
    this.existingMemo,
  });

  final String bookId;
  final Memo? existingMemo;

  @override
  ConsumerState<MemoEditScreen> createState() => _MemoEditScreenState();
}

class _MemoEditScreenState extends ConsumerState<MemoEditScreen> {
  late final TextEditingController _contentCtrl;
  late final TextEditingController _pageCtrl;
  late bool _isShared;
  bool _saving = false;

  bool get _isEditing => widget.existingMemo != null;

  @override
  void initState() {
    super.initState();
    _contentCtrl =
        TextEditingController(text: widget.existingMemo?.content ?? '');
    _pageCtrl = TextEditingController(
        text: widget.existingMemo?.pageNumber?.toString() ?? '');
    _isShared = widget.existingMemo?.isShared ?? true;
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final content = _contentCtrl.text.trim();
    if (content.isEmpty) return;

    setState(() => _saving = true);
    final repo = ref.read(memoRepoProvider);
    final page = int.tryParse(_pageCtrl.text);

    if (_isEditing) {
      final updated = widget.existingMemo!.copyWith(
        content: content,
        pageNumber: page,
        isShared: _isShared,
      );
      await repo.updateMemo(updated);
    } else {
      await repo.createMemo(
        bookId: widget.bookId,
        content: content,
        pageNumber: page,
        isShared: _isShared,
      );
    }

    ref.invalidate(bookMemosProvider(widget.bookId));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '메모 수정' : '메모 작성'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _contentCtrl,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: '메모 내용',
              hintText: '책 속 인상 깊은 문장이나 생각을 적어보세요',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pageCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '페이지 (선택)',
              hintText: '예: 42',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('공유'),
            subtitle: Text(_isShared ? '다른 사용자에게 공개됩니다' : '나만 볼 수 있습니다'),
            value: _isShared,
            onChanged: (v) => setState(() => _isShared = v),
          ),
        ],
      ),
    );
  }
}
