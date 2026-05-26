import 'package:dartz/dartz.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_error.dart';
import 'package:messenger_clone0/features/group_chats/data/models/group_message_model.dart';

abstract interface class FetchGroupMessagesRepo {
  // ─── Server ────────────────────────────────────────────────────
  Future<Either<SupabaseError, List<GroupMessageModel>>> fetchInitialMessages({
    required String groupId,
    required int pageSize,
  });

  Future<Either<SupabaseError, List<GroupMessageModel>>> fetchMoreMessages({
    required String groupId,
    required DateTime before,
    required int pageSize,
  });

  Future<Either<SupabaseError, Unit>> markGroupAsRead({
    required String groupId,
    required String userId,
  });

  Future<Either<SupabaseError, Unit>> deleteMessages(List<String> messageIds);

  Future<Either<SupabaseError, Unit>> editMessage({
    required String messageId,
    required String content,
  });

  Future<Either<SupabaseError, List<Map<String, dynamic>>>> fetchMissingUsers(
    List<String> userIds,
  );

  // ─── Hive ───────────────────────────────────────────────────────
  Future<Either<SupabaseError, List<GroupMessageModel>>> getLocalMessages({
    required String groupId,
    required int limit,
  });

  Future<Either<SupabaseError, Unit>> saveMessageLocally(
    GroupMessageModel message,
  );

  Future<Either<SupabaseError, Unit>> deleteMessageLocally(String messageId);

  Future<Either<SupabaseError, GroupMessageModel?>> getLocalMessage(
    String messageId,
  );
}
