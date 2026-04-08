import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'services/naver_book_api.dart';
import 'services/supabase_repository.dart';
import 'services/tts_service.dart';

final naverBookApiProvider = Provider<NaverBookApi>((ref) => NaverBookApi());

final supabaseRepoProvider =
    Provider<SupabaseRepository>((ref) => SupabaseRepository());

final ttsServiceProvider = Provider<TtsService>((ref) => TtsService());
