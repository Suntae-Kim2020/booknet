import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers.dart';
import '../../services/csv_export_service.dart';
import '../../services/notification_service.dart';
import 'discussion_search_screen.dart';

class DiscussionHomeScreen extends ConsumerStatefulWidget {
  final String discussionId;
  const DiscussionHomeScreen({super.key, required this.discussionId});

  @override
  ConsumerState<DiscussionHomeScreen> createState() =>
      _DiscussionHomeScreenState();
}

class _DiscussionHomeScreenState extends ConsumerState<DiscussionHomeScreen>
    with TickerProviderStateMixin {
  late TabController _tabCtrl;
  Map<String, dynamic>? _discussion;
  bool _loading = true;
  String _myRole = 'member';

  String get _uid => Supabase.instance.client.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 5, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(discussionRepoProvider);
      final d = await repo.getDiscussion(widget.discussionId);
      final status = await repo.myMembershipStatus(widget.discussionId);
      if (!mounted) return;
      setState(() {
        _discussion = d?.toMap();
        _myRole = status;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  bool get _isHost => _myRole == 'host';
  bool get _isAdmin => _myRole == 'host' || _myRole == 'moderator';

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('토론방')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final title = _discussion?['title'] as String? ?? '토론방';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.sports_esports),
            tooltip: '게임',
            onPressed: () => context.push('/games'),
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          labelPadding: const EdgeInsets.symmetric(horizontal: 2),
          tabs: const [
            Tab(icon: Icon(Icons.event, size: 20), text: '일정'),
            Tab(icon: Icon(Icons.chat, size: 20), text: '채팅'),
            Tab(icon: Icon(Icons.how_to_vote, size: 20), text: '투표'),
            Tab(icon: Icon(Icons.auto_stories, size: 20), text: '활동'),
            Tab(icon: Icon(Icons.info_outline, size: 20), text: '정보'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _MeetingsTab(
              discussionId: widget.discussionId, isAdmin: _isAdmin),
          _ChatTab(discussionId: widget.discussionId),
          _VoteTab(discussionId: widget.discussionId),
          _ActivityTab(discussionId: widget.discussionId),
          _InfoTab(
              discussionId: widget.discussionId,
              discussion: _discussion,
              isHost: _isHost,
              isAdmin: _isAdmin),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  탭 1: 일정 + 출석
// ═══════════════════════════════════════════════════
class _MeetingsTab extends ConsumerStatefulWidget {
  final String discussionId;
  final bool isAdmin;
  const _MeetingsTab({required this.discussionId, required this.isAdmin});

  @override
  ConsumerState<_MeetingsTab> createState() => _MeetingsTabState();
}

class _MeetingsTabState extends ConsumerState<_MeetingsTab> {
  List<Map<String, dynamic>> _meetings = [];
  bool _loading = true;
  String? _error;
  String? _nextModeratorNick;
  String? _nextModeratorId;
  List<Map<String, dynamic>> _memberOrder = [];
  Map<String, String> _nickMap = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(discussionRepoProvider);
      final list = await repo.meetings(widget.discussionId);
      final members = await repo.memberOrder(widget.discussionId);
      final nextId = await repo.nextModeratorId(widget.discussionId);

      final nMap = <String, String>{};
      for (final m in members) {
        nMap[m['user_id'] as String] = m['nickname'] as String;
      }

      if (!mounted) return;
      setState(() {
        _meetings = list;
        _memberOrder = members;
        _nickMap = nMap;
        _nextModeratorId = nextId;
        _nextModeratorNick = nextId != null ? nMap[nextId] : null;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  void _showRotationOrder() {
    final nextIdx = _memberOrder.indexWhere((m) => m['user_id'] == _nextModeratorId);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('진행자 순번'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(_memberOrder.length, (i) {
            final m = _memberOrder[(nextIdx + i) % _memberOrder.length];
            final nick = m['nickname'] as String? ?? '?';
            final isNext = i == 0;
            return ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: isNext ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
                child: Text('${i + 1}',
                    style: TextStyle(
                      color: isNext ? Colors.white : Colors.black54,
                      fontWeight: FontWeight.bold,
                    )),
              ),
              title: Text(nick,
                  style: TextStyle(
                    fontWeight: isNext ? FontWeight.bold : FontWeight.normal,
                    color: isNext ? Theme.of(context).colorScheme.primary : null,
                  )),
              trailing: isNext ? const Chip(label: Text('다음', style: TextStyle(fontSize: 11))) : null,
            );
          }),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인')),
        ],
      ),
    );
  }

  Future<void> _createMeeting() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 19, minute: 0),
    );
    if (time == null || !mounted) return;

    final scheduledAt =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);

    final locationCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('모임 일정 추가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(DateFormat('yyyy-MM-dd HH:mm').format(scheduledAt)),
            const SizedBox(height: 12),
            TextField(
              controller: locationCtrl,
              decoration: const InputDecoration(
                labelText: '장소 (선택)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('추가')),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(discussionRepoProvider).createMeeting(
            discussionId: widget.discussionId,
            scheduledAt: scheduledAt,
            moderatorId: _nextModeratorId,
            location:
                locationCtrl.text.trim().isEmpty ? null : locationCtrl.text.trim(),
          );
      // 모임 알림 예약 (하루 전 + 1시간 전)
      await LocalNotificationService.scheduleMeetingReminder(
        meetingId: widget.discussionId + scheduledAt.millisecondsSinceEpoch.toString(),
        title: '독서토론 모임',
        scheduledAt: scheduledAt,
        location: locationCtrl.text.trim().isEmpty ? null : locationCtrl.text.trim(),
      );
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy-MM-dd (E) HH:mm', 'ko');

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // 상태 표시
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (_error != null)
          Card(
            color: Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text('오류: $_error'),
            ),
          ),
        // 다음 진행자 안내
        if (_nextModeratorNick != null)
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: ListTile(
              leading: const Icon(Icons.person_pin, size: 28),
              title: const Text('다음 진행자', style: TextStyle(fontSize: 12)),
              subtitle: Text(_nextModeratorNick!,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              trailing: _memberOrder.isNotEmpty
                  ? TextButton(
                      onPressed: _showRotationOrder,
                      child: const Text('순번 보기'),
                    )
                  : null,
            ),
          ),
        const SizedBox(height: 8),
        // 일정 추가 버튼 (항상 표시)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _loading ? null : _createMeeting,
              icon: const Icon(Icons.add),
              label: const Text('일정 추가'),
            ),
          ),
        ),
        // 빈 목록 안내
        if (!_loading && _error == null && _meetings.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(
              child: Text('등록된 일정이 없습니다.',
                  style: TextStyle(color: Colors.grey, fontSize: 15)),
            ),
          ),
        // 일정 목록
        ..._meetings.map((m) {
          final at = DateTime.parse(m['scheduled_at'] as String);
          final isPast = at.isBefore(DateTime.now());
          final modId = m['moderator_id'] as String?;
          final modNick = modId != null ? _nickMap[modId] : null;
          return Card(
            child: ExpansionTile(
              leading: Icon(
                isPast ? Icons.check_circle : Icons.event,
                color: isPast ? Colors.green : null,
              ),
              title: Text(df.format(at)),
              subtitle: Text([
                if (m['location'] != null) m['location'] as String,
                if (modNick != null) '진행: $modNick',
              ].join(' · ')),
              children: [
                _AttendanceSection(meetingId: m['id'] as String),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _AttendanceSection extends ConsumerStatefulWidget {
  final String meetingId;
  const _AttendanceSection({required this.meetingId});

  @override
  ConsumerState<_AttendanceSection> createState() => _AttendanceSectionState();
}

class _AttendanceSectionState extends ConsumerState<_AttendanceSection> {
  List<Map<String, dynamic>> _records = [];
  bool _loading = true;
  String get _uid => Supabase.instance.client.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list =
        await ref.read(discussionRepoProvider).attendance(widget.meetingId);
    if (!mounted) return;
    setState(() {
      _records = list;
      _loading = false;
    });
  }

  bool get _alreadyCheckedIn =>
      _records.any((r) => r['user_id'] == _uid);

  Future<void> _checkIn() async {
    await ref.read(discussionRepoProvider).checkIn(widget.meetingId);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('출석 ${_records.length}명',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              if (!_alreadyCheckedIn)
                FilledButton.tonalIcon(
                  onPressed: _checkIn,
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('출석 체크'),
                )
              else
                const Chip(
                  avatar: Icon(Icons.check_circle, size: 18, color: Colors.green),
                  label: Text('출석 완료'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _records.map((r) {
              final nick = r['nickname'] as String? ?? '알 수 없음';
              final status = r['status'] as String? ?? 'present';
              return Chip(
                avatar: Icon(
                  status == 'present'
                      ? Icons.person
                      : (status == 'late' ? Icons.schedule : Icons.close),
                  size: 18,
                ),
                label: Text(nick),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  탭 2: 채팅
// ═══════════════════════════════════════════════════
class _ChatTab extends ConsumerStatefulWidget {
  final String discussionId;
  const _ChatTab({required this.discussionId});

  @override
  ConsumerState<_ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends ConsumerState<_ChatTab> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _replyTarget;
  String get _uid => Supabase.instance.client.auth.currentUser?.id ?? '';

  static const _avatarColors = [
    Color(0xFFE53935), Color(0xFF1E88E5), Color(0xFF43A047),
    Color(0xFFFFA000), Color(0xFF8E24AA), Color(0xFF00ACC1),
    Color(0xFFD81B60), Color(0xFF5C6BC0),
  ];

  Color _colorForUid(String uid) {
    return _avatarColors[uid.hashCode.abs() % _avatarColors.length];
  }

  RealtimeChannel? _channel;
  final _nickCache = <String, String>{};

  @override
  void initState() {
    super.initState();
    _load();
    _subscribe();
  }

  void _subscribe() {
    _channel = Supabase.instance.client
        .channel('chat_${widget.discussionId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'discussion_chat',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'discussion_id',
            value: widget.discussionId,
          ),
          callback: (payload) async {
            final row = payload.newRecord;
            final senderId = row['sender_id'] as String? ?? '';
            if (!_nickCache.containsKey(senderId)) {
              final p = await Supabase.instance.client
                  .from('profiles')
                  .select('nickname')
                  .eq('id', senderId)
                  .maybeSingle();
              _nickCache[senderId] = (p?['nickname'] as String?) ?? '알 수 없음';
            }
            if (!mounted) return;
            setState(() {
              _messages.add({...row, 'nickname': _nickCache[senderId]});
            });
            _scrollToBottom();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await ref
          .read(discussionRepoProvider)
          .chatMessages(widget.discussionId);
      if (!mounted) return;
      setState(() {
        _messages = list.reversed.toList();
        _loading = false;
        _error = null;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    final replyId = _replyTarget?['id'] as String?;
    _msgCtrl.clear();
    setState(() => _replyTarget = null);
    try {
      await ref.read(discussionRepoProvider).sendMessage(
            widget.discussionId,
            text,
            replyTo: replyId,
          );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('전송 실패: $e')));
    }
  }

  Future<void> _pickAndSendImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('카메라로 촬영'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('갤러리에서 선택'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 70, maxWidth: 1200);
    if (picked == null) return;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미지 업로드 중...')));

    try {
      final repo = ref.read(discussionRepoProvider);
      final imageUrl = await repo.uploadChatImage(widget.discussionId, picked.path);
      await repo.sendMessage(widget.discussionId, '📷 사진', imageUrl: imageUrl);
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('이미지 전송 실패: $e')));
    }
  }

  void _openImageViewer(BuildContext context, String url) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _ImageViewerScreen(imageUrl: url),
    ));
  }

  void _setReply(Map<String, dynamic> msg) {
    setState(() => _replyTarget = msg);
    _msgCtrl.selection = TextSelection.collapsed(offset: _msgCtrl.text.length);
  }

  String? _findNickById(String? id) {
    if (id == null) return null;
    final msg = _messages.where((m) => m['id'] == id).firstOrNull;
    return msg?['nickname'] as String?;
  }

  String? _findContentById(String? id) {
    if (id == null) return null;
    final msg = _messages.where((m) => m['id'] == id).firstOrNull;
    return msg?['content'] as String?;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('채팅 로드 오류:\n$_error', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('다시 시도')),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: _messages.isEmpty
                ? const Center(child: Text('아직 메시지가 없습니다.\n첫 메시지를 보내보세요!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) {
                      final m = _messages[i];
                      final isMine = m['sender_id'] == _uid;
                      final nick = m['nickname'] as String? ?? '?';
                      final content = m['content'] as String? ?? '';
                      final imageUrl = m['image_url'] as String?;
                      final senderId = m['sender_id'] as String? ?? '';
                      final time = DateTime.tryParse(m['created_at'] as String? ?? '');
                      final timeStr = time != null ? DateFormat('HH:mm').format(time) : '';
                      final replyTo = m['reply_to'] as String?;
                      final replyNick = _findNickById(replyTo);
                      final replyContent = _findContentById(replyTo);

                      // 날짜 구분선
                      Widget? dateSep;
                      if (i == 0 || _isDifferentDay(_messages[i - 1], m)) {
                        final dateStr = time != null
                            ? DateFormat('yyyy년 M월 d일 (E)', 'ko').format(time)
                            : '';
                        dateSep = Center(
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(dateStr,
                                style: const TextStyle(fontSize: 11, color: Colors.black54)),
                          ),
                        );
                      }

                      // 같은 발신자 연속 여부
                      final showAvatar = !isMine &&
                          (i == 0 || _messages[i - 1]['sender_id'] != senderId);

                      return Column(
                        children: [
                          if (dateSep != null) dateSep,
                          GestureDetector(
                            onLongPress: () => _setReply(m),
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: isMine
                                  ? _buildMyBubble(theme, content, timeStr, replyNick, replyContent, imageUrl)
                                  : _buildOtherBubble(theme, nick, senderId, content, timeStr, showAvatar, replyNick, replyContent, imageUrl),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ),
        // 답글 프리뷰
        if (_replyTarget != null)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            color: theme.colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                Container(width: 3, height: 30, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_replyTarget!['nickname'] as String? ?? '',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary)),
                      Text(_replyTarget!['content'] as String? ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _replyTarget = null),
                ),
              ],
            ),
          ),
        // 입력 영역
        Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.image, size: 24),
                  onPressed: _pickAndSendImage,
                  color: theme.colorScheme.primary,
                ),
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    maxLines: 4,
                    minLines: 1,
                    decoration: InputDecoration(
                      hintText: '메시지 입력',
                      isDense: true,
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _send,
                    icon: const Icon(Icons.send, size: 20),
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  bool _isDifferentDay(Map<String, dynamic> prev, Map<String, dynamic> curr) {
    final a = DateTime.tryParse(prev['created_at'] as String? ?? '');
    final b = DateTime.tryParse(curr['created_at'] as String? ?? '');
    if (a == null || b == null) return false;
    return a.year != b.year || a.month != b.month || a.day != b.day;
  }

  Widget _buildReplyPreview(ThemeData theme, String? replyNick, String? replyContent, bool isMine) {
    if (replyNick == null && replyContent == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      decoration: BoxDecoration(
        color: isMine
            ? theme.colorScheme.primary.withValues(alpha: 0.08)
            : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: theme.colorScheme.primary, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(replyNick ?? '',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
          Text(replyContent ?? '',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildMyBubble(ThemeData theme, String content, String timeStr, String? replyNick, String? replyContent, String? imageUrl) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 4, bottom: 2),
          child: Text(timeStr, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE500),
              borderRadius: BorderRadius.circular(14).copyWith(
                  bottomRight: const Radius.circular(4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (replyNick != null || replyContent != null)
                  _buildReplyPreview(theme, replyNick, replyContent, true),
                if (imageUrl != null)
                  GestureDetector(
                    onTap: () => _openImageViewer(context, imageUrl),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(imageUrl, width: 200, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image)),
                    ),
                  ),
                if (imageUrl != null && content != '📷 사진') const SizedBox(height: 4),
                if (content != '📷 사진' || imageUrl == null)
                  Text(content, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOtherBubble(ThemeData theme, String nick, String senderId,
      String content, String timeStr, bool showAvatar, String? replyNick, String? replyContent, String? imageUrl) {
    final avatarColor = _colorForUid(senderId);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showAvatar)
          CircleAvatar(
            radius: 18,
            backgroundColor: avatarColor,
            child: Text(
              nick.isNotEmpty ? nick[0] : '?',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          )
        else
          const SizedBox(width: 36),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showAvatar)
                Padding(
                  padding: const EdgeInsets.only(left: 2, bottom: 2),
                  child: Text(nick, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14).copyWith(
                            topLeft: const Radius.circular(4)),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (replyNick != null || replyContent != null)
                            _buildReplyPreview(theme, replyNick, replyContent, false),
                          if (imageUrl != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(imageUrl, width: 200, fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image)),
                            ),
                          if (imageUrl != null && content != '📷 사진') const SizedBox(height: 4),
                          if (content != '📷 사진' || imageUrl == null)
                            Text(content, style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    child: Text(timeStr, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════
//  탭 3: 도서 투표
// ═══════════════════════════════════════════════════
class _VoteTab extends ConsumerStatefulWidget {
  final String discussionId;
  const _VoteTab({required this.discussionId});

  @override
  ConsumerState<_VoteTab> createState() => _VoteTabState();
}

class _VoteTabState extends ConsumerState<_VoteTab> {
  List<Map<String, dynamic>> _candidates = [];
  Set<String> _myVotedIds = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(discussionRepoProvider);
    final cands = await repo.bookCandidates(widget.discussionId);
    final myVotes = await repo.myVotes(widget.discussionId);
    if (!mounted) return;
    setState(() {
      _candidates = cands;
      _myVotedIds =
          myVotes.map((v) => v['candidate_id'] as String).toSet();
      _loading = false;
    });
  }

  Future<void> _suggestBook() async {
    final bookRepo = ref.read(bookRepoProvider);
    final books = await bookRepo.myBooks();
    if (!mounted) return;

    if (books.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('서재에 책이 없습니다.')));
      return;
    }

    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('후보로 추천할 책 선택',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...books.map((b) => ListTile(
                leading: b.coverUrl != null
                    ? Image.network(b.coverUrl!, width: 36)
                    : const Icon(Icons.book),
                title: Text(b.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(b.author),
                onTap: () => Navigator.pop(ctx, b.id),
              )),
        ],
      ),
    );

    if (selected != null) {
      await ref
          .read(discussionRepoProvider)
          .suggestBook(widget.discussionId, selected);
      _load();
    }
  }

  Future<void> _toggleVote(String candidateId) async {
    final repo = ref.read(discussionRepoProvider);
    if (_myVotedIds.contains(candidateId)) {
      await repo.unvote(candidateId);
    } else {
      await repo.vote(candidateId);
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          FilledButton.icon(
            onPressed: _suggestBook,
            icon: const Icon(Icons.add),
            label: const Text('도서 후보 추천'),
          ),
          const SizedBox(height: 16),
          if (_candidates.isEmpty)
            const Center(
                child: Padding(
              padding: EdgeInsets.only(top: 60),
              child: Text('추천된 도서 후보가 없습니다.\n내 서재에서 책을 추천해보세요.',
                  textAlign: TextAlign.center),
            ))
          else
            ..._candidates.map((c) {
              final id = c['id'] as String;
              final book = c['books'] as Map<String, dynamic>?;
              final title = book?['title'] as String? ?? '알 수 없는 책';
              final author = book?['author'] as String? ?? '';
              final cover = book?['cover_url'] as String?;
              final votes = c['votes'] as List?;
              final voteCount = votes?.length ?? 0;
              final voted = _myVotedIds.contains(id);

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: cover != null
                      ? Image.network(cover, width: 40)
                      : const Icon(Icons.book),
                  title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(author),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$voteCount',
                          style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary)),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: Icon(
                          voted
                              ? Icons.thumb_up
                              : Icons.thumb_up_outlined,
                          color: voted ? theme.colorScheme.primary : null,
                        ),
                        onPressed: () => _toggleVote(id),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  탭 4: 활동 (토론 주제 · 구절 · 후기)
// ═══════════════════════════════════════════════════
class _ActivityTab extends ConsumerStatefulWidget {
  final String discussionId;
  const _ActivityTab({required this.discussionId});

  @override
  ConsumerState<_ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends ConsumerState<_ActivityTab> {
  int _section = 0; // 0=주제, 1=구절, 2=후기
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  String get _uid => Supabase.instance.client.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(discussionRepoProvider);
      final list = switch (_section) {
        0 => await repo.topics(widget.discussionId),
        1 => await repo.quotes(widget.discussionId),
        2 => await repo.notes(widget.discussionId),
        _ => <Map<String, dynamic>>[],
      };
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  void _switchSection(int s) {
    setState(() {
      _section = s;
      _loading = true;
    });
    _load();
  }

  Future<void> _add() async {
    final contentCtrl = TextEditingController();
    final pageCtrl = TextEditingController();
    final title = ['토론 주제 추가', '인상 깊은 구절 추가', '모임 후기 추가'][_section];
    final hint = ['토론하고 싶은 주제나 질문을 적어주세요', '책 속 인상 깊은 문장을 적어주세요', '모임 후기나 느낀 점을 적어주세요'][_section];
    final showPage = _section == 1;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _SttInputDialog(
        title: title,
        hint: hint,
        contentCtrl: contentCtrl,
        pageCtrl: showPage ? pageCtrl : null,
      ),
    );

    if (ok == true && contentCtrl.text.trim().isNotEmpty) {
      try {
        final repo = ref.read(discussionRepoProvider);
        switch (_section) {
          case 0:
            await repo.createTopic(widget.discussionId, contentCtrl.text.trim());
          case 1:
            await repo.createQuote(widget.discussionId, contentCtrl.text.trim(),
                pageNumber: int.tryParse(pageCtrl.text));
          case 2:
            await repo.createNote(widget.discussionId, contentCtrl.text.trim());
        }
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('오류: $e')));
        }
      }
    }
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('삭제'),
        content: const Text('삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final repo = ref.read(discussionRepoProvider);
      switch (_section) {
        case 0: await repo.deleteTopic(id);
        case 1: await repo.deleteQuote(id);
        case 2: await repo.deleteNote(id);
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labels = ['토론 주제', '인상 깊은 구절', '모임 후기'];
    final icons = [Icons.question_answer, Icons.format_quote, Icons.edit_note];
    final df = DateFormat('MM/dd HH:mm');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: SegmentedButton<int>(
            segments: List.generate(3, (i) => ButtonSegment(
              value: i,
              label: Text(labels[i], style: const TextStyle(fontSize: 12)),
              icon: Icon(icons[i], size: 18),
            )),
            selected: {_section},
            onSelectionChanged: (s) => _switchSection(s.first),
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: Text('${labels[_section]} 추가'),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text('오류: $_error'))
                  : _items.isEmpty
                      ? Center(child: Text('등록된 ${labels[_section]}이 없습니다.',
                          style: const TextStyle(color: Colors.grey)))
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: _items.length,
                            itemBuilder: (context, i) {
                              final item = _items[i];
                              final content = item['content'] as String? ?? '';
                              final nick = item['nickname'] as String? ?? '';
                              final authorId = item['author_id'] as String? ?? '';
                              final time = DateTime.tryParse(item['created_at'] as String? ?? '');
                              final page = item['page_number'] as int?;
                              final isMine = authorId == _uid;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 14,
                                            backgroundColor: theme.colorScheme.primaryContainer,
                                            child: Text(nick.isNotEmpty ? nick[0] : '?',
                                                style: TextStyle(fontSize: 12, color: theme.colorScheme.primary)),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(nick, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                          const Spacer(),
                                          if (time != null)
                                            Text(df.format(time),
                                                style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                          if (isMine)
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, size: 18),
                                              onPressed: () => _delete(item['id'] as String),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      if (_section == 1)
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.surfaceContainerHighest,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border(left: BorderSide(
                                              color: theme.colorScheme.primary, width: 3)),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('"$content"',
                                                  style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 15)),
                                              if (page != null)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 4),
                                                  child: Text('p.$page',
                                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                                ),
                                            ],
                                          ),
                                        )
                                      else
                                        Text(content, style: const TextStyle(fontSize: 14)),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════
//  탭 5: 정보
// ═══════════════════════════════════════════════════
class _InfoTab extends ConsumerStatefulWidget {
  final String discussionId;
  final Map<String, dynamic>? discussion;
  final bool isHost;
  final bool isAdmin;
  const _InfoTab({
    required this.discussionId,
    required this.discussion,
    required this.isHost,
    required this.isAdmin,
  });

  @override
  ConsumerState<_InfoTab> createState() => _InfoTabState();
}

class _InfoTabState extends ConsumerState<_InfoTab> {
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final s = await ref.read(discussionRepoProvider).discussionStats(widget.discussionId);
      if (mounted) setState(() => _stats = s);
    } catch (_) {}
  }

  Future<void> _exportCsv(BuildContext context, String name, Future<dynamic> Function() export) async {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name 내보내기 중...')));
    try {
      final file = await export();
      if (context.mounted) await CsvExportService.shareFile(file, context);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('내보내기 실패: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.discussion;
    if (d == null) return const Center(child: Text('정보를 불러올 수 없습니다.'));

    final theme = Theme.of(context);
    final df = DateFormat('yyyy-MM-dd (E) HH:mm', 'ko');
    final isOnline = d['is_online'] as bool? ?? false;
    final region = d['region'] as String? ?? '';
    final desc = d['description'] as String?;
    final rules = d['rules'] as String?;
    final maxP = d['max_participants'] as int? ?? 10;
    final curP = d['current_participants'] as int? ?? 0;
    final scheduledAt = DateTime.tryParse(d['scheduled_at'] as String? ?? '');
    final isHost = widget.isHost;
    final isAdmin = widget.isAdmin;
    final discussionId = widget.discussionId;

    final meetingCount = _stats?['meetingCount'] as int? ?? 0;
    final memberCount = _stats?['memberCount'] as int? ?? 0;
    final books = (_stats?['books'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final members = (_stats?['members'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final attendanceMap = (_stats?['attendanceMap'] as Map?)?.cast<String, int>() ?? {};

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── 통계 요약 ──
        Row(
          children: [
            _StatCard(icon: Icons.event, label: '모임', value: '$meetingCount회'),
            const SizedBox(width: 8),
            _StatCard(icon: Icons.people, label: '멤버', value: '$memberCount명'),
            const SizedBox(width: 8),
            _StatCard(icon: Icons.book, label: '읽은 책', value: '${books.length}권'),
          ],
        ),
        const SizedBox(height: 16),

        // ── 멤버 참여율 ──
        if (members.isNotEmpty && meetingCount > 0) ...[
          Text('멤버 참여율', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ...members.map((m) {
            final uid = m['user_id'] as String;
            final nick = m['nickname'] as String? ?? '?';
            final count = attendanceMap[uid] ?? 0;
            final rate = meetingCount > 0 ? count / meetingCount : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(width: 70, child: Text(nick, style: const TextStyle(fontSize: 13))),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: rate,
                      backgroundColor: Colors.grey.shade200,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('$count/${meetingCount}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
        ],

        // ── 읽은 책 아카이브 ──
        if (books.isNotEmpty) ...[
          const Divider(height: 24),
          Text('읽은 책 아카이브', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ...books.map((b) {
            final bookData = b['books'] as Map<String, dynamic>?;
            final bookTitle = bookData?['title'] as String? ?? '알 수 없는 책';
            final author = bookData?['author'] as String? ?? '';
            final cover = bookData?['cover_url'] as String?;
            final at = DateTime.tryParse(b['scheduled_at'] as String? ?? '');
            return Card(
              child: ListTile(
                leading: cover != null
                    ? Image.network(cover, width: 36, errorBuilder: (_, __, ___) => const Icon(Icons.book))
                    : const Icon(Icons.book),
                title: Text(bookTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(author),
                trailing: at != null
                    ? Text(DateFormat('yy.MM').format(at), style: const TextStyle(fontSize: 12, color: Colors.grey))
                    : null,
              ),
            );
          }),
        ],

        const Divider(height: 32),

        // ── 기본 정보 ──
        Text(d['title'] as String? ?? '',
            style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            Chip(
              avatar: Icon(isOnline ? Icons.videocam : Icons.place, size: 18),
              label: Text(isOnline ? '온라인' : (region.isEmpty ? '오프라인' : region)),
            ),
            Chip(label: Text('$curP / $maxP 명')),
          ],
        ),
        if (scheduledAt != null)
          ListTile(
            leading: const Icon(Icons.event),
            title: Text(df.format(scheduledAt)),
            subtitle: const Text('첫 모임 일시'),
          ),
        if (desc != null && desc.isNotEmpty) ...[
          const Divider(height: 32),
          Text('소개', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(desc),
        ],
        if (rules != null && rules.isNotEmpty) ...[
          const Divider(height: 32),
          Text('규칙/공지', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(rules),
        ],
        const Divider(height: 32),
        _MemberSection(discussionId: discussionId, isHost: isHost),
        const Divider(height: 32),
        _AnnouncementsSection(discussionId: discussionId, isAdmin: isAdmin),
        if (isAdmin) ...[
          const Divider(height: 32),
          Text('데이터 내보내기', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.people, size: 18),
                label: const Text('멤버 목록'),
                onPressed: () => _exportCsv(context, '멤버목록',
                    () => CsvExportService.exportMembers(discussionId)),
              ),
              ActionChip(
                avatar: const Icon(Icons.check_circle, size: 18),
                label: const Text('출석 현황'),
                onPressed: () => _exportCsv(context, '출석현황',
                    () => CsvExportService.exportAttendance(discussionId)),
              ),
              ActionChip(
                avatar: const Icon(Icons.event, size: 18),
                label: const Text('모임 이력'),
                onPressed: () => _exportCsv(context, '모임이력',
                    () => CsvExportService.exportMeetingHistory(discussionId)),
              ),
            ],
          ),
        ],
        if (isHost) ...[
          const Divider(height: 32),
          FilledButton.tonalIcon(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('토론방 삭제'),
                  content: const Text('이 토론방을 삭제하시겠습니까?\n모든 데이터가 사라집니다.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('취소')),
                    FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: Colors.red),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('삭제')),
                  ],
                ),
              );
              if (ok == true) {
                await ref
                    .read(discussionRepoProvider)
                    .deleteDiscussion(discussionId);
                ref.invalidate(myDiscussionsProvider);
                if (context.mounted) Navigator.of(context).pop();
              }
            },
            icon: const Icon(Icons.delete, color: Colors.red),
            label:
                const Text('토론방 삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ],
    );
  }
}

class _AnnouncementsSection extends ConsumerStatefulWidget {
  final String discussionId;
  final bool isAdmin;
  const _AnnouncementsSection({required this.discussionId, required this.isAdmin});

  @override
  ConsumerState<_AnnouncementsSection> createState() => _AnnouncementsSectionState();
}

class _AnnouncementsSectionState extends ConsumerState<_AnnouncementsSection> {
  List<Map<String, dynamic>> _announcements = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await ref.read(discussionRepoProvider).announcements(widget.discussionId);
      if (!mounted) return;
      setState(() {
        _announcements = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _AnnouncementInputDialog(
        titleCtrl: titleCtrl,
        contentCtrl: contentCtrl,
      ),
    );

    if (result != null && titleCtrl.text.trim().isNotEmpty) {
      await ref.read(discussionRepoProvider).createAnnouncement(
            widget.discussionId,
            titleCtrl.text.trim(),
            content: contentCtrl.text.trim().isEmpty ? null : contentCtrl.text.trim(),
            isPinned: result['pinned'] as bool? ?? false,
          );
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('공지사항', style: theme.textTheme.titleMedium),
            const Spacer(),
            if (widget.isAdmin)
              TextButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('추가'),
              ),
          ],
        ),
        if (_loading) const Center(child: CircularProgressIndicator()),
        if (!_loading && _announcements.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('공지사항이 없습니다.', style: TextStyle(color: Colors.grey)),
          ),
        ..._announcements.map((a) {
          final isPinned = a['is_pinned'] as bool? ?? false;
          final title = a['title'] as String? ?? '';
          final content = a['content'] as String?;
          final time = DateTime.tryParse(a['created_at'] as String? ?? '');
          return Card(
            color: isPinned ? theme.colorScheme.primaryContainer : null,
            child: ListTile(
              leading: Icon(isPinned ? Icons.push_pin : Icons.campaign, size: 20),
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (content != null && content.isNotEmpty) Text(content),
                  if (time != null)
                    Text(DateFormat('yyyy-MM-dd HH:mm').format(time),
                        style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════
//  음성 입력 지원 다이얼로그
// ═══════════════════════════════════════════════════
class _SttInputDialog extends StatefulWidget {
  final String title;
  final String hint;
  final TextEditingController contentCtrl;
  final TextEditingController? pageCtrl;

  const _SttInputDialog({
    required this.title,
    required this.hint,
    required this.contentCtrl,
    this.pageCtrl,
  });

  @override
  State<_SttInputDialog> createState() => _SttInputDialogState();
}

class _SttInputDialogState extends State<_SttInputDialog> {
  final _speech = SpeechToText();
  bool _available = false;
  bool _listening = false;
  String _prefix = '';
  String _suffix = '';

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _available = await _speech.initialize(
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
    super.dispose();
  }

  Future<void> _toggleVoice() async {
    if (!_available) return;
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }

    final ctrl = widget.contentCtrl;
    final sel = ctrl.selection;
    final pos = (sel.isValid && sel.start >= 0) ? sel.start : ctrl.text.length;
    _prefix = ctrl.text.substring(0, pos);
    _suffix = ctrl.text.substring(pos);
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
        final spoken = r.recognizedWords;
        widget.contentCtrl.value = TextEditingValue(
          text: _prefix + spoken + _suffix,
          selection: TextSelection.collapsed(offset: _prefix.length + spoken.length),
        );
        setState(() {});
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                TextField(
                  controller: widget.contentCtrl,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    border: const OutlineInputBorder(),
                  ),
                ),
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: GestureDetector(
                    onTap: _toggleVoice,
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: _listening ? Colors.red : Colors.blue,
                      child: Icon(
                        _listening ? Icons.stop : Icons.mic,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_listening)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 8),
                    Text('듣고 있습니다...', style: TextStyle(fontSize: 12, color: Colors.red)),
                  ],
                ),
              ),
            if (widget.pageCtrl != null) ...[
              const SizedBox(height: 8),
              TextField(
                controller: widget.pageCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '페이지 (선택)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('추가')),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════
//  멤버 관리
// ═══════════════════════════════════════════════════
class _MemberSection extends ConsumerStatefulWidget {
  final String discussionId;
  final bool isHost;
  const _MemberSection({required this.discussionId, required this.isHost});

  @override
  ConsumerState<_MemberSection> createState() => _MemberSectionState();
}

class _MemberSectionState extends ConsumerState<_MemberSection> {
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;
  String get _uid => Supabase.instance.client.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(discussionRepoProvider);
      final m = await repo.memberList(widget.discussionId);
      final r = (widget.isHost)
          ? await repo.joinRequests(widget.discussionId)
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _members = m;
        _requests = r;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _kick(String userId, String nick) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('멤버 강퇴'),
        content: Text('$nick 님을 강퇴하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('강퇴'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(discussionRepoProvider).kickMember(widget.discussionId, userId);
      _load();
    }
  }

  Future<void> _approve(String userId) async {
    await ref.read(discussionRepoProvider).approveJoinRequest(widget.discussionId, userId);
    _load();
  }

  Future<void> _reject(String userId) async {
    await ref.read(discussionRepoProvider).rejectJoinRequest(widget.discussionId, userId);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) return const Center(child: CircularProgressIndicator());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 가입 승인 대기 (호스트만)
        if (widget.isHost && _requests.isNotEmpty) ...[
          Row(
            children: [
              Text('가입 신청', style: theme.textTheme.titleMedium),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 10,
                backgroundColor: Colors.red,
                child: Text('${_requests.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._requests.map((r) {
            final nick = r['nickname'] as String;
            final uid = r['user_id'] as String;
            final msg = r['message'] as String?;
            return Card(
              color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
              child: ListTile(
                leading: CircleAvatar(child: Text(nick.isNotEmpty ? nick[0] : '?')),
                title: Text(nick),
                subtitle: msg != null && msg.isNotEmpty ? Text(msg, maxLines: 2) : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      onPressed: () => _approve(uid),
                      tooltip: '승인',
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      onPressed: () => _reject(uid),
                      tooltip: '거절',
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
        ],

        // 멤버 목록
        Text('멤버 ${_members.length}명', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        ..._members.map((m) {
          final nick = m['nickname'] as String;
          final uid = m['user_id'] as String;
          final role = m['role'] as String? ?? 'member';
          final region = m['region'] as String?;
          final isMe = uid == _uid;
          final roleLabel = switch (role) {
            'host' => '호스트',
            'moderator' => '운영자',
            _ => '멤버',
          };

          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: role == 'host'
                    ? Colors.amber
                    : (role == 'moderator' ? theme.colorScheme.primary : Colors.grey.shade300),
                child: Text(
                  nick.isNotEmpty ? nick[0] : '?',
                  style: TextStyle(
                    color: role == 'host' || role == 'moderator' ? Colors.white : Colors.black54,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Row(
                children: [
                  Text(nick),
                  if (isMe) const Text(' (나)', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
              subtitle: Text([roleLabel, if (region != null && region.isNotEmpty) region].join(' · '),
                  style: const TextStyle(fontSize: 12)),
              trailing: widget.isHost && !isMe && role != 'host'
                  ? PopupMenuButton<String>(
                      itemBuilder: (_) => [
                        if (role != 'moderator')
                          const PopupMenuItem(value: 'moderator', child: Text('운영자 지정')),
                        if (role == 'moderator')
                          const PopupMenuItem(value: 'member', child: Text('운영자 해제')),
                        const PopupMenuItem(value: 'kick', child: Text('강퇴', style: TextStyle(color: Colors.red))),
                      ],
                      onSelected: (v) async {
                        if (v == 'kick') {
                          _kick(uid, nick);
                        } else {
                          await ref.read(discussionRepoProvider).changeRole(widget.discussionId, uid, v);
                          _load();
                        }
                      },
                    )
                  : null,
            ),
          );
        }),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatCard({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, size: 24, color: theme.colorScheme.primary),
              const SizedBox(height: 4),
              Text(value,
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              Text(label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnnouncementInputDialog extends StatefulWidget {
  final TextEditingController titleCtrl;
  final TextEditingController contentCtrl;
  const _AnnouncementInputDialog({required this.titleCtrl, required this.contentCtrl});

  @override
  State<_AnnouncementInputDialog> createState() => _AnnouncementInputDialogState();
}

class _AnnouncementInputDialogState extends State<_AnnouncementInputDialog> {
  final _speech = SpeechToText();
  bool _available = false;
  bool _listening = false;
  bool _pinned = false;
  TextEditingController? _activeCtrl;
  String _prefix = '';
  String _suffix = '';

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _available = await _speech.initialize(
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
    super.dispose();
  }

  Future<void> _toggleVoice(TextEditingController ctrl) async {
    if (!_available) return;
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }

    _activeCtrl = ctrl;
    final sel = ctrl.selection;
    final pos = (sel.isValid && sel.start >= 0) ? sel.start : ctrl.text.length;
    _prefix = ctrl.text.substring(0, pos);
    _suffix = ctrl.text.substring(pos);
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
        final spoken = r.recognizedWords;
        _activeCtrl?.value = TextEditingValue(
          text: _prefix + spoken + _suffix,
          selection: TextSelection.collapsed(offset: _prefix.length + spoken.length),
        );
        setState(() {});
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('공지사항 추가'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                TextField(
                  controller: widget.titleCtrl,
                  decoration: const InputDecoration(
                    labelText: '제목',
                    border: OutlineInputBorder(),
                  ),
                ),
                Positioned(
                  right: 4,
                  top: 4,
                  child: GestureDetector(
                    onTap: () => _toggleVoice(widget.titleCtrl),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: _listening && _activeCtrl == widget.titleCtrl
                          ? Colors.red : Colors.blue,
                      child: Icon(
                        _listening && _activeCtrl == widget.titleCtrl
                            ? Icons.stop : Icons.mic,
                        color: Colors.white, size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Stack(
              children: [
                TextField(
                  controller: widget.contentCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: '내용 (선택)',
                    border: OutlineInputBorder(),
                  ),
                ),
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: GestureDetector(
                    onTap: () => _toggleVoice(widget.contentCtrl),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: _listening && _activeCtrl == widget.contentCtrl
                          ? Colors.red : Colors.blue,
                      child: Icon(
                        _listening && _activeCtrl == widget.contentCtrl
                            ? Icons.stop : Icons.mic,
                        color: Colors.white, size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_listening)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 8),
                    Text('듣고 있습니다...', style: TextStyle(fontSize: 12, color: Colors.red)),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('상단 고정'),
              value: _pinned,
              onChanged: (v) => setState(() => _pinned = v),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        FilledButton(
          onPressed: () => Navigator.pop(context, {'pinned': _pinned}),
          child: const Text('추가'),
        ),
      ],
    );
  }
}

class _ImageViewerScreen extends StatefulWidget {
  final String imageUrl;
  const _ImageViewerScreen({required this.imageUrl});

  @override
  State<_ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<_ImageViewerScreen> {
  final _transformCtrl = TransformationController();

  @override
  void dispose() {
    _transformCtrl.dispose();
    super.dispose();
  }

  Future<void> _download() async {
    try {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('다운로드 중...')));
      final response = await HttpClient().getUrl(Uri.parse(widget.imageUrl));
      final httpResponse = await response.close();
      final bytes = await httpResponse.fold<List<int>>([], (prev, el) => prev..addAll(el));

      final dir = await getApplicationDocumentsDirectory();
      final fileName = 'booknet_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      await CsvExportService.shareFile(file, context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('다운로드 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('사진'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: '다운로드',
            onPressed: _download,
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          transformationController: _transformCtrl,
          minScale: 0.5,
          maxScale: 5.0,
          child: Image.network(
            widget.imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: progress.expectedTotalBytes != null
                      ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                      : null,
                  color: Colors.white,
                ),
              );
            },
            errorBuilder: (_, __, ___) => const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image, size: 64, color: Colors.grey),
                SizedBox(height: 8),
                Text('이미지를 불러올 수 없습니다', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
