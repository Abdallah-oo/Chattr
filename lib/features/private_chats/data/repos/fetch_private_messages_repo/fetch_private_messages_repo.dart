import 'package:dartz/dartz.dart';
import 'package:messenger_clone0/core/services/supabase/supabase_error.dart';
import 'package:messenger_clone0/features/private_chats/data/models/private_message_model.dart';

abstract interface class FetchPrivateMessagesRepo {
 Future<Either<SupabaseError, List<PrivateMessageModel>>> fetchInitialMessages({
    required String chatId,
    required int pageSize,
  });

  /// جيب الصفحة التالية (pagination)
  Future<Either<SupabaseError, List<PrivateMessageModel>>> fetchMoreMessages({
    required String chatId,
    required DateTime before,
    required int pageSize,
  });

  /// حدّث الرسايل المحددة كـ read في DB
  Future<Either<SupabaseError,Unit>> markMessagesAsRead(List<String> messageIds);

  /// احذف رسايل (soft delete)
  Future<Either<SupabaseError, Unit>> deleteMessages(List<String> messageIds);

  /// عدّل محتوى رسالة
  Future<Either<SupabaseError, Unit>> editMessage({
    required String messageId,
    required String content,
  });

  // ─── Hive ───────────────────────────────────────────────────────

  /// جيب الرسايل المحفوظة محلياً
  Future<Either<String, List<PrivateMessageModel>>> getLocalMessages({
    required String chatId,
    required int limit,
  });

  /// احفظ رسالة محلياً
  Future<Either<String, Unit>> saveMessageLocally(PrivateMessageModel message);

  /// احذف رسالة من الـ local cache
  Future<Either<String, Unit>> deleteMessageLocally(String messageId);

  /// جيب رسالة واحدة من الـ local cache
  Future<Either<String, PrivateMessageModel?>> getLocalMessage(String messageId);
}