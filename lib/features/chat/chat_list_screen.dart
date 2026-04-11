import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/chat_room.dart';
import '../../providers.dart';

final chatRoomsProvider = FutureProvider<List<ChatRoom>>((ref) async {
  return ref.read(chatRepoProvider).myChatRooms();
});

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rooms = ref.watch(chatRoomsProvider);
    final df = DateFormat('MM-dd HH:mm');

    return Scaffold(
      appBar: AppBar(title: const Text('채팅')),
      body: rooms.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Text('채팅이 없습니다.\n꾸러미 구매 요청을 보내면 채팅이 시작됩니다.',
                  textAlign: TextAlign.center),
            );
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final room = list[i];
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.chat)),
                title: Text('채팅방 ${room.id.substring(0, 8)}'),
                subtitle: room.lastMessageAt != null
                    ? Text(df.format(room.lastMessageAt!))
                    : const Text('새 대화'),
                onTap: () => context.push('/chat/${room.id}'),
              );
            },
          );
        },
      ),
    );
  }
}
