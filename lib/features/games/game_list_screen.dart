import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class GameListScreen extends StatefulWidget {
  const GameListScreen({super.key});

  @override
  State<GameListScreen> createState() => _GameListScreenState();
}

class _GameListScreenState extends State<GameListScreen> {
  static const _games = [
    _GameItem(
      title: '룰렛',
      subtitle: '숫자 원판 · 텍스트 원판 · 전자시계 추첨',
      icon: Icons.casino,
      color: Color(0xFFE53935),
      route: '/games/roulette',
    ),
    _GameItem(
      title: '주사위 던지기',
      subtitle: '주사위를 굴려 숫자를 정해보세요',
      icon: Icons.casino_outlined,
      color: Color(0xFF1E88E5),
      route: '/games/dice',
    ),
    _GameItem(
      title: '사다리타기',
      subtitle: '누가 어떤 결과를 받을까요?',
      icon: Icons.stairs,
      color: Color(0xFF43A047),
      route: '/games/ladder',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('파티 게임'),
        centerTitle: true,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _games.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final game = _games[index];
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => context.push(game.route),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: game.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(game.icon, color: game.color, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            game.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            game.subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GameItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;

  const _GameItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
  });
}
