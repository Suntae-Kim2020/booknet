import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DiceScreen extends StatefulWidget {
  const DiceScreen({super.key});

  @override
  State<DiceScreen> createState() => _DiceScreenState();
}

class _DiceScreenState extends State<DiceScreen>
    with TickerProviderStateMixin {
  int _diceCount = 1;
  // [top, front, right] 면의 값
  List<List<int>> _faces = [
    [1, 2, 3]
  ];
  bool _isRolling = false;

  late AnimationController _rollCtrl;
  late AnimationController _bounceCtrl;
  late Animation<double> _throwY;
  late Animation<double> _rotateAnim;
  late Animation<double> _bounce;

  @override
  void initState() {
    super.initState();
    _rollCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _throwY = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -160), weight: 35),
      TweenSequenceItem(tween: Tween(begin: -160, end: 0), weight: 65),
    ]).animate(CurvedAnimation(parent: _rollCtrl, curve: Curves.easeOut));

    _rotateAnim = Tween<double>(begin: 0, end: 1).animate(_rollCtrl);

    _bounce = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -20), weight: 30),
      TweenSequenceItem(tween: Tween(begin: -20, end: 0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0, end: -8), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -8, end: 0), weight: 20),
    ]).animate(CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _rollCtrl.dispose();
    _bounceCtrl.dispose();
    super.dispose();
  }

  void _toggleDiceCount() {
    if (_isRolling) return;
    setState(() {
      _diceCount = _diceCount == 1 ? 2 : 1;
      _faces = List.generate(_diceCount, (_) => [1, 2, 3]);
    });
  }

  // 주사위 반대면 규칙: 합이 항상 7
  List<int> _randomDiceFaces(Random rng) {
    final top = rng.nextInt(6) + 1;
    final possibleFronts = [1, 2, 3, 4, 5, 6]
      ..remove(top)
      ..remove(7 - top);
    final front = possibleFronts[rng.nextInt(possibleFronts.length)];
    final possibleRights = [1, 2, 3, 4, 5, 6]
      ..remove(top)
      ..remove(7 - top)
      ..remove(front)
      ..remove(7 - front);
    final right = possibleRights[rng.nextInt(possibleRights.length)];
    return [top, front, right];
  }

  Future<void> _roll() async {
    if (_isRolling) return;
    setState(() => _isRolling = true);

    final rng = Random();
    HapticFeedback.mediumImpact();

    _rollCtrl.reset();
    _bounceCtrl.reset();
    _rollCtrl.forward();

    // 굴리는 동안 면 빠르게 바뀜
    for (int i = 0; i < 18; i++) {
      await Future.delayed(Duration(milliseconds: 40 + i * 4));
      if (!mounted) return;
      setState(() {
        _faces = List.generate(_diceCount, (_) => _randomDiceFaces(rng));
      });
      if (i % 3 == 0) {
        SystemSound.play(SystemSoundType.click);
        HapticFeedback.selectionClick();
      }
    }

    await _rollCtrl.forward().orCancel.catchError((_) {});

    // 착지
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.click);

    // 최종 값
    setState(() {
      _faces = List.generate(_diceCount, (_) => _randomDiceFaces(rng));
    });

    _bounceCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 150));
    HapticFeedback.lightImpact();

    await _bounceCtrl.forward().orCancel.catchError((_) {});
    setState(() => _isRolling = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topValues = _faces.map((f) => f[0]).toList();
    final total = topValues.fold(0, (a, b) => a + b);

    return Scaffold(
      appBar: AppBar(title: const Text('주사위 던지기')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 1, label: Text('1개')),
                ButtonSegment(value: 2, label: Text('2개')),
              ],
              selected: {_diceCount},
              onSelectionChanged: (_) => _toggleDiceCount(),
            ),
            const SizedBox(height: 48),
            AnimatedBuilder(
              animation: Listenable.merge([_rollCtrl, _bounceCtrl]),
              builder: (context, child) {
                final yOff = _rollCtrl.isAnimating
                    ? _throwY.value
                    : (_bounceCtrl.isAnimating ? _bounce.value : 0.0);
                return Transform.translate(
                  offset: Offset(0, yOff),
                  child: child,
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_diceCount, (i) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: AnimatedBuilder(
                      animation: _rollCtrl,
                      builder: (context, _) {
                        final rotAngle = _rollCtrl.isAnimating
                            ? _rotateAnim.value * pi * 4
                            : 0.0;
                        return Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.001)
                            ..rotateX(rotAngle * 0.3)
                            ..rotateZ(rotAngle * 0.2),
                          child: _IsometricDice(
                            top: _faces[i][0],
                            front: _faces[i][1],
                            right: _faces[i][2],
                            size: 90,
                          ),
                        );
                      },
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 40),
            if (_diceCount == 2)
              Text(
                '합계: $total',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            if (_diceCount == 2) const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                topValues.join(' + '),
                key: ValueKey(topValues.toString()),
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 48),
            FilledButton.icon(
              onPressed: _isRolling ? null : _roll,
              icon: const Icon(Icons.casino),
              label: Text(_isRolling ? '굴리는 중...' : '굴리기'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(160, 52),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 등각투영 3D 주사위 — 윗면, 앞면, 오른쪽면 3면 표시
class _IsometricDice extends StatelessWidget {
  final int top, front, right;
  final double size;
  const _IsometricDice({
    required this.top,
    required this.front,
    required this.right,
    this.size = 90,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size * 1.5, size * 1.6),
      painter: _IsometricDicePainter(
        top: top,
        front: front,
        right: right,
      ),
    );
  }
}

class _IsometricDicePainter extends CustomPainter {
  final int top, front, right;
  _IsometricDicePainter({
    required this.top,
    required this.front,
    required this.right,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    // 등각투영 꼭짓점 계산
    final faceW = w * 0.48;
    final faceH = faceW * 0.55; // 윗면 높이 (비스듬히)
    final bodyH = faceW * 0.85; // 앞면 높이

    // 중심점 기준
    final topCenter = Offset(cx, faceH);
    final topLeft = Offset(cx - faceW, faceH + faceH * 0.0);
    final topRight = Offset(cx + faceW, faceH + faceH * 0.0);
    final topTop = Offset(cx, 0);
    final bottomLeft = Offset(cx - faceW, faceH + bodyH);
    final bottomRight = Offset(cx + faceW, faceH + bodyH);
    final bottomCenter = Offset(cx, faceH + bodyH + faceH);

    // 그림자
    final shadowPath = Path()
      ..moveTo(topLeft.dx + 8, topLeft.dy + 12)
      ..lineTo(bottomLeft.dx + 8, bottomLeft.dy + 12)
      ..lineTo(bottomCenter.dx + 8, bottomCenter.dy + 12)
      ..lineTo(bottomRight.dx + 8, bottomRight.dy + 12)
      ..lineTo(topRight.dx + 8, topRight.dy + 12)
      ..lineTo(topTop.dx + 8, topTop.dy + 12)
      ..close();
    canvas.drawPath(
      shadowPath,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // === 윗면 (가장 밝음) ===
    final topPath = Path()
      ..moveTo(topTop.dx, topTop.dy)
      ..lineTo(topRight.dx, topRight.dy)
      ..lineTo(topCenter.dx, topCenter.dy + faceH)
      ..lineTo(topLeft.dx, topLeft.dy)
      ..close();
    canvas.drawPath(topPath, Paint()..color = const Color(0xFFF5F5F5));
    canvas.drawPath(
        topPath,
        Paint()
          ..color = Colors.grey.shade300
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);

    // === 왼쪽 앞면 (중간 밝기) ===
    final frontPath = Path()
      ..moveTo(topLeft.dx, topLeft.dy)
      ..lineTo(topCenter.dx, topCenter.dy + faceH)
      ..lineTo(bottomCenter.dx, bottomCenter.dy)
      ..lineTo(bottomLeft.dx, bottomLeft.dy)
      ..close();
    canvas.drawPath(frontPath, Paint()..color = const Color(0xFFE0E0E0));
    canvas.drawPath(
        frontPath,
        Paint()
          ..color = Colors.grey.shade400
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);

    // === 오른쪽 면 (가장 어두움) ===
    final rightPath = Path()
      ..moveTo(topCenter.dx, topCenter.dy + faceH)
      ..lineTo(topRight.dx, topRight.dy)
      ..lineTo(bottomRight.dx, bottomRight.dy)
      ..lineTo(bottomCenter.dx, bottomCenter.dy)
      ..close();
    canvas.drawPath(rightPath, Paint()..color = const Color(0xFFBDBDBD));
    canvas.drawPath(
        rightPath,
        Paint()
          ..color = Colors.grey.shade500
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);

    // === 점 그리기 ===
    _drawDotsOnFace(canvas, topTop, topRight,
        Offset(topCenter.dx, topCenter.dy + faceH), topLeft, this.top,
        color: Colors.black87);

    _drawDotsOnFace(canvas, topLeft,
        Offset(topCenter.dx, topCenter.dy + faceH), bottomCenter, bottomLeft, front,
        color: Colors.black54);

    _drawDotsOnFace(canvas, Offset(topCenter.dx, topCenter.dy + faceH),
        topRight, bottomRight, bottomCenter, right,
        color: Colors.black45);
  }

  void _drawDotsOnFace(Canvas canvas, Offset tl, Offset tr, Offset br,
      Offset bl, int value,
      {Color color = Colors.black}) {
    // 면의 중심과 축 벡터
    final centerX = (tl.dx + tr.dx + br.dx + bl.dx) / 4;
    final centerY = (tl.dy + tr.dy + br.dy + bl.dy) / 4;
    final center = Offset(centerX, centerY);

    // u 벡터: tl→tr 방향, v 벡터: tl→bl 방향
    final u = Offset((tr.dx - tl.dx) / 2, (tr.dy - tl.dy) / 2);
    final v = Offset((bl.dx - tl.dx) / 2, (bl.dy - tl.dy) / 2);

    final dotR = u.distance * 0.12;
    final paint = Paint()..color = color;

    // 점 위치를 (u, v) 좌표로 표현 (-0.5~0.5 범위)
    final positions = _dotUV(value);
    for (final p in positions) {
      final pos = center + u * p.dx + v * p.dy;
      canvas.drawCircle(pos, dotR, paint);
    }
  }

  List<Offset> _dotUV(int value) {
    const d = 0.55;
    switch (value) {
      case 1:
        return [Offset.zero];
      case 2:
        return [const Offset(-d, -d), const Offset(d, d)];
      case 3:
        return [const Offset(-d, -d), Offset.zero, const Offset(d, d)];
      case 4:
        return [
          const Offset(-d, -d), const Offset(d, -d),
          const Offset(-d, d), const Offset(d, d),
        ];
      case 5:
        return [
          const Offset(-d, -d), const Offset(d, -d), Offset.zero,
          const Offset(-d, d), const Offset(d, d),
        ];
      case 6:
        return [
          const Offset(-d, -d), const Offset(d, -d),
          const Offset(-d, 0), const Offset(d, 0),
          const Offset(-d, d), const Offset(d, d),
        ];
      default:
        return [Offset.zero];
    }
  }

  @override
  bool shouldRepaint(covariant _IsometricDicePainter old) =>
      old.top != top || old.front != front || old.right != right;
}
