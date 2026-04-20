import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class LadderScreen extends StatefulWidget {
  const LadderScreen({super.key});

  @override
  State<LadderScreen> createState() => _LadderScreenState();
}

class _LadderScreenState extends State<LadderScreen>
    with SingleTickerProviderStateMixin {
  int _playerCount = 3;
  late List<TextEditingController> _nameControllers;
  late List<TextEditingController> _prizeControllers;

  // Ladder data
  List<List<bool>> _bridges = [];
  List<List<Offset>> _paths = [];
  bool _isAnimating = false;
  bool _showResults = false;
  double _animProgress = 0;
  late AnimationController _animController;
  late Animation<double> _animation;

  // Mapping: player index -> prize index after traversal
  List<int> _results = [];

  @override
  void initState() {
    super.initState();
    _initControllers();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8000),
    );
    _animation = CurvedAnimation(
      parent: _animController,
      curve: Curves.linear,
    );
    int _lastTick = -1;
    _animation.addListener(() {
      setState(() => _animProgress = _animation.value);
      // 5%마다 틱 사운드
      final tick = (_animation.value * 20).floor();
      if (tick != _lastTick) {
        _lastTick = tick;
        SystemSound.play(SystemSoundType.click);
        HapticFeedback.selectionClick();
      }
    });
  }

  void _initControllers() {
    _nameControllers = List.generate(
      _playerCount,
      (i) => TextEditingController(text: '참가자 ${i + 1}'),
    );
    _prizeControllers = List.generate(
      _playerCount,
      (i) => TextEditingController(text: '결과 ${i + 1}'),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    for (final c in _nameControllers) {
      c.dispose();
    }
    for (final c in _prizeControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _setPlayerCount(int count) {
    if (_isAnimating) return;
    // Dispose old controllers
    for (final c in _nameControllers) {
      c.dispose();
    }
    for (final c in _prizeControllers) {
      c.dispose();
    }
    setState(() {
      _playerCount = count;
      _initControllers();
      _bridges = [];
      _paths = [];
      _showResults = false;
      _results = [];
    });
  }

  void _generateAndRun() {
    if (_isAnimating) return;

    final random = Random();
    final rows = 8 + random.nextInt(5); // 8-12 bridge rows

    // Generate bridges: for each row, decide if there's a bridge
    // between adjacent vertical lines
    _bridges = List.generate(rows, (_) {
      final row = List.generate(_playerCount - 1, (_) => false);
      for (int i = 0; i < _playerCount - 1; i++) {
        // ~40% chance of a bridge, but no two adjacent bridges in the same row
        if (i > 0 && row[i - 1]) continue;
        row[i] = random.nextDouble() < 0.4;
      }
      // Ensure at least one bridge per row for a more interesting ladder
      if (!row.contains(true)) {
        row[random.nextInt(_playerCount - 1)] = true;
      }
      return row;
    });

    // Trace each player's path
    _results = List.filled(_playerCount, 0);
    _paths = [];

    for (int player = 0; player < _playerCount; player++) {
      int currentLine = player;
      final path = <Offset>[Offset(currentLine.toDouble(), -1)];

      for (int row = 0; row < _bridges.length; row++) {
        // Move down to this row
        path.add(Offset(currentLine.toDouble(), row.toDouble()));

        // Check for bridge to the right
        if (currentLine < _playerCount - 1 && _bridges[row][currentLine]) {
          currentLine++;
          path.add(Offset(currentLine.toDouble(), row.toDouble()));
        }
        // Check for bridge to the left
        else if (currentLine > 0 && _bridges[row][currentLine - 1]) {
          currentLine--;
          path.add(Offset(currentLine.toDouble(), row.toDouble()));
        }
      }

      // Final position
      path.add(Offset(currentLine.toDouble(), _bridges.length.toDouble()));
      _paths.add(path);
      _results[player] = currentLine;
    }

    setState(() {
      _showResults = false;
      _isAnimating = true;
      _animProgress = 0;
    });

    HapticFeedback.mediumImpact();
    _animController.reset();
    _animController.forward().then((_) {
      HapticFeedback.heavyImpact();
      setState(() {
        _isAnimating = false;
        _showResults = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasLadder = _bridges.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('사다리타기')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Player count selector
            Text('참가자 수', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton.filled(
                  onPressed: _isAnimating || _playerCount <= 2
                      ? null
                      : () => _setPlayerCount(_playerCount - 1),
                  icon: const Icon(Icons.remove),
                ),
                const SizedBox(width: 12),
                Text(
                  '$_playerCount명',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 12),
                IconButton.filled(
                  onPressed: _isAnimating || _playerCount >= 50
                      ? null
                      : () => _setPlayerCount(_playerCount + 1),
                  icon: const Icon(Icons.add),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Slider(
                    value: _playerCount.toDouble(),
                    min: 2,
                    max: 50,
                    divisions: 48,
                    label: '$_playerCount명',
                    onChanged: _isAnimating
                        ? null
                        : (v) => _setPlayerCount(v.round()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Names input
            Text('참가자 이름', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_playerCount, (i) {
                return SizedBox(
                  width: 140,
                  child: TextField(
                    controller: _nameControllers[i],
                    onTap: () => _nameControllers[i].selection =
                        TextSelection(
                            baseOffset: 0,
                            extentOffset: _nameControllers[i].text.length),
                    decoration: InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            // Prizes input
            Text('결과/상품', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_playerCount, (i) {
                return SizedBox(
                  width: 140,
                  child: TextField(
                    controller: _prizeControllers[i],
                    onTap: () => _prizeControllers[i].selection =
                        TextSelection(
                            baseOffset: 0,
                            extentOffset: _prizeControllers[i].text.length),
                    decoration: InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            // Start button
            Center(
              child: FilledButton.icon(
                onPressed: _isAnimating ? null : _generateAndRun,
                icon: const Icon(Icons.play_arrow),
                label: Text(_isAnimating ? '진행 중...' : '시작'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(160, 48),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Ladder display
            if (hasLadder)
              SizedBox(
                height: 400,
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _LadderPainter(
                    playerCount: _playerCount,
                    bridges: _bridges,
                    paths: _paths,
                    progress: _animProgress,
                    names: _nameControllers.map((c) => c.text).toList(),
                    prizes: _prizeControllers.map((c) => c.text).toList(),
                  ),
                ),
              ),
            // Results
            if (_showResults) ...[
              const Divider(height: 32),
              Text(
                '결과',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ...List.generate(_playerCount, (i) {
                final prizeIndex = _results[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _playerColors[i % _playerColors.length],
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(_nameControllers[i].text),
                    trailing: Text(
                      _prizeControllers[prizeIndex].text,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                        fontSize: 15,
                      ),
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

const _playerColors = [
  Color(0xFFE53935),
  Color(0xFF1E88E5),
  Color(0xFF43A047),
  Color(0xFFFFA000),
  Color(0xFF8E24AA),
  Color(0xFF00ACC1),
];

class _LadderPainter extends CustomPainter {
  final int playerCount;
  final List<List<bool>> bridges;
  final List<List<Offset>> paths;
  final double progress;
  final List<String> names;
  final List<String> prizes;

  _LadderPainter({
    required this.playerCount,
    required this.bridges,
    required this.paths,
    required this.progress,
    required this.names,
    required this.prizes,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (bridges.isEmpty) return;

    final topPadding = 28.0;
    final bottomPadding = 28.0;
    final sidePadding = 24.0;
    final usableWidth = size.width - sidePadding * 2;
    final usableHeight = size.height - topPadding - bottomPadding;
    final colSpacing = usableWidth / (playerCount - 1);
    final rowCount = bridges.length;
    final rowSpacing = usableHeight / (rowCount + 1);

    double xForCol(int col) => sidePadding + col * colSpacing;
    double yForRow(int row) => topPadding + (row + 1) * rowSpacing;

    // Draw vertical lines
    final linePaint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    for (int col = 0; col < playerCount; col++) {
      final x = xForCol(col);
      canvas.drawLine(
        Offset(x, topPadding),
        Offset(x, size.height - bottomPadding),
        linePaint,
      );
    }

    // Draw bridges
    final bridgePaint = Paint()
      ..color = Colors.grey.shade500
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    for (int row = 0; row < rowCount; row++) {
      for (int col = 0; col < playerCount - 1; col++) {
        if (bridges[row][col]) {
          final y = yForRow(row);
          canvas.drawLine(
            Offset(xForCol(col), y),
            Offset(xForCol(col + 1), y),
            bridgePaint,
          );
        }
      }
    }

    // Draw names at top
    for (int i = 0; i < playerCount; i++) {
      final tp = TextPainter(
        text: TextSpan(
          text: names[i],
          style: TextStyle(
            color: _playerColors[i % _playerColors.length],
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: colSpacing);
      tp.paint(canvas, Offset(xForCol(i) - tp.width / 2, 4));
    }

    // Draw prizes at bottom
    for (int i = 0; i < playerCount; i++) {
      final tp = TextPainter(
        text: TextSpan(
          text: prizes[i],
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: colSpacing);
      tp.paint(
        canvas,
        Offset(xForCol(i) - tp.width / 2, size.height - bottomPadding + 8),
      );
    }

    // Draw animated paths
    for (int player = 0; player < paths.length; player++) {
      final path = paths[player];
      if (path.isEmpty) continue;

      final pathPaint = Paint()
        ..color = _playerColors[player % _playerColors.length]
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      // Convert path points to pixel coordinates
      final pixelPoints = path.map((p) {
        final x = xForCol(p.dx.toInt());
        final row = p.dy;
        final y =
            row < 0 ? topPadding : (row >= rowCount ? size.height - bottomPadding : yForRow(row.toInt()));
        return Offset(x, y);
      }).toList();

      // Calculate total path length
      double totalLength = 0;
      for (int i = 1; i < pixelPoints.length; i++) {
        totalLength += (pixelPoints[i] - pixelPoints[i - 1]).distance;
      }

      // Draw path up to progress
      final drawLength = totalLength * progress;
      double drawnSoFar = 0;
      final drawPath = Path();
      drawPath.moveTo(pixelPoints[0].dx, pixelPoints[0].dy);

      Offset? lastPoint;
      for (int i = 1; i < pixelPoints.length; i++) {
        final segLen = (pixelPoints[i] - pixelPoints[i - 1]).distance;
        if (drawnSoFar + segLen <= drawLength) {
          drawPath.lineTo(pixelPoints[i].dx, pixelPoints[i].dy);
          drawnSoFar += segLen;
          lastPoint = pixelPoints[i];
        } else {
          final remaining = drawLength - drawnSoFar;
          final t = remaining / segLen;
          final p = Offset.lerp(pixelPoints[i - 1], pixelPoints[i], t)!;
          drawPath.lineTo(p.dx, p.dy);
          lastPoint = p;
          break;
        }
      }

      canvas.drawPath(drawPath, pathPaint);

      // Draw player dot at current position
      if (lastPoint != null) {
        canvas.drawCircle(
          lastPoint,
          6,
          Paint()..color = _playerColors[player % _playerColors.length],
        );
        canvas.drawCircle(
          lastPoint,
          6,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LadderPainter oldDelegate) => true;
}
