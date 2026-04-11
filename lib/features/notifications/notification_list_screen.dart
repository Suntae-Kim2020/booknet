import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/app_notification.dart';
import '../../providers.dart';

final notificationsProvider =
    FutureProvider<List<AppNotification>>((ref) async {
  return ref.read(notificationRepoProvider).myNotifications();
});

class NotificationListScreen extends ConsumerWidget {
  const NotificationListScreen({super.key});

  IconData _iconForType(String type) {
    switch (type) {
      case 'discussion_match':
        return Icons.forum;
      case 'purchase_request':
        return Icons.shopping_bag;
      case 'chat_message':
        return Icons.chat;
      case 'bundle_sold':
        return Icons.sell;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    final df = DateFormat('MM-dd HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('알림'),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(notificationRepoProvider).markAllRead();
              ref.invalidate(notificationsProvider);
            },
            child: const Text('모두 읽음'),
          ),
        ],
      ),
      body: notifications.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('알림이 없습니다.'));
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final n = list[i];
              return ListTile(
                leading: Icon(
                  _iconForType(n.type),
                  color: n.isRead ? Colors.grey : null,
                ),
                title: Text(n.title,
                    style: n.isRead
                        ? null
                        : const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(n.body ?? df.format(n.createdAt)),
                trailing: Text(df.format(n.createdAt),
                    style: Theme.of(context).textTheme.bodySmall),
                onTap: () async {
                  if (!n.isRead) {
                    await ref
                        .read(notificationRepoProvider)
                        .markRead(n.id);
                    ref.invalidate(notificationsProvider);
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
