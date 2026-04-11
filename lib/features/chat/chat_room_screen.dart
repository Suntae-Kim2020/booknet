import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/chat_message.dart';
import '../../providers.dart';

class ChatRoomScreen extends ConsumerStatefulWidget {
  const ChatRoomScreen({super.key, required this.roomId});

  final String roomId;

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<ChatMessage> _messages = [];
  bool _loading = true;
  RealtimeChannel? _channel;

  String get _uid => Supabase.instance.client.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _subscribeRealtime();
  }

  Future<void> _loadMessages() async {
    final msgs =
        await ref.read(chatRepoProvider).messages(widget.roomId, limit: 100);
    setState(() {
      _messages = msgs.reversed.toList();
      _loading = false;
    });
    await ref.read(chatRepoProvider).markMessagesRead(widget.roomId);
    _scrollToBottom();
  }

  void _subscribeRealtime() {
    _channel = ref.read(chatRepoProvider).subscribeToRoom(
      widget.roomId,
      (msg) {
        setState(() => _messages.add(msg));
        _scrollToBottom();
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();
    await ref.read(chatRepoProvider).sendMessage(
          roomId: widget.roomId,
          content: text,
        );
  }

  Future<void> _sendPriceOffer() async {
    final priceCtrl = TextEditingController();
    final price = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('가격 제안'),
        content: TextField(
          controller: priceCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '희망 가격 (원)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, int.tryParse(priceCtrl.text)),
            child: const Text('제안'),
          ),
        ],
      ),
    );
    if (price != null) {
      await ref.read(chatRepoProvider).sendMessage(
            roomId: widget.roomId,
            content: '${NumberFormat.decimalPattern().format(price)}원을 제안합니다.',
            messageType: 'price_offer',
            metadata: {'offered_price': price},
          );
    }
  }

  Future<void> _sendDeliveryChoice() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('거래 방식 선택'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'delivery'),
            child: const Text('택배 거래'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'in_person'),
            child: const Text('직접 거래'),
          ),
        ],
      ),
    );
    if (choice != null) {
      final label = choice == 'delivery' ? '택배 거래' : '직접 거래';
      await ref.read(chatRepoProvider).sendMessage(
            roomId: widget.roomId,
            content: '$label를 희망합니다.',
            messageType: 'delivery_choice',
            metadata: {'delivery_method': choice},
          );
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('HH:mm');
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('흥정'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'price') _sendPriceOffer();
              if (v == 'delivery') _sendDeliveryChoice();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'price', child: Text('가격 제안')),
              const PopupMenuItem(value: 'delivery', child: Text('거래 방식 선택')),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) {
                      final msg = _messages[i];
                      final isMine = msg.senderId == _uid;
                      return Align(
                        alignment: isMine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isMine
                                ? theme.colorScheme.primaryContainer
                                : theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          constraints: BoxConstraints(
                            maxWidth:
                                MediaQuery.of(context).size.width * 0.75,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (msg.messageType == 'price_offer')
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.local_offer,
                                        size: 16,
                                        color: theme.colorScheme.primary),
                                    const SizedBox(width: 4),
                                    const Text('가격 제안',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12)),
                                  ],
                                ),
                              if (msg.messageType == 'delivery_choice')
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.local_shipping,
                                        size: 16,
                                        color: theme.colorScheme.primary),
                                    const SizedBox(width: 4),
                                    const Text('거래 방식',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12)),
                                  ],
                                ),
                              Text(msg.content),
                              const SizedBox(height: 2),
                              Text(df.format(msg.createdAt),
                                  style: theme.textTheme.bodySmall),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    border: Border(
                        top: BorderSide(color: theme.dividerColor)),
                  ),
                  child: SafeArea(
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _msgCtrl,
                            decoration: const InputDecoration(
                              hintText: '메시지 입력...',
                              border: InputBorder.none,
                            ),
                            onSubmitted: (_) => _send(),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.send),
                          onPressed: _send,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
