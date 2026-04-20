import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/login_screen.dart';
import 'features/auth/profile_setup_screen.dart';
import 'features/home/home_shell.dart';
import 'features/library/library_screen.dart';
import 'features/search/book_search_screen.dart';
import 'features/search/isbn_scanner_screen.dart';
import 'features/marketplace/marketplace_screen.dart';
import 'features/marketplace/bundle_detail_screen.dart';
import 'features/marketplace/bundle_edit_screen.dart';
import 'features/discussion/discussion_create_screen.dart';
import 'features/discussion/discussion_detail_screen.dart';
import 'features/discussion/discussion_home_screen.dart';
import 'features/discussion/discussion_search_screen.dart';
import 'features/games/game_list_screen.dart';
import 'features/games/roulette_screen.dart';
import 'features/games/dice_screen.dart';
import 'features/games/ladder_screen.dart';
import 'features/reviews/reviews_screen.dart';
import 'features/book_detail/book_detail_screen.dart';
import 'features/memo/memo_list_screen.dart';
import 'features/memo/memo_edit_screen.dart';
import 'features/memo/memo_search_screen.dart';
import 'features/chat/chat_list_screen.dart';
import 'features/chat/chat_room_screen.dart';
import 'features/notifications/notification_list_screen.dart';
import 'features/settings/settings_screen.dart';
import 'models/memo.dart';
import 'providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/library',
    redirect: (context, state) {
      if (authState.isLoading) return null;

      final session = authState.valueOrNull?.session;
      final isLoggedIn = session != null;
      final path = state.uri.path;
      final isAuthRoute = path == '/login' || path == '/profile/setup';

      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && path == '/login') return '/library';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/profile/setup',
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => HomeShell(child: child),
        routes: [
          GoRoute(
            path: '/library',
            builder: (context, state) => const LibraryScreen(),
          ),
          GoRoute(
            path: '/marketplace',
            builder: (context, state) => const MarketplaceScreen(),
          ),
          GoRoute(
            path: '/discussion',
            builder: (context, state) => const DiscussionSearchScreen(),
          ),
          GoRoute(
            path: '/chat',
            builder: (context, state) => const ChatListScreen(),
          ),
          GoRoute(
            path: '/more',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
      // 검색
      GoRoute(
        path: '/search',
        builder: (context, state) => const BookSearchScreen(),
      ),
      GoRoute(
        path: '/scan',
        builder: (context, state) => const IsbnScannerScreen(),
      ),
      GoRoute(
        path: '/memos/search',
        builder: (context, state) => const MemoSearchScreen(),
      ),
      // 책 상세 + 메모
      GoRoute(
        path: '/book/:id',
        builder: (context, state) =>
            BookDetailScreen(bookId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/book/:id/memos',
        builder: (context, state) => MemoListScreen(
          bookId: state.pathParameters['id']!,
          bookTitle: state.extra as String?,
        ),
      ),
      GoRoute(
        path: '/book/:id/memo/edit',
        builder: (context, state) => MemoEditScreen(
          bookId: state.pathParameters['id']!,
          existingMemo: state.extra as Memo?,
        ),
      ),
      // 꾸러미
      GoRoute(
        path: '/bundle/edit',
        builder: (context, state) => const BundleEditScreen(),
      ),
      GoRoute(
        path: '/bundle/:id',
        builder: (context, state) =>
            BundleDetailScreen(bundleId: state.pathParameters['id']!),
      ),
      // 한줄평
      GoRoute(
        path: '/reviews',
        builder: (context, state) => const ReviewsScreen(),
      ),
      GoRoute(
        path: '/discussion/create',
        builder: (context, state) => const DiscussionCreateScreen(),
      ),
      GoRoute(
        path: '/discussion/:id',
        builder: (context, state) =>
            DiscussionDetailScreen(discussionId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/discussion/:id/home',
        builder: (context, state) =>
            DiscussionHomeScreen(discussionId: state.pathParameters['id']!),
      ),
      // 채팅
      GoRoute(
        path: '/chat/:roomId',
        builder: (context, state) =>
            ChatRoomScreen(roomId: state.pathParameters['roomId']!),
      ),
      // 알림
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationListScreen(),
      ),
      // 설정
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      // 게임
      GoRoute(
        path: '/games',
        builder: (context, state) => const GameListScreen(),
      ),
      GoRoute(
        path: '/games/roulette',
        builder: (context, state) => const RouletteScreen(),
      ),
      GoRoute(
        path: '/games/dice',
        builder: (context, state) => const DiceScreen(),
      ),
      GoRoute(
        path: '/games/ladder',
        builder: (context, state) => const LadderScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('경로 오류: ${state.error}')),
    ),
  );
});
