import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/home/home_shell.dart';
import 'features/library/library_screen.dart';
import 'features/search/book_search_screen.dart';
import 'features/search/isbn_scanner_screen.dart';
import 'features/marketplace/marketplace_screen.dart';
import 'features/marketplace/bundle_edit_screen.dart';
import 'features/discussion/discussion_search_screen.dart';
import 'features/reviews/reviews_screen.dart';
import 'features/book_detail/book_detail_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/library',
    routes: [
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
            path: '/reviews',
            builder: (context, state) => const ReviewsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const BookSearchScreen(),
      ),
      GoRoute(
        path: '/scan',
        builder: (context, state) => const IsbnScannerScreen(),
      ),
      GoRoute(
        path: '/book/:id',
        builder: (context, state) =>
            BookDetailScreen(bookId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/bundle/edit',
        builder: (context, state) => const BundleEditScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('경로 오류: ${state.error}')),
    ),
  );
});
