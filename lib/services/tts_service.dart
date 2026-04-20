import 'package:flutter_tts/flutter_tts.dart';

/// 한 줄 평 등을 음성으로 읽어주는 서비스
class TtsService {
  TtsService() {
    _init();
  }

  final FlutterTts _tts = FlutterTts();
  bool _ready = false;

  Future<void> _init() async {
    await _tts.setLanguage('ko-KR');
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);
    _ready = true;
  }

  Future<void> speak(String text) async {
    if (!_ready) await _init();
    if (text.trim().isEmpty) return;
    await _tts.stop();
    await _tts.speak(text);
  }

  /// 여러 텍스트를 순차적으로 읽기
  Future<void> speakAll(List<String> texts) async {
    if (!_ready) await _init();
    await _tts.stop();
    final joined = texts
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .join('. ');
    if (joined.isEmpty) return;
    await _tts.speak(joined);
  }

  Future<void> stop() => _tts.stop();
}
