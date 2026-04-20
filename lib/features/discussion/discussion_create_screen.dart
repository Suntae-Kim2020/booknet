import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/book.dart';
import '../../models/discussion.dart';
import '../../providers.dart';
import '../library/library_screen.dart';
import 'discussion_search_screen.dart';
import 'region_picker.dart';

/// 독서토론 모임 생성 화면
class DiscussionCreateScreen extends ConsumerStatefulWidget {
  const DiscussionCreateScreen({super.key});

  @override
  ConsumerState<DiscussionCreateScreen> createState() =>
      _DiscussionCreateScreenState();
}

class _DiscussionCreateScreenState
    extends ConsumerState<DiscussionCreateScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _region = TextEditingController();
  final _onlineUrl = TextEditingController();
  final _rules = TextEditingController();
  final _maxParticipants = TextEditingController(text: '10');
  final _minAge = TextEditingController();
  final _maxAge = TextEditingController();

  DateTime _scheduledAt = DateTime.now().add(const Duration(days: 7));
  bool _isOnline = false;
  String _gender = 'any'; // any / male_only / female_only
  String _recurrence = 'one_time'; // one_time / weekly / monthly
  String _approval = 'auto'; // auto / manual
  Book? _selectedBook;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _region.dispose();
    _onlineUrl.dispose();
    _rules.dispose();
    _maxParticipants.dispose();
    _minAge.dispose();
    _maxAge.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt),
    );
    if (time == null) return;
    setState(() {
      _scheduledAt = DateTime(
          date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _pickBook() async {
    final book = await showModalBottomSheet<Book>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _BookPickerSheet(),
    );
    if (book != null) setState(() => _selectedBook = book);
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      _snack('모임방 이름을 입력해주세요.');
      return;
    }
    if (_selectedBook == null) {
      _snack('토론할 책을 선택해주세요.');
      return;
    }
    if (_isOnline == false && _region.text.trim().isEmpty) {
      _snack('오프라인 모임은 지역을 입력해주세요.');
      return;
    }

    setState(() => _saving = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
      final repo = ref.read(discussionRepoProvider);
      final bookRepo = ref.read(bookRepoProvider);

      // 1. 책이 내 서재에 없으면 추가
      final myBooks = await bookRepo.myBooks();
      final hasBook = myBooks.any((b) => b.id == _selectedBook!.id);
      if (!hasBook) {
        await bookRepo.upsertBook(Book(
          id: _selectedBook!.id,
          ownerId: uid,
          isbn: _selectedBook!.isbn,
          title: _selectedBook!.title,
          author: _selectedBook!.author,
          publisher: _selectedBook!.publisher,
          coverUrl: _selectedBook!.coverUrl,
          description: _selectedBook!.description,
          publishedAt: _selectedBook!.publishedAt,
        ));
      }

      // 2. 모임 생성
      final discussion = Discussion(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        hostId: uid,
        bookId: _selectedBook!.id,
        currentBookId: _selectedBook!.id,
        currentModeratorId: uid,
        title: _title.text.trim(),
        description: _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        region: _region.text.trim(),
        isOnline: _isOnline,
        onlineUrl: _onlineUrl.text.trim().isEmpty
            ? null
            : _onlineUrl.text.trim(),
        scheduledAt: _scheduledAt,
        maxParticipants: int.tryParse(_maxParticipants.text) ?? 10,
        genderPolicy: _gender,
        minAge: int.tryParse(_minAge.text),
        maxAge: int.tryParse(_maxAge.text),
        recurrence: _recurrence,
        approvalMode: _approval,
        rules: _rules.text.trim().isEmpty ? null : _rules.text.trim(),
      );
      await repo.createDiscussion(discussion);

      // 3. 호스트를 참가자로 추가 (role=host)
      await Supabase.instance.client
          .from('discussion_participants')
          .upsert({
        'discussion_id': discussion.id,
        'user_id': uid,
        'status': 'joined',
        'role': 'host',
      });

      // 4. discussion_books에 현재 책 등록
      await Supabase.instance.client.from('discussion_books').upsert({
        'discussion_id': discussion.id,
        'book_id': _selectedBook!.id,
        'status': 'current',
        'moderator_id': uid,
        'scheduled_at': _scheduledAt.toIso8601String(),
      });

      ref.invalidate(myBooksProvider);
      ref.invalidate(myDiscussionsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('독서토론 모임이 만들어졌습니다.')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      _snack('오류: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy-MM-dd HH:mm');
    return Scaffold(
      appBar: AppBar(
        title: const Text('독서토론 만들기'),
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
            controller: _title,
            decoration: const InputDecoration(
              labelText: '모임방 이름 *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: '소개',
              hintText: '어떤 모임인가요?',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // 책 선택
          Text('토론할 책 *',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Card(
            child: ListTile(
              leading: _selectedBook?.coverUrl != null
                  ? Image.network(_selectedBook!.coverUrl!, width: 40)
                  : const Icon(Icons.book),
              title: Text(_selectedBook?.title ?? '책을 선택하세요'),
              subtitle: _selectedBook != null
                  ? Text('${_selectedBook!.author} · ${_selectedBook!.publisher}')
                  : null,
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickBook,
            ),
          ),
          const SizedBox(height: 16),

          // 온/오프라인
          Text('모임 형식',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                  value: false, label: Text('오프라인'), icon: Icon(Icons.place)),
              ButtonSegment(
                  value: true, label: Text('온라인'), icon: Icon(Icons.videocam)),
            ],
            selected: {_isOnline},
            onSelectionChanged: (s) => setState(() => _isOnline = s.first),
          ),
          const SizedBox(height: 12),
          if (_isOnline)
            TextField(
              controller: _onlineUrl,
              decoration: const InputDecoration(
                labelText: '온라인 링크 (Zoom/Meet 등)',
                border: OutlineInputBorder(),
              ),
            )
          else
            Card(
              child: ListTile(
                leading: const Icon(Icons.place),
                title: Text(_region.text.isEmpty ? '지역 선택' : _region.text),
                subtitle: _region.text.isEmpty
                    ? const Text('시/군/구 또는 동/읍/면까지 검색')
                    : null,
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final picked = await showRegionPicker(context,
                      initial: _region.text);
                  if (picked != null) {
                    setState(() => _region.text = picked);
                  }
                },
              ),
            ),
          const SizedBox(height: 16),

          // 첫 모임 일시
          Text('첫 모임 일시',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Card(
            child: ListTile(
              leading: const Icon(Icons.event),
              title: Text(df.format(_scheduledAt)),
              subtitle: _recurrence == 'one_time'
                  ? null
                  : Text(_recurrence == 'weekly'
                      ? '이후 같은 요일·시각에 매주 반복'
                      : '이후 같은 날짜·시각에 매월 반복'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickDateTime,
            ),
          ),
          const SizedBox(height: 16),

          // 정기성
          Text('정기 모임', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'one_time', label: Text('일회성')),
              ButtonSegment(value: 'weekly', label: Text('매주')),
              ButtonSegment(value: 'monthly', label: Text('매월')),
            ],
            selected: {_recurrence},
            onSelectionChanged: (s) => setState(() => _recurrence = s.first),
          ),
          const SizedBox(height: 16),

          // 참여 조건
          Text('참여 조건',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: _maxParticipants,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '최대 인원',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _minAge,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '최소 나이',
                    hintText: '예: 20',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _maxAge,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '최대 나이',
                    hintText: '예: 45',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('성별', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'any', label: Text('무관')),
              ButtonSegment(value: 'male_only', label: Text('남성만')),
              ButtonSegment(value: 'female_only', label: Text('여성만')),
            ],
            selected: {_gender},
            onSelectionChanged: (s) => setState(() => _gender = s.first),
          ),
          const SizedBox(height: 16),

          // 가입 승인
          Text('가입 방식', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'auto', label: Text('즉시 가입')),
              ButtonSegment(value: 'manual', label: Text('호스트 승인')),
            ],
            selected: {_approval},
            onSelectionChanged: (s) => setState(() => _approval = s.first),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _rules,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: '규칙/공지 (선택)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 32),

          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check),
            label: Text(_saving ? '저장 중...' : '모임 만들기'),
          ),
        ],
      ),
    );
  }
}

/// 책 선택 시트: 내 서재 + 네이버 검색
class _BookPickerSheet extends ConsumerStatefulWidget {
  const _BookPickerSheet();

  @override
  ConsumerState<_BookPickerSheet> createState() => _BookPickerSheetState();
}

class _BookPickerSheetState extends ConsumerState<_BookPickerSheet> {
  final _search = TextEditingController();
  List<Book> _searchResults = [];
  bool _searching = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _doSearch() async {
    final q = _search.text.trim();
    if (q.isEmpty) return;
    setState(() => _searching = true);
    try {
      final books = await ref.read(naverBookApiProvider).searchByKeyword(q);
      setState(() => _searchResults = books);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myBooks = ref.watch(myBooksProvider);
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      expand: false,
      builder: (_, scroll) {
        return Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('책 선택',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                controller: _search,
                decoration: InputDecoration(
                  hintText: '네이버에서 책 검색',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: _doSearch,
                  ),
                ),
                onSubmitted: (_) => _doSearch(),
              ),
            ),
            if (_searching) const LinearProgressIndicator(),
            Expanded(
              child: ListView(
                controller: scroll,
                children: [
                  if (_searchResults.isNotEmpty) ...[
                    const Padding(
                      padding:
                          EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text('검색 결과',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    ..._searchResults.map((b) => ListTile(
                          leading: b.coverUrl != null
                              ? Image.network(b.coverUrl!, width: 36)
                              : const Icon(Icons.book),
                          title: Text(b.title, maxLines: 2),
                          subtitle: Text('${b.author} · ${b.publisher}'),
                          onTap: () => Navigator.pop(context, b),
                        )),
                    const Divider(),
                  ],
                  const Padding(
                    padding:
                        EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text('내 서재',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  myBooks.when(
                    loading: () => const Center(
                        child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    )),
                    error: (e, _) => Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('$e')),
                    data: (list) => Column(
                      children: list
                          .map((b) => ListTile(
                                leading: b.coverUrl != null
                                    ? Image.network(b.coverUrl!, width: 36)
                                    : const Icon(Icons.book),
                                title: Text(b.title, maxLines: 2),
                                subtitle:
                                    Text('${b.author} · ${b.publisher}'),
                                onTap: () => Navigator.pop(context, b),
                              ))
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
