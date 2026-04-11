import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/profile.dart';

class ProfileRepository {
  SupabaseClient get _db => Supabase.instance.client;
  String get _uid => _db.auth.currentUser?.id ?? '';

  Future<Profile?> myProfile() async {
    final rows = await _db.from('profiles').select().eq('id', _uid);
    if ((rows as List).isEmpty) return null;
    return Profile.fromMap(rows.first);
  }

  Future<Profile?> getProfile(String userId) async {
    final rows = await _db.from('profiles').select().eq('id', userId);
    if ((rows as List).isEmpty) return null;
    return Profile.fromMap(rows.first);
  }

  Future<Profile> upsertProfile(Profile profile) async {
    final row = await _db
        .from('profiles')
        .upsert(profile.toMap())
        .select()
        .single();
    return Profile.fromMap(row);
  }
}
