import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CsvExportService {
  static SupabaseClient get _db => Supabase.instance.client;
  static String get _uid => _db.auth.currentUser?.id ?? '';
  static final _df = DateFormat('yyyy-MM-dd HH:mm');

  /// 내 독서기록 CSV
  static Future<File> exportMyBooks() async {
    final rows = await _db
        .from('books')
        .select()
        .eq('owner_id', _uid)
        .isFilter('deleted_at', null)
        .order('created_at');

    final buf = StringBuffer();
    buf.writeln('제목,저자,출판사,ISBN,읽기상태,읽은날짜,등록일');
    for (final b in (rows as List)) {
      final title = _esc(b['title'] as String? ?? '');
      final author = _esc(b['author'] as String? ?? '');
      final publisher = _esc(b['publisher'] as String? ?? '');
      final isbn = b['isbn'] as String? ?? '';
      final isRead = b['is_read'] == true;
      final readAt = b['read_at'] as String?;
      final status = isRead ? '읽음' : (readAt != null ? '읽는중' : '안읽음');
      final readDate = readAt != null ? _df.format(DateTime.parse(readAt)) : '';
      final createdAt = b['created_at'] != null
          ? _df.format(DateTime.parse(b['created_at'] as String))
          : '';
      buf.writeln('$title,$author,$publisher,$isbn,$status,$readDate,$createdAt');
    }
    return _writeFile('내_독서기록', buf.toString());
  }

  /// 내 메모 CSV
  static Future<File> exportMyMemos() async {
    final rows = await _db
        .from('memos')
        .select('*, books(title)')
        .eq('user_id', _uid)
        .order('created_at', ascending: false);

    final buf = StringBuffer();
    buf.writeln('책제목,메모내용,페이지,공유여부,작성일');
    for (final m in (rows as List)) {
      final bookTitle = _esc((m['books'] as Map?)?['title'] as String? ?? '');
      final content = _esc(m['content'] as String? ?? '');
      final page = m['page_number']?.toString() ?? '';
      final shared = m['is_shared'] == true ? '공개' : '비공개';
      final date = m['created_at'] != null
          ? _df.format(DateTime.parse(m['created_at'] as String))
          : '';
      buf.writeln('$bookTitle,$content,$page,$shared,$date');
    }
    return _writeFile('내_메모', buf.toString());
  }

  /// 내 한줄평 CSV
  static Future<File> exportMyReviews() async {
    final rows = await _db
        .from('reviews')
        .select('*, books(title)')
        .eq('user_id', _uid)
        .order('created_at', ascending: false);

    final buf = StringBuffer();
    buf.writeln('책제목,별점,한줄평,작성일');
    for (final r in (rows as List)) {
      final bookTitle = _esc((r['books'] as Map?)?['title'] as String? ?? '');
      final rating = r['rating']?.toString() ?? '';
      final content = _esc(r['content'] as String? ?? '');
      final date = r['created_at'] != null
          ? _df.format(DateTime.parse(r['created_at'] as String))
          : '';
      buf.writeln('$bookTitle,$rating,$content,$date');
    }
    return _writeFile('내_한줄평', buf.toString());
  }

  /// 토론방 멤버 목록 CSV
  static Future<File> exportMembers(String discussionId) async {
    final rows = await _db
        .from('discussion_participants')
        .select('user_id, role, status, joined_at')
        .eq('discussion_id', discussionId)
        .eq('status', 'joined')
        .order('joined_at');

    final buf = StringBuffer();
    buf.writeln('닉네임,역할,지역,가입일');
    for (final r in (rows as List)) {
      final uid = r['user_id'] as String;
      final p = await _db.from('profiles').select('nickname, region').eq('id', uid).maybeSingle();
      final nick = _esc((p?['nickname'] as String?) ?? '');
      final role = switch (r['role'] as String?) {
        'host' => '호스트',
        'moderator' => '운영자',
        _ => '멤버',
      };
      final region = _esc((p?['region'] as String?) ?? '');
      final joined = r['joined_at'] != null
          ? _df.format(DateTime.parse(r['joined_at'] as String))
          : '';
      buf.writeln('$nick,$role,$region,$joined');
    }
    return _writeFile('멤버목록', buf.toString());
  }

  /// 토론방 출석 현황 CSV
  static Future<File> exportAttendance(String discussionId) async {
    // 모임 목록
    final meetings = await _db
        .from('discussion_meetings')
        .select('id, scheduled_at, location')
        .eq('discussion_id', discussionId)
        .order('scheduled_at');
    final meetingList = (meetings as List).cast<Map<String, dynamic>>();

    // 멤버 목록
    final members = await _db
        .from('discussion_participants')
        .select('user_id')
        .eq('discussion_id', discussionId)
        .eq('status', 'joined');
    final memberIds = (members as List).map((m) => m['user_id'] as String).toList();

    // 닉네임 조회
    final nickMap = <String, String>{};
    for (final uid in memberIds) {
      final p = await _db.from('profiles').select('nickname').eq('id', uid).maybeSingle();
      nickMap[uid] = (p?['nickname'] as String?) ?? uid.substring(0, 8);
    }

    // 출석 데이터 조회
    final attendanceMap = <String, Map<String, String>>{}; // meetingId -> {userId -> status}
    for (final m in meetingList) {
      final mid = m['id'] as String;
      final att = await _db
          .from('discussion_attendance')
          .select('user_id, status')
          .eq('meeting_id', mid);
      attendanceMap[mid] = {
        for (final a in (att as List))
          a['user_id'] as String: a['status'] as String? ?? 'present'
      };
    }

    final buf = StringBuffer();
    // 헤더: 이름, 모임1날짜, 모임2날짜, ...
    buf.write('이름');
    for (final m in meetingList) {
      final date = DateFormat('MM/dd').format(DateTime.parse(m['scheduled_at'] as String));
      buf.write(',$date');
    }
    buf.writeln(',출석률');

    // 각 멤버 행
    for (final uid in memberIds) {
      buf.write(_esc(nickMap[uid] ?? ''));
      int attended = 0;
      for (final m in meetingList) {
        final mid = m['id'] as String;
        final status = attendanceMap[mid]?[uid];
        final label = switch (status) {
          'present' => 'O',
          'late' => '△',
          'absent' => 'X',
          _ => '-',
        };
        if (status == 'present' || status == 'late') attended++;
        buf.write(',$label');
      }
      final rate = meetingList.isNotEmpty
          ? '${(attended / meetingList.length * 100).round()}%'
          : '-';
      buf.writeln(',$rate');
    }
    return _writeFile('출석현황', buf.toString());
  }

  /// 토론방 모임 이력 CSV
  static Future<File> exportMeetingHistory(String discussionId) async {
    final rows = await _db
        .from('discussion_meetings')
        .select()
        .eq('discussion_id', discussionId)
        .order('scheduled_at');

    final buf = StringBuffer();
    buf.writeln('회차,날짜,장소,진행자,비고');
    int num = 1;
    for (final m in (rows as List)) {
      final date = m['scheduled_at'] != null
          ? _df.format(DateTime.parse(m['scheduled_at'] as String))
          : '';
      final location = _esc(m['location'] as String? ?? '');
      final modId = m['moderator_id'] as String?;
      String modNick = '';
      if (modId != null) {
        final p = await _db.from('profiles').select('nickname').eq('id', modId).maybeSingle();
        modNick = _esc((p?['nickname'] as String?) ?? '');
      }
      final notes = _esc(m['notes'] as String? ?? '');
      buf.writeln('${num++},$date,$location,$modNick,$notes');
    }
    return _writeFile('모임이력', buf.toString());
  }

  // CSV 특수문자 이스케이프
  static String _esc(String s) {
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  // 파일 저장
  static Future<File> _writeFile(String name, String content) async {
    final dir = await getApplicationDocumentsDirectory();
    final date = DateFormat('yyyyMMdd').format(DateTime.now());
    final file = File('${dir.path}/${name}_$date.csv');
    // UTF-8 BOM + UTF-8 인코딩 (Excel 한글 깨짐 방지)
    final bom = [0xEF, 0xBB, 0xBF];
    await file.writeAsBytes([...bom, ...utf8.encode(content)]);
    return file;
  }

  /// 파일 공유 (AirDrop, 메일, 카카오톡 등)
  static Future<void> shareFile(File file, BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: file.path.split('/').last,
      sharePositionOrigin: box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : null,
    );
  }
}
