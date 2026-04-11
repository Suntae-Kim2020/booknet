import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../models/book.dart';

/// 네이버 책 검색 API 클라이언트
/// https://developers.naver.com/docs/serviceapi/search/book/book.md
class NaverBookApi {
  NaverBookApi({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;
  static const _base = 'https://openapi.naver.com/v1/search/book.json';
  static const _baseAdv = 'https://openapi.naver.com/v1/search/book_adv.json';

  Map<String, String> get _headers => {
        'X-Naver-Client-Id': dotenv.env['NAVER_CLIENT_ID'] ?? '',
        'X-Naver-Client-Secret': dotenv.env['NAVER_CLIENT_SECRET'] ?? '',
      };

  /// 키워드 검색 (제목/저자/출판사 등)
  Future<List<Book>> searchByKeyword(String query, {int display = 20}) async {
    final res = await _dio.get(
      _base,
      queryParameters: {'query': query, 'display': display},
      options: Options(headers: _headers),
    );
    return _parseItems(res.data);
  }

  /// ISBN으로 정확 검색
  Future<Book?> searchByIsbn(String isbn) async {
    final res = await _dio.get(
      _baseAdv,
      queryParameters: {'d_isbn': isbn},
      options: Options(headers: _headers),
    );
    final list = _parseItems(res.data);
    return list.isEmpty ? null : list.first;
  }

  List<Book> _parseItems(dynamic data) {
    final items = (data['items'] as List?) ?? const [];
    return items.map<Book>((raw) {
      final m = raw as Map<String, dynamic>;
      final title = _stripTags(m['title'] as String? ?? '');
      final author = _stripTags(m['author'] as String? ?? '');
      final publisher = _stripTags(m['publisher'] as String? ?? '');
      final isbn = (m['isbn'] as String? ?? '').split(' ').last;
      return Book(
        id: isbn.isEmpty ? title : isbn,
        ownerId: '', // 등록 시 실제 uid로 설정
        isbn: isbn,
        title: title,
        author: author,
        publisher: publisher,
        coverUrl: m['image'] as String?,
        description: _stripTags(m['description'] as String? ?? ''),
        publishedAt: _parseDate(m['pubdate'] as String?),
      );
    }).toList();
  }

  String _stripTags(String s) =>
      s.replaceAll(RegExp(r'<[^>]+>'), '').replaceAll('&quot;', '"');

  DateTime? _parseDate(String? s) {
    if (s == null || s.length < 8) return null;
    return DateTime.tryParse(
        '${s.substring(0, 4)}-${s.substring(4, 6)}-${s.substring(6, 8)}');
  }
}
