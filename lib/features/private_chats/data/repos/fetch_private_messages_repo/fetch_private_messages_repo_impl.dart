import 'package:dartz/dartz.dart';
import 'package:messenger_clone0/core/services/hive/hive_services.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_client_manager.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_error.dart';
import 'package:messenger_clone0/features/private_chats/data/models/private_message_model.dart';
import 'package:messenger_clone0/features/private_chats/data/repos/fetch_private_messages_repo/fetch_private_messages_repo.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FetchPrivateMessagesRepoImpl implements FetchPrivateMessagesRepo {
  final SupabaseClientManager client;
  FetchPrivateMessagesRepoImpl(this.client);
  SupabaseClient get _client => client.client;

  @override
  Future<Either<String, Unit>> deleteMessageLocally(String messageId) async {
    try {
      await HiveService.deletePrivateMessage(messageId);
      return const Right(unit);
    } catch (e) {
      return Left('$e');
    }
  }

  @override
  Future<Either<SupabaseError, Unit>> deleteMessages(
    List<String> messageIds,
  ) async {
    try {
      for (final id in messageIds) {
        await _client
            .from('message')
            .update({'is_deleted': true})
            .eq('message_id', id);
      }
      return const Right(unit);
    } catch (e) {
      return Left(SupabaseError(message: "$e"));
    }
  }

  @override
  Future<Either<SupabaseError, Unit>> editMessage({
    required String messageId,
    required String content,
  }) async {
    try {
      await _client
          .from('message')
          .update({'content': content})
          .eq('message_id', messageId);
      return const Right(unit);
    } catch (e) {
      return Left(SupabaseError(message: "$e"));
    }
  }

  @override
  Future<Either<SupabaseError, List<PrivateMessageModel>>>
  fetchInitialMessages({required String chatId, required int pageSize}) async {
    try {
      final rows = await _client
          .from('message')
          .select()
          .eq('chat_id', chatId)
          .order('created_at', ascending: false)
          .limit(pageSize);
      final messages = rows
          .map<PrivateMessageModel>((r) => PrivateMessageModel.fromJson(r))
          .toList()
          .reversed
          .toList();
      return Right(messages);
    } catch (e) {
      return Left(SupabaseError(message: "$e"));
    }
  }

  @override
  Future<Either<SupabaseError, List<PrivateMessageModel>>> fetchMoreMessages({
    required String chatId,
    required DateTime before,
    required int pageSize,
  }) async {
    try {
      final rows = await _client
          .from('message')
          .select()
          .eq('chat_id', chatId)
          .lt('created_at', before.toIso8601String())
          .order('created_at', ascending: false)
          .limit(pageSize);
      final messages = rows
          .map<PrivateMessageModel>((r) => PrivateMessageModel.fromJson(r))
          .toList();

      return Right(messages);
    } catch (e) {
      return Left(SupabaseError(message: "$e"));
    }
  }

  @override
  Future<Either<String, PrivateMessageModel?>> getLocalMessage(
    String messageId,
  ) async {
    try {
      final message = await HiveService.getPrivateMessage(messageId);
      return Right(message);
    } catch (e) {
      return Left('$e');
    }
  }

  @override
  Future<Either<String, List<PrivateMessageModel>>> getLocalMessages({
    required String chatId,
    required int limit,
  }) async {
    try {
      final messages = await HiveService.getPrivateMessages(
        chatId,
        limit: limit,
      );
      return Right(messages);
    } catch (e) {
      return Left('$e');
    }
  }

  @override
  Future<Either<SupabaseError, Unit>> markMessagesAsRead(
    List<String> messageIds,
  ) async {
    try {
      await _client
          .from('message')
          .update({'read': true})
          .inFilter('message_id', messageIds);
      return const Right(unit);
    } catch (e) {
      return Left(SupabaseError(message: "$e"));
    }
  }

  @override
  Future<Either<String, Unit>> saveMessageLocally(
    PrivateMessageModel message,
  ) async {
    try {
      await HiveService.savePrivateMessage(message);
      return const Right(unit);
    } catch (e) {
      return Left('$e');
    }
  }
}
