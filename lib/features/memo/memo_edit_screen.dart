import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

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

  final _speech = SpeechToText();
  bool _speechAvailable = false;
  bool _listening = false;
  // 음성 입력 시작 시점의 커서 앞/뒤 텍스트와 누적 삽입 길이
  String _prefix = '';
  String _suffix = '';
  int _lastInsertLen = 0;

  bool get _isEditing => widget.existingMemo != null;

  @override
  void initState() {
    super.initState();
    _contentCtrl =
        TextEditingController(text: widget.existingMemo?.content ?? '');
    _pageCtrl = TextEditingController(
        text: widget.existingMemo?.pageNumber?.toString() ?? '');
    _isShared = widget.existingMemo?.isShared ?? true;
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: (err) {
        if (mounted) setState(() => _listening = false);
      },
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) setState(() => _listening = false);
        }
      },
    );
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _speech.stop();
    _contentCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleVoice() async {
    if (!_speechAvailable) {
      _snack('음성 인식을 사용할 수 없습니다.');
      return;
    }
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }
    // 현재 커서 위치 기준으로 prefix/suffix 분리 (커서가 없으면 맨 뒤)
    final sel = _contentCtrl.selection;
    final pos = (sel.isValid && sel.start >= 0)
        ? sel.start
        : _contentCtrl.text.length;
    _prefix = _contentCtrl.text.substring(0, pos);
    _suffix = _contentCtrl.text.substring(pos);
    if (_prefix.isNotEmpty && !_prefix.endsWith(' ') && !_prefix.endsWith('\n')) {
      _prefix = '$_prefix ';
    }
    _lastInsertLen = 0;
    setState(() => _listening = true);

    await _speech.listen(
      localeId: 'ko_KR',
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        partialResults: true,
      ),
      onResult: _handleResult,
    );
  }

  void _handleResult(dynamic r) {
    var spoken = r.recognizedWords as String;
    // "페이지 42" / "42 페이지" / "42쪽" 같은 표현 감지 → 페이지 필드로
    final pageRe = RegExp(
      r'(?:페이지\s*|페\s*)(\d+)|(\d+)\s*(?:페이지|쪽|페)',
    );
    final m = pageRe.firstMatch(spoken);
    if (m != null) {
      final numStr = m.group(1) ?? m.group(2);
      if (numStr != null) {
        _pageCtrl.text = numStr;
        spoken = spoken.replaceFirst(m.group(0)!, '').trim();
      }
    }

    final newText = _prefix + spoken + _suffix;
    _contentCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: _prefix.length + spoken.length),
    );
    _lastInsertLen = spoken.length;
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
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
          Stack(
            children: [
              TextField(
                controller: _contentCtrl,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: '메모 내용',
                  hintText: '책 속 인상 깊은 문장이나 생각을 적어보세요.\n마이크 버튼으로 음성 입력도 가능합니다.',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              Positioned(
                right: 8,
                bottom: 8,
                child: FloatingActionButton.small(
                  heroTag: 'content_mic',
                  onPressed: _toggleVoice,
                  backgroundColor: _listening
                      ? Colors.red
                      : Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(_listening ? Icons.stop : Icons.mic),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pageCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '페이지 (선택)',
              hintText: '예: 42 · 음성으로 "페이지 42" 말하면 자동 입력',
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
