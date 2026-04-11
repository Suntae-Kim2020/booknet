import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'services/auth_service.dart';
import 'services/naver_book_api.dart';
import 'services/tts_service.dart';
import 'services/repositories/book_repository.dart';
import 'services/repositories/bundle_repository.dart';
import 'services/repositories/chat_repository.dart';
import 'services/repositories/discussion_repository.dart';
import 'services/repositories/memo_repository.dart';
import 'services/repositories/notification_repository.dart';
import 'services/repositories/profile_repository.dart';
import 'services/repositories/review_repository.dart';

// ---------- Auth ----------
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authStateProvider = StreamProvider<User?>((ref) {
  try {
    return ref.watch(authServiceProvider).authStateChanges;
  } catch (_) {
    // Firebase 미설정 시 빈 스트림
    return Stream.value(null);
  }
});

// ---------- External APIs ----------
final naverBookApiProvider = Provider<NaverBookApi>((ref) => NaverBookApi());
final ttsServiceProvider = Provider<TtsService>((ref) => TtsService());

// ---------- Repositories ----------
final bookRepoProvider = Provider<BookRepository>((ref) => BookRepository());
final bundleRepoProvider = Provider<BundleRepository>((ref) => BundleRepository());
final chatRepoProvider = Provider<ChatRepository>((ref) => ChatRepository());
final discussionRepoProvider = Provider<DiscussionRepository>((ref) => DiscussionRepository());
final memoRepoProvider = Provider<MemoRepository>((ref) => MemoRepository());
final notificationRepoProvider = Provider<NotificationRepository>((ref) => NotificationRepository());
final profileRepoProvider = Provider<ProfileRepository>((ref) => ProfileRepository());
final reviewRepoProvider = Provider<ReviewRepository>((ref) => ReviewRepository());
