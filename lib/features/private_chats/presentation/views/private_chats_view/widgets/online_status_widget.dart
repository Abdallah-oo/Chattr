import 'package:chattr/features/private_chats/presentation/cubits/fetch_private_chats_cubit/fetch_private_chats_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class OnlineStatusWidget extends StatelessWidget {
  const OnlineStatusWidget({super.key, this.chatId});
  final String? chatId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FetchPrivateChatsCubit, FetchPrivateChatsState>(
      buildWhen: (prev, curr) {
        // rebuild بس لو الـ online/lastSeen للـ friend ده اتغير
        if (curr is! FetchPrivateChatsSuccess) return false;
        if (prev is! FetchPrivateChatsSuccess) return true;
        final prevChat = prev.chats
            .where((c) => c.chatId == chatId)
            .firstOrNull;
        final currChat = curr.chats
            .where((c) => c.chatId == chatId)
            .firstOrNull;
        return prevChat?.friend?.isOnLine != currChat?.friend?.isOnLine ||
            prevChat?.friend?.lastSeen != currChat?.friend?.lastSeen;
      },
      builder: (context, state) {
        if (state is! FetchPrivateChatsSuccess) return const SizedBox.shrink();

        final chat = state.chats.where((c) => c.chatId == chatId).firstOrNull;
        if (chat == null) return const SizedBox.shrink();

        final isOnline = chat.friend?.isOnLine;
        final lastSeen = chat.friend?.lastSeen;

        if (isOnline == true) {
          return const Text(
            'Online',
            style: TextStyle(fontSize: 12, color: Colors.green),
          );
        }

        if (lastSeen != null) {
          return Text(
            'Last seen ${_formatLastSeen(lastSeen)}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  static String _formatLastSeen(DateTime lastSeen) {
    final diff = DateTime.now().difference(lastSeen);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'yesterday';
    return '${diff.inDays} days ago';
  }
}
