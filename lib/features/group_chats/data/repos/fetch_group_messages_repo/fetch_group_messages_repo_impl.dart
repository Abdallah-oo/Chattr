import 'package:dartz/dartz.dart';
import 'package:messenger_clone0/core/services/hive/hive_services.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_client_manager.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_error.dart';
import 'package:messenger_clone0/features/group_chats/data/models/group_message_model.dart';
import 'package:messenger_clone0/features/group_chats/data/repos/fetch_group_messages_repo/fetch_group_messages_repo.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class FetchGroupMessagesRepoImpl implements FetchGroupMessagesRepo {
  const FetchGroupMessagesRepoImpl({
    required SupabaseClientManager clientManager,
  }) : _clientManager = clientManager;

  final SupabaseClientManager _clientManager;
  SupabaseClient get _client => _clientManager.client;

  // ─── Server ─────────────────────────────────────────────────────

  @override
  Future<Either<SupabaseError, List<GroupMessageModel>>> fetchInitialMessages({
    required String groupId,
    required int pageSize,
  }) async {
    try {
      final rows = await _client
          .from('group_messages')
          .select()
          .eq('group_id', groupId)
          .order('created_at', ascending: false)
          .limit(pageSize);

      final msgs = rows
          .map<GroupMessageModel>((r) => GroupMessageModel.fromJson(r))
          .toList()
          .reversed
          .toList();

      return right(msgs);
    } catch (e) {
      return left(SupabaseError(message: '$e'));
    }
  }

  @override
  Future<Either<SupabaseError, List<GroupMessageModel>>> fetchMoreMessages({
    required String groupId,
    required DateTime before,
    required int pageSize,
  }) async {
    try {
      final rows = await _client
          .from('group_messages')
          .select()
          .eq('group_id', groupId)
          .lt('created_at', before.toIso8601String())
          .order('created_at', ascending: false)
          .limit(pageSize);

      final msgs = rows
          .map<GroupMessageModel>((r) => GroupMessageModel.fromJson(r))
          .toList();

      return right(msgs);
    } catch (e) {
      return left(SupabaseError(message: '$e'));
    }
  }

  @override
  Future<Either<SupabaseError, Unit>> markGroupAsRead({
    required String groupId,
    required String userId,
  }) async {
    try {
      await _client
          .from('group_members')
          .update({'last_read_at': DateTime.now().toIso8601String()})
          .eq('group_id', groupId)
          .eq('user_id', userId);
      return right(unit);
    } catch (e) {
      return left(SupabaseError(message: '$e'));
    }
  }

  @override
  Future<Either<SupabaseError, Unit>> deleteMessages(
    List<String> messageIds,
  ) async {
    try {
      for (final id in messageIds) {
        await _client
            .from('group_messages')
            .update({'is_deleted': true})
            .eq('message_id', id);
      }
      return right(unit);
    } catch (e) {
      return left(SupabaseError(message: '$e'));
    }
  }

  @override
  Future<Either<SupabaseError, Unit>> editMessage({
    required String messageId,
    required String content,
  }) async {
    try {
      await _client
          .from('group_messages')
          .update({'content': content})
          .eq('message_id', messageId);
      return right(unit);
    } catch (e) {
      return left(SupabaseError(message: '$e'));
    }
  }

  @override
  Future<Either<SupabaseError, List<Map<String, dynamic>>>> fetchMissingUsers(
    List<String> userIds,
  ) async {
    try {
      final rows = await _client
          .from('messenger_users')
          .select()
          .inFilter('id', userIds);
      return right(List<Map<String, dynamic>>.from(rows));
    } catch (e) {
      return left(SupabaseError(message: '$e'));
    }
  }

  // ─── Hive ────────────────────────────────────────────────────────

  @override
  Future<Either<SupabaseError, List<GroupMessageModel>>> getLocalMessages({
    required String groupId,
    required int limit,
  }) async {
    try {
      final msgs = await HiveService.getGroupMessages(groupId, limit: limit);
      return right(msgs);
    } catch (e) {
      return left(SupabaseError(message: '$e'));
    }
  }

  @override
  Future<Either<SupabaseError, Unit>> saveMessageLocally(
    GroupMessageModel message,
  ) async {
    try {
      await HiveService.saveGroupMessage(message);
      return right(unit);
    } catch (e) {
      return left(SupabaseError(message: '$e'));
    }
  }

  @override
  Future<Either<SupabaseError, Unit>> deleteMessageLocally(
    String messageId,
  ) async {
    try {
      await HiveService.deleteGroupMessage(messageId);
      return right(unit);
    } catch (e) {
      return left(SupabaseError(message: '$e'));
    }
  }

  @override
  Future<Either<SupabaseError, GroupMessageModel?>> getLocalMessage(
    String messageId,
  ) async {
    try {
      final msg = await HiveService.getGroupMessage(messageId);
      return right(msg);
    } catch (e) {
      return left(SupabaseError(message: '$e'));
    }
  }
}
