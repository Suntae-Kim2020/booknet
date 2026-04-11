import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/app_notification.dart';

class NotificationRepository {
  SupabaseClient get _db => Supabase.instance.client;
  String get _uid => _db.auth.currentUser?.id ?? '';

  Future<List<AppNotification>> myNotifications({int limit = 50}) async {
    final rows = await _db
        .from('notifications')
        .select()
        .eq('user_id', _uid)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List).map((e) => AppNotification.fromMap(e)).toList();
  }

  Future<int> unreadCount() async {
    final rows = await _db
        .from('notifications')
        .select('id')
        .eq('user_id', _uid)
        .eq('is_read', false);
    return (rows as List).length;
  }

  Future<void> markRead(String notificationId) async {
    await _db
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  Future<void> markAllRead() async {
    await _db
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', _uid)
        .eq('is_read', false);
  }

  Future<void> createNotification({
    required String userId,
    required String type,
    required String title,
    String? body,
    Map<String, dynamic>? data,
    String channel = 'in_app',
  }) async {
    await _db.from('notifications').insert({
      'user_id': userId,
      'type': type,
      'title': title,
      'body': body,
      'data': data,
      'channel': channel,
    });
  }

  /// Supabase Realtime 구독
  RealtimeChannel subscribeToNotifications(
    void Function(AppNotification) onNotification,
  ) {
    return _db
        .channel('notifications:$_uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: _uid,
          ),
          callback: (payload) {
            onNotification(AppNotification.fromMap(payload.newRecord));
          },
        )
        .subscribe();
  }
}
