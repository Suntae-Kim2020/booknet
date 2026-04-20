import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// 카카오 Local API 기반 주소 검색 (시/군/구/동/읍/면 까지)
Future<String?> showRegionPicker(BuildContext context, {String? initial}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _RegionPickerSheet(initial: initial),
  );
}

class _RegionPickerSheet extends StatefulWidget {
  const _RegionPickerSheet({this.initial});
  final String? initial;

  @override
  State<_RegionPickerSheet> createState() => _RegionPickerSheetState();
}

class _RegionPickerSheetState extends State<_RegionPickerSheet> {
  late final TextEditingController _q;
  Timer? _debounce;
  List<_RegionResult> _results = [];
  bool _loading = false;
  String? _error;

  static final _dio = Dio();

  @override
  void initState() {
    super.initState();
    _q = TextEditingController(text: widget.initial ?? '');
    if (_q.text.isNotEmpty) _search(_q.text);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(v));
  }

  Future<void> _search(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      setState(() {
        _results = [];
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final restKey = dotenv.env['KAKAO_REST_API_KEY'] ?? '';
      // 1) 키워드 → 행정동 검색 (동/읍/면)
      final res = await _dio.get(
        'https://dapi.kakao.com/v2/local/search/address.json',
        queryParameters: {'query': q, 'size': 30},
        options: Options(headers: {
          'Authorization': 'KakaoAK $restKey',
        }),
      );
      final docs = (res.data['documents'] as List?) ?? const [];
      final results = <_RegionResult>[];
      final seen = <String>{};
      for (final d in docs) {
        final addr = d['address'] as Map<String, dynamic>?;
        if (addr == null) continue;
        final region1 = addr['region_1depth_name'] as String? ?? '';
        final region2 = addr['region_2depth_name'] as String? ?? '';
        final region3 = addr['region_3depth_name'] as String? ?? '';
        final full = [region1, region2, region3]
            .where((s) => s.isNotEmpty)
            .join(' ');
        if (full.isEmpty || !seen.add(full)) continue;
        results.add(_RegionResult(full));
      }
      setState(() => _results = results);
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response?.data['msg'] ?? e.response?.data.toString())
          : e.response?.data?.toString() ?? e.message;
      setState(() => _error = '카카오 API 오류 (${e.response?.statusCode}): $msg');
    } catch (e) {
      setState(() => _error = '검색 오류: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      expand: false,
      builder: (_, scroll) {
        return Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('지역 검색',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                controller: _q,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '예: 강남구 역삼, 수원 영통, 전주 효자',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: _onChanged,
                onSubmitted: _search,
              ),
            ),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(_error!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error)),
              ),
            // 직접 입력 옵션
            if (_q.text.trim().isNotEmpty &&
                !_results.any((r) => r.fullName == _q.text.trim()))
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                child: ListTile(
                  leading: const Icon(Icons.edit_location_alt),
                  title: Text('직접 입력: "${_q.text.trim()}"'),
                  onTap: () => Navigator.pop(context, _q.text.trim()),
                ),
              ),
            Expanded(
              child: _results.isEmpty
                  ? Center(
                      child: Text(
                        _q.text.trim().isEmpty
                            ? '검색어를 입력하세요'
                            : (_loading ? '검색 중...' : '검색 결과가 없습니다'),
                      ),
                    )
                  : ListView.builder(
                      controller: scroll,
                      itemCount: _results.length,
                      itemBuilder: (_, i) {
                        final r = _results[i];
                        return ListTile(
                          leading: const Icon(Icons.place_outlined, size: 20),
                          title: Text(r.fullName),
                          onTap: () => Navigator.pop(context, r.fullName),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _RegionResult {
  _RegionResult(this.fullName);
  final String fullName;
}
