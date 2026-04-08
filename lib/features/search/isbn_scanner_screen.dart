import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../providers.dart';

class IsbnScannerScreen extends ConsumerStatefulWidget {
  const IsbnScannerScreen({super.key});

  @override
  ConsumerState<IsbnScannerScreen> createState() => _IsbnScannerScreenState();
}

class _IsbnScannerScreenState extends ConsumerState<IsbnScannerScreen> {
  bool _handled = false;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null) return;
    _handled = true;

    try {
      final book = await ref.read(naverBookApiProvider).searchByIsbn(code);
      if (book == null) {
        _showSnack('ISBN $code 검색 결과 없음');
        _handled = false;
        return;
      }
      await ref.read(supabaseRepoProvider).upsertBook(book);
      _showSnack('등록: ${book.title}');
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _showSnack('오류: $e');
      _handled = false;
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ISBN 바코드 스캔')),
      body: MobileScanner(onDetect: _onDetect),
    );
  }
}
