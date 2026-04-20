import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum RouletteType { wheelNumber, wheelText, digital }

class RouletteScreen extends StatefulWidget {
  const RouletteScreen({super.key});

  @override
  State<RouletteScreen> createState() => _RouletteScreenState();
}

class _RouletteScreenState extends State<RouletteScreen> {
  RouletteType _type = RouletteType.wheelNumber;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('룰렛')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: SegmentedButton<RouletteType>(
              segments: const [
                ButtonSegment(
                    value: RouletteType.wheelNumber,
                    label: Text('숫자 원판'),
                    icon: Icon(Icons.pin, size: 18)),
                ButtonSegment(
                    value: RouletteType.wheelText,
                    label: Text('텍스트 원판'),
                    icon: Icon(Icons.text_fields, size: 18)),
                ButtonSegment(
                    value: RouletteType.digital,
                    label: Text('전자시계'),
                    icon: Icon(Icons.access_time, size: 18)),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
          ),
          Expanded(
            child: switch (_type) {
              RouletteType.wheelNumber => const _WheelNumberMode(),
              RouletteType.wheelText => const _WheelTextMode(),
              RouletteType.digital => const _DigitalMode(),
            },
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// 빵빠레 (Confetti) 오버레이
// ═══════════════════════════════════════════════════
class _ConfettiOverlay extends StatefulWidget {
  final VoidCallback onDone;
  const _ConfettiOverlay({required this.onDone});

  @override
  State<_ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<_ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    final rng = Random();
    _particles = List.generate(120, (_) => _Particle(rng));
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3000))
      ..addListener(() => setState(() {}))
      ..forward().then((_) => widget.onDone());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: MediaQuery.of(context).size,
        painter: _ConfettiPainter(_particles, _ctrl.value),
      ),
    );
  }
}

class _Particle {
  final double x, speed, size, rotation, rotSpeed;
  final Color color;
  final int shape; // 0=rect, 1=circle, 2=star
  _Particle(Random r)
      : x = r.nextDouble(),
        speed = 0.3 + r.nextDouble() * 0.7,
        size = 4 + r.nextDouble() * 8,
        rotation = r.nextDouble() * 2 * pi,
        rotSpeed = (r.nextDouble() - 0.5) * 10,
        color = [
          const Color(0xFFE53935),
          const Color(0xFF1E88E5),
          const Color(0xFF43A047),
          const Color(0xFFFDD835),
          const Color(0xFF8E24AA),
          const Color(0xFFFF6F00),
          const Color(0xFFD81B60),
          const Color(0xFF00BCD4),
          const Color(0xFFFF9800),
          const Color(0xFF4CAF50),
        ][r.nextInt(10)],
        shape = r.nextInt(3);
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double t;
  _ConfettiPainter(this.particles, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final x = p.x * size.width + sin(t * 4 + p.rotation) * 30;
      final y = -20 + t * (size.height + 40) * p.speed;
      final opacity = t < 0.8 ? 1.0 : (1.0 - (t - 0.8) / 0.2);
      final paint = Paint()..color = p.color.withValues(alpha: opacity.clamp(0, 1));

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotation + p.rotSpeed * t);
      if (p.shape == 0) {
        canvas.drawRect(
            Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
            paint);
      } else if (p.shape == 1) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        final path = Path();
        for (int i = 0; i < 5; i++) {
          final angle = -pi / 2 + i * 4 * pi / 5;
          final r = p.size * 0.5;
          if (i == 0) {
            path.moveTo(r * cos(angle), r * sin(angle));
          } else {
            path.lineTo(r * cos(angle), r * sin(angle));
          }
        }
        path.close();
        canvas.drawPath(path, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => true;
}

// 드럼 롤 효과 (빠른 클릭 + 햅틱)
Future<void> _drumRoll({int beats = 20, int startMs = 30, int endMs = 80}) async {
  for (int i = 0; i < beats; i++) {
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.selectionClick();
    final ms = startMs + ((endMs - startMs) * i / beats).round();
    await Future.delayed(Duration(milliseconds: ms));
  }
}

Future<void> _fanfare() async {
  for (int i = 0; i < 5; i++) {
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.click);
    await Future.delayed(const Duration(milliseconds: 100));
  }
}

// ═══════════════════════════════════════════════════
//  모드 1: 숫자 원판
// ═══════════════════════════════════════════════════
class _WheelNumberMode extends StatefulWidget {
  const _WheelNumberMode();
  @override
  State<_WheelNumberMode> createState() => _WheelNumberModeState();
}

class _WheelNumberModeState extends State<_WheelNumberMode>
    with SingleTickerProviderStateMixin {
  final _minCtrl = TextEditingController(text: '1');
  final _maxCtrl = TextEditingController(text: '45');
  bool _remember = false;
  final Set<int> _usedNumbers = {};
  late AnimationController _animCtrl;
  double _currentAngle = 0;
  bool _spinning = false;
  bool _showConfetti = false;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 5000));
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  List<int> get _availableNumbers {
    final mn = int.tryParse(_minCtrl.text) ?? 1;
    final mx = int.tryParse(_maxCtrl.text) ?? 45;
    return [for (int i = mn; i <= mx; i++) if (!_usedNumbers.contains(i)) i];
  }

  void _spin() {
    final numbers = _availableNumbers;
    if (_spinning) return;
    if (numbers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('사용 가능한 번호가 없습니다. 초기화하세요.')));
      return;
    }
    if (numbers.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('최소 2개 번호가 필요합니다.')));
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    final rng = Random();
    final extra = 5 + rng.nextInt(6);
    final randomOff = rng.nextDouble() * 2 * pi;
    final total = extra * 2 * pi + randomOff;
    final start = _currentAngle;
    int lastSeg = -1;

    final anim = Tween<double>(begin: 0, end: total).animate(
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));

    anim.addListener(() {
      final angle = start + anim.value;
      setState(() => _currentAngle = angle);
      final seg = ((angle % (2 * pi)) / (2 * pi / numbers.length)).floor();
      if (seg != lastSeg) {
        lastSeg = seg;
        SystemSound.play(SystemSoundType.click);
        HapticFeedback.selectionClick();
      }
    });

    setState(() => _spinning = true);
    HapticFeedback.mediumImpact();
    _animCtrl.reset();
    _animCtrl.forward().then((_) async {
      await _fanfare();
      setState(() {
        _spinning = false;
        _showConfetti = true;
      });
      _showNumberResult(numbers);
    });
  }

  void _showNumberResult(List<int> numbers) {
    final segAngle = 2 * pi / numbers.length;
    final norm = _currentAngle % (2 * pi);
    final idx = ((2 * pi - norm) % (2 * pi) / segAngle).floor() % numbers.length;
    final result = numbers[idx];

    if (_remember) _usedNumbers.add(result);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('🎉 당첨!', textAlign: TextAlign.center),
        content: Text('$result',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900)),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() => _showConfetti = false);
              },
              child: const Text('확인')),
        ],
      ),
    ).then((_) {
      setState(() => _showConfetti = false);
      Future.delayed(const Duration(milliseconds: 50), () {
        FocusManager.instance.primaryFocus?.unfocus();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final numbers = _availableNumbers;
    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  SizedBox(
                    width: 70,
                    child: TextField(
                      controller: _minCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: '최소', isDense: true,
                          border: OutlineInputBorder()),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('~')),
                  SizedBox(
                    width: 70,
                    child: TextField(
                      controller: _maxCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: '최대', isDense: true,
                          border: OutlineInputBorder()),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilterChip(
                    label: const Text('번호기억'),
                    selected: _remember,
                    onSelected: (v) => setState(() {
                      _remember = v;
                      if (!v) _usedNumbers.clear();
                    }),
                  ),
                ],
              ),
            ),
            if (_remember && _usedNumbers.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                          '사용됨: ${(_usedNumbers.toList()..sort()).join(", ")}',
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 12)),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _usedNumbers.clear()),
                      child: const Text('초기화'),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: Center(
                child: numbers.length < 2
                    ? const Text('숫자 범위를 확인하세요 (최소 2개)')
                    : _WheelWidget(
                        items: numbers.map((n) => '$n').toList(),
                        angle: _currentAngle,
                        spinning: _spinning,
                        onSpin: _spin,
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: FilledButton.icon(
                onPressed: _spinning || numbers.length < 2 ? null : _spin,
                icon: const Icon(Icons.play_arrow),
                label: Text(_spinning ? '돌아가는 중...' : '돌리기'),
                style: FilledButton.styleFrom(minimumSize: const Size(160, 48)),
              ),
            ),
          ],
        ),
        if (_showConfetti)
          _ConfettiOverlay(onDone: () => setState(() => _showConfetti = false)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════
//  모드 2: 텍스트 원판
// ═══════════════════════════════════════════════════
class _WheelTextMode extends StatefulWidget {
  const _WheelTextMode();
  @override
  State<_WheelTextMode> createState() => _WheelTextModeState();
}

class _WheelTextModeState extends State<_WheelTextMode>
    with SingleTickerProviderStateMixin {
  final List<String> _items = ['당첨', '꽝'];
  final _textCtrl = TextEditingController();
  late AnimationController _animCtrl;
  double _currentAngle = 0;
  bool _spinning = false;
  bool _showConfetti = false;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 5000));
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  void _addItem() {
    final t = _textCtrl.text.trim();
    if (t.isEmpty || _items.length >= 12) return;
    setState(() {
      _items.add(t);
      _textCtrl.clear();
    });
  }

  void _spin() {
    if (_spinning || _items.length < 2) return;
    final rng = Random();
    final extra = 5 + rng.nextInt(6);
    final total = extra * 2 * pi + rng.nextDouble() * 2 * pi;
    final start = _currentAngle;
    int lastSeg = -1;

    final anim = Tween<double>(begin: 0, end: total).animate(
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    anim.addListener(() {
      final angle = start + anim.value;
      setState(() => _currentAngle = angle);
      final seg = ((angle % (2 * pi)) / (2 * pi / _items.length)).floor();
      if (seg != lastSeg) {
        lastSeg = seg;
        SystemSound.play(SystemSoundType.click);
        HapticFeedback.selectionClick();
      }
    });

    setState(() => _spinning = true);
    HapticFeedback.mediumImpact();
    _animCtrl.reset();
    _animCtrl.forward().then((_) async {
      await _fanfare();
      final segAngle = 2 * pi / _items.length;
      final norm = _currentAngle % (2 * pi);
      final idx = ((2 * pi - norm) % (2 * pi) / segAngle).floor() % _items.length;

      setState(() {
        _spinning = false;
        _showConfetti = true;
      });

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('🎉 결과!', textAlign: TextAlign.center),
          content: Text(_items[idx],
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900)),
          actions: [
            TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() => _showConfetti = false);
                },
                child: const Text('확인')),
          ],
        ),
      ).then((_) {
        setState(() => _showConfetti = false);
        FocusManager.instance.primaryFocus?.unfocus();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              flex: 3,
              child: Center(
                child: _WheelWidget(
                  items: _items,
                  angle: _currentAngle,
                  spinning: _spinning,
                  onSpin: _spin,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: FilledButton.icon(
                onPressed: _spinning || _items.length < 2 ? null : _spin,
                icon: const Icon(Icons.play_arrow),
                label: Text(_spinning ? '돌아가는 중...' : '돌리기'),
                style: FilledButton.styleFrom(minimumSize: const Size(160, 48)),
              ),
            ),
            const Divider(),
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _textCtrl,
                            decoration: InputDecoration(
                              hintText: '항목 추가 (최대 12개)',
                              isDense: true,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                            ),
                            onSubmitted: (_) => _addItem(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _addItem,
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _items.length,
                      itemBuilder: (_, i) => ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 12,
                          backgroundColor: _segColors[i % _segColors.length],
                          child: Text('${i + 1}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 11)),
                        ),
                        title: Text(_items[i]),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: _spinning || _items.length <= 2
                              ? null
                              : () => setState(() => _items.removeAt(i)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_showConfetti)
          _ConfettiOverlay(onDone: () => setState(() => _showConfetti = false)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════
//  모드 3: 전자시계 (슬롯머신)
// ═══════════════════════════════════════════════════
class _DigitalMode extends StatefulWidget {
  const _DigitalMode();
  @override
  State<_DigitalMode> createState() => _DigitalModeState();
}

class _DigitalModeState extends State<_DigitalMode>
    with SingleTickerProviderStateMixin {
  final _minCtrl = TextEditingController(text: '1');
  final _maxCtrl = TextEditingController(text: '999');
  bool _rolling = false;
  bool _showConfetti = false;
  bool _remember = false;
  final Set<int> _usedNumbers = {};
  List<int> _digits = [0, 0, 0];
  List<bool> _stopped = [];
  late AnimationController _tickCtrl;
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _tickCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
  }

  @override
  void dispose() {
    _tickCtrl.dispose();
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  int get _digitCount {
    final mx = int.tryParse(_maxCtrl.text) ?? 999;
    return max(mx, 1).toString().length;
  }

  Future<void> _roll() async {
    if (_rolling) return;
    final mn = int.tryParse(_minCtrl.text) ?? 1;
    final mx = int.tryParse(_maxCtrl.text) ?? 999;
    if (mn > mx || mn < 0) return;

    FocusManager.instance.primaryFocus?.unfocus();

    // 사용 가능한 번호 목록
    final available = [
      for (int i = mn; i <= mx; i++)
        if (!_usedNumbers.contains(i)) i
    ];
    if (available.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('사용 가능한 번호가 없습니다. 초기화하세요.')));
      }
      return;
    }

    final result = available[_rng.nextInt(available.length)];
    final dc = _digitCount;
    final resultStr = result.toString().padLeft(dc, '0');
    final targetDigits = resultStr.split('').map(int.parse).toList();

    _digits = List.filled(dc, 0);
    _stopped = List.filled(dc, false);
    setState(() => _rolling = true);

    // 뒷자리(dc-1)가 먼저 멈추고, 앞자리(0)가 가장 늦게 멈춤
    // 각 자리의 멈추는 시점(ms): 뒷자리부터 1500, 2500, 3500, ...
    final stopTimes = List.generate(dc, (i) {
      final order = dc - 1 - i; // 뒷자리=0, 앞자리=dc-1
      return 1500 + order * 1000;
    });
    final totalDuration = stopTimes.reduce(max);

    final sw = Stopwatch()..start();
    int tickCount = 0;

    // 메인 루프: 80ms마다 아직 안 멈춘 자리 랜덤 변경
    while (sw.elapsedMilliseconds < totalDuration + 200) {
      await Future.delayed(const Duration(milliseconds: 80));
      if (!mounted) return;

      final elapsed = sw.elapsedMilliseconds;
      bool anyChanged = false;

      for (int i = 0; i < dc; i++) {
        if (!_stopped[i] && elapsed >= stopTimes[i]) {
          // 이 자리 확정
          _digits[i] = targetDigits[i];
          _stopped[i] = true;
          HapticFeedback.mediumImpact();
          SystemSound.play(SystemSoundType.click);
          anyChanged = true;
        } else if (!_stopped[i]) {
          _digits[i] = _rng.nextInt(10);
          anyChanged = true;
        }
      }

      tickCount++;
      if (tickCount % 2 == 0 && !_stopped.every((s) => s)) {
        SystemSound.play(SystemSoundType.click);
        HapticFeedback.selectionClick();
      }

      if (anyChanged) setState(() {});

      if (_stopped.every((s) => s)) break;
    }

    // 모두 확정
    setState(() {
      for (int i = 0; i < dc; i++) {
        _digits[i] = targetDigits[i];
        _stopped[i] = true;
      }
    });

    await _fanfare();

    if (_remember) _usedNumbers.add(result);

    if (!mounted) return;
    setState(() {
      _rolling = false;
      _showConfetti = true;
    });

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('🎉 당첨!', textAlign: TextAlign.center),
        content: Text('$result',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900)),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() => _showConfetti = false);
              },
              child: const Text('확인')),
        ],
      ),
    ).then((_) {
      setState(() => _showConfetti = false);
      Future.delayed(const Duration(milliseconds: 50), () {
        FocusManager.instance.primaryFocus?.unfocus();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dc = _digitCount;

    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 90,
                    child: TextField(
                      controller: _minCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: '최소', isDense: true,
                          border: OutlineInputBorder()),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('~', style: TextStyle(fontSize: 20))),
                  SizedBox(
                    width: 90,
                    child: TextField(
                      controller: _maxCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: '최대', isDense: true,
                          border: OutlineInputBorder()),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilterChip(
                    label: const Text('번호기억'),
                    selected: _remember,
                    onSelected: (v) => setState(() {
                      _remember = v;
                      if (!v) _usedNumbers.clear();
                    }),
                  ),
                ],
              ),
            ),
            if (_remember && _usedNumbers.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                          '사용됨: ${(_usedNumbers.toList()..sort()).join(", ")}',
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 12)),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _usedNumbers.clear()),
                      child: const Text('초기화'),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Text('$dc자리 숫자',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: Colors.grey.shade600)),
            Expanded(
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(dc, (i) {
                      final digit = i < _digits.length ? _digits[i] : 0;
                      final isStopped =
                          i < _stopped.length ? _stopped[i] : true;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 100),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 12),
                        decoration: BoxDecoration(
                          color: isStopped && _rolling == false
                              ? const Color(0xFF1B5E20)
                              : const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isStopped && _rolling == false
                                ? Colors.greenAccent
                                : Colors.grey.shade700,
                            width: 2,
                          ),
                          boxShadow: isStopped && _rolling == false
                              ? [
                                  BoxShadow(
                                    color:
                                        Colors.greenAccent.withValues(alpha: 0.4),
                                    blurRadius: 12,
                                  )
                                ]
                              : null,
                        ),
                        child: Text(
                          '$digit',
                          style: TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            color: isStopped && !_rolling
                                ? Colors.greenAccent
                                : const Color(0xFFFF3D00),
                            shadows: [
                              Shadow(
                                color: (isStopped && !_rolling
                                        ? Colors.greenAccent
                                        : Colors.redAccent)
                                    .withValues(alpha: 0.6),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: FilledButton.icon(
                onPressed: _rolling ? null : _roll,
                icon: const Icon(Icons.play_arrow),
                label: Text(_rolling ? '추첨 중...' : '추첨하기'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(180, 52),
                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        ),
        if (_showConfetti)
          _ConfettiOverlay(onDone: () => setState(() => _showConfetti = false)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════
//  공통 원판 위젯
// ═══════════════════════════════════════════════════
const _segColors = [
  Color(0xFFE53935), Color(0xFF1E88E5), Color(0xFF43A047),
  Color(0xFFFDD835), Color(0xFF8E24AA), Color(0xFFFF6F00),
  Color(0xFF00ACC1), Color(0xFFD81B60), Color(0xFF7CB342),
  Color(0xFF5C6BC0), Color(0xFFFF8A65), Color(0xFF26A69A),
];

class _WheelWidget extends StatelessWidget {
  final List<String> items;
  final double angle;
  final bool spinning;
  final VoidCallback onSpin;

  const _WheelWidget({
    required this.items,
    required this.angle,
    required this.spinning,
    required this.onSpin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final sz = min(constraints.maxWidth, constraints.maxHeight) - 48;
        final wheelSz = max(sz, 200.0);
        return SizedBox(
          width: wheelSz,
          height: wheelSz + 24,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                top: 0,
                child: CustomPaint(
                  size: const Size(24, 20),
                  painter:
                      _PointerPainter(color: theme.colorScheme.onSurface),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: GestureDetector(
                  onTap: spinning ? null : onSpin,
                  child: Transform.rotate(
                    angle: angle,
                    child: CustomPaint(
                      size: Size(wheelSz - 24, wheelSz - 24),
                      painter: _WheelPainter(items: items, colors: _segColors),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WheelPainter extends CustomPainter {
  final List<String> items;
  final List<Color> colors;
  _WheelPainter({required this.items, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final segAngle = 2 * pi / items.length;

    for (int i = 0; i < items.length; i++) {
      final start = -pi / 2 + i * segAngle;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start, segAngle, true,
        Paint()..color = colors[i % colors.length],
      );
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start, segAngle, true,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(start + segAngle / 2);
      final tp = TextPainter(
        text: TextSpan(
          text: items[i],
          style: const TextStyle(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: radius * 0.45);
      tp.paint(canvas,
          Offset(radius * 0.55 - tp.width / 2, -tp.height / 2));
      canvas.restore();
    }

    canvas.drawCircle(center, 16, Paint()..color = Colors.white);
    canvas.drawCircle(
      center, 16,
      Paint()
        ..color = Colors.grey.shade400
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _WheelPainter old) => true;
}

class _PointerPainter extends CustomPainter {
  final Color color;
  _PointerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _PointerPainter old) => old.color != color;
}
