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
import 'features/marketplace/bundle_edit_screen.dart';
import 'features/discussion/discussion_search_screen.dart';
import 'features/reviews/reviews_screen.dart';
import 'features/book_detail/book_detail_screen.dart';
import 'features/memo/memo_list_screen.dart';
import 'features/memo/memo_edit_screen.dart';
import 'features/memo/memo_search_screen.dart';
import 'features/book_photo/book_photo_screen.dart';
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
      final isLoggedIn = authState.valueOrNull != null;
      final isAuthRoute = state.uri.path == '/login' ||
          state.uri.path == '/profile/setup';

      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && state.uri.path == '/login') return '/library';
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
        path: '/photo',
        builder: (context, state) => const BookPhotoScreen(),
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
      // 한줄평
      GoRoute(
        path: '/reviews',
        builder: (context, state) => const ReviewsScreen(),
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
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('경로 오류: ${state.error}')),
    ),
  );
});
