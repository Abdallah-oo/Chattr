import 'package:chattr/core/services/hive/hive_services.dart';
import 'package:chattr/features/auth/data/models/user_model.dart';

class UsersCache {
static final Map<String, UserModel> \_cache = {};

static bool contains(String id) => \_cache.containsKey(id);

static UserModel? getUser(String id) {
return \_cache[id];
}

static Future<UserModel?> getUserSmart(String id) async {
// 1️⃣ دور في الذاكرة
if (\_cache.containsKey(id)) return \_cache[id];

    // 2️⃣ دور في Hive
    final user = await HiveService.getUser(id);
    if (user != null) {
      _cache[id] = user;
      return user;
    }

    // 3️⃣ غير موجود
    return null;

}

static void addUser(UserModel user) {
if (user.id != null) {
\_cache[user.id!] = user;
}
}

static void addUsers(List<UserModel> users) {
for (var u in users) {
addUser(u);
}
}

static void clear() {
\_cache.clear();
}
}
//----------------------------
import 'dart:async';
import 'dart:io';
import 'package:chattr/core/services/supabase/supabase_storage.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'audio_state.dart';

class AudioCubit extends Cubit<AudioState> {
AudioCubit(this.\_storage) : super(const AudioState());

final AudioRecorder \_recorder = AudioRecorder();
final SupabaseStorage \_storage ;

Timer? \_timer;
int lastDuration = 0;

Future<void> startRecording({
required String chatId,
required String senderId,
}) async {
try {
// ✅ permission check
final hasPermission = await \_recorder.hasPermission();
if (!hasPermission) {
emit(
state.copyWith(
status: RecordingStatus.error,
errorMessage: "No mic permission",
),
);
return;
}

      // ✅ cancel any previous timer
      _timer?.cancel();

      final dir = await getTemporaryDirectory();
      final path =
          "${dir.path}/$chatId-$senderId-${DateTime.now().millisecondsSinceEpoch}.m4a";

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );

      if (isClosed) return;

      emit(
        state.copyWith(
          status: RecordingStatus.recording,
          duration: Duration.zero,
        ),
      );

      // ✅ start timer safely
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (isClosed) return;
        emit(state.copyWith(duration: Duration(seconds: timer.tick)));
      });
    } catch (e) {
      if (!isClosed) {
        emit(
          state.copyWith(
            status: RecordingStatus.error,
            errorMessage: e.toString(),
          ),
        );
      }
    }

}

Future<String?> stopRecordingOnly() async {
\_timer?.cancel();
lastDuration = state.duration.inSeconds;

    try {
      if (await _recorder.isRecording()) {
        final path = await _recorder.stop();

        if (path == null || !File(path).existsSync()) return null;

        if (!isClosed) {
          emit(state.copyWith(status: RecordingStatus.uploading));
        }

        return path;
      }
      return null;
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(status: RecordingStatus.error));
      }
      return null;
    }

}

// ✅ upload في الخلفية
Future<void> uploadAndNotify({
required String localPath,
required String groupId,
required Function(String uploadedUrl) onUploaded,
}) async {
try {
final uploadedPath = await \_storage.uploadAudio(file: File(localPath),storageFile: 'chat-audio');
final audioUrl = \_storage.getFileUrl(path: uploadedPath, storageFile: 'chat-audio');

      if (!isClosed) {
        emit(
          state.copyWith(
            status: RecordingStatus.success,
            duration: Duration.zero,
          ),
        );
      }

      onUploaded(audioUrl);
    } catch (e) {
      if (!isClosed) {
        emit(
          state.copyWith(
            status: RecordingStatus.error,
            errorMessage: e.toString(),
          ),
        );
      }
    }

}

/// cancel recording
Future<void> cancelRecording() async {
\_timer?.cancel();

    try {
      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }
    } catch (_) {}

    if (!isClosed) {
      emit(const AudioState());
    }

}

@override
Future<void> close() {
\_timer?.cancel();
\_recorder.dispose();
return super.close();
}
}
//---------------------------------------------
import 'package:equatable/equatable.dart';

enum RecordingStatus { idle, recording, uploading, success, locked, error }

class AudioState extends Equatable {
final RecordingStatus status;
final Duration duration;
final String? errorMessage;

const AudioState({
this.status = RecordingStatus.idle,
this.duration = Duration.zero,
this.errorMessage,
});

AudioState copyWith({
RecordingStatus? status,
Duration? duration,
String? errorMessage,
}) {
return AudioState(
status: status ?? this.status,
duration: duration ?? this.duration,
errorMessage: errorMessage ?? this.errorMessage,
);
}

@override
List<Object?> get props => [status, duration, errorMessage];
}//-------------------------------------------------------------

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

part 'download_image_state.dart';

enum GalleryPermissionStatus { granted, permanentlyDenied }

class DownloadImageCubit extends Cubit<DownloadImageState> {
DownloadImageCubit() : super(DownloadImageInitial());

final Dio \_dio = Dio();

bool \_isValidImageUrl(String url) {
return url.endsWith(".jpg") ||
url.endsWith(".png") ||
url.endsWith(".jpeg") ||
url.endsWith(".webp");
}

String \_handleDioError(DioException e) {
switch (e.type) {
case DioExceptionType.connectionTimeout:
return "انتهت مهلة الاتصال";

      case DioExceptionType.receiveTimeout:
        return "التحميل استغرق وقت طويل";

      case DioExceptionType.badResponse:
        return "فشل تحميل الصورة من السيرفر";

      case DioExceptionType.connectionError:
        return "تأكد من اتصال الإنترنت";

      default:
        return "حدث خطأ غير متوقع";
    }

}

Future<GalleryPermissionStatus> \_checkGalleryPermission() async {
final hasAccess = await Gal.hasAccess();

    if (hasAccess) return GalleryPermissionStatus.granted;

    final requested = await Gal.requestAccess();

    if (requested) return GalleryPermissionStatus.granted;

    return GalleryPermissionStatus.permanentlyDenied;

}

Future<void> downloadImage(String imageUrl) async {
if (state is DownloadImageLoading) return;

    emit(DownloadImageLoading(progress: 0));

    try {
      if (!_isValidImageUrl(imageUrl)) {
        emit(DownloadImagefailure(errorMessage: "رابط الصورة غير صالح"));
        return;
      }

      /// ✅ Check Permission
      final permissionStatus = await _checkGalleryPermission();

      if (permissionStatus == GalleryPermissionStatus.permanentlyDenied) {
        emit(
          DownloadImagefailure(
            errorMessage: "تم رفض الصلاحية نهائياً، فعلها من الإعدادات",
          ),
        );
        return;
      }

      final hasAccess = await Gal.hasAccess();

      if (!hasAccess) {
        emit(DownloadImagefailure(errorMessage: "تم رفض صلاحية الوصول للصور"));
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final filePath =
          '${tempDir.path}/image_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await _dio.download(
        imageUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            emit(DownloadImageLoading(progress: progress));
          }
        },
      );

      final file = File(filePath);
      if (!file.existsSync()) {
        emit(DownloadImagefailure(errorMessage: "فشل حفظ الصورة"));
        return;
      }

      await Gal.putImage(filePath);

      await file.delete();

      emit(DownloadImageSucess());
    } on DioException catch (e) {
      emit(DownloadImagefailure(errorMessage: _handleDioError(e)));
    } catch (e) {
      emit(DownloadImagefailure(errorMessage: "$e"));
    }

}
}
//-------------------------------------------------------------
part of 'download_image_cubit.dart';

@immutable
sealed class DownloadImageState {}

final class DownloadImageInitial extends DownloadImageState {}
final class DownloadImageLoading extends DownloadImageState {
final double progress;
DownloadImageLoading({required this.progress});
}
final class DownloadImageSucess extends DownloadImageState {}
final class DownloadImagefailure extends DownloadImageState {
final String errorMessage;
DownloadImagefailure({required this.errorMessage});
}

//------------------------------------------------------------------------
import 'dart:async';
import 'dart:io';
import 'package:chattr/core/services/supabase/supabase_auth_services.dart';
import 'package:chattr/core/services/supabase/supabase_client_manager.dart';
import 'package:chattr/core/services/supabase/supabase_crud_services.dart';
import 'package:chattr/core/services/supabase/supabase_error.dart';
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
part 'fetch_current_user_data_state.dart';

class FetchCurrentUserDataCubit extends Cubit<FetchCurrentUserDataState>
with WidgetsBindingObserver {
FetchCurrentUserDataCubit({
required AuthService auth,
required SupabaseCrudServices crud,
required this.client,
}) : \_auth = auth,
\_crud = crud,
super(FetchCurrentUserDataInitial());

final AuthService \_auth;
final SupabaseCrudServices \_crud;
final SupabaseClientManager client;
SupabaseClient get \_client => client.client;
UserModel? currentUser;
Timer? \_heartbeatTimer;

// ─────────────────────────────────────────────────────────────────
// FETCH
// ─────────────────────────────────────────────────────────────────

Future<void> fetchCurruntUserData() async {
emit(FetchCurrentUserDataLoading());
try {
final response = await \_crud.getById(
table: 'messenger_users',
id: \_auth.currentUser!.id,
);

      currentUser = UserModel.fromJson(response);
      emit(FetchCurrentUserDataSuccess());
      // await NotificationService.instance.onUserLoggedIn();
      _initPresence();
    } on AuthException catch (e) {
      throw SupabaseError(message: e.message);
    } on SocketException {
      throw SupabaseError(message: 'No internet connection');
    } catch (e) {
      emit(FetchCurrentUserDataFailure(errorMessage: '$e'));
    }

}

// ─────────────────────────────────────────────────────────────────
// PRESENCE
// ─────────────────────────────────────────────────────────────────

void \_initPresence() {
WidgetsBinding.instance.addObserver(this);
\_setOnline(true);
\_startHeartbeat();
}

@override
void didChangeAppLifecycleState(AppLifecycleState state) {
switch (state) {
case AppLifecycleState.resumed:
\_setOnline(true);
\_startHeartbeat();
break;
case AppLifecycleState.paused:
case AppLifecycleState.detached:
// شيلنا inactive عشان بيحصل من غير ما الـ app يروح الخلفية فعلاً
\_setOnline(false);
\_stopHeartbeat();
break;
default:
break;
}
}

Future<void> \_setOnline(bool isOnline) async {
final id = \_auth.currentUser?.id;
if (id == null) return;

    try {
      await _client
          .from('messenger_users')
          .update({
            'is_online': isOnline,
            'last_seen': DateTime.now().toIso8601String(),
          })
          .eq('id', id);
    } catch (e) {
      debugPrint('❌ _setOnline: $e');
    }

}

void _startHeartbeat() {
\_stopHeartbeat();
\_heartbeatTimer = Timer.periodic(
const Duration(seconds: 30),
(_) => \_setOnline(true),
);
}

void \_stopHeartbeat() {
\_heartbeatTimer?.cancel();
\_heartbeatTimer = null;
}

// ─────────────────────────────────────────────────────────────────
// DISPOSE
// ─────────────────────────────────────────────────────────────────

@override
Future<void> close() async {
\_stopHeartbeat();
WidgetsBinding.instance.removeObserver(this);
await \_setOnline(false); // await عشان يخلص قبل الـ dispose
return super.close();
}
}
//-------------------------------------------------------------
part of 'fetch_current_user_data_cubit.dart';

@immutable
sealed class FetchCurrentUserDataState {}

final class FetchCurrentUserDataInitial extends FetchCurrentUserDataState {}

final class FetchCurrentUserDataSuccess extends FetchCurrentUserDataState {}

final class FetchCurrentUserDataFailure extends FetchCurrentUserDataState {
final String errorMessage;
FetchCurrentUserDataFailure({required this.errorMessage});
}

final class FetchCurrentUserDataLoading extends FetchCurrentUserDataState {}
//----------------------------------------------------------------------

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

part 'pick_image_state.dart';

class PickImageCubit extends Cubit<PickImageState> {
PickImageCubit({ImagePicker? imagePicker, ImageCropper? imageCropper})
: \_imagePicker = imagePicker ?? ImagePicker(),
\_imageCropper = imageCropper ?? ImageCropper(),
super(const PickImageInitial());

final ImagePicker \_imagePicker;
final ImageCropper \_imageCropper;

File? \_imageFile;

/// الصورة الحالية المختارة (read-only من الخارج)
File? get imageFile => \_imageFile;

// ──────────────────────────────────────────────
// Public Methods
// ──────────────────────────────────────────────

/// اختيار صورة من المصدر المحدد مع إمكانية القص لصور البروفايل
Future<void> pickImage({
required ImageSource source,
required bool cropForProfile,
}) async {
if (isClosed) return;
emit(const PickImageLoading());

    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1080,
        maxHeight: 1080,
      );

      if (pickedFile == null) {
        // المستخدم ألغى الاختيار، نرجع للحالة السابقة
        _restorePreviousState();
        return;
      }

      if (cropForProfile) {
        await _cropImage(pickedFile.path);
      } else {
        _setImage(File(pickedFile.path));
      }
    } on Exception catch (e) {
      emit(PickImageFailure(errorMessage: _mapExceptionToMessage(e)));
    }

}

/// حذف الصورة المختارة
void deleteImage() {
\_imageFile = null;
emit(const PickImageDeleted());
}

// ──────────────────────────────────────────────
// Private Helpers
// ──────────────────────────────────────────────

Future<void> \_cropImage(String sourcePath) async {
final CroppedFile? croppedFile = await \_imageCropper.cropImage(
sourcePath: sourcePath,
aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
uiSettings: \_buildCropUiSettings(),
);

    if (croppedFile == null) {
      // المستخدم ألغى القص
      _restorePreviousState();
      return;
    }

    _setImage(File(croppedFile.path));

}

List<PlatformUiSettings> \_buildCropUiSettings() {
return [
AndroidUiSettings(
toolbarTitle: 'Crop Image',
toolbarColor: Colors.black,
toolbarWidgetColor: Colors.white,
lockAspectRatio: true,
cropStyle: CropStyle.circle,
hideBottomControls: false,
initAspectRatio: CropAspectRatioPreset.square,
),
IOSUiSettings(
title: 'Crop Image',
aspectRatioLockEnabled: true,
resetAspectRatioEnabled: false,
),
];
}

void \_setImage(File file) {
\_imageFile = file;
emit(PickImageSuccess(imageFile: file));
}

void \_restorePreviousState() {
if (\_imageFile != null) {
emit(PickImageSuccess(imageFile: \_imageFile!));
} else {
emit(const PickImageInitial());
}
}

String \_mapExceptionToMessage(Exception e) {
final message = e.toString().toLowerCase();

    if (message.contains('permission')) {
      return 'Permission denied. Please allow access to camera/gallery.';
    } else if (message.contains('camera')) {
      return 'Camera is not available on this device.';
    } else if (message.contains('storage')) {
      return 'Storage access denied. Please check app permissions.';
    }

    return 'Something went wrong. Please try again.';

}
}
//----------------------------------------------------------
part of 'pick_image_cubit.dart';

@immutable
sealed class PickImageState {
const PickImageState();
}

/// الحالة الأولية قبل أي action
final class PickImageInitial extends PickImageState {
const PickImageInitial();
}

/// جاري تحميل الصورة أو المعالجة
final class PickImageLoading extends PickImageState {
const PickImageLoading();
}

/// تم اختيار الصورة بنجاح
final class PickImageSuccess extends PickImageState {
final File imageFile;

const PickImageSuccess({required this.imageFile});
}

/// حدث خطأ أثناء اختيار الصورة أو المعالجة
final class PickImageFailure extends PickImageState {
final String errorMessage;

const PickImageFailure({required this.errorMessage});
}

/// تم حذف الصورة
final class PickImageDeleted extends PickImageState {
const PickImageDeleted();
}
//-----------------------------------------------------------------
import 'package:flutter_bloc/flutter_bloc.dart';

part 'search_state.dart';

class SearchCubit extends Cubit<SearchState> {
SearchCubit() : super(SearchInitial());

void search({
required List<dynamic> list,
required String query,
required String Function(dynamic item) searchBy,
}) {
if (query.isEmpty) {
emit(SearchClosed());
return;
}

    final filtered = list
        .where(
          (item) => searchBy(item).toLowerCase().contains(query.toLowerCase()),
        )
        .toList();

    emit(SearchActive(filteredList: filtered));

}

void closeSearch() => emit(SearchClosed());
}
//------------------------------------------------------------
part of 'search_cubit.dart';

sealed class SearchState {}

final class SearchInitial extends SearchState {}

final class SearchActive extends SearchState {
final List<dynamic> filteredList;
SearchActive({required this.filteredList});
}

final class SearchClosed extends SearchState {}
//--------------------------------------------------------------
import 'package:chattr/features/private_chats/data/models/private_message_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'select_messages_state.dart';

class SelectMessagesCubit extends Cubit<SelectMessagesState> {
SelectMessagesCubit() : super(SelectMessagesInitial());

final Set<String> \_selectedIds = {};
final List<dynamic> \_selectedMessages = [];

List<dynamic> get selectedMessages =>
List.unmodifiable(\_selectedMessages);

bool isSelected(dynamic message) {
final id = message.messageId ?? message.tempId;
return \_selectedIds.contains(id);
}

void selectMessage(dynamic message) {
final id = message.messageId ?? message.tempId;

    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
      _selectedMessages.removeWhere(
        (m) => (m.messageId ?? m.tempId) == id,
      );
      emit(RemoveSelectMessages());
    } else {
      _selectedIds.add(id);
      _selectedMessages.add(message);
      emit(AddSelectMessages());
    }

}

void copyMessages() {
final text = \_selectedMessages.map((e) => e.content).join('\n');
Clipboard.setData(ClipboardData(text: text));
\_clear();
emit(CopySelectedImages());
}

void clearSelection() {
\_clear();
emit(ClearSelection());
}

bool containMedia() {
if(selectedMessages is List<PrivateMessageModel>){
return \_selectedMessages.any(
(m) => m.privateMessageType != PrivateMessageType.text,
);

    }
    return false;

}

void \_clear() {
\_selectedIds.clear();
\_selectedMessages.clear();
}
}//------------------------------------------------------------
part of 'select_messages_cubit.dart';

@immutable
sealed class SelectMessagesState {}

final class SelectMessagesInitial extends SelectMessagesState {}

final class AddSelectMessages extends SelectMessagesState {}

final class RemoveSelectMessages extends SelectMessagesState {}

final class DeleteMessagesSuccess extends SelectMessagesState {}

final class DeleteMessagesLoading extends SelectMessagesState {}

final class DeleteMessagesFailure extends SelectMessagesState {
final String errorMessage;
DeleteMessagesFailure({required this.errorMessage});
}

final class ClearSelection extends SelectMessagesState {}

final class CopySelectedImages extends SelectMessagesState {}
//------------------------------------------------------------
import 'package:chattr/core/themes/app_colors.dart';
import 'package:chattr/core/themes/app_text_styles.dart';
import 'package:chattr/core/widgets/custom_text.dart';
import 'package:flutter/material.dart';

class CustomSnackBar {
static void show(
BuildContext context, {
required String message,
IconData? icon,
EdgeInsetsGeometry? customPadding,
Color? backgroundColor,
Duration duration = const Duration(seconds: 3),
SnackBarAction? action,
}) {
final SnackBar snackBar =
SnackBar(
content: Row(
children: [
if (icon != null) Icon(icon, color: Colors.white, size: 22),
if (icon != null) const SizedBox(width: 10),
Expanded(
child: CustomText(text: message, style: AppTextStyles.bodyMedium),
),
],
),
backgroundColor: backgroundColor ?? Colors.black87,
behavior: SnackBarBehavior.floating,
margin: customPadding ?? EdgeInsets.fromLTRB(17, 0, 17, 100),
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
duration: duration,
action: action,
elevation: 6,
);

    ScaffoldMessenger.of(
        Navigator.of(context, rootNavigator: true).overlay!.context,
      )
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);

}

/// Success SnackBar
static void success(BuildContext context, String message) {
show(
context,
message: message,
icon: Icons.check_circle_rounded,
backgroundColor: const Color.fromARGB(255, 7, 105, 11),
);
}

///Error SnackBar
static void error(
BuildContext context,
String message, {
EdgeInsetsGeometry? padding,
}) {
show(
context,
message: message,
customPadding: padding,
icon: Icons.error_outline_rounded,
backgroundColor: AppColors.error,
);
}

///Warning SnackBar
static void warning(BuildContext context, String message) {
show(
context,
message: message,
icon: Icons.warning_amber_rounded,
backgroundColor: Colors.orange.shade700,
);
}

///Info SnackBar
static void info(BuildContext context, String message) {
show(
context,
message: message,
icon: Icons.info_outline_rounded,
backgroundColor: Colors.blue.shade600,
);
}
}
//-------------------------------------------------------------------

//?private chats
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:chattr/features/group_chats/data/models/group_model.dart';
import 'package:chattr/features/group_chats/presentation/cubits/fetch_groups_cubit/fetch_groups_cubit.dart';
import 'package:chattr/features/private_chats/data/models/private_chat_model.dart';

class PrivateChatParams {
final PrivateChatModel chatData;
final UserModel curruntUser;
PrivateChatParams({required this.chatData, required this.curruntUser});
}

//?shared
class ViewImageParams {
final String imageUrl;
final String senderName;
final dynamic messageData;
ViewImageParams({
required this.imageUrl,
required this.senderName,
required this.messageData,
});
}

//?group chats
class GroupChatParams {
final GroupModel groupData;
final UserModel currentUser;
final List<UserInGroup> memberData;
final FetchGroupsCubit ?fetchGroupsCubit;

GroupChatParams({
required this.groupData,
required this.currentUser,
required this.memberData, this.fetchGroupsCubit,
});
}
//--------------------------------------------------------------
import 'package:chattr/core/cubits/audio_cubit/audio_cubit.dart';
import 'package:chattr/core/cubits/download_image/download_image_cubit.dart';
import 'package:chattr/core/cubits/fetch_current_user_data/fetch_current_user_data_cubit.dart';
import 'package:chattr/core/cubits/pick_image/pick_image_cubit.dart';
import 'package:chattr/core/cubits/select_messages/select_messages_cubit.dart';
import 'package:chattr/core/routing/router_models.dart';
import 'package:chattr/core/routing/routes.dart';
import 'package:chattr/core/services/supabase/supabase_auth_services.dart';
import 'package:chattr/core/services/supabase/supabase_client_manager.dart';
import 'package:chattr/core/services/supabase/supabase_crud_services.dart';
import 'package:chattr/core/services/supabase/supabase_storage.dart';
import 'package:chattr/core/utils/di/get_it.dart';
import 'package:chattr/core/widgets/image/ui/view_image.dart';
import 'package:chattr/features/auth/data/repos/auth_repo.dart';
import 'package:chattr/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:chattr/features/auth/presentation/views/login_view/login_view.dart';
import 'package:chattr/features/auth/presentation/views/signup_view/signup_view.dart';
import 'package:chattr/features/contacts/presentation/cubits/fetch_contacts_cubit/fetch_contacts_cubit.dart';
import 'package:chattr/features/group_chats/data/repos/add_and_remove_admin_repo/add_and_remove_admin_repo.dart';
import 'package:chattr/features/group_chats/data/repos/create_group_repo/create_group_repo.dart';
import 'package:chattr/features/group_chats/data/repos/delete_member_repo/delete_member_repo.dart';
import 'package:chattr/features/group_chats/data/repos/edit_group_data_repo/edit_group_data_repo.dart';
import 'package:chattr/features/group_chats/presentation/cubits/add_and_remove_admin_cubit/add_and_remove_admin_cubit.dart';
import 'package:chattr/features/group_chats/presentation/cubits/create_group_cubit/create_group_cubit.dart';
import 'package:chattr/features/group_chats/presentation/cubits/delete_group_cubit/delete_group_cubit.dart';
import 'package:chattr/features/group_chats/presentation/cubits/delete_member_cubit/delete_member_cubit.dart';
import 'package:chattr/features/group_chats/presentation/cubits/edit_group_data_cubit/edit_group_data_cubit.dart';
import 'package:chattr/features/group_chats/presentation/cubits/fetch_group_messages_cubit/fetch_group_messages_cubit.dart';
import 'package:chattr/features/group_chats/presentation/cubits/fetch_groups_cubit/fetch_groups_cubit.dart';
import 'package:chattr/features/group_chats/presentation/cubits/select_group_members_cubit/select_group_members_cubit.dart';
import 'package:chattr/features/group_chats/presentation/views/group_messages_view/views/group_messages_view.dart';
import 'package:chattr/features/group_chats/presentation/views/group_messages_view/widgets/view_group_members.dart';
import 'package:chattr/features/group_chats/presentation/views/groups_view/widgets/create_group.dart';
import 'package:chattr/features/private_chats/presentation/cubits/fetch_private_chats_cubit/fetch_private_chats_cubit.dart';
import 'package:chattr/features/private_chats/presentation/cubits/fetch_private_messages_cubit/fetch_private_messages_cubit.dart';
import 'package:chattr/features/private_chats/presentation/views/private_chat_body_view/private_chat_body_view.dart';
import 'package:chattr/root.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

abstract class AppRouter {
static final router = GoRouter(
routes: [
//login
GoRoute(
path: Routes.initial,
builder: (context, state) => BlocProvider(
create: (context) => AuthCubit(getIt<AuthRepo>()),
child: LoginView(),
),
),

      ///signup
      GoRoute(
        path: Routes.signup,
        builder: (context, state) => MultiBlocProvider(
          providers: [
            BlocProvider(create: (context) => PickImageCubit()),
            BlocProvider(create: (context) => AuthCubit(getIt<AuthRepo>())),
          ],
          child: SignupView(),
        ),
      ),

      //Navigation Bar
      GoRoute(
        path: Routes.root,
        builder: (context, state) {
          return MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (context) => FetchCurrentUserDataCubit(
                  auth: getIt<AuthService>(),
                  crud: getIt<SupabaseCrudServices>(),
                  client: getIt<SupabaseClientManager>(),
                )..fetchCurruntUserData(),
              ),

              BlocProvider(
                create: (_) => getIt<FetchContactsCubit>()..fetchContacts(),
              ),
              BlocProvider(create: (_) => getIt<FetchPrivateMessagesCubit>()),
              BlocProvider(
                create: (_) =>
                    getIt<FetchPrivateChatsCubit>()..fetchPrivateChats(),
              ),
              BlocProvider(
                create: (_) => getIt<FetchGroupsCubit>()..fetchGroups(),
              ),
              BlocProvider(create: (_) => getIt<FetchGroupMessagesCubit>()),
            ],
            child: Root(),
          );
        },
      ),

      //view image
      GoRoute(
        path: Routes.viewImage,
        builder: (context, state) {
          final imageInfo = state.extra as ViewImageParams;
          return BlocProvider(
            create: (context) => DownloadImageCubit(),
            child: ViewImage(imageInfo: imageInfo),
          );
        },
      ),
      //?private chat body
      GoRoute(
        path: Routes.privateChatsBody,

        builder: (context, state) {
          final chatData = state.extra as PrivateChatParams;

          return PrivateChatBodyView(
            chatData: chatData.chatData,
            user: chatData.curruntUser,
          );
        },
      ),
      //?group chat body
      //creat
      GoRoute(
        path: Routes.creatGroup,
        builder: (context, state) {
          final FetchContactsCubit contactsCubit =
              state.extra as FetchContactsCubit;
          return MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (context) => CreateGroupCubit(
                  auth: getIt<AuthService>(),
                  repo: getIt<CreateGroupRepo>(),
                ),
              ),
              BlocProvider(create: (context) => PickImageCubit()),
              BlocProvider(create: (context) => SelectGroupMembersCubit()),
            ],
            child: CreatGroup(contactsCubit: contactsCubit),
          );
        },
      ),

      //group messages view
      GoRoute(
        path: Routes.groupMessages,
        builder: (context, state) {
          final GroupChatParams groupData = state.extra as GroupChatParams;

          return MultiBlocProvider(
            providers: [
              BlocProvider(create: (context) => PickImageCubit()),
              BlocProvider(
                create: (context) => AudioCubit(getIt<SupabaseStorage>()),
              ),

              BlocProvider(create: (context) => SelectMessagesCubit()),
            ],
            child: GroupMessagesView(groupData: groupData),
          );
        },
      ),

      //view group members
      GoRoute(
        path: Routes.viewGroupMembers,
        builder: (context, state) {
          final GroupChatParams groupData = state.extra as GroupChatParams;

          return MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (context) => AddAndRemoveAdminCubit(
                  repo: getIt<AddAndRemoveAdminRepo>(),
                ),
              ),
              BlocProvider(
                create: (context) =>
                    DeleteMemberCubit(getIt<DeleteMemberRepo>()),
              ),
              BlocProvider(
                create: (context) =>
                    DeleteGroupCubit(getIt<SupabaseCrudServices>()),
              ),
            ],
            child: ViewGroupMembers(groupData: groupData),
          );
        },
      ),

      //edit group
      GoRoute(
        path: Routes.editGroup,
        builder: (context, state) {
          final GroupChatParams groupData = state.extra as GroupChatParams;

          return MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (context) =>
                    EditGroupDataCubit(getIt<EditGroupDataRepo>()),
              ),
              BlocProvider(
                create: (context) =>
                    DeleteGroupCubit(getIt<SupabaseCrudServices>()),
              ),
              BlocProvider(create: (context) => SelectGroupMembersCubit()),
              BlocProvider(create: (context) => PickImageCubit()),
            ],
            child: EditGroup(groupData: groupData),
          );
        },
      ),
    ],

);
}
//-------------------------------------------------------------
class Routes {
static const initial = '/';
static const login = '/Login';
static const signup = '/Signup';
static const viewImage = '/ViewImage';
static const privateChatsBody = '/PrivateChatsBody';
static const root = '/Root';
static const creatGroup = '/CreatGroup';
static const groupMessages = '/GroupMessages';
static const viewGroupMembers = '/ViewGroupMembers';
static const editGroup = '/EditGroup';
}
//-------------------------------------------------------------------
import 'package:chattr/core/cache/users_cache.dart';
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:chattr/features/group_chats/data/models/group_message_model.dart';
import 'package:chattr/features/group_chats/data/models/group_model.dart';
import 'package:chattr/features/private_chats/data/models/private_chat_model.dart';
import 'package:chattr/features/private_chats/data/models/private_message_model.dart';
import 'package:hive/hive.dart';

class HiveService {
static const String userBoxName = 'users';
static const String privateChatsBoxName = 'privateChats';
static const String privateMessageBoxName = 'privateMessages';
static const String groupsBoxName = 'groups';
static const String groupsMessagesBoxName = 'groupMessages';

/// ---------------- USERS ----------------
static Future<void> saveUser(UserModel user) async {
final box = Hive.box<UserModel>('users');
await box.put(user.id, user);
UsersCache.addUser(user);
}

static Future<UserModel?> getUser(String id) async {
final box = Hive.box<UserModel>('users');
return box.get(id);
}

static Future<void> replaceUsers(List<UserModel> users) async {
final box = Hive.box<UserModel>(userBoxName);
await box.clear();
for (var u in users) {
await box.put(u.id, u);
UsersCache.addUser(u);
}
}

static Future<List<UserModel>> getUsers() async {
final box = Hive.box<UserModel>('users');
return box.values.toList();
}

//--------------- PRIVATE CHATS ----------------
static Future<void> savePrivateChat(PrivateChatModel chat) async {
final box = Hive.box<PrivateChatModel>(privateChatsBoxName);
await box.put(chat.chatId, chat);
}

static Future<List<PrivateChatModel>> getPrivateChats() async {
final box = Hive.box<PrivateChatModel>(privateChatsBoxName);
return box.values.toList();
}

static Future<void> replacePrivateChats(List<PrivateChatModel> chats) async {
final box = Hive.box<PrivateChatModel>(privateChatsBoxName);
await box.clear();
for (var g in chats) {
await box.put(g.chatId, g);
}
}

static Future<void> clearChats() async {
final box = Hive.box<PrivateChatModel>(privateChatsBoxName);
await box.clear();
}

//----------------Private Messages ----------------
static Future<void> savePrivateMessage(PrivateMessageModel message) async {
final box = Hive.box<PrivateMessageModel>(privateMessageBoxName);
final key = message.messageId ?? message.tempId;
await box.put(key, message);
}

static Future<void> deletePrivateMessage(String key) async {
final box = Hive.box<PrivateMessageModel>(privateMessageBoxName);
await box.delete(key);
}

static Future<List<PrivateMessageModel>> getPrivateMessages(
String chatId, {
int limit = 30,
}) async {
final box = Hive.box<PrivateMessageModel>(privateMessageBoxName);
final messages = box.values.where((m) => m.chatId == chatId).toList();
messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
if (messages.length <= limit) return messages;
return messages.sublist(messages.length - limit);
}

static Future<PrivateMessageModel?> getPrivateMessage(
String messageId,
) async {
final box = Hive.box<PrivateMessageModel>(privateMessageBoxName);
return box.get(messageId);
}

static Future<void> savePrivateMessageLocalPath({
required String messageId,
required String localPath,
}) async {
final box = Hive.box<PrivateMessageModel>(privateMessageBoxName);
final msg = box.get(messageId);

    if (msg == null) return;
    await box.put(messageId, msg.copyWith(localPath: localPath));

}

/// جيب الـ local path
static Future<String?> getPrivateMessageLocalPath(String messageId) async {
final box = Hive.box<PrivateMessageModel>(privateMessageBoxName);
final msg = box.get(messageId);
return msg?.localPath;
}

//--------------- group chats ----------------

static Future<void> saveGroup(GroupModel group) async {
final box = Hive.box<GroupModel>(groupsBoxName);
await box.put(group.id, group);
}

static Future<List<GroupModel>> getGroups() async {
final box = Hive.box<GroupModel>(groupsBoxName);
return box.values.toList();
}

static Future<void> replaceGroups(List<GroupModel> groups) async {
final box = Hive.box<GroupModel>(groupsBoxName);
await box.clear();
for (var g in groups) {
await box.put(g.id, g);
}
}

static Future<void> clearGroups() async {
final box = Hive.box<GroupModel>(groupsBoxName);
await box.clear();
}

//--------------- group messages ----------------
static Future<void> saveGroupMessage(GroupMessageModel message) async {
final box = Hive.box<GroupMessageModel>(groupsMessagesBoxName);
final key = message.messageId ?? message.tempId;
await box.put(key, message);
}

static Future<void> deleteGroupMessage(String key) async {
final box = Hive.box<GroupMessageModel>(groupsMessagesBoxName);
await box.delete(key);
}

static Future<List<GroupMessageModel>> getGroupMessages(
String groupId, {
int limit = 30,
}) async {
final box = Hive.box<GroupMessageModel>(groupsMessagesBoxName);
final messages = box.values.where((m) => m.groupId == groupId).toList();
messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
if (messages.length <= limit) return messages;
return messages.sublist(messages.length - limit);
}

static Future<GroupMessageModel?> getGroupMessage(String messageId) async {
final box = Hive.box<GroupMessageModel>(groupsMessagesBoxName);
return box.get(messageId);
}

static Future<void> saveGroupMessageLocalPath({
required String messageId,
required String localPath,
}) async {
final box = Hive.box<GroupMessageModel>(groupsMessagesBoxName);
final msg = box.get(messageId);

    if (msg == null) return;
    await box.put(messageId, msg.copyWith(localPath: localPath));

}

/// جيب الـ local path
static Future<String?> getGroupMessageLocalPath(String messageId) async {
final box = Hive.box<GroupMessageModel>(groupsMessagesBoxName);
final msg = box.get(messageId);
return msg?.localPath;
}

/// ---------------- Clear All ----------------

static Future<void> clearAll() async {
await Hive.box<UserModel>(userBoxName).clear();
await Hive.box<PrivateChatModel>(privateChatsBoxName).clear();
await Hive.box<PrivateMessageModel>(privateMessageBoxName).clear();
await Hive.box<GroupModel>(groupsBoxName).clear();
await Hive.box<GroupMessageModel>(groupsMessagesBoxName).clear();
}
}
//---------------------------------------------------------------------
class HiveTypeIds {
//user model
static const users = 1;
//private chats
static const privateChats = 2;
static const privateMessages = 3;
static const privateMessageType = 4;
static const privateMessageStatus = 5;
//groups chats
static const groups = 6;
static const groupMessages = 7;
static const groupMessageStatus = 8;
static const groupMessageType = 9;
static const usersInGroup = 10;
}
//------------------------------------------------------------------------
import 'dart:async';
import 'dart:io';

import 'package:chattr/core/services/supabase/supabase_client_manager.dart';
import 'package:chattr/core/services/supabase/supabase_error.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
final SupabaseClientManager client;

AuthService(this.client);
SupabaseClient get \_client => client.client;

Future<User> logIn(String email, String password) async {
try {
final res = await \_client.auth.signInWithPassword(
email: email,
password: password,
);
return res.user!;
} catch (e) {
throw \_handleError(e);
}
}

Future<User> signUp(String email, String password) async {
try {
final res = await \_client.auth.signUp(email: email, password: password);
return res.user!;
} catch (e) {
throw \_handleError(e);
}
}

Future<void> signOut() async {
try {
await \_client.auth.signOut();
} catch (e) {
throw \_handleError(e);
}
}

Future<void> resetPassword(String email) async {
try {
await \_client.auth.resetPasswordForEmail(email);
} catch (e) {
throw \_handleError(e);
}
}

User? get currentUser => \_client.auth.currentUser;
SupabaseError \_handleError(Object e) {
if (e is AuthException) {
final msg = e.message.toLowerCase();

      if (msg.contains('invalid login credentials')) {
        return SupabaseError(message: 'Email or password is incorrect');
      }

      if (msg.contains('already registered')) {
        return SupabaseError(message: 'Email already exists');
      }

      if (e.statusCode == '429') {
        return SupabaseError(message: 'Too many attempts, try again later');
      }

      if (msg.contains('jwt expired')) {
        return SupabaseError(message: 'Session expired, login again');
      }

      return SupabaseError(message: e.message);
    } else if (e is SocketException) {
      return SupabaseError(message: 'No internet connection');
    } else if (e is TimeoutException) {
      return SupabaseError(message: 'Request timeout, try again');
    } else {
      return SupabaseError(message: 'Unexpected error occurred');
    }

}
}
//------------------------------------------------------------------

import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseClientManager {
final client = Supabase.instance.client;
}
//----------------------------------------------------------------------

import 'dart:io';

import 'package:chattr/core/services/supabase/supabase_client_manager.dart';
import 'package:chattr/core/services/supabase/supabase_error.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseCrudServices {

final SupabaseClientManager \_clientManager;

SupabaseCrudServices(this.\_clientManager);

SupabaseClient get \_client => \_clientManager.client;

// ===================== GET =====================

Future<List<Map<String, dynamic>>> get({required String table}) {
return \_execute(() async {
final response = await \_client.from(table).select();
return response;
}, debugLabel: 'Get');
}

Future<Map<String, dynamic>> getById({
required String table,
required String id,
}) {
return \_execute(() async {
return await \_client.from(table).select().eq('id', id).single();
}, debugLabel: 'GetById');
}

Future<Map<String, dynamic>?> getByFilter({
required String table,
required String filterColumn,
required String filterValue,
}) {
return \_execute(() async {
return await \_client
.from(table)
.select()
.eq(filterColumn, filterValue)
.maybeSingle();
}, debugLabel: 'GetByFilter');
}

// ===================== POST =====================

Future<void> postWithoutSelect({
required String table,
required Map<String, dynamic> data,
}) {
return \_execute(() async {
await \_client.from(table).insert(data);
}, debugLabel: 'PostWithoutSelect');
}

Future<Map<String, dynamic>> post({
required String table,
required Map<String, dynamic> data,
}) {
return \_execute(() async {
return await \_client.from(table).insert(data).select().single();
}, debugLabel: 'Post');
}

// ===================== UPDATE =====================

Future<void> put({
required String table,
required Map<String, dynamic> data,
required String column,
required dynamic id,
}) {
return \_execute(() async {
await \_client.from(table).update(data).eq(column, id);
}, debugLabel: 'Put');
}

// ===================== DELETE =====================

Future<void> delete({
required String table,
required column,
required String id,
}) {
return \_execute(() async {
await \_client.from(table).delete().eq(column, id);
}, debugLabel: 'Delete');
}

// ===================== CORE EXECUTOR =====================

Future<T> \_execute<T>(
Future<T> Function() action, {
required String debugLabel,
}) async {
try {
return await action();
} on AuthException catch (e) {
throw SupabaseError(message: e.message);
} on PostgrestException catch (e) {
return \_handlePostgrestError(e);
} on SocketException {
throw SupabaseError(message: 'No internet connection');
} catch (e) {
// ignore: avoid_print
print("this is the error($debugLabel): $e");
throw SupabaseError(message: 'Unexpected error occurred');
}
}

Never \_handlePostgrestError(PostgrestException e) {
if (e.code == '42501') {
throw SupabaseError(message: 'Permission denied. Check RLS policies.');
} else if (e.code == '23505') {
throw SupabaseError(message: 'Duplicate entry.');
}

    throw SupabaseError(message: e.message);

}
}
//-----------------------------------------------------------------
class SupabaseError implements Exception {
final String message;

const SupabaseError({required this.message});

@override
String toString() => message;
}
//----------------------------------------------------------------------
import 'dart:io';

import 'package:chattr/core/services/supabase/supabase_client_manager.dart';
import 'package:chattr/core/services/supabase/supabase_error.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class SupabaseStorage {
final SupabaseClientManager \_clientManager;
SupabaseClient get \_client => \_clientManager.client;
SupabaseStorage(this.\_clientManager);

// ===================== Public APIs =====================

Future<String> uploadImage({
required File file,
required String storageFile,
}) async {
return \_execute(() => \_uploadFile(file: file, storageFile: storageFile));
}

Future<String> uploadAudio({
required File file,
required String storageFile,
}) async {
return \_execute(
() => \_uploadFile(
file: file,
storageFile: storageFile,
contentType: 'audio/m4a',
),
);
}

Future<String> updateImage({
required String oldPath,
required File newFile,
required String storageFile,
}) async {
return \_execute(() async {
await deleteFile(path: oldPath, storageFile: storageFile);
return uploadImage(file: newFile, storageFile: storageFile);
});
}

Future<String> updateAudio({
required String oldPath,
required File newFile,
required String storageFile,
}) async {
return \_execute(() async {
await deleteFile(path: oldPath, storageFile: storageFile);
return uploadAudio(file: newFile, storageFile: storageFile);
});
}

Future<void> deleteFile({
required String path,
required String storageFile,
}) async {
return \_execute(() async {
await \_client.storage.from(storageFile).remove([path]);
});
}

String getFileUrl({required String path, required String storageFile}) {
return \_client.storage.from(storageFile).getPublicUrl(path);
}

// ===================== Core Upload =====================

Future<String> \_uploadFile({
required File file,
required String storageFile,
String? contentType,
}) async {
final uuid = const Uuid().v4();
final extension = file.path.split('.').last;
final path = "public/$uuid.$extension";

    await _client.storage
        .from(storageFile)
        .upload(
          path,
          file,
          fileOptions: FileOptions(
            contentType: contentType ?? 'application/octet-stream',
          ),
        );

    return path;

}

// ===================== Error Handler =====================

Future<T> _execute<T>(Future<T> Function() action) async {
try {
return await action();
} on AuthException catch (e) {
throw SupabaseError(message: e.message);
} on SocketException {
throw SupabaseError(message: 'No internet connection');
} catch (_) {
throw SupabaseError(message: 'Unexpected error occurred');
}
}
}
//---------------------------------------------------------------
import 'package:flutter/material.dart';

abstract class AppColors {
// ===================== Brand =====================

static const Color primary = Color(0xFF2A6BE6);
static const Color secondary = Color(0xFF03DAC6);

// ===================== Background =====================

static const Color background = Color(0xFF121212);
static const Color surface = Color(0xFF1A1A1A);

// ===================== Text =====================

static const Color textPrimary = Color(0xFFE0E0E0);
static const Color textSecondary = Color(0xFFCECECC);
static const Color textHint = Color(0x8AFFFFFF);

// ===================== Borders =====================

static const Color border = Color(0xFF333333);
static const Color inputBorder = Color(0xFF5A5A58);

// ===================== Status =====================

static const Color error = Color(0xFFCE1E12);

// ===================== Shadows =====================

static final List<BoxShadow> shadowSm = [
BoxShadow(
color: surface.withOpacity(0.05),
blurRadius: 4,
offset: const Offset(0, 2),
),
];

static final List<BoxShadow> shadowMd = [
BoxShadow(
color: surface.withOpacity(0.08),
blurRadius: 8,
offset: const Offset(0, 4),
),
];

static final List<BoxShadow> shadowLg = [
BoxShadow(
color: surface.withOpacity(0.12),
blurRadius: 16,
offset: const Offset(0, 8),
),
];
}
//------------------------------------------------------------------
import 'package:chattr/core/themes/app_colors.dart';
import 'package:flutter/material.dart';

abstract class AppTextStyles {
// ===================== Display =====================

static const TextStyle displayLarge = TextStyle(
fontSize: 32,
fontWeight: FontWeight.bold,
color: AppColors.textPrimary,
height: 1.2,
letterSpacing: -0.5,
);

static const TextStyle displayMedium = TextStyle(
fontSize: 28,
fontWeight: FontWeight.bold,
color: AppColors.textPrimary,
height: 1.2,
letterSpacing: -0.3,
);

// ===================== Headlines =====================

static const TextStyle headlineLarge = TextStyle(
fontSize: 24,
fontWeight: FontWeight.w700,
color: AppColors.textPrimary,
height: 1.3,
);

static const TextStyle headlineMedium = TextStyle(
fontSize: 20,
fontWeight: FontWeight.w600,
color: AppColors.textPrimary,
height: 1.3,
);

static const TextStyle headlineSmall = TextStyle(
fontSize: 18,
fontWeight: FontWeight.w600,
color: AppColors.textPrimary,
height: 1.4,
);

// ===================== Body =====================

static const TextStyle bodyLarge = TextStyle(
fontSize: 16,
fontWeight: FontWeight.w500,
color: AppColors.textPrimary,
height: 1.5,
);

static const TextStyle bodyMedium = TextStyle(
fontSize: 14,
fontWeight: FontWeight.w400,
color: AppColors.textPrimary,
height: 1.5,
);

static const TextStyle bodySmall = TextStyle(
fontSize: 12,
fontWeight: FontWeight.w400,
color: AppColors.textSecondary,
height: 1.4,
);

// ===================== Labels =====================

static const TextStyle labelLarge = TextStyle(
fontSize: 14,
fontWeight: FontWeight.w600,
color: AppColors.textPrimary,
letterSpacing: 0.2,
);

static const TextStyle labelMedium = TextStyle(
fontSize: 12,
fontWeight: FontWeight.w500,
color: AppColors.textSecondary,
letterSpacing: 0.2,
);

// ===================== Buttons =====================

static const TextStyle buttonLarge = TextStyle(
fontSize: 16,
fontWeight: FontWeight.w600,
color: Colors.white,
);

static const TextStyle buttonMedium = TextStyle(
fontSize: 14,
fontWeight: FontWeight.w600,
color: Colors.white,
);

// ===================== Inputs =====================

static const TextStyle hint = TextStyle(
fontSize: 14,
fontWeight: FontWeight.w400,
color: AppColors.textHint,
);

// ===================== Status =====================

static const TextStyle error = TextStyle(
fontSize: 13,
fontWeight: FontWeight.w500,
color: AppColors.error,
);
}
//----------------------------------------------------------------------
import 'package:chattr/core/services/supabase/supabase_auth_services.dart';
import 'package:chattr/core/services/supabase/supabase_client_manager.dart';
import 'package:chattr/core/services/supabase/supabase_crud_services.dart';
import 'package:chattr/core/services/supabase/supabase_storage.dart';
import 'package:chattr/features/auth/data/repos/auth_repo.dart';
import 'package:chattr/features/auth/data/repos/auth_repo_impl.dart';
import 'package:chattr/features/contacts/data/repos/add_to_contacts_repo/add_to_contacts_repo.dart';
import 'package:chattr/features/contacts/data/repos/add_to_contacts_repo/add_to_contacts_repo_impl.dart';
import 'package:chattr/features/contacts/data/repos/fetch_contacts_repo/fetch_contacts_repo.dart';
import 'package:chattr/features/contacts/data/repos/fetch_contacts_repo/fetch_contacts_repo_impl.dart';
import 'package:chattr/features/contacts/presentation/cubits/fetch_contacts_cubit/fetch_contacts_cubit.dart';
import 'package:chattr/features/group_chats/data/repos/add_and_remove_admin_repo/add_and_remove_admin_repo.dart';
import 'package:chattr/features/group_chats/data/repos/add_and_remove_admin_repo/add_and_remove_admin_repo_impl.dart';
import 'package:chattr/features/group_chats/data/repos/create_group_repo/create_group_repo.dart';
import 'package:chattr/features/group_chats/data/repos/create_group_repo/create_group_repo_impl.dart';
import 'package:chattr/features/group_chats/data/repos/delete_member_repo/delete_member_repo.dart';
import 'package:chattr/features/group_chats/data/repos/delete_member_repo/delete_member_repo_impl.dart';
import 'package:chattr/features/group_chats/data/repos/edit_group_data_repo/edit_group_data_repo.dart';
import 'package:chattr/features/group_chats/data/repos/edit_group_data_repo/edit_group_data_repo_impl.dart';
import 'package:chattr/features/group_chats/data/repos/fetch_group_messages_repo/fetch_group_messages_repo.dart';
import 'package:chattr/features/group_chats/data/repos/fetch_group_messages_repo/fetch_group_messages_repo_impl.dart';
import 'package:chattr/features/group_chats/data/repos/fetch_groups_repo/fetch_groups_repo.dart';
import 'package:chattr/features/group_chats/data/repos/fetch_groups_repo/fetch_groups_repo_impl.dart';
import 'package:chattr/features/group_chats/data/repos/send_group_message_repo/send_group_message_repo.dart';
import 'package:chattr/features/group_chats/data/repos/send_group_message_repo/send_group_message_repo_impl.dart';
import 'package:chattr/features/group_chats/presentation/cubits/fetch_group_messages_cubit/fetch_group_messages_cubit.dart';
import 'package:chattr/features/group_chats/presentation/cubits/fetch_groups_cubit/fetch_groups_cubit.dart';
import 'package:chattr/features/private_chats/data/repos/add_friend_repo/add_friend_repo.dart';
import 'package:chattr/features/private_chats/data/repos/add_friend_repo/add_friend_repo_impl.dart';
import 'package:chattr/features/private_chats/data/repos/fetch_private_chats_repo/fetch_private_chat_repo.dart';
import 'package:chattr/features/private_chats/data/repos/fetch_private_chats_repo/fetch_private_chat_repo_impl.dart';
import 'package:chattr/features/private_chats/data/repos/fetch_private_messages_repo/fetch_private_messages_repo.dart';
import 'package:chattr/features/private_chats/data/repos/fetch_private_messages_repo/fetch_private_messages_repo_impl.dart';
import 'package:chattr/features/private_chats/data/repos/send_private_message_repo/send_private_message_repo.dart';
import 'package:chattr/features/private_chats/data/repos/send_private_message_repo/send_private_message_repo_impl.dart';
import 'package:chattr/features/private_chats/presentation/cubits/fetch_private_chats_cubit/fetch_private_chats_cubit.dart';
import 'package:chattr/features/private_chats/presentation/cubits/fetch_private_messages_cubit/fetch_private_messages_cubit.dart';
import 'package:get_it/get_it.dart';

final getIt = GetIt.instance;

void setUpGetIt() {
//client manager
getIt.registerLazySingleton<SupabaseClientManager>(
() => SupabaseClientManager(),
);
//auth services
getIt.registerLazySingleton<AuthService>(
() => AuthService(getIt<SupabaseClientManager>()),
);
//crud services
getIt.registerLazySingleton<SupabaseCrudServices>(
() => SupabaseCrudServices(getIt<SupabaseClientManager>()),
);
//storage services
getIt.registerLazySingleton<SupabaseStorage>(
() => SupabaseStorage(getIt<SupabaseClientManager>()),
);
// auth repo
getIt.registerLazySingleton<AuthRepo>(
() => AuthRepoImpl(
getIt<AuthService>(),
getIt<SupabaseCrudServices>(),
getIt<SupabaseStorage>(),
),
);
// add to contacts repo
getIt.registerLazySingleton<AddToContactsRepo>(
() => AddToContactsRepoImpl(
getIt<SupabaseClientManager>(),
getIt<AuthService>(),
getIt<SupabaseCrudServices>(),
),
);
//Fetch Contacts repo
getIt.registerLazySingleton<FetchContactsRepo>(
() => FetchContactsRepoImpl(
getIt<SupabaseClientManager>(),
getIt<SupabaseCrudServices>(),
),
);
//add friend repo
getIt.registerLazySingleton<AddFriendRepo>(
() => AddFriendRepoImpl(
getIt<SupabaseCrudServices>(),
getIt<SupabaseClientManager>(),
),
);
//fetch private chats repo
getIt.registerLazySingleton<FetchPrivateChatRepo>(
() => FetchPrivateChatRepoImpl(
getIt<AuthService>(),
getIt<SupabaseClientManager>(),
),
);
//fetch private messages repo
getIt.registerLazySingleton<FetchPrivateMessagesRepo>(
() => FetchPrivateMessagesRepoImpl(getIt<SupabaseClientManager>()),
);
//send private message repo
getIt.registerLazySingleton<SendPrivateMessageRepo>(
() => SendPrivateMessageRepoImpl(
crud: getIt<SupabaseCrudServices>(),
storage: getIt<SupabaseStorage>(),
),
);
//fetch contacts cubit
getIt.registerLazySingleton<FetchContactsCubit>(
() => FetchContactsCubit(getIt<FetchContactsRepo>(), getIt<AuthService>()),
);

// fetch private messages cubit
getIt.registerLazySingleton<FetchPrivateMessagesCubit>(
() => FetchPrivateMessagesCubit(
auth: getIt<AuthService>(),
client: getIt<SupabaseClientManager>(),
repo: getIt<FetchPrivateMessagesRepo>(),
),
);
//fetch private chats cubit
getIt.registerLazySingleton<FetchPrivateChatsCubit>(() {
final chatsCubit = FetchPrivateChatsCubit(
client: getIt<SupabaseClientManager>(),
fetchMessages: getIt<FetchPrivateMessagesCubit>(),
repo: getIt<FetchPrivateChatRepo>(),
);
// setChatsCubit هنا مرة واحدة
getIt<FetchPrivateMessagesCubit>().setChatsCubit(chatsCubit);
return chatsCubit;
});

//?group chats
//add and remove admin repo
getIt.registerLazySingleton<AddAndRemoveAdminRepo>(
() => AddAndRemoveAdminRepoImpl(getIt<SupabaseClientManager>()),
);
//create group repo
getIt.registerLazySingleton<CreateGroupRepo>(
() => CreateGroupRepoImpl(
crud: getIt<SupabaseCrudServices>(),
storage: getIt<SupabaseStorage>(),
),
);

//delete member repo
getIt.registerLazySingleton<DeleteMemberRepo>(
() => DeleteMemberRepoImpl(getIt<SupabaseClientManager>()),
);

//edit group data repo
getIt.registerLazySingleton<EditGroupDataRepo>(
() => EditGroupDataRepoImpl(
crud: getIt<SupabaseCrudServices>(),
storage: getIt<SupabaseStorage>(),
),
);

//fetch groups repo
getIt.registerLazySingleton<FetchGroupsRepo>(
() => FetchGroupsRepoImpl(getIt<SupabaseClientManager>()),
);
// fetch group messages repo
getIt.registerLazySingleton<FetchGroupMessagesRepo>(
() => FetchGroupMessagesRepoImpl(
clientManager: getIt<SupabaseClientManager>(),
),
);

//send group message repo
getIt.registerLazySingleton<SendGroupMessageRepo>(
() => SendGroupMessageRepoImpl(
crud: getIt<SupabaseCrudServices>(),
storage: getIt<SupabaseStorage>(),
),
);

//fetch groups cubit
getIt.registerLazySingleton<FetchGroupsCubit>(
() => FetchGroupsCubit(
auth: getIt<AuthService>(),
client: getIt<SupabaseClientManager>(),
repo: getIt<FetchGroupsRepo>(),
),
);

//fetch group messages cubit
getIt.registerLazySingleton<FetchGroupMessagesCubit>(
() => FetchGroupMessagesCubit(
auth: getIt<AuthService>(),
client: getIt<SupabaseClientManager>(),
repo: getIt<FetchGroupMessagesRepo>(),
),
);
}
//-------------------------------------------------------------------
import 'dart:math' as math;
import 'package:flutter/material.dart';

extension ContextExtensions on BuildContext {
double get screenWidth => MediaQuery.of(this).size.width;
double get screenHeight => MediaQuery.of(this).size.height;

double responsiveWidth({
double? screen,
required double percentage,
required double min,
required double max,
}) {
return math.min(math.max((screen ?? screenWidth) \* percentage, min), max);
}

double responsiveHeight({
double? screen,
required double percentage,
required double min,
required double max,
}) {
return math.min(math.max((screen ?? screenHeight) \* percentage, min), max);
}
}
//-----------------------------------------------------------------------

class AuthValidation {
///Field validator
static String? required(String? value) {
if (value == null || value.trim().isEmpty) return 'Required field';
return null;
}

///email validator
static String? email(String? value) {
if (value == null || value.trim().isEmpty) return 'Required field';
final emailRegex = RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$');
if (!emailRegex.hasMatch(value.trim())) return 'Enter a valid email';
return null;
}

///password validator

static String? password(String? value) {
if (value == null || value.trim().isEmpty) return 'Required field';
if (value.length < 8) return 'At least 8 characters';
return null;
}

///phone validator

static String? phone(String? value) {
if (value == null || value.trim().isEmpty) return 'Required field';
final phoneRegex = RegExp(r'^\+?[0-9]{7,15}$');
if (!phoneRegex.hasMatch(value.trim())) return 'Enter a valid phone number';
return null;
}
}
//---------------------------------------------------------------------

import 'package:just_audio/just_audio.dart';

class AudioPlayerManager {
AudioPlayerManager._();
static final AudioPlayerManager instance = AudioPlayerManager._();

AudioPlayer? \_currentPlayer;
String? \_currentMessageId;

// ✅ لما تشغل player جديد - وقف القديم
Future<void> play({
required String messageId,
required AudioPlayer player,
}) async {
// وقف الـ player القديم لو مختلف
if (\_currentPlayer != null && \_currentPlayer != player) {
await \_currentPlayer!.pause();
}

\_currentPlayer = player;
\_currentMessageId = messageId;
await player.play(); // ✅ شغّل دايماً
}

void unregister(String messageId) {
if (\_currentMessageId == messageId) {
\_currentPlayer = null;
\_currentMessageId = null;
}
}
}//-----------------------------------------------------------
// ✅ Dashed ring painter
import 'dart:math' as math;

import 'package:flutter/material.dart';

class DashedRingPainter extends CustomPainter {
@override
void paint(Canvas canvas, Size size) {
final paint = Paint()
..color = Colors.red.withOpacity(0.7)
..strokeWidth = 1.5
..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1;
    const dashCount = 12;
    const dashAngle = 2 * math.pi / dashCount;

    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * dashAngle;
      final endAngle = startAngle + dashAngle * 0.5;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        endAngle - startAngle,
        false,
        paint,
      );
    }

}

@override
bool shouldRepaint(DashedRingPainter old) => false;
}//------------------------------------------------------------
import 'dart:math' as math;
import 'package:flutter/material.dart';
class WaveformPainter extends CustomPainter {
final double progress;
final double animValue;
final bool isPlaying;

WaveformPainter({
required this.progress,
required this.animValue,
required this.isPlaying,
});

@override
void paint(Canvas canvas, Size size) {
const barCount = 28;
final barWidth = (size.width - (barCount - 1) \* 2.5) / barCount;

    // أطوال الموجات - تقليد شكل واتساب
    final heights = List.generate(barCount, (i) {
      final base = math.sin(i * 0.8) * 0.4 +
          math.sin(i * 0.3) * 0.3 +
          math.cos(i * 1.2) * 0.2 +
          0.55;
      return (base.clamp(0.15, 0.95));
    });

    for (int i = 0; i < barCount; i++) {
      final x = i * (barWidth + 2.5);
      final barProgress = i / barCount;

      // ✅ animation للبارات اللي بتشتغل
      double heightMultiplier = heights[i];
      if (isPlaying && barProgress <= progress) {
        final wave = math.sin(
          (animValue * 2 * math.pi) + (i * 0.4),
        );
        heightMultiplier = (heights[i] + wave * 0.15).clamp(0.1, 1.0);
      }

      final barHeight = size.height * heightMultiplier;
      final top = (size.height - barHeight) / 2;

      final isPlayed = barProgress <= progress;

      final paint = Paint()
        ..color = isPlayed
            ? Colors.white
            : Colors.white.withOpacity(0.3)
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.fill;

      final rRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, top, barWidth, barHeight),
        Radius.circular(barWidth / 2),
      );

      canvas.drawRRect(rRect, paint);
    }

}

@override
bool shouldRepaint(WaveformPainter old) =>
old.progress != progress ||
old.animValue != animValue ||
old.isPlaying != isPlaying;
}//--------------------------------------------------
import 'package:flutter/material.dart';

class PulseRing extends StatelessWidget {
const PulseRing({super.key, required this.pulseAnim});
final Animation<double> pulseAnim;

@override
Widget build(BuildContext context) {
return Positioned(
right: 0,
left: 0,
child: Transform.scale(
scale: pulseAnim.value,
child: Container(
width: 42,
height: 42,
decoration: BoxDecoration(
shape: BoxShape.circle,
border: Border.all(
color: Colors.red.withOpacity(0.4 \* (2 - pulseAnim.value)),
width: 2,
),
),
),
),
);
}
}
//------------------------------------------------------------
import 'package:flutter/material.dart';

class RecordButton extends StatelessWidget {
const RecordButton({super.key, required this.scaleAnim, required this.isRecording});
final Animation<double> scaleAnim;
final bool isRecording;
@override
Widget build(BuildContext context) {
return Positioned(
right: 0,
left: 0,
child: Transform.scale(
scale: scaleAnim.value,
child: AnimatedContainer(
duration: const Duration(milliseconds: 200),
curve: Curves.easeOut,
width: 40,
height: 40,
decoration: BoxDecoration(
shape: BoxShape.circle,
gradient: isRecording
? const LinearGradient(
colors: [Color(0xFFFF4444), Color(0xFFCC0000)],
begin: Alignment.topLeft,
end: Alignment.bottomRight,
)
: const LinearGradient(
colors: [Color(0xFF2196F3), Color(0xFF1565C0)],
begin: Alignment.topLeft,
end: Alignment.bottomRight,
),
boxShadow: [
BoxShadow(
color: isRecording
? Colors.red.withOpacity(0.5)
: Colors.blue.withOpacity(0.4),
blurRadius: isRecording ? 12 : 6,
spreadRadius: isRecording ? 2 : 0,
),
],
),
child: AnimatedSwitcher(
duration: const Duration(milliseconds: 200),
child: Icon(
isRecording ? Icons.stop_rounded : Icons.mic,
key: ValueKey(isRecording),
color: Colors.white,
size: 20,
),
),
),
),
);
}
}
//-----------------------------------------------------------------------------
import 'package:chattr/core/themes/app_text_styles.dart';
import 'package:chattr/core/widgets/custom_text.dart';
import 'package:flutter/material.dart';

class RecordTimerText extends StatelessWidget {
const RecordTimerText({
super.key,
required this.isRecording,
required this.seconds,
});
final bool isRecording;
final int seconds;

@override
Widget build(BuildContext context) {
String formatDuration(int seconds) {
final m = (seconds ~/ 60).toString().padLeft(2, '0');
final s = (seconds % 60).toString().padLeft(2, '0');
return '$m:$s';
}

    return Positioned(
      top: -30,
      right: 0,
      left: 0,

      child: AnimatedOpacity(
        opacity: isRecording ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.withOpacity(0.3), width: 1),
          ),
          child: CustomText(
            align: TextAlign.center,

            text: formatDuration(seconds),
            style: AppTextStyles.bodyMedium,
          ),
        ),
      ),
    );

}
}
//---------------------------------------------------------------------
import 'dart:async';
import 'dart:math' as math;

import 'package:chattr/core/cubits/audio_cubit/audio_cubit.dart';
import 'package:chattr/core/cubits/audio_cubit/audio_state.dart';
import 'package:chattr/core/widgets/audio/ui/painters/dashed_ring_painter.dart';
import 'package:chattr/core/widgets/audio/ui/widgets/pulse_ring.dart';
import 'package:chattr/core/widgets/audio/ui/widgets/record_button.dart';
import 'package:chattr/core/widgets/audio/ui/widgets/record_timer_text.dart';
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:chattr/features/group_chats/presentation/cubits/send_group_message_cubit/send_group_message_cubit.dart';
import 'package:chattr/features/private_chats/presentation/cubits/send_private_message_cubit/send_private_message_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AudioRecordButton extends StatefulWidget {
final String chatId;
final String senderId;
final UserModel sender;
final bool isGroup;

const AudioRecordButton({
super.key,
required this.chatId,
required this.senderId,
required this.sender,
required this.isGroup,
});

@override
State<AudioRecordButton> createState() => \_AudioRecordButtonState();
}

class \_AudioRecordButtonState extends State<AudioRecordButton>
with TickerProviderStateMixin {
// ✅ Scale animation
late AnimationController \_scaleController;
late Animation<double> \_scaleAnim;

// ✅ Pulse animation
late AnimationController \_pulseController;
late Animation<double> \_pulseAnim;

// ✅ Ring rotation animation
late AnimationController \_ringController;

// ✅ Timer
Timer? \_timer;
int \_seconds = 0;

void _startAnimations() {
\_scaleController.forward();
\_pulseController.repeat(reverse: true);
\_ringController.repeat();
\_seconds = 0;
\_timer = Timer.periodic(const Duration(seconds: 1), (_) {
if (mounted) setState(() => \_seconds++);
});
}

void \_stopAnimations() {
\_scaleController.reverse();
\_pulseController.stop();
\_pulseController.reset();
\_ringController.stop();
\_ringController.reset();
\_timer?.cancel();
setState(() => \_seconds = 0);
}

//.........................................
@override
void initState() {
\_scaleController = AnimationController(
vsync: this,
duration: const Duration(milliseconds: 150),
);
\_scaleAnim = Tween<double>(
begin: 1.0,
end: 1.2,
).animate(CurvedAnimation(parent: \_scaleController, curve: Curves.easeOut));
\_pulseController = AnimationController(
vsync: this,
duration: const Duration(milliseconds: 900),
);
\_pulseAnim = Tween<double>(
begin: 1.0,
end: 1.5,
).animate(CurvedAnimation(parent: \_pulseController, curve: Curves.easeOut));
\_ringController = AnimationController(
vsync: this,
duration: const Duration(milliseconds: 2000),
);

    super.initState();

}

@override
void dispose() {
\_scaleController.dispose();
\_pulseController.dispose();
\_ringController.dispose();
\_timer?.cancel();
super.dispose();
}

@override
Widget build(BuildContext context) {
return GestureDetector(
onLongPressStart: (_) {
HapticFeedback.mediumImpact(); //vibrate on start
\_startAnimations();
context.read<AudioCubit>().startRecording(
chatId: widget.chatId,
senderId: widget.senderId,
);
},
onLongPressEnd: (_) async {
HapticFeedback.lightImpact();
\_stopAnimations();

        final cubit = context.read<AudioCubit>();
        if (cubit.state.status != RecordingStatus.recording) return;

        final localPath = await cubit.stopRecordingOnly();
        if (localPath == null || !context.mounted) return;
        final sendPrivateVoice = widget.isGroup
            ? null
            : context.read<SendPrivateMessageCubit>();
        final sendGroupVoice = widget.isGroup
            ? context.read<SendGroupMessageCubit>()
            : null;
        // ✅ اعرض فوراً بدون URL
        widget.isGroup
            ? sendGroupVoice!.showLocalVoice(
                sender: widget.sender,
                senderId: widget.senderId,
                groupId: widget.chatId,
                audioPath: localPath,
                duration: cubit.lastDuration,
              )
            : sendPrivateVoice!.showLocalVoice(
                sender: widget.sender,
                senderId: widget.senderId,
                chatId: widget.chatId,
                audioPath: localPath,
                duration: cubit.lastDuration,
              );

        // ✅ upload في الخلفية
        unawaited(
          cubit.uploadAndNotify(
            localPath: localPath,
            groupId: widget.chatId,
            onUploaded: (uploadedUrl) {
              widget.isGroup
                  ? sendGroupVoice!.updateVoiceUrl(
                      groupId: widget.chatId,
                      localPath: localPath,
                      uploadedUrl: uploadedUrl,
                    )
                  : sendPrivateVoice!.updateVoiceUrl(
                      chatId: widget.chatId,
                      localPath: localPath,
                      uploadedUrl: uploadedUrl,
                    );
            },
          ),
        );
      },
      child: BlocBuilder<AudioCubit, AudioState>(
        builder: (context, state) {
          final isRecording = state.status == RecordingStatus.recording;

          return AnimatedBuilder(
            animation: Listenable.merge([
              _scaleAnim,
              _pulseAnim,
              _ringController,
            ]),
            builder: (context, _) {
              return SizedBox(
                width: 40,
                height: 50,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.centerRight,
                  children: [
                    // ✅ Timer text
                    if (isRecording)
                      RecordTimerText(
                        isRecording: isRecording,
                        seconds: _seconds,
                      ),
                    // ✅ Pulse ring
                    if (isRecording) PulseRing(pulseAnim: _pulseAnim),
                    // ✅ Rotating dashed ring
                    if (isRecording)
                      Positioned(
                        right: 0,
                        left: 0,
                        child: Transform.rotate(
                          angle: _ringController.value * 2 * math.pi,
                          child: CustomPaint(
                            size: const Size(46, 46),
                            painter: DashedRingPainter(),
                          ),
                        ),
                      ),

                    RecordButton(
                      scaleAnim: _scaleAnim,
                      isRecording: isRecording,
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );

}
}
//---------------------------------------------------------------------------
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chattr/core/cubits/pick_image/pick_image_cubit.dart';
import 'package:chattr/core/themes/app_colors.dart';
import 'package:chattr/core/widgets/image/widgets/image_source_bottom.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

const \_kAvatarRadius = 45.0;
const \_kFallbackAvatarUrl =
'https://uxwing.com/wp-content/themes/uxwing/download/peoples-avatars/default-avatar-profile-picture-male-icon.png';

class PickImageWidget extends StatelessWidget {
const PickImageWidget({
super.key,
this.defaultImageUrl,
this.isProfile = false,
this.isEditing = true,
});

final String? defaultImageUrl;
final bool isProfile;
final bool isEditing;

@override
Widget build(BuildContext context) {
return Stack(
clipBehavior: Clip.none,
children: [
_AvatarContainer(
radius: _kAvatarRadius,
child: BlocBuilder<PickImageCubit, PickImageState>(
builder: (context, state) => _buildAvatarContent(context, state),
),
),
if (isEditing)
Positioned(
right: -10,
bottom: -10,
child: _CameraButton(
onTap: () => ImageSourceBottomSheet.show(
context,
cropForProfile: isProfile,
),
),
),
],
);
}

Widget \_buildAvatarContent(BuildContext context, PickImageState state) {
final imageFile = context.read<PickImageCubit>().imageFile;

    if (imageFile != null) {
      return _LocalImage(file: imageFile, radius: _kAvatarRadius);
    }

    return _NetworkImage(imageUrl: defaultImageUrl ?? _kFallbackAvatarUrl);

}
}

// ──────────────────────────────────────────────
// Private Sub-Widgets
// ──────────────────────────────────────────────

class \_AvatarContainer extends StatelessWidget {
const \_AvatarContainer({required this.radius, required this.child});

final double radius;
final Widget child;

@override
Widget build(BuildContext context) {
return Stack(
clipBehavior: Clip.none,
children: [
Container(
width: radius _ 2,
height: radius _ 2,
decoration: BoxDecoration(
color: Colors.grey,
shape: BoxShape.circle,
border: Border.all(color: AppColors.border, width: 2),
),
clipBehavior: Clip.hardEdge,

          child: child,
        ),
        Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary, width: 1.5),
            boxShadow: AppColors.shadowSm,
          ),
        ),
      ],
    );

}
}

class \_NetworkImage extends StatelessWidget {
const \_NetworkImage({required this.imageUrl});

final String imageUrl;

@override
Widget build(BuildContext context) {
return CachedNetworkImage(
imageUrl: imageUrl,
fit: BoxFit.cover,
placeholder: (_, _) => const Center(
child: CupertinoActivityIndicator(color: Colors.white54, radius: 9),
),
errorWidget: (_, _, \_) =>
const Icon(Icons.person_sharp, color: Colors.grey, size: 42),
);
}
}

class \_LocalImage extends StatelessWidget {
const \_LocalImage({required this.file, required this.radius});

final dynamic file; // File
final double radius;

@override
Widget build(BuildContext context) {
return Image.file(
file,
fit: BoxFit.cover,
width: radius _ 2,
height: radius _ 2,
);
}
}

class \_CameraButton extends StatelessWidget {
const \_CameraButton({required this.onTap});

final VoidCallback onTap;

@override
Widget build(BuildContext context) {
return GestureDetector(
onTap: onTap,
behavior: HitTestBehavior.opaque,
child: Container(
width: 32,
height: 32,
decoration: BoxDecoration(
color: AppColors.primary,
shape: BoxShape.circle,
border: Border.all(color: Colors.white, width: 2),
),
child: const Icon(
Icons.camera_alt_rounded,
color: Colors.white,
size: 16,
),
),
);
}
}
//-----------------------------------------------------------------------
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chattr/core/cubits/download_image/download_image_cubit.dart';
import 'package:chattr/core/helpers/snack_bar.dart';
import 'package:chattr/core/routing/router_models.dart';
import 'package:chattr/core/themes/app_colors.dart';
import 'package:chattr/core/themes/app_text_styles.dart';
import 'package:chattr/core/widgets/custom_text.dart';
import 'package:chattr/core/widgets/image/widgets/download_image_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ViewImage extends StatefulWidget {
const ViewImage({super.key, required this.imageInfo});
final ViewImageParams imageInfo;

@override
State<ViewImage> createState() => \_ViewImageState();
}

class \_ViewImageState extends State<ViewImage> {
final ValueNotifier<bool> showInfo = ValueNotifier(true);
@override
void dispose() {
showInfo.dispose();
super.dispose();
}

@override
Widget build(BuildContext context) {
return Scaffold(
body: BlocListener<DownloadImageCubit, DownloadImageState>(
listener: (context, state) {
if (state is DownloadImagefailure) {
CustomSnackBar.error(context, state.errorMessage);
}
if (state is DownloadImageSucess) {
CustomSnackBar.success(context, "Image Saved in Gallary");
}
},
child: Stack(
children: [
GestureDetector(
onTap: () {
showInfo.value = !showInfo.value;
},
child: InteractiveViewer(
minScale: 0.5,
maxScale: 4.0,
child: Center(
child: Hero(
tag: widget.imageInfo.imageUrl,
child:
(widget.imageInfo.imageUrl.startsWith('/') &&
File(widget.imageInfo.imageUrl).existsSync())
? ClipRRect(
borderRadius: BorderRadius.circular(8),
child: Image.file(
File(widget.imageInfo.imageUrl),
fit: BoxFit.cover,
width: double.infinity,
gaplessPlayback: true,
cacheWidth:
800, // يحط الصورة في الـ image cache بـ resolution معقولة
frameBuilder: (_, child, frame, _) =>
frame == null ? _Placeholder() : child,
),
)
: CachedNetworkImage(
fit: BoxFit.contain,
imageUrl: widget.imageInfo.imageUrl,
placeholder: (context, url) => Center(
child: CupertinoActivityIndicator(
color: Colors.white54,
radius: 9,
),
),
errorWidget: (context, url, error) => Center(
child: const Icon(
Icons.image_not_supported_outlined,
color: Colors.red,
size: 40,
),
),
),
),
),
),
),
ValueListenableBuilder<bool>(
valueListenable: showInfo,
builder: (context, value, _) {
return Visibility(
visible: value,
child: Container(
padding: EdgeInsets.fromLTRB(0, 50, 0, 10),
color: AppColors.surface.withOpacity(0.5),
height: 100,
child: Row(
children: [
Gap(5),
InkWell(
onTap: () => context.pop(),
child: Icon(CupertinoIcons.back),
),
Gap(10),
Column(
mainAxisSize: MainAxisSize.min,
crossAxisAlignment: CrossAxisAlignment.start,
children: [
CustomText(
text: widget.imageInfo.senderName,
style: AppTextStyles.bodySmall,
),

                            CustomText(
                              text: widget.imageInfo.messageData.createdAt
                                  .toString(),
                              style: AppTextStyles.bodySmall.copyWith(
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                        Spacer(),
                        DownloadImageButton(
                          imageUrl: widget.imageInfo.imageUrl,
                        ),
                        Gap(20),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );

}
}

class \_Placeholder extends StatelessWidget {
@override
Widget build(BuildContext context) => const SizedBox(
height: 200,
width: double.infinity,
child: Center(
child: CupertinoActivityIndicator(color: Colors.white54, radius: 9),
),
);
}
//--------------------------------------------------------------------
import 'package:chattr/core/cubits/download_image/download_image_cubit.dart';
import 'package:chattr/core/utils/extensions/responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DownloadImageButton extends StatelessWidget {
final String imageUrl;
const DownloadImageButton({super.key, required this.imageUrl});

@override
Widget build(BuildContext context) {
return BlocBuilder<DownloadImageCubit, DownloadImageState>(
buildWhen: (prev, curr) =>
prev is DownloadImageLoading || curr is DownloadImageLoading,
builder: (context, state) {
final isLoading = state is DownloadImageLoading;

        return isLoading
            ? SizedBox(
                width: context.screenWidth * 0.2,
                child: LinearProgressIndicator(
                  value: state.progress,
                  color: Colors.grey,
                ),
              )
            : InkWell(
                onTap: () {
                  context.read<DownloadImageCubit>().downloadImage(imageUrl);
                },
                child: Icon(Icons.download),
              );
      },
    );

}
}
//-------------------------------------------------------
import 'package:chattr/core/cubits/pick_image/pick_image_cubit.dart';
import 'package:chattr/core/themes/app_colors.dart';
import 'package:chattr/core/themes/app_text_styles.dart';
import 'package:chattr/core/widgets/custom_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

class ImageSourceBottomSheet extends StatelessWidget {
const ImageSourceBottomSheet({super.key, required this.cropForProfile});

final bool cropForProfile;

/// Helper ثابت لعرض الـ bottom sheet بطريقة منظمة
static Future<void> show(
BuildContext context, {
required bool cropForProfile,
}) {
return showModalBottomSheet(
context: context,
shape: const RoundedRectangleBorder(
borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
),
builder: (sheetContext) => BlocProvider.value(
value: context.read<PickImageCubit>(),
child: ImageSourceBottomSheet(cropForProfile: cropForProfile),
),
);
}

@override
Widget build(BuildContext context) {
return SafeArea(
child: Padding(
padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
\_SheetHandle(),
const Gap(8),
const CustomText(
style: AppTextStyles.headlineSmall,
text: 'Select Image Source',
),
const Divider(height: 20),
BlocBuilder<PickImageCubit, PickImageState>(
builder: (context, state) {
final hasImage =
context.read<PickImageCubit>().imageFile != null;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _SourceOption(
                      icon: CupertinoIcons.camera,
                      label: 'Camera',
                      onTap: () => _onSourceSelected(
                        context,
                        source: ImageSource.camera,
                      ),
                    ),
                    _SourceOption(
                      icon: CupertinoIcons.photo_fill_on_rectangle_fill,
                      label: 'Gallery',
                      onTap: () => _onSourceSelected(
                        context,
                        source: ImageSource.gallery,
                      ),
                    ),
                    if (hasImage)
                      _SourceOption(
                        icon: Icons.delete_outline_rounded,
                        label: 'Delete',
                        iconColor: AppColors.error,
                        labelColor: AppColors.error,
                        onTap: () => _onDeleteSelected(context),
                      ),
                  ],
                );
              },
            ),
            const Gap(10),
          ],
        ),
      ),
    );

}

void \_onSourceSelected(BuildContext context, {required ImageSource source}) {
context.pop();
context.read<PickImageCubit>().pickImage(
source: source,
cropForProfile: cropForProfile,
);
}

void \_onDeleteSelected(BuildContext context) {
context.pop();
context.read<PickImageCubit>().deleteImage();
}
}

// ──────────────────────────────────────────────
// Private Sub-Widgets
// ──────────────────────────────────────────────

class \_SheetHandle extends StatelessWidget {
@override
Widget build(BuildContext context) {
return Container(
width: 40,
height: 4,
decoration: BoxDecoration(
color: Colors.grey.shade300,
borderRadius: BorderRadius.circular(2),
),
);
}
}

class \_SourceOption extends StatelessWidget {
const \_SourceOption({
required this.icon,
required this.label,
required this.onTap,
this.iconColor,
this.labelColor,
});

final IconData icon;
final String label;
final VoidCallback onTap;
final Color? iconColor;
final Color? labelColor;

@override
Widget build(BuildContext context) {
return InkWell(
onTap: onTap,
borderRadius: BorderRadius.circular(12),
child: Padding(
padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
Icon(icon, color: iconColor, size: 28),
const Gap(6),
Text(
label,
style: TextStyle(
color: labelColor,
fontSize: 13,
fontWeight: FontWeight.w500,
),
),
],
),
),
);
}
}
//--------------------------------------------------------------
import 'dart:async';
import 'dart:io';

import 'package:chattr/core/helpers/snack_bar.dart';
import 'package:chattr/core/services/hive/hive_services.dart';
import 'package:chattr/core/themes/app_text_styles.dart';
import 'package:chattr/core/utils/extensions/responsive.dart';
import 'package:chattr/core/widgets/audio/helper/audio_player_manager.dart';
import 'package:chattr/core/widgets/audio/ui/painters/waveform_painter.dart';
import 'package:chattr/core/widgets/custom_text.dart';
import 'package:chattr/features/private_chats/data/models/private_message_model.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

class AudioMessageWidget extends StatefulWidget {
const AudioMessageWidget({super.key, required this.audioMessage});
final dynamic audioMessage;

@override
State<AudioMessageWidget> createState() => \_AudioMessageWidgetState();
}

class \_AudioMessageWidgetState extends State<AudioMessageWidget>
with TickerProviderStateMixin {
late AudioPlayer \_player;
bool isPlaying = false;
bool isLoading = true;
bool hasError = false;
Duration duration = Duration.zero;
Duration position = Duration.zero;

StreamSubscription? \_positionSub;
StreamSubscription? \_stateSub;
StreamSubscription? \_durationSub;

// ✅ Animation controllers
late AnimationController \_waveController;
late AnimationController \_playButtonController;
late Animation<double> \_playButtonScale;

//...........................................
Future<void> \_initAudio() async {
try {
final content = widget.audioMessage.content;
final messageId = widget.audioMessage.messageId;

      if (content.startsWith('/')) {
        await _player.setFilePath(content);
        if (!mounted) return;
        setState(() => isLoading = false);
        _setupStreams();
        return;
      }

      if (messageId != null) {
        final localPath = widget.audioMessage is PrivateMessageModel
            ? await HiveService.getPrivateMessageLocalPath(messageId)
            : await HiveService.getGroupMessageLocalPath(messageId);

        if (localPath != null && File(localPath).existsSync()) {
          await _player.setFilePath(localPath);
          if (!mounted) return;
          setState(() {
            isLoading = false;
            duration = _player.duration ?? duration;
          });
          _setupStreams();
          return;
        }
      }

      await _player.setUrl(content);
      if (!mounted) return;
      setState(() {
        isLoading = false;
        duration = _player.duration ?? duration;
      });
      _setupStreams();

      if (messageId != null) {
        unawaited(_downloadAndCache(content, messageId));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        hasError = true;
      });
    }

}

Future<void> _downloadAndCache(String url, String messageId) async {
try {
final dir = await getApplicationDocumentsDirectory();
final localPath = '${dir.path}/audio_$messageId.m4a';

      if (File(localPath).existsSync()) {
        widget.audioMessage is PrivateMessageModel
            ? await HiveService.savePrivateMessageLocalPath(
                messageId: messageId,
                localPath: localPath,
              )
            : await HiveService.saveGroupMessageLocalPath(
                messageId: messageId,
                localPath: localPath,
              );
        return;
      }

      final response = await http.get(Uri.parse(url));

      await File(localPath).writeAsBytes(response.bodyBytes);

      widget.audioMessage is PrivateMessageModel
          ? await HiveService.savePrivateMessageLocalPath(
              messageId: messageId,
              localPath: localPath,
            )
          : await HiveService.saveGroupMessageLocalPath(
              messageId: messageId,
              localPath: localPath,
            );
    } catch (e) {
      if (!mounted) return;
      final message = e is http.ClientException
          ? "Network error while loading audio."
          : "Failed to load audio.";
      CustomSnackBar.error(context, message);
    }

}

//................................
void \_setupStreams() {
\_durationSub = \_player.durationStream.listen((d) {
if (!mounted) return;
if (d != null) setState(() => duration = d);
});

    _positionSub = _player.positionStream.listen((pos) {
      if (!mounted) return;
      setState(() => position = pos);
    });

    _stateSub = _player.playerStateStream.listen((s) {
      if (!mounted) return;
      setState(() => isPlaying = s.playing);
      if (s.playing) {
        _waveController.repeat();
      } else {
        _waveController.stop();
      }
      if (s.processingState == ProcessingState.completed) {
        _player.seek(Duration.zero);
        _player.pause();
        setState(() => position = Duration.zero);
      }
    });

}

void _togglePlay() async {
\_playButtonController.forward().then(
(_) => \_playButtonController.reverse(),
);

    if (isPlaying) {
      await _player.pause();
      AudioPlayerManager.instance.unregister(
        widget.audioMessage.messageId ?? widget.audioMessage.tempId,
      );
    } else {
      // ✅ هيوقف أي player تاني تلقائياً
      await AudioPlayerManager.instance.play(
        messageId: widget.audioMessage.messageId ?? widget.audioMessage.tempId,
        player: _player,
      );
    }

}

double get \_progress {
if (duration.inMilliseconds == 0) return 0;
return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
}

String formatTime(Duration d) {
final min = d.inMinutes.remainder(60).toString().padLeft(2, '0');
final sec = d.inSeconds.remainder(60).toString().padLeft(2, '0');
return "$min:$sec";
}

//...........................................
@override
void initState() {
super.initState();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _playButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _playButtonScale = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _playButtonController, curve: Curves.easeOut),
    );

    _player = AudioPlayer();

    if (widget.audioMessage.mediaDuration != null) {
      duration = Duration(seconds: widget.audioMessage.mediaDuration!);
    }

    final content = widget.audioMessage.content;

    // ✅ لو local file أو عنده localPath في الـ message - مش محتاج loading
    // لو URL بس - loading
    isLoading =
        !content.startsWith('/') &&
        widget.audioMessage.localPath == null &&
        widget.audioMessage.messageId != null;

    _initAudio();

}

@override
void dispose() {
AudioPlayerManager.instance.unregister(
widget.audioMessage.messageId ?? widget.audioMessage.tempId,
);
\_positionSub?.cancel();
\_stateSub?.cancel();
\_durationSub?.cancel();
\_waveController.dispose();
\_playButtonController.dispose();
\_player.dispose();
super.dispose();
}

@override
Widget build(BuildContext context) {
final waveFormWidth = context.responsiveWidth(
percentage: 0.23,
min: context.screenWidth _ 0.15,
max: context.screenWidth _ 0.25,
);
return Row(
mainAxisSize: MainAxisSize.min,
crossAxisAlignment: CrossAxisAlignment.start,
children: [
// ✅ زرار التشغيل مع animation
ScaleTransition(
scale: \_playButtonScale,
child: GestureDetector(
onTap: isLoading || hasError ? null : \_togglePlay,
child: Container(
width: 35,
height: 35,
decoration: BoxDecoration(
color: Colors.white.withOpacity(0.2),
shape: BoxShape.circle,
border: Border.all(
color: Colors.white.withOpacity(0.5),
width: 1.5,
),
),
child: Center(
child: hasError
? const Icon(
Icons.error_outline,
color: Colors.red,
size: 22,
)
: isLoading
? SizedBox(
width: 10,
height: 10,
child: CircularProgressIndicator(
color: Colors.white,
strokeWidth: 2,
),
)
: AnimatedSwitcher(
duration: const Duration(milliseconds: 200),
child: Icon(
isPlaying ? Icons.pause : Icons.play_arrow,
key: ValueKey(isPlaying),
color: Colors.white,
size: 24,
),
),
),
),
),
),

        Gap(12),

        // ✅ الوسط - موجات + progress + وقت
        SizedBox(
          width: waveFormWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ Waveform + progress
              SizedBox(
                height: 35,

                child: AnimatedBuilder(
                  animation: _waveController,
                  builder: (context, _) {
                    return CustomPaint(
                      size: const Size(double.infinity, 32),
                      painter: WaveformPainter(
                        progress: _progress,
                        animValue: _waveController.value,
                        isPlaying: isPlaying,
                      ),
                    );
                  },
                ),
              ),

              Gap(5),

              // ✅ الوقت
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CustomText(
                    text: formatTime(position),
                    style: AppTextStyles.bodySmall,
                  ),
                  CustomText(
                    text: formatTime(duration),
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );

}
}
//-------------------------------------------------------
import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chattr/core/services/hive/hive_services.dart';
import 'package:chattr/features/private_chats/data/models/private_message_model.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class ImageMessageWidget extends StatefulWidget {
const ImageMessageWidget({super.key, required this.imageMessage});
final dynamic imageMessage;

@override
State<ImageMessageWidget> createState() => \_ImageMessageWidgetState();
}

class \_ImageMessageWidgetState extends State<ImageMessageWidget>
with AutomaticKeepAliveClientMixin {
// KeepAlive — يمنع Flutter من dispose الـ widget لما يخرج من الشاشة
@override
bool get wantKeepAlive => true;

String? \_localPath;
bool \_hiveLookedUp = false;
bool \_downloadStarted = false;

// ─── sync resolve — بيشتغل قبل أول frame ────────────────────────
String? \_quickResolve() {
final content = widget.imageMessage.content as String;
final modelLocalPath = widget.imageMessage.localPath as String?;

    // temp optimistic — content نفسه local path
    if (content.startsWith('/') && File(content).existsSync()) return content;

    // localPath على الـ model مباشرة
    if (modelLocalPath != null && File(modelLocalPath).existsSync()) {
      return modelLocalPath;
    }

    return null;

}

@override
void initState() {
super.initState();
\_localPath = \_quickResolve();
if (\_localPath == null) \_startAsyncResolve();
}

@override
void didUpdateWidget(ImageMessageWidget old) {
super.didUpdateWidget(old);

    // لو الـ model جاب localPath جديد — upgrade فوراً
    final newLocalPath = widget.imageMessage.localPath as String?;
    if (_localPath == null &&
        newLocalPath != null &&
        File(newLocalPath).existsSync()) {
      setState(() => _localPath = newLocalPath);
      return;
    }

    // لو الـ content اتغير (temp→URL) — أعد الـ resolve
    final oldContent = old.imageMessage.content as String;
    final newContent = widget.imageMessage.content as String;
    if (oldContent != newContent) {
      _hiveLookedUp = false;
      _downloadStarted = false;
      final quick = _quickResolve();
      if (quick != null) {
        setState(() => _localPath = quick);
      } else {
        _startAsyncResolve();
      }
    }

}

Future<void> \_startAsyncResolve() async {
final messageId = widget.imageMessage.messageId as String?;
final content = widget.imageMessage.content as String;

    // Hive lookup
    if (!_hiveLookedUp && messageId != null) {
      _hiveLookedUp = true;
      final hivePath = widget.imageMessage is PrivateMessageModel
          ? await HiveService.getPrivateMessageLocalPath(messageId)
          : await HiveService.getGroupMessageLocalPath(messageId);
      if (hivePath != null && File(hivePath).existsSync()) {
        if (mounted) setState(() => _localPath = hivePath);
        return;
      }
    }

    // download في الخلفية — الـ build عارض الـ URL في نفس الوقت
    if (!_downloadStarted && messageId != null && content.startsWith('http')) {
      _downloadStarted = true;
      unawaited(_downloadAndCache(content, messageId));
    }

}

Future<void> _downloadAndCache(String url, String messageId) async {
try {
final dir = await getApplicationDocumentsDirectory();
final raw = url.split('.').last.split('?').first;
final ext = ['jpg', 'jpeg', 'png', 'webp'].contains(raw) ? raw : 'jpg';
final path = '${dir.path}/img_$messageId.$ext';

      if (!File(path).existsSync()) {
        final res = await http.get(Uri.parse(url));
        if (res.statusCode != 200) return;
        await File(path).writeAsBytes(res.bodyBytes);
      }

      widget.imageMessage is PrivateMessageModel
          ? await HiveService.savePrivateMessageLocalPath(
              messageId: messageId,
              localPath: path,
            )
          : await HiveService.saveGroupMessageLocalPath(
              messageId: messageId,
              localPath: path,
            );

      if (mounted) setState(() => _localPath = path);
    } catch (e) {
      debugPrint('❌ ImageMessageWidget._downloadAndCache: $e');
    }

}

@override
Widget build(BuildContext context) {
super.build(context); // مطلوب مع AutomaticKeepAliveClientMixin

    // ✅ Local file — أسرع وأفضل
    if (_localPath != null) {
      return RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(_localPath!),
            fit: BoxFit.cover,
            width: double.infinity,
            gaplessPlayback: true,
            cacheWidth:
                800, // يحط الصورة في الـ image cache بـ resolution معقولة
            frameBuilder: (_, child, frame, _) =>
                frame == null ? _Placeholder() : child,
          ),
        ),
      );
    }

    final content = widget.imageMessage.content as String;

    // ✅ URL
    if (content.startsWith('http')) {
      return RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: content,
            fit: BoxFit.cover,
            width: double.infinity,
            placeholder: (_, _) => _Placeholder(),
            errorWidget: (_, _, _) => _ErrorWidget(),
          ),
        ),
      );
    }

    return _Placeholder();

}
}

// ─── ثابتة الحجم دايماً عشان الـ container ما يتغيرش ────────────
class \_Placeholder extends StatelessWidget {
@override
Widget build(BuildContext context) => const SizedBox(
height: 200,
width: double.infinity,
child: Center(
child: CupertinoActivityIndicator(color: Colors.white54, radius: 9),
),
);
}

class \_ErrorWidget extends StatelessWidget {
@override
Widget build(BuildContext context) => const SizedBox(
height: 200,
width: double.infinity,
child: Center(
child: Icon(
Icons.image_not_supported_outlined,
color: Colors.red,
size: 40,
),
),
);
}
//------------------------------------------------------------
import 'package:chattr/core/themes/app_colors.dart';
import 'package:chattr/core/themes/app_text_styles.dart';
import 'package:chattr/core/utils/extensions/responsive.dart';
import 'package:chattr/core/widgets/custom_text.dart';
import 'package:chattr/core/widgets/message/widgets/audio_message_widget.dart';
import 'package:chattr/core/widgets/message/widgets/image_message_widget.dart';
import 'package:chattr/features/group_chats/data/models/group_message_model.dart';
import 'package:chattr/features/group_chats/presentation/cubits/send_group_message_cubit/send_group_message_cubit.dart';
import 'package:chattr/features/private_chats/data/models/private_message_model.dart';
import 'package:chattr/features/private_chats/presentation/cubits/send_private_message_cubit/send_private_message_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

class MessageContent extends StatelessWidget {
const MessageContent({
super.key,
required this.isMe,
required this.message,
required this.chatId,
});

final bool isMe;
final dynamic message;
final String chatId;

///retry send failed message
void \_retryMessage(BuildContext context) {
if (message is PrivateMessageModel) {
final failedMessage = message as PrivateMessageModel;
context.read<SendPrivateMessageCubit>().retryMessage(failedMessage);
} else if (message is GroupMessageModel) {
final failedMessage = message as GroupMessageModel;
context.read<SendGroupMessageCubit>().retryMessage(failedMessage);
}
}

///retry delete failed message
void \_retryDelete(BuildContext context) {
if (message is PrivateMessageModel) {
final privateMessage = message as PrivateMessageModel;
final privateChatId = chatId;

      context.read<SendPrivateMessageCubit>().retryDelete(
        chatId: privateChatId,
        message: privateMessage,
      );
    } else if (message is GroupMessageModel) {
      final groupMessage = message as GroupMessageModel;
      final groupId = chatId;
      context.read<SendGroupMessageCubit>().retryDelete(
        groupId: groupId,
        message: groupMessage,
      );
    }

}

///retry edit message
void \_retryEdit(BuildContext context) {
if (message is PrivateMessageModel) {
final privateMessage = message as PrivateMessageModel;
final privateChatId = chatId;
final content = message.content;
context.read<SendPrivateMessageCubit>().retryEditMessage(
chatId: privateChatId,
message: privateMessage,
content: content,
);
} else if (message is GroupMessageModel) {
final groupMessage = message as GroupMessageModel;
final groupId = chatId;
context.read<SendGroupMessageCubit>().retryEditMessage(
content: message.content,
groupId: groupId,
message: groupMessage,
);
}
}

void \_retry({required dynamic status, required BuildContext context}) {
final retryActions = status is PrivateMessageStatus
? {
PrivateMessageStatus.failed: \_retryMessage,
PrivateMessageStatus.deleteFailed: \_retryDelete,
PrivateMessageStatus.editingFaild: \_retryEdit,
}
: {
GroupMessageStatus.failed: \_retryMessage,
GroupMessageStatus.deleteFailed: \_retryDelete,
GroupMessageStatus.editingFaild: \_retryEdit,
};
retryActions[status]?.call(context);
}

@override
Widget build(BuildContext context) {
final status = message is PrivateMessageModel
? (message as PrivateMessageModel).privateMessageStatus
: (message as GroupMessageModel).status;

    return message is PrivateMessageModel
        ?
          //?private message content
          Row(
            children: [
              if ((isMe) &&
                  (status == PrivateMessageStatus.failed ||
                      status == PrivateMessageStatus.deleteFailed ||
                      status == PrivateMessageStatus.editingFaild)) ...[
                GestureDetector(
                  onTap: () => _retry(status: status, context: context),
                  child: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.refresh, size: 16, color: Colors.white),
                  ),
                ),
                Gap(5),
              ],
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(10),
                        topRight: Radius.circular(10),
                        bottomRight: isMe
                            ? Radius.circular(10)
                            : Radius.circular(0),
                        bottomLeft: isMe
                            ? Radius.circular(0)
                            : Radius.circular(10),
                      ),
                      color: message.isDeleted == true
                          ? AppColors.primary.withOpacity(0.6)
                          : AppColors.primary,
                    ),
                    constraints: BoxConstraints(
                      maxWidth: context.screenWidth * 0.5,
                    ),
                    child: Column(
                      crossAxisAlignment: isMe
                          ? CrossAxisAlignment.start
                          : CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        message.isDeleted == true
                            ? CustomText(
                                align: TextAlign.start,

                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontSize: message.isDeleted == true ? 12 : 14,
                                ),

                                text: " message has been deleted ⊘",
                              )
                            :
                              ///privateMessage
                              message.privateMessageType ==
                                  PrivateMessageType.voice
                            ? AudioMessageWidget(audioMessage: message)
                            : message.privateMessageType ==
                                  PrivateMessageType.image
                            ? ImageMessageWidget(imageMessage: message)
                            : CustomText(
                                align: TextAlign.start,
                                style: AppTextStyles.headlineSmall.copyWith(
                                  fontSize: message.isDeleted == true ? 12 : 14,
                                  color: message.isDeleted == true
                                      ? Colors.grey
                                      : Colors.white,
                                ),
                                text: message.content,
                                maxLines: 1024,
                              ),
                        Gap(isMe ? 10 : 20),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            !isMe
                                ? SizedBox.shrink()
                                : message.isDeleted == true
                                ? SizedBox.shrink()
                                : _buildStatusIndicator(status),
                            Gap(50),
                          ],
                        ),
                      ],
                    ),
                  ),

                  Positioned(
                    bottom: 8,
                    right: !isMe ? null : 5,
                    left: isMe ? null : 5,
                    child: CustomText(
                      style: AppTextStyles.bodySmall.copyWith(
                        color: message.isDeleted == true
                            ? Colors.grey
                            : Colors.white,
                      ),
                      text: (DateFormat(
                        'jm',
                      ).format(DateTime.parse((message.createdAt).toString()))),
                    ),
                  ),
                ],
              ),
            ],
          )
        :
          //?group message content
          Row(
            children: [
              if ((isMe) &&
                  (status == GroupMessageStatus.failed ||
                      status == GroupMessageStatus.deleteFailed ||
                      status == GroupMessageStatus.editingFaild)) ...[
                GestureDetector(
                  onTap: () => _retry(status: status, context: context),
                  child: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.refresh, size: 16, color: Colors.white),
                  ),
                ),
                Gap(5),
              ],
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(10),
                        topRight: Radius.circular(10),
                        bottomRight: isMe
                            ? Radius.circular(10)
                            : Radius.circular(0),
                        bottomLeft: isMe
                            ? Radius.circular(0)
                            : Radius.circular(10),
                      ),
                      color: message.isDeleted == true
                          ? AppColors.primary.withOpacity(0.6)
                          : AppColors.primary,
                    ),
                    constraints: BoxConstraints(
                      maxWidth: context.screenWidth * 0.5,
                    ),
                    child: Column(
                      crossAxisAlignment: isMe
                          ? CrossAxisAlignment.start
                          : CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        message.isDeleted == true
                            ? CustomText(
                                align: TextAlign.start,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontSize: message.isDeleted == true ? 12 : 14,
                                ),
                                text: " message has been deleted ⊘",
                              )
                            : message.messageType == GroupMessageType.voice
                            ? AudioMessageWidget(audioMessage: message)
                            : message.messageType == GroupMessageType.image
                            ? ImageMessageWidget(imageMessage: message)
                            : CustomText(
                                align: TextAlign.start,
                                style: AppTextStyles.headlineSmall.copyWith(
                                  fontSize: message.isDeleted == true ? 12 : 14,
                                  color: message.isDeleted == true
                                      ? Colors.grey
                                      : Colors.white,
                                ),
                                text: message.content,
                                maxLines: 1024,
                              ),
                        Gap(isMe ? 10 : 20),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            !isMe
                                ? SizedBox.shrink()
                                : message.isDeleted == true
                                ? SizedBox.shrink()
                                : _buildStatusIndicator(status),
                            Gap(50),
                          ],
                        ),
                      ],
                    ),
                  ),

                  Positioned(
                    bottom: 8,
                    right: !isMe ? null : 5,
                    left: isMe ? null : 5,
                    child: CustomText(
                      style: AppTextStyles.bodySmall.copyWith(
                        color: message.isDeleted == true
                            ? Colors.grey
                            : Colors.white,
                      ),
                      text: (DateFormat(
                        'jm',
                      ).format(DateTime.parse((message.createdAt).toString()))),
                    ),
                  ),
                ],
              ),
            ],
          );

}

//..................................................................
Widget \_buildStatusIndicator(dynamic status) {
if (status is PrivateMessageStatus) {
switch (status) {
case PrivateMessageStatus.sending:
return Icon(
Icons.access_time_rounded,
size: 16,
color: Colors.white70,
);

        case PrivateMessageStatus.sent:
          return Icon(
            Icons.check_circle_outline_rounded,
            size: 16,
            color: Colors.white70,
          );

        case PrivateMessageStatus.failed:
          return Icon(Icons.error_outline, size: 16, color: Colors.red);

        case PrivateMessageStatus.deleting:
          return Icon(
            Icons.access_time_rounded,
            size: 16,
            color: Colors.white70,
          );

        case PrivateMessageStatus.deleteFailed:
          return Icon(Icons.error_outline, size: 16, color: Colors.red);

        case PrivateMessageStatus.editing:
          return Icon(
            Icons.access_time_rounded,
            size: 16,
            color: Colors.white70,
          );

        case PrivateMessageStatus.editingFaild:
          return Icon(Icons.error_outline, size: 16, color: Colors.red);
      }
    } else {
      switch (status) {
        case GroupMessageStatus.sending:
          return Icon(
            Icons.access_time_rounded,
            size: 16,
            color: Colors.white70,
          );

        case GroupMessageStatus.sent:
          return Icon(
            Icons.check_circle_outline_rounded,
            size: 16,
            color: Colors.white70,
          );

        case GroupMessageStatus.failed:
          return Icon(Icons.error_outline, size: 16, color: Colors.red);

        case GroupMessageStatus.deleting:
          return Icon(
            Icons.access_time_rounded,
            size: 16,
            color: Colors.white70,
          );

        case GroupMessageStatus.deleteFailed:
          return Icon(Icons.error_outline, size: 16, color: Colors.red);

        case GroupMessageStatus.editing:
          return Icon(
            Icons.access_time_rounded,
            size: 16,
            color: Colors.white70,
          );

        case GroupMessageStatus.editingFaild:
          return Icon(Icons.error_outline, size: 16, color: Colors.red);
      }
    }
    return SizedBox.shrink();

}
}
//---------------------------------------------------------------
import 'package:chattr/core/helpers/snack_bar.dart';
import 'package:chattr/core/themes/app_text_styles.dart';
import 'package:chattr/core/utils/extensions/responsive.dart';
import 'package:chattr/core/widgets/custom_text.dart';
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:chattr/features/group_chats/presentation/cubits/send_group_message_cubit/send_group_message_cubit.dart';
import 'package:chattr/features/private_chats/data/models/private_chat_model.dart';
import 'package:chattr/features/private_chats/presentation/cubits/send_private_message_cubit/send_private_message_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SendWelcomMessage extends StatelessWidget {
const SendWelcomMessage({
super.key,
required this.chatData,
required this.currentUser,
});

final dynamic chatData;
final UserModel currentUser;

@override
Widget build(BuildContext context) {
return chatData is PrivateChatModel
?
/// chat message
BlocListener<SendPrivateMessageCubit, SendPrivateMessageState>(
listener: (context, state) {
if (state is SendPrivateMessageFailure) {
CustomSnackBar.error(context, state.errorMessage);
}
},
child: Center(
child:
BlocBuilder<SendPrivateMessageCubit, SendPrivateMessageState>(
buildWhen: (prev, curr) =>
curr is SendPrivateMessageLoading ||
prev is SendPrivateMessageLoading,
builder: (context, state) {
final isLoading = state is SendPrivateMessageLoading;
return InkWell(
onTap: isLoading
? null
: () {
context
.read<SendPrivateMessageCubit>()
.sendTextMessage(
message: "Hi! Let’s start talking 👋",
chatId: chatData.chatId,
sender: currentUser,
senderId: currentUser.id!,
);
},
child: Card(
child: Padding(
padding: EdgeInsets.symmetric(
horizontal: context.screenWidth _ 0.1,
vertical: 25,
),
child: Column(
mainAxisSize: MainAxisSize.min,
mainAxisAlignment: MainAxisAlignment.center,
children: [
CustomText(
text: "👋",
style: AppTextStyles.displayLarge,
),
CustomText(
text: " Say Hi! Let’s start talking",
style: AppTextStyles.bodySmall,
),
],
),
),
),
);
},
),
),
)
:
//group chat
BlocListener<SendGroupMessageCubit, SendGroupMessageState>(
listener: (context, state) {
if (state is SendGroupMessageFailure) {
CustomSnackBar.error(context, state.errorMessage);
}
},
child: Center(
child: BlocBuilder<SendGroupMessageCubit, SendGroupMessageState>(
buildWhen: (prev, curr) =>
curr is SendGroupMessageLoading ||
prev is SendGroupMessageLoading,
builder: (context, state) {
final isLoading = state is SendGroupMessageLoading;
return InkWell(
onTap: isLoading
? null
: () {
context
.read<SendGroupMessageCubit>()
.sendTextMessage(
message: "Hi! Let’s start talking 👋",
groupId: chatData.id,
sender: currentUser,
senderId: currentUser.id!,
);
},
child: Card(
child: Padding(
padding: EdgeInsets.symmetric(
horizontal: context.screenWidth _ 0.1,
vertical: 25,
),
child: Column(
mainAxisSize: MainAxisSize.min,
mainAxisAlignment: MainAxisAlignment.center,
children: [
CustomText(
text: "👋",
style: AppTextStyles.displayLarge,
),
CustomText(
text: " Say Hi! Let’s start talking",
style: AppTextStyles.bodySmall,
),
],
),
),
),
);
},
),
),
);
}
}
//-------------------------------------------------------------------------
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chattr/core/cache/users_cache.dart';
import 'package:chattr/core/cubits/select_messages/select_messages_cubit.dart';
import 'package:chattr/core/routing/router_models.dart';
import 'package:chattr/core/routing/routes.dart';
import 'package:chattr/core/themes/app_text_styles.dart';
import 'package:chattr/core/widgets/custom_text.dart';
import 'package:chattr/core/widgets/message/widgets/message_content.dart';
import 'package:chattr/core/widgets/message/widgets/send_welcom_message.dart';
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:chattr/features/group_chats/data/models/group_message_model.dart';
import 'package:chattr/features/group_chats/presentation/cubits/fetch_group_messages_cubit/fetch_group_messages_cubit.dart';
import 'package:chattr/features/private_chats/data/models/private_chat_model.dart';
import 'package:chattr/features/private_chats/data/models/private_message_model.dart';
import 'package:chattr/features/private_chats/presentation/cubits/fetch_private_messages_cubit/fetch_private_messages_cubit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ChatMessagesList extends StatelessWidget {
  const ChatMessagesList({
    super.key,
    this.scrollController,
    required this.chatData,
    required this.currentUser,
  });

  final dynamic chatData;
  final UserModel currentUser;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final String myId = currentUser.id!;

    return chatData is PrivateChatModel
        ?
          //private chat
          BlocBuilder<FetchPrivateMessagesCubit, FetchPrivateMessagesState>(
            buildWhen: (_, curr) {
              if (curr is FetchPrivateMessagesLoading) return false;
              if (curr is! FetchPrivateMessagesSuccess) return false;
              return curr.chatId == chatData.chatId;
            },
            builder: (context, state) {
              if (state is FetchPrivateMessagesfailure) {
                return SliverFillRemaining(
                  child: Center(
                    child: CustomText(
                      text: state.errMessage,
                      style: AppTextStyles.bodyMedium,
                    ),
                  ),
                );
              }
              if (state is! FetchPrivateMessagesSuccess ||
                  state.chatId != chatData.chatId) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final messages = state.messages;

              if (messages.isEmpty) {
                return SliverFillRemaining(
                  child: SendWelcomMessage(
                    chatData: chatData,
                    currentUser: currentUser,
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  addAutomaticKeepAlives:
                      true, // يحتفظ بالـ widgets اللي فيها KeepAlive
                  addRepaintBoundaries: true,
                  childCount: messages.length,
                  (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == myId;
                    final isImage =
                        msg.privateMessageType == PrivateMessageType.image;

                    // Key ثابت — يمنع Flutter من إعادة بناء الـ widget لما الـ list تتغير
                    final stableKey = ValueKey(msg.messageId ?? msg.tempId);

                    return BlocBuilder<
                      SelectMessagesCubit,
                      SelectMessagesState
                    >(
                      builder: (context, selState) {
                        final cubit = context.read<SelectMessagesCubit>();
                        final isSelected = cubit.isSelected(msg);

                        return AnimatedContainer(
                          key: stableKey,
                          duration: const Duration(milliseconds: 150),
                          margin: EdgeInsets.only(bottom: isSelected ? 2 : 5),
                          padding: isSelected
                              ? const EdgeInsets.symmetric(vertical: 5)
                              : EdgeInsets.zero,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            color: isSelected
                                ? Colors.white.withOpacity(0.05)
                                : Colors.transparent,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: GestureDetector(
                              onTap: () {
                                if (msg.isDeleted) return;
                                if (cubit.selectedMessages.isNotEmpty &&
                                    msg.senderId == myId) {
                                  cubit.selectMessage(msg);
                                  return;
                                }
                                if (isImage &&
                                    msg.privateMessageStatus !=
                                        PrivateMessageStatus.sending) {
                                  final sender =
                                      msg.sender ??
                                      UsersCache.getUser(msg.senderId);
                                  context.push(
                                    Routes.viewImage,
                                    extra: ViewImageParams(
                                      imageUrl: msg.localPath ?? msg.content,
                                      senderName: sender?.name ?? 'Unknown',
                                      messageData: msg,
                                    ),
                                  );
                                }
                              },
                              onLongPress: () {
                                if (msg.isDeleted) return;
                                if (cubit.selectedMessages.isEmpty &&
                                    msg.senderId == myId) {
                                  cubit.selectMessage(msg);
                                }
                              },
                              child:
                                  //message bubble
                                  Row(
                                    mainAxisAlignment: isMe
                                        ? MainAxisAlignment.start
                                        : MainAxisAlignment.end,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      MessageContent(
                                        isMe: isMe,
                                        message: msg,
                                        chatId: chatData.chatId,
                                      ),
                                    ],
                                  ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              );
            },
          )
        : //group chat
          BlocBuilder<FetchGroupMessagesCubit, FetchGroupMessagesState>(
            buildWhen: (_, curr) {
              if (curr is FetchGroupMessagesLoading) return false;
              if (curr is! FetchGroupMessagesSuccess) return false;
              return curr.groupId == chatData.id;
            },
            builder: (context, state) {
              if (state is FetchGroupMessagesFailure) {
                return SliverFillRemaining(
                  child: Center(
                    child: CustomText(
                      text: state.errorMessage,
                      style: AppTextStyles.bodyMedium,
                    ),
                  ),
                );
              }
              if (state is! FetchGroupMessagesSuccess ||
                  state.groupId != chatData.id) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final messages = state.messages;

              if (messages.isEmpty) {
                return SliverFillRemaining(
                  child: SendWelcomMessage(
                    chatData: chatData,
                    currentUser: currentUser,
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  addAutomaticKeepAlives:
                      true, // يحتفظ بالـ widgets اللي فيها KeepAlive
                  addRepaintBoundaries: true,
                  childCount: messages.length,
                  (context, index) {
                    GroupMessageModel msg;
                    UserModel? sender;
                    msg = messages[index];
                    if (msg.sender == null) {
                      sender = UsersCache.getUser(msg.senderId);
                      msg = msg.copyWith(sender: sender);
                    } else {
                      sender = msg.sender;
                    }

                    final isMe = msg.senderId == myId;
                    final isImage = msg.messageType == GroupMessageType.image;

                    // Key ثابت — يمنع Flutter من إعادة بناء الـ widget لما الـ list تتغير
                    final stableKey = ValueKey(msg.messageId ?? msg.tempId);

                    return BlocBuilder<
                      SelectMessagesCubit,
                      SelectMessagesState
                    >(
                      builder: (context, selState) {
                        final cubit = context.read<SelectMessagesCubit>();
                        final isSelected = cubit.isSelected(msg);

                        return AnimatedContainer(
                          key: stableKey,
                          duration: const Duration(milliseconds: 150),
                          margin: EdgeInsets.only(bottom: isSelected ? 2 : 5),
                          padding: isSelected
                              ? const EdgeInsets.symmetric(vertical: 5)
                              : EdgeInsets.zero,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            color: isSelected
                                ? Colors.white.withOpacity(0.05)
                                : Colors.transparent,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: GestureDetector(
                              onTap: () {
                                if (msg.isDeleted) return;
                                if (cubit.selectedMessages.isNotEmpty &&
                                    msg.senderId == myId) {
                                  cubit.selectMessage(msg);
                                  return;
                                }
                                if (isImage &&
                                    msg.status != GroupMessageStatus.sending) {
                                  context.push(
                                    Routes.viewImage,
                                    extra: ViewImageParams(
                                      imageUrl: msg.localPath ?? msg.content,
                                      senderName: sender?.name ?? 'Unknown',
                                      messageData: msg,
                                    ),
                                  );
                                }
                              },
                              onLongPress: () {
                                if (msg.isDeleted) return;
                                if (cubit.selectedMessages.isEmpty &&
                                    msg.senderId == myId) {
                                  cubit.selectMessage(msg);
                                }
                              },
                              child: Row(
                                mainAxisAlignment: isMe
                                    ? MainAxisAlignment.start
                                    : MainAxisAlignment.end,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  MessageContent(
                                    isMe: isMe,
                                    message: msg,
                                    chatId: chatData.id,
                                  ),
                                  if (!isMe) ...[
                                    const Gap(5),
                                    _SenderImage(sender: sender),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              );
            },
          );
  }
}

class _SenderImage extends StatelessWidget {
  const _SenderImage({required this.sender});

  final UserModel? sender;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 10,
      child: ClipOval(
        child: CachedNetworkImage(
          height: 30,
          width: 30,
          fit: BoxFit.fill,
          imageUrl:
              sender?.image ??
              'https://static.thenounproject.com/png/1856610-200.png',
          placeholder: (context, url) =>
              CupertinoActivityIndicator(color: Colors.white54, radius: 9),
          errorWidget: (context, url, error) => const Icon(
            Icons.image_not_supported_outlined,
            color: Colors.red,
            size: 40,
          ),
        ),
      ),
    );
  }
}

//------------------------------------------------------------
import 'package:chattr/core/cubits/pick_image/pick_image_cubit.dart';
import 'package:chattr/core/helpers/snack_bar.dart';
import 'package:chattr/core/themes/app_colors.dart';
import 'package:chattr/core/utils/extensions/responsive.dart';
import 'package:chattr/core/widgets/audio/ui/audio_button.dart';
import 'package:chattr/core/widgets/custom_text_field.dart';
import 'package:chattr/core/widgets/image/widgets/image_source_bottom.dart';
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:chattr/features/group_chats/presentation/cubits/send_group_message_cubit/send_group_message_cubit.dart';
import 'package:chattr/features/private_chats/data/models/private_chat_model.dart';
import 'package:chattr/features/private_chats/presentation/cubits/send_private_message_cubit/send_private_message_cubit.dart';
import 'package:chattr/features/private_chats/presentation/views/private_chat_body_view/widgets/image_view_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class SendMessageField extends StatefulWidget {
const SendMessageField({
super.key,
required this.chatData,
required this.curruntUser,
});
final dynamic chatData;
final UserModel curruntUser;
@override
State<SendMessageField> createState() => \_SendMessageFieldState();
}

class \_SendMessageFieldState extends State<SendMessageField> {
late TextEditingController messageController;

@override
void initState() {
messageController = TextEditingController();
super.initState();
}

@override
void dispose() {
messageController.dispose();
super.dispose();
}

@override
Widget build(BuildContext context) {
return
widget.chatData is PrivateChatModel
?
//?private chat
Padding(
padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
child: MultiBlocListener(
listeners: [
BlocListener<SendPrivateMessageCubit, SendPrivateMessageState>(
listener: (context, state) {
if (state is SendPrivateMessageSuccess) {
if (context.read<PickImageCubit>().imageFile != null) {
context.read<PickImageCubit>().deleteImage();
} else {
messageController.clear();
}
}
},
),

                ///group
                BlocListener<PickImageCubit, PickImageState>(
                  listener: (context, state) {
                    if (state is PickImageFailure) {
                      CustomSnackBar.error(context, state.errorMessage);
                    }
                  },
                ),
              ],
              child: Column(
                children: [
                  ImageViewContainer(),

                  SizedBox(
                    width: context.screenWidth,
                    child: Row(
                      children: [
                        Expanded(
                          child:  CustomTextField(
                            keyboardType: TextInputType.multiline,
                            minLines: 1,
                            maxLines: 2,
                            controller: messageController,
                            hint: "message",
                            validation: (v) {
                              return null;
                            },
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.emoji_emotions),
                                Gap(8),
                                GestureDetector(
                                  onTap: () => ImageSourceBottomSheet.show(
                                    context,
                                    cropForProfile: false,
                                  ),
                                  child: Icon(Icons.add_photo_alternate),
                                ),
                                Gap(10),
                              ],
                            ),
                          ),
                        ),
                        Gap(20),

                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: messageController,
                          builder: (context, value, _) {
                            final isEmpty = value.text.trim().isEmpty;

                            return BlocBuilder<PickImageCubit, PickImageState>(
                              builder: (context, state) {
                                final imagePath = context
                                    .read<PickImageCubit>()
                                    .imageFile;
                                return
                                /// friend chat
                                BlocBuilder<
                                  SendPrivateMessageCubit,
                                  SendPrivateMessageState
                                >(
                                  buildWhen: (prev, curr) =>
                                      prev is SendPrivateMessageLoading ||
                                      curr is SendPrivateMessageLoading,
                                  builder: (context, state) {
                                    final isLoading =
                                        state is SendPrivateMessageLoading;
                                    return InkWell(
                                      onTap:
                                          (!isEmpty || imagePath != null) &&
                                              !isLoading
                                          ? () {
                                              if (imagePath != null) {
                                                context
                                                    .read<
                                                      SendPrivateMessageCubit
                                                    >()
                                                    .sendImage(
                                                      imageFile: imagePath,
                                                      chatId: widget
                                                          .chatData
                                                          .chatId,
                                                      sender:
                                                          widget.curruntUser,
                                                      senderId: widget
                                                          .curruntUser
                                                          .id!,
                                                    );
                                              } else {
                                                final message =
                                                    messageController.text
                                                        .trim();
                                                messageController.clear();
                                                context
                                                    .read<
                                                      SendPrivateMessageCubit
                                                    >()
                                                    .sendTextMessage(
                                                      message: message,
                                                      chatId: widget
                                                          .chatData
                                                          .chatId,
                                                      sender:
                                                          widget.curruntUser,
                                                      senderId: widget
                                                          .curruntUser
                                                          .id!,
                                                    );
                                              }
                                            }
                                          : null,
                                      child: isEmpty && imagePath == null
                                          ? AudioRecordButton(
                                              sender: widget.curruntUser,
                                              chatId: widget.chatData.chatId,
                                              senderId: widget.curruntUser.id!,

                                              isGroup: false,
                                            )
                                          : SizedBox(
                                              height: 50,
                                              width: 40,
                                              child: Icon(
                                                Icons.send_sharp,
                                                color: AppColors.primary,
                                                size: 27,
                                              ),
                                            ),
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),

                        Gap(10),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
        :
          //?group chat
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: MultiBlocListener(
              listeners: [
                BlocListener<SendGroupMessageCubit, SendGroupMessageState>(
                  listener: (context, state) {
                    if (state is SendGroupMessageSuccess) {
                      if (context.read<PickImageCubit>().imageFile != null) {
                        context.read<PickImageCubit>().deleteImage();
                      } else {
                        messageController.clear();
                      }
                    }
                  },
                ),

                BlocListener<PickImageCubit, PickImageState>(
                  listener: (context, state) {
                    if (state is PickImageFailure) {
                      CustomSnackBar.error(context, state.errorMessage);
                    }
                  },
                ),
              ],
              child: Column(
                children: [
                  ImageViewContainer(),

                  SizedBox(
                    width: context.screenWidth,
                    child: Row(
                      children: [
                        Expanded(
                          child:  CustomTextField(
                            keyboardType: TextInputType.multiline,
                            minLines: 1,
                            maxLines: 2,
                            controller: messageController,
                            hint: "message",
                            validation: (v) {
                              return null;
                            },
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.emoji_emotions),
                                Gap(8),
                                GestureDetector(
                                  onTap: () => ImageSourceBottomSheet.show(
                                    context,
                                    cropForProfile: false,
                                  ),
                                  child: Icon(Icons.add_photo_alternate),
                                ),
                                Gap(10),
                              ],
                            ),
                          ),
                        ),
                        Gap(20),

                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: messageController,
                          builder: (context, value, _) {
                            final isEmpty = value.text.trim().isEmpty;

                            return BlocBuilder<PickImageCubit, PickImageState>(
                              builder: (context, state) {
                                final imagePath = context
                                    .read<PickImageCubit>()
                                    .imageFile;
                                return
                                /// friend chat
                                BlocBuilder<
                                  SendGroupMessageCubit,
                                  SendGroupMessageState
                                >(
                                  buildWhen: (prev, curr) =>
                                      prev is SendGroupMessageLoading ||
                                      curr is SendGroupMessageLoading,
                                  builder: (context, state) {
                                    final isLoading =
                                        state is SendGroupMessageLoading;
                                    return InkWell(
                                      onTap:
                                          (!isEmpty || imagePath != null) &&
                                              !isLoading
                                          ? () {
                                              if (imagePath != null) {
                                                context
                                                    .read<
                                                      SendGroupMessageCubit
                                                    >()
                                                    .sendImage(
                                                      imageFile: imagePath,
                                                      groupId:
                                                          widget.chatData.id,
                                                      sender:
                                                          widget.curruntUser,
                                                      senderId: widget
                                                          .curruntUser
                                                          .id!,
                                                    );
                                              } else {
                                                final message =
                                                    messageController.text
                                                        .trim();
                                                messageController.clear();
                                                context
                                                    .read<
                                                      SendGroupMessageCubit
                                                    >()
                                                    .sendTextMessage(
                                                      message: message,
                                                      groupId:
                                                          widget.chatData.id,
                                                      sender:
                                                          widget.curruntUser,
                                                      senderId: widget
                                                          .curruntUser
                                                          .id!,
                                                    );
                                              }
                                            }
                                          : null,
                                      child: isEmpty && imagePath == null
                                          ? AudioRecordButton(
                                              sender: widget.curruntUser,
                                              chatId: widget.chatData.id,
                                              senderId: widget.curruntUser.id!,

                                              isGroup: true,
                                            )
                                          : SizedBox(
                                              height: 50,
                                              width: 40,
                                              child: Icon(
                                                Icons.send_sharp,
                                                color: AppColors.primary,
                                                size: 27,
                                              ),
                                            ),
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),

                        Gap(10),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );

}
}
//--------------------------------------------------
import 'package:chattr/core/themes/app_colors.dart';
import 'package:chattr/core/themes/app_text_styles.dart';
import 'package:chattr/core/widgets/custom_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
const CustomAppBar({
super.key,
required this.title,
this.actions,
this.leading,
this.titleItems,
});

final String title;
final List<Widget>? actions;
final Widget? leading;
final List<Widget>? titleItems;

@override
Widget build(BuildContext context) {
return AppBar(
backgroundColor: AppColors.surface,
systemOverlayStyle: SystemUiOverlayStyle.light,
elevation: 0,
scrolledUnderElevation: 0,
automaticallyImplyLeading: false,
leading: leading,
actions:
actions ??
[Icon(Icons.more_horiz_rounded, color: Colors.grey), Gap(15)],
title: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
CustomText(text: title, style: AppTextStyles.headlineSmall),
...(titleItems ?? []),
],
),
);
}

@override
Size get preferredSize => Size.fromHeight(kToolbarHeight + 5);
}
//---------------------------------------------------------------
import 'package:chattr/core/themes/app_colors.dart';
import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
const CustomButton({
super.key,
required this.raduis,
this.onPressed,
this.padding,
required this.child,
this.color,
this.borderSide,
this.elevetion,
this.borderRadiusGeometry,
});
final void Function()? onPressed;

final EdgeInsetsGeometry? padding;
final Widget child;
final double raduis;
final Color? color;
final BorderSide? borderSide;
final double? elevetion;
final BorderRadiusGeometry? borderRadiusGeometry;

@override
Widget build(BuildContext context) {
return ElevatedButton(
onPressed: onPressed,
style: ButtonStyle(
elevation: WidgetStateProperty.all(elevetion),

        backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.disabled)) {
            return color ?? AppColors.primary;
          }
          return color ?? AppColors.primary;
        }),

        padding: WidgetStateProperty.all(
          padding ?? EdgeInsets.symmetric(vertical: 12),
        ),

        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: borderRadiusGeometry ?? BorderRadius.circular(raduis),
            side: borderSide ?? BorderSide.none,
          ),
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: WidgetStateProperty.all(const Size(0, 0)),
      ),
      child: child,
    );

}
}
//---------------------------------------------------
import 'package:chattr/core/themes/app_colors.dart';
import 'package:chattr/core/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

class CustomTextField extends StatefulWidget {
const CustomTextField({
super.key,
required this.hint,
this.secure,
this.keyboardType,
this.controller,
this.validation,
this.suffixIcon,
this.prefixIcon,
this.onChange,
this.color,
this.textStyle,
this.borderColor,
this.cursorColor,
this.maxLines,
this.minLines,
});

final bool? secure;
final String hint;
final TextInputType? keyboardType;
final TextEditingController? controller;
final String? Function(String?)? validation;
final Widget? suffixIcon;
final Widget? prefixIcon;
final void Function(String)? onChange;
final Color? color;
final TextStyle? textStyle;
final Color? borderColor;
final Color? cursorColor;
final int? maxLines;
final int? minLines;

@override
State<CustomTextField> createState() => \_CustomTextFieldState();
}

class \_CustomTextFieldState extends State<CustomTextField> {
late TextDirection \_currentDirection;
// ---------------- TEXT DIRECTION ----------------
TextDirection \_detectDirection(String text) {
if (text.trim().isEmpty) return TextDirection.ltr;

    return Bidi.detectRtlDirectionality(text)
        ? TextDirection.rtl
        : TextDirection.ltr;

}

// ---------------- ON CHANGE HANDLER ----------------
void \_handleChange(String value) {
final newDirection = \_detectDirection(value);

    if (newDirection != _currentDirection) {
      setState(() {
        _currentDirection = newDirection;
      });
    }

    widget.onChange?.call(value);

}

@override
void initState() {
super.initState();
\_currentDirection = \_detectDirection(widget.controller?.text ?? '');
}

InputDecoration \_buildDecoration() {
return InputDecoration(
hintText: widget.hint,
hintStyle: widget.textStyle,
suffixIcon: widget.suffixIcon,
prefixIcon: widget.prefixIcon,
filled: true,
fillColor: widget.color ?? AppColors.surface,
contentPadding: const EdgeInsets.fromLTRB(10, 5, 5, 5),
enabledBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(20),
borderSide: BorderSide(color: widget.borderColor ?? AppColors.border),
),
focusedBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(20),
borderSide: BorderSide(
color: widget.borderColor ?? AppColors.inputBorder,
),
),
errorBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(20),
borderSide: const BorderSide(color: AppColors.error, width: 1.5),
),
focusedErrorBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(20),
borderSide: const BorderSide(color: AppColors.error, width: 1.5),
),
errorStyle: const TextStyle(
color: AppColors.error,
fontWeight: FontWeight.bold,
fontSize: 12,
),
prefixIconColor: Colors.grey,
suffixIconColor: Colors.grey,
);
}

@override
Widget build(BuildContext context) {
return Column(
children: [
TextFormField(
controller: widget.controller,
minLines: widget.minLines,
maxLines: widget.secure == true ? 1 : widget.maxLines,
obscureText: widget.secure ?? false,
keyboardType: widget.keyboardType ?? TextInputType.text,
style:
widget.textStyle ??
AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
textDirection: _currentDirection,
cursorColor: widget.cursorColor ?? Colors.grey,
cursorHeight: 15,
cursorOpacityAnimates: true,
autovalidateMode: AutovalidateMode.onUserInteraction,
validator: widget.validation,
onChanged: _handleChange,
decoration: _buildDecoration(),
),
],
);
}
}
//-----------------------------------------------------------
import 'package:auto_size_text/auto_size_text.dart';
import 'package:chattr/core/themes/app_text_styles.dart';
import 'package:flutter/material.dart';

class CustomText extends StatelessWidget {
const CustomText({
super.key,
required this.text,
this.style,
this.align,
this.maxLines,
this.minFontSize,
});

final String text;
final TextStyle? style;
final TextAlign? align;
final int? maxLines;
final double? minFontSize;

@override
Widget build(BuildContext context) {
return AutoSizeText(
text,
textAlign: align ?? TextAlign.start,
style: style ?? AppTextStyles.bodyMedium,
maxLines: maxLines ?? 1,
minFontSize: minFontSize ?? 10,
overflow: TextOverflow.ellipsis,
);
}
}
//----------------------------------------------------------------------------
import 'package:chattr/core/services/hive/hive_type_ids.dart';
import 'package:hive/hive.dart';

part 'user_model.g.dart';

@HiveType(typeId: HiveTypeIds.users) // رقم فريد
class UserModel {
@HiveField(0)
final String? id;

@HiveField(1)
final String? name;

@HiveField(2)
final String? email;

@HiveField(3)
final String? image;

@HiveField(4)
final String? about;

@HiveField(5)
final DateTime? createdAt;

@HiveField(6)
final DateTime? lastSeen;

@HiveField(7)
final List<String>? myContacts;

@HiveField(8)
final bool? isOnLine;

UserModel({
required this.id,
this.name,

    this.email,
    this.image,
    this.about,
    this.createdAt,
    this.myContacts,
    this.lastSeen,
    this.isOnLine,

});

factory UserModel.fromJson(Map<String, dynamic> json) {
return UserModel(
id: json['id'],
name: json['name'],
email: json['email'],
image: json['image'],
about: json['about'],
createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
lastSeen: DateTime.tryParse(json['last_seen'] ?? '') ?? DateTime.now(),
myContacts: (json['my_contacts'] as List<dynamic>?)
?.map((e) => e.toString())
.toList(), // 🔹 هنا التحويل من dynamic لـ String,

      isOnLine: json['is_online'],
    );

}

Map<String, dynamic> toJson() {
return {
'id': id,
'name': name,
'email': email,
'image': image,
'about': about,
'created_at': createdAt?.toIso8601String(),
'last_seen': lastSeen?.toIso8601String(),
'is_online': isOnLine,
'my_contacts': myContacts ?? [],
};
}

UserModel copyWith({
String? id,
String? name,
String? email,
String? image,
String? about,
DateTime? createdAt,
DateTime? lastSeen,
List<String>? myContacts,
bool? isOnLine,
}) {
return UserModel(
id: id ?? this.id,
name: name ?? this.name,
email: email ?? this.email,
image: image ?? this.image,
about: about ?? this.about,
createdAt: createdAt ?? this.createdAt,
lastSeen: lastSeen ?? this.lastSeen,
myContacts: myContacts ?? this.myContacts,
isOnLine: isOnLine ?? this.isOnLine,
);
}
}
//--------------------------------------------------------------
import 'dart:io';

import 'package:chattr/core/services/hive/hive_services.dart';
import 'package:chattr/core/services/supabase/supabase_auth_services.dart';
import 'package:chattr/core/services/supabase/supabase_crud_services.dart';
import 'package:chattr/core/services/supabase/supabase_error.dart';
import 'package:chattr/core/services/supabase/supabase_storage.dart';
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:chattr/features/auth/data/repos/auth_repo.dart';
import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepoImpl implements AuthRepo {
final AuthService \_authService;
final SupabaseCrudServices \_crud;
final SupabaseStorage \_storage;

AuthRepoImpl(this.\_authService, this.\_crud, this.\_storage);

@override
Future<Either<SupabaseError, User>> login({
required String email,
required String password,
}) async {
try {
final respons = await \_authService.logIn(email, password);
final userId = \_authService.currentUser!.id;
final response = await \_crud.getById(
table: "messenger_users",
id: userId,
);
final user = UserModel.fromJson(response);

      await HiveService.saveUser(user);
      return Right(respons);
    } catch (e) {
      return Left(SupabaseError(message: '$e'));
    }

}

@override
Future<Either<SupabaseError, User>> signup({
required String name,
required String email,
required String password,
required File image,
}) async {
try {
final respons = await \_authService.signUp(email, password);
final myUuid = \_authService.currentUser!.id;
final path = await \_storage.uploadImage(
file: image,
storageFile: 'users_image',
);
final imagePath = \_storage.getFileUrl(
path: path,
storageFile: 'users_image',
);

      ///user data as user model
      final UserModel data = UserModel(
        id: myUuid,
        name: name,
        email: email,
        image: imagePath,
        about: "",
        createdAt: DateTime.now().toUtc(),
        lastSeen: DateTime.now().toUtc(),
        isOnLine: false,
        myContacts: [],
      );
      await _crud.post(table: "messenger_users", data: data.toJson());
      await HiveService.saveUser(data);
      return Right(respons);
    } catch (e) {
      return Left(SupabaseError(message: '$e'));
    }

}
}
//--------------------------------------------------------------
import 'dart:io';

import 'package:chattr/core/services/supabase/supabase_error.dart';
import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class AuthRepo {
Future<Either<SupabaseError, User>> login({
required String email,
required String password,
});

Future<Either<SupabaseError, User>> signup({
required String name,
required String email,
required String password,
required File image,
});
}
//-------------------------------------------------------
import 'dart:io';

import 'package:chattr/features/auth/data/repos/auth_repo.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
AuthCubit(this.authRepo) : super(AuthState.initial());
final AuthRepo authRepo;
//login btn cubit
Future<void> onTapLoginBut({
required String email,
required String password,
}) async {
if (state.status == AuthStatus.loading) return;

    emit(const AuthState(action: AuthAction.login, status: AuthStatus.loading));

    final user = await authRepo.login(email: email, password: password);
    user.fold(
      (error) => emit(
        AuthState(
          action: AuthAction.login,
          status: AuthStatus.failure,
          errorMessage: error.message,
        ),
      ),
      (_) => emit(
        const AuthState(action: AuthAction.login, status: AuthStatus.success),
      ),
    );

}

//SignUp cubit
Future<void> onTapSignUpBut({
required String name,
required String email,
required String password,
required File image,
}) async {
if (state.status == AuthStatus.loading) return;

    emit(
      const AuthState(action: AuthAction.signup, status: AuthStatus.loading),
    );

    final user = await authRepo.signup(
      name: name,
      email: email,
      password: password,
      image: image,
    );
    user.fold(
      (error) => emit(
        AuthState(
          action: AuthAction.signup,
          status: AuthStatus.failure,
          errorMessage: error.message,
        ),
      ),
      (_) => emit(
        const AuthState(action: AuthAction.signup, status: AuthStatus.success),
      ),
    );

}
}
//---------------------------------------------------------------------
part of 'auth_cubit.dart';

enum AuthAction { none, login, signup }

enum AuthStatus { initial, loading, success, failure }

class AuthState {
final AuthAction action;
final AuthStatus status;
final String? errorMessage;

const AuthState({
required this.action,
required this.status,
this.errorMessage,
});

factory AuthState.initial() {
return const AuthState(action: AuthAction.none, status: AuthStatus.initial);
}

AuthState copyWith({
AuthAction? action,
AuthStatus? status,
String? errorMessage,
}) {
return AuthState(
action: action ?? this.action,
status: status ?? this.status,
errorMessage: errorMessage ?? this.errorMessage,
);
}
}
//--------------------------------------------------------
import 'package:chattr/core/routing/routes.dart';
import 'package:chattr/core/themes/app_colors.dart';
import 'package:chattr/core/themes/app_text_styles.dart';
import 'package:chattr/core/utils/extensions/responsive.dart';
import 'package:chattr/core/utils/validators/auth_validation.dart';
import 'package:chattr/core/widgets/custom_button.dart';
import 'package:chattr/core/widgets/custom_text.dart';
import 'package:chattr/core/widgets/custom_text_field.dart';
import 'package:chattr/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class LoginViewBody extends StatefulWidget {
const LoginViewBody({super.key});

@override
State<LoginViewBody> createState() => \_LoginViewBodyState();
}

class \_LoginViewBodyState extends State<LoginViewBody> {
final ValueNotifier<bool> \_isPasswordVisible = ValueNotifier(false);
final formKey = GlobalKey<FormState>();
late TextEditingController \_emailController;
late TextEditingController \_passwordController;
@override
void initState() {
super.initState();
\_emailController = TextEditingController(text: "test@gmail.com");
\_passwordController = TextEditingController(text: "123456789");
}

@override
void dispose() {
\_emailController.dispose();
\_passwordController.dispose();
super.dispose();
}

@override
Widget build(BuildContext context) {
return Padding(
padding: EdgeInsets.symmetric(horizontal: 20),
child: SingleChildScrollView(
child: Form(
key: formKey,
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Gap(context.screenHeight _ 0.1),
Center(child: SvgPicture.asset("assets/svgs/logo1.svg")),
Gap(context.screenHeight _ 0.1),
CustomText(text: "Login", style: AppTextStyles.displayMedium),
Gap(20),
CustomTextField(
hint: "Email",
controller: _emailController,
validation: AuthValidation.email,
keyboardType: TextInputType.emailAddress,
prefixIcon: const Icon(CupertinoIcons.mail),
),
Gap(10),
ValueListenableBuilder<bool>(
valueListenable: \_isPasswordVisible,
builder: (context, isVisible, _) {
return CustomTextField(
controller: \_passwordController,
keyboardType: TextInputType.text,
prefixIcon: const Icon(CupertinoIcons.lock),
suffixIcon: IconButton(
icon: Icon(
isVisible ? Icons.visibility : Icons.visibility_off,
),
onPressed: () => \_isPasswordVisible.value = !isVisible,
),
secure: !isVisible,
hint: 'password',
validation: AuthValidation.password,
);
},
),
Gap(30),
\_LoginButton(
formKey: formKey,
emailController: \_emailController,
passwordController: \_passwordController,
),
Gap(10),
Align(
alignment: Alignment.centerRight,
child: GestureDetector(
onTap: () {
context.push(Routes.signup);
},
child: Text.rich(
TextSpan(
children: [
TextSpan(
text: "Don't have an account? ",
style: AppTextStyles.bodySmall, // النص العادي
),
TextSpan(
text: "Sign Up",
style: AppTextStyles.labelLarge.copyWith(
color: AppColors.primary,
), // الجزء القابل للضغط
),
],
),
),
),
),
],
),
),
),
);
}
}

//login button
class \_LoginButton extends StatelessWidget {
const \_LoginButton({
required this.formKey,
required this.emailController,
required this.passwordController,
});
final TextEditingController emailController;
final TextEditingController passwordController;
final GlobalKey<FormState> formKey;

void \_login(BuildContext context) {
if (formKey.currentState!.validate()) {
context.read<AuthCubit>().onTapLoginBut(
email: emailController.text.trim(),
password: passwordController.text.trim(),
);
}
}

@override
Widget build(BuildContext context) {
return BlocBuilder<AuthCubit, AuthState>(
builder: (context, state) {
final isLoading =
state.status == AuthStatus.loading &&
state.action == AuthAction.login;
return CustomButton(
onPressed: isLoading ? null : () => \_login(context),

          raduis: 15,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CustomText(text: "Login", style: AppTextStyles.buttonLarge),
              Gap(10),
              if (isLoading) ...[
                const Gap(11),
                CupertinoActivityIndicator(
                  animating: true,
                  color: Colors.white,
                  radius: 10,
                ),
              ],
            ],
          ),
        );
      },
    );

}
}
//-------------------------------------------------------
import 'package:chattr/core/helpers/snack_bar.dart';
import 'package:chattr/core/routing/routes.dart';
import 'package:chattr/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:chattr/features/auth/presentation/views/login_view/login_view_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class LoginView extends StatelessWidget {
const LoginView({super.key});

@override
Widget build(BuildContext context) {
return GestureDetector(
onTap: () => FocusScope.of(context).unfocus(),
child: BlocListener<AuthCubit, AuthState>(
listener: (context, state) {
if (state.status == AuthStatus.failure) {
CustomSnackBar.error(context, state.errorMessage ?? '');
}
if (state.status == AuthStatus.success) {
WidgetsBinding.instance.addPostFrameCallback((\_) {
CustomSnackBar.success(context, 'Login Successfully');
});
context.pushReplacement(Routes.root);
}
},
child: Scaffold(body: LoginViewBody()),
),
);
}
}
//-------------------------------------------------------------
import 'package:chattr/core/cubits/pick_image/pick_image_cubit.dart';
import 'package:chattr/core/helpers/snack_bar.dart';
import 'package:chattr/core/themes/app_colors.dart';
import 'package:chattr/core/themes/app_text_styles.dart';
import 'package:chattr/core/utils/extensions/responsive.dart';
import 'package:chattr/core/utils/validators/auth_validation.dart';
import 'package:chattr/core/widgets/custom_button.dart';
import 'package:chattr/core/widgets/custom_text.dart';
import 'package:chattr/core/widgets/custom_text_field.dart';
import 'package:chattr/core/widgets/image/ui/pick_image.dart';
import 'package:chattr/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class SignupViewBody extends StatefulWidget {
const SignupViewBody({super.key});

@override
State<SignupViewBody> createState() => \_SignupViewBodyState();
}

class \_SignupViewBodyState extends State<SignupViewBody> {
final ValueNotifier<bool> \_isPasswordVisible = ValueNotifier(false);
final formKey = GlobalKey<FormState>();
late TextEditingController \_nameController;
late TextEditingController \_emailController;
late TextEditingController \_passwordController;
@override
void initState() {
\_nameController = TextEditingController();
\_emailController = TextEditingController();
\_passwordController = TextEditingController();
super.initState();
}

@override
void dispose() {
\_nameController.dispose();
\_emailController.dispose();
\_passwordController.dispose();
super.dispose();
}

@override
Widget build(BuildContext context) {
return Padding(
padding: EdgeInsets.symmetric(horizontal: 20),
child: SingleChildScrollView(
child: Form(
key: formKey,
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Gap(context.screenHeight \* 0.1),

              CustomText(text: "SignUp", style: AppTextStyles.displayMedium),
              Gap(20),
              PickImageWidget(isProfile: true),
              Gap(20),
              CustomTextField(
                keyboardType: TextInputType.name,

                prefixIcon: const Icon(CupertinoIcons.person),
                hint: "Name",
                controller: _nameController,
                validation: AuthValidation.required,
              ),
              Gap(10),
              CustomTextField(
                keyboardType: TextInputType.emailAddress,
                prefixIcon: const Icon(CupertinoIcons.mail),
                hint: "Email",
                controller: _emailController,
                validation: AuthValidation.email,
              ),
              Gap(10),
              ValueListenableBuilder<bool>(
                valueListenable: _isPasswordVisible,
                builder: (context, isVisible, _) {
                  return CustomTextField(
                    controller: _passwordController,
                    keyboardType: TextInputType.text,
                    prefixIcon: const Icon(CupertinoIcons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        isVisible ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () => _isPasswordVisible.value = !isVisible,
                    ),
                    secure: !isVisible,
                    hint: 'password',
                    validation: AuthValidation.password,
                  );
                },
              ),
              Gap(30),
              _SignupButton(
                nameController: _nameController,
                emailController: _emailController,
                passwordController: _passwordController,
                formKey: formKey,
              ),
              Gap(10),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () {
                    context.pop();
                  },
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: "Already have An Account ? ",
                          style: AppTextStyles.bodySmall, // النص العادي
                        ),
                        TextSpan(
                          text: "Login",
                          style: AppTextStyles.labelLarge.copyWith(
                            color: AppColors.primary,
                          ), // الجزء القابل للضغط
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

}
}

//login button
class \_SignupButton extends StatelessWidget {
const \_SignupButton({
required this.formKey,
required this.emailController,
required this.passwordController,
required this.nameController,
});
final TextEditingController emailController;
final TextEditingController nameController;
final TextEditingController passwordController;
final GlobalKey<FormState> formKey;

void \_signup(BuildContext context) {
final imageFile = context.read<PickImageCubit>().imageFile;
if (imageFile == null) {
CustomSnackBar.warning(context, 'Please select a profile picture');
return;
}
if (formKey.currentState!.validate()) {
context.read<AuthCubit>().onTapSignUpBut(
name: nameController.text.trim(),
email: emailController.text.trim(),
password: passwordController.text.trim(),
image: imageFile,
);
}
}

@override
Widget build(BuildContext context) {
return BlocBuilder<AuthCubit, AuthState>(
builder: (context, state) {
final isLoading =
state.status == AuthStatus.loading &&
state.action == AuthAction.signup;
return CustomButton(
onPressed: isLoading ? null : () => \_signup(context),

          raduis: 15,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CustomText(text: "Sign Up", style: AppTextStyles.buttonLarge),
              Gap(10),
              if (isLoading) ...[
                const Gap(11),
                CupertinoActivityIndicator(
                  animating: true,
                  color: Colors.white,
                  radius: 10,
                ),
              ],
            ],
          ),
        );
      },
    );

}
}
//-------------------------------------------------------------------
import 'package:chattr/core/helpers/snack_bar.dart';
import 'package:chattr/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:chattr/features/auth/presentation/views/signup_view/signup_view_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class SignupView extends StatelessWidget {
const SignupView({super.key});

@override
Widget build(BuildContext context) {
return GestureDetector(
onTap: () => FocusScope.of(context).unfocus(),
child: BlocListener<AuthCubit, AuthState>(
listener: (context, state) {
if (state.status == AuthStatus.failure) {
CustomSnackBar.error(context, state.errorMessage ?? '');
}
if (state.status == AuthStatus.success) {
CustomSnackBar.success(
context,
'Successfully Registered , you can login now',
);
context.pop();
}
},
child: Scaffold(body: SignupViewBody()),
),
);
}
}
//---------------------------------------------------------------
import 'package:chattr/core/services/hive/hive_services.dart';
import 'package:chattr/core/services/supabase/supabase_auth_services.dart';
import 'package:chattr/core/services/supabase/supabase_client_manager.dart';
import 'package:chattr/core/services/supabase/supabase_crud_services.dart';
import 'package:chattr/core/services/supabase/supabase_error.dart';
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:chattr/features/contacts/data/repos/add_to_contacts_repo/add_to_contacts_repo.dart';
import 'package:dartz/dartz.dart';

class AddToContactsRepoImpl implements AddToContactsRepo {
final SupabaseClientManager \_clientManager;
final SupabaseCrudServices \_crud;
final AuthService \_auth;
AddToContactsRepoImpl(this.\_clientManager, this.\_auth, this.\_crud);

// add friend to your contatcs
@override
Future<Either<SupabaseError, UserModel>> addToContacts(
String contactEmail,
) async {
try {
final myId = \_auth.currentUser!.id;
final client = \_clientManager.client;
// Get contact data
final contactData = await \_crud.getByFilter(
table: 'messenger_users',
filterColumn: 'email',
filterValue: contactEmail,
);

      if (contactData == null) {
        return left(const SupabaseError(message: 'User not found'));
      }

      final contact = UserModel.fromJson(contactData);

      if (contact.id == myId) {
        return left(const SupabaseError(message: 'You cannot add yourself'));
      }
      // Get my contacts
      final myData = await client
          .from('messenger_users')
          .select('my_contacts')
          .eq('id', myId)
          .single();

      final currentContacts =
          (myData['my_contacts'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];

      // Prevent duplicate
      if (currentContacts.contains(contact.id)) {
        return left(const SupabaseError(message: 'Contact already added'));
      }

      // Append and update
      currentContacts.add(contact.id!);
      // Update my contacts
      await client
          .from('messenger_users')
          .update({'my_contacts': currentContacts})
          .eq('id', myId);
      await HiveService.saveUser(contact);
      return Right(contact);
    } catch (e) {
      return left(SupabaseError(message: "$e"));
    }

}
}
//-----------------------------------------------
import 'package:chattr/core/services/supabase/supabase_error.dart';
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:dartz/dartz.dart';

abstract interface class AddToContactsRepo {
Future<Either<SupabaseError, UserModel>> addToContacts(String contactEmail);
}
//--------------------------------------------------------------------
import 'package:chattr/core/services/hive/hive_services.dart';
import 'package:chattr/core/services/supabase/supabase_client_manager.dart';
import 'package:chattr/core/services/supabase/supabase_crud_services.dart';
import 'package:chattr/core/services/supabase/supabase_error.dart';
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:chattr/features/contacts/data/repos/fetch_contacts_repo/fetch_contacts_repo.dart';
import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FetchContactsRepoImpl implements FetchContactsRepo {
final SupabaseClientManager client;
final SupabaseCrudServices \_crud;
FetchContactsRepoImpl(this.client, this.\_crud);
SupabaseClient get \_client => client.client;
@override
Future<Either<SupabaseError, List<Map<String, dynamic>>>> fetchAllContacts(
List<String> ids,
) async {
try {
final result = await \_client
.from('messenger_users')
.select()
.inFilter('id', ids)
.order('created_at', ascending: true); // ← ترتيب ثابت

      return right(result);
    } catch (e) {
      return left(SupabaseError(message: "$e"));
    }

}

@override
Future<Either<SupabaseError, UserModel>> fetchMe(String myId) async {
try {
final myData = await \_crud.getById(table: 'messenger_users', id: myId);
return right(UserModel.fromJson(myData));
} catch (e) {
return left(SupabaseError(message: "$e"));
}
}

@override
Either<SupabaseError, RealtimeChannel> subscribeToUser(String userId) {
try {
final channel = \_client.channel('my-contacts-$userId');
return right(channel);
} catch (e) {
return left(SupabaseError(message: e.toString()));
}
}

@override
Future<Either<String, List<UserModel>>> getUsers() async {
try {
final allUsers = await HiveService.getUsers();
return right(allUsers);
} catch (e) {
return left('$e');
}
}

@override
Future<Either<String, Unit>> saveUser(UserModel user) async {
try {
await HiveService.saveUser(user);
return right(unit);
} catch (e) {
return left('$e');
}
}

@override
Future<Either<String, Unit>> saveUsers(List<UserModel> users) async {
try {
for (var u in users) {
await HiveService.saveUser(u);
}
return right(unit);
} catch (e) {
return left('$e');
}
}
}
//---------------------------------------------------------------
import 'package:chattr/core/services/supabase/supabase_error.dart';
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class FetchContactsRepo {
Future<Either<SupabaseError, List<Map<String, dynamic>>>> fetchAllContacts(
List<String> ids,
);
Future<Either<SupabaseError, UserModel>> fetchMe(String myId);
Either<SupabaseError, RealtimeChannel> subscribeToUser(String userId);
Future<Either<String, List<UserModel>>> getUsers();
Future<Either<String, Unit>> saveUsers(List<UserModel> users);
Future<Either<String, Unit>> saveUser(UserModel user);
}
//----------------------------------------------------------------------
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:chattr/features/contacts/data/repos/add_to_contacts_repo/add_to_contacts_repo.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'add_to_contacts_state.dart';

class AddToContactsCubit extends Cubit<AddToContactsState> {
AddToContactsCubit(this.\_contactsRepo) : super(AddToContactsInitial());
final AddToContactsRepo \_contactsRepo;

Future<void> addContact(String contactEmail) async {
emit(AddToContactsLoading());
final result = await \_contactsRepo.addToContacts(contactEmail);
result.fold(
(l) => emit(AddToContactsFailure(errorMessage: l.message)),
(r) => emit(AddToContactsSuccess(contact: r)),
);
}
}
//-------------------------------------------------------
part of 'add_to_contacts_cubit.dart';

sealed class AddToContactsState {}

final class AddToContactsInitial extends AddToContactsState {}

final class AddToContactsLoading extends AddToContactsState {}

final class AddToContactsSuccess extends AddToContactsState {
final UserModel contact;
AddToContactsSuccess({required this.contact});
}

final class AddToContactsFailure extends AddToContactsState {
final String errorMessage;
AddToContactsFailure({required this.errorMessage});
}
//---------------------------------------------------------------
import 'package:chattr/core/services/supabase/supabase_auth_services.dart';
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:chattr/features/contacts/data/repos/fetch_contacts_repo/fetch_contacts_repo.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'fetch_contacts_state.dart';

class FetchContactsCubit extends Cubit<FetchContactsState> {
FetchContactsCubit(this.\_repo, this.\_auth) : super(FetchContactsInitial());

final FetchContactsRepo \_repo;
final AuthService \_auth;

List<UserModel> contacts = [];
RealtimeChannel? \_channel;

Future<void> fetchContacts() async {
emit(FetchContactsLoading());

    try {
      final myId = _auth.currentUser!.id;

      // ===== LOCAL (Hive) =====
      final localResult = await _repo.getUsers();
      final localUsers = localResult.fold((e) => <UserModel>[], (u) => u);

      final localMe = localUsers.firstWhere(
        (u) => u.id == myId,
        orElse: () => UserModel(id: myId),
      );

      List<String> contactIds = localMe.myContacts ?? [];

      if (contactIds.isEmpty) {
        final remoteMeResult = await _repo.fetchMe(myId);
        final remoteMe = remoteMeResult.fold((e) => null, (u) => u);
        if (remoteMe != null) {
          await _repo.saveUser(remoteMe);
          contactIds = remoteMe.myContacts ?? [];
        }
        if (contactIds.isEmpty) {
          emit(FetchContactsSuccess(contacts: []));
          _subscribeToRealtime(myId);
          return;
        }
      }

      // ===== REMOTE (Supabase) =====
      if (contactIds.isEmpty) {
        emit(FetchContactsSuccess(contacts: []));
        _subscribeToRealtime(myId);
        return;
      }

      final remoteResult = await _repo.fetchAllContacts(contactIds);
      final contactsList = remoteResult.fold(
        (e) => <UserModel>[],
        (data) => data.map((e) => UserModel.fromJson(e)).toList(),
      );

      for (final user in contactsList) {
        await _repo.saveUser(user);
      }

      contacts = contactsList;
      contacts.sort((a, b) {
        final aDate = a.createdAt ?? DateTime(0);
        final bDate = b.createdAt ?? DateTime(0);
        return aDate.compareTo(bDate);
      });
      emit(FetchContactsSuccess(contacts: contacts));
      _subscribeToRealtime(myId);
    } catch (e) {
      emit(FetchContactsFailure(errorMessage: e.toString()));
    }

}

void \_subscribeToRealtime(String myId) {
\_channel?.unsubscribe();

    final channelResult = _repo.subscribeToUser(myId);

    channelResult.fold((e) => null, (channel) {
      _channel = channel;

      _channel!
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'messenger_users',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: myId,
            ),
            callback: (payload) async {
              final updatedMe = UserModel.fromJson(payload.newRecord);

              await _repo.saveUser(updatedMe);

              final newContactIds = updatedMe.myContacts ?? [];

              final allUsersResult = await _repo.getUsers();
              final allUsers = allUsersResult.fold(
                (e) => <UserModel>[],
                (u) => u,
              );

              final cachedIds = allUsers.map((u) => u.id).toSet();
              final missingIds = newContactIds
                  .where((id) => !cachedIds.contains(id))
                  .toList();

              if (missingIds.isNotEmpty) {
                final remoteResult = await _repo.fetchAllContacts(missingIds);
                final fetched = remoteResult.fold(
                  (e) => <UserModel>[],
                  (data) => data.map((e) => UserModel.fromJson(e)).toList(),
                );
                for (final u in fetched) {
                  await _repo.saveUser(u);
                }
                allUsers.addAll(fetched);
              }

              final newContacts = allUsers
                  .where((u) => u.id != myId && newContactIds.contains(u.id))
                  .toList();

              if (_listsEqual(contacts, newContacts)) return;

              contacts = newContacts;
              emit(FetchContactsSuccess(contacts: contacts));
            },
          )
          .subscribe();
    });

}

bool \_listsEqual(List<UserModel> a, List<UserModel> b) {
if (a.length != b.length) return false;
for (int i = 0; i < a.length; i++) {
if (a[i].id != b[i].id) return false;
}
return true;
}

@override
Future<void> close() {
\_channel?.unsubscribe();
return super.close();
}
}
//----------------------------------------------------
part of 'fetch_contacts_cubit.dart';

sealed class FetchContactsState {}

final class FetchContactsInitial extends FetchContactsState {}

final class FetchContactsLoading extends FetchContactsState {}

final class FetchContactsSuccess extends FetchContactsState {
final List<UserModel> contacts;
FetchContactsSuccess({required this.contacts});
}

final class FetchContactsFailure extends FetchContactsState {
final String errorMessage;
FetchContactsFailure({required this.errorMessage});
}
//------------------------------------------------------------
import 'package:chattr/core/helpers/snack_bar.dart';
import 'package:chattr/core/themes/app_colors.dart';
import 'package:chattr/core/themes/app_text_styles.dart';
import 'package:chattr/core/utils/validators/auth_validation.dart';
import 'package:chattr/core/widgets/custom_button.dart';
import 'package:chattr/core/widgets/custom_text.dart';
import 'package:chattr/core/widgets/custom_text_field.dart';
import 'package:chattr/features/contacts/presentation/cubits/add_to_contacts_cubit/add_to_contacts_cubit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class AddContactBottomSheet extends StatefulWidget {
const AddContactBottomSheet({super.key}); // ← شيلنا required this.context

@override
State<AddContactBottomSheet> createState() => \_AddContactBottomSheetState();
}

class \_AddContactBottomSheetState extends State<AddContactBottomSheet> {
final GlobalKey<FormState> \_formKey = GlobalKey<FormState>();
late TextEditingController \_emailController;

@override
void initState() {
super.initState();
\_emailController = TextEditingController();
}

@override
void dispose() {
\_emailController.dispose();
super.dispose();
}

@override
Widget build(BuildContext context) {
return GestureDetector(
onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
child: BlocListener<AddToContactsCubit, AddToContactsState>(
listener: (context, state) {
if (state is AddToContactsFailure) {
CustomSnackBar.error(
context,
state.errorMessage,
); // ← context مش widget.context
context.pop();
}
if (state is AddToContactsSuccess) {
CustomSnackBar.success(
context,
"user added to contacts successfully",
);
context.pop();
}
},
child: Container(
decoration: BoxDecoration(
color: AppColors.surface,
borderRadius: const BorderRadius.only(
topLeft: Radius.circular(22),
topRight: Radius.circular(22),
),
),
child: Padding(
padding: const EdgeInsets.symmetric(horizontal: 20),
child: Form(
key: \_formKey,
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
mainAxisSize: MainAxisSize.min,
children: [
const Gap(9),

                  Center(
                    child: Container(
                      height: 5,
                      width: 50,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Gap(10),
                  Row(
                    children: [
                      CustomText(
                        text: "Add contact",
                        style: AppTextStyles.headlineSmall,
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.qr_code_scanner,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                  const Gap(15),
                  CustomTextField(
                    controller: _emailController,
                    hint: "Email",
                    borderColor: AppColors.border,
                    textStyle: AppTextStyles.bodySmall,
                    validation: AuthValidation.email,
                  ),
                  const Gap(10),
                  _AddContactButton(
                    formKey: _formKey,
                    emailController: _emailController,
                  ),
                  const Gap(20),
                ],
              ),
            ),
          ),
        ),
      ),
    );

}
}

class \_AddContactButton extends StatelessWidget {
const \_AddContactButton({
required GlobalKey<FormState> formKey,
required TextEditingController emailController,
}) : \_formKey = formKey,
\_emailController = emailController;

final GlobalKey<FormState> \_formKey;
final TextEditingController \_emailController;

@override
Widget build(BuildContext context) {
return BlocBuilder<AddToContactsCubit, AddToContactsState>(
buildWhen: (prev, curr) =>
curr is AddToContactsLoading || prev is AddToContactsLoading,
builder: (context, state) {
final isLoading = state is AddToContactsLoading;
return CustomButton(
onPressed: () {
if (\_formKey.currentState!.validate()) {
context.read<AddToContactsCubit>().addContact(
\_emailController.text.trim(),
);
}
},
raduis: 7,
child: Row(
mainAxisAlignment: MainAxisAlignment.center,
children: [
CustomText(
text: "Add To Contacts",
style: AppTextStyles.buttonMedium,
),
Gap(5),
isLoading
? CupertinoActivityIndicator(color: Colors.grey, radius: 8)
: SizedBox.shrink(),
],
),
);
},
);
}
}
//------------------------------------------------------------
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chattr/core/cubits/fetch_current_user_data/fetch_current_user_data_cubit.dart';
import 'package:chattr/core/routing/router_models.dart';
import 'package:chattr/core/routing/routes.dart';
import 'package:chattr/core/themes/app_colors.dart';
import 'package:chattr/core/themes/app_text_styles.dart';
import 'package:chattr/core/widgets/custom_text.dart';
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:chattr/features/private_chats/data/models/private_chat_model.dart';
import 'package:chattr/features/private_chats/presentation/cubits/add_friend_cubit/add_friend_cubit.dart';
import 'package:chattr/features/private_chats/presentation/cubits/fetch_private_chats_cubit/fetch_private_chats_cubit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ContactItem extends StatelessWidget {
const ContactItem({super.key, required this.user});

final UserModel user;

@override
Widget build(BuildContext context) {
return Card(
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
color: AppColors.surface,
elevation: 0.3,
margin: const EdgeInsets.fromLTRB(10, 0, 10, 5),
child: Padding(
padding: const EdgeInsets.all(15),
child: Row(
children: [
\_Avatar(imageUrl: user.image),
const Gap(10),
\_UserInfo(name: user.name, email: user.email),
const Spacer(),
BlocBuilder<FetchPrivateChatsCubit, FetchPrivateChatsState>(
builder: (context, state) {
List<PrivateChatModel> chats = [];

                if (state is FetchPrivateChatsSuccess) {
                  chats = state.chats;
                }

                return _MessageButton(
                  onTap: () => _navigateToChat(
                    context: context,
                    user: user,
                    chats: chats,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );

}
}

void \_navigateToChat({
required BuildContext context,
required UserModel user,
required List<PrivateChatModel> chats,
}) async {
final hasChat = chats.any((chat) => chat.friend?.id == user.id);

if (!hasChat) {
final addFriendCubit = context.read<AddFriendCubit>();
await addFriendCubit.addFriend(email: user.email!);
if (addFriendCubit.state is AddFriendSuccess) {
final chat = (addFriendCubit.state as AddFriendSuccess).chat;
final currentUser = context.read<FetchCurrentUserDataCubit>().currentUser;
final PrivateChatParams chatData = PrivateChatParams(
chatData: chat,
curruntUser: currentUser!,
);

      context.push(Routes.privateChatsBody, extra: chatData);
    }

} else {
final chat = chats.firstWhere((chat) => chat.friend?.id == user.id);
final currentUser = context.read<FetchCurrentUserDataCubit>().currentUser;
final PrivateChatParams chatData = PrivateChatParams(
chatData: chat,
curruntUser: currentUser!,
);
context.push(Routes.privateChatsBody, extra: chatData);
}
}

class \_Avatar extends StatelessWidget {
const \_Avatar({this.imageUrl});
final String? imageUrl;

static const \_fallback =
'https://static.thenounproject.com/png/1856610-200.png';

@override
Widget build(BuildContext context) {
return CircleAvatar(
radius: 20,
child: ClipOval(
child: CachedNetworkImage(
fit: BoxFit.cover,
imageUrl: imageUrl ?? _fallback,
placeholder: (_, _) => const CupertinoActivityIndicator(
color: Colors.white54,
radius: 9,
),
errorWidget: (_, _, _) => const Icon(
Icons.image_not_supported_outlined,
color: Colors.red,
size: 40,
),
),
),
);
}
}

class \_UserInfo extends StatelessWidget {
const \_UserInfo({this.name, this.email});
final String? name;
final String? email;

@override
Widget build(BuildContext context) {
return Column(
mainAxisSize: MainAxisSize.min,
crossAxisAlignment: CrossAxisAlignment.start,
children: [
CustomText(text: name ?? '', style: AppTextStyles.bodyMedium),
CustomText(text: email ?? '', style: AppTextStyles.bodySmall),
],
);
}
}

class \_MessageButton extends StatelessWidget {
const \_MessageButton({required this.onTap});
final VoidCallback onTap;

@override
Widget build(BuildContext context) {
return BlocBuilder<AddFriendCubit, AddFriendState>(
buildWhen: (prev, curr) =>
prev is AddFriendLoading || curr is AddFriendLoading,
builder: (context, state) {
final bool isLoadind = state is AddFriendLoading;
return InkWell(
onTap: onTap,
child: isLoadind
? const CircularProgressIndicator(color: AppColors.primary)
: Icon(Icons.message, color: AppColors.primary),
);
},
);
}
}
//---------------------------------------------------------------------
import 'package:chattr/core/cubits/search/search_cubit.dart';
import 'package:chattr/core/themes/app_colors.dart';
import 'package:chattr/core/widgets/custom_text_field.dart';
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:chattr/features/contacts/presentation/cubits/fetch_contacts_cubit/fetch_contacts_cubit.dart';
import 'package:chattr/features/contacts/presentation/views/widgets/contact_item.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class ContactsViewBody extends StatefulWidget {
const ContactsViewBody({super.key});

@override
State<ContactsViewBody> createState() => \_ContactsViewBodyState();
}

class \_ContactsViewBodyState extends State<ContactsViewBody> {
late TextEditingController \_searchController;

@override
void initState() {
super.initState();
\_searchController = TextEditingController();
}

@override
void dispose() {
\_searchController.dispose();
super.dispose();
}

@override
Widget build(BuildContext context) {
return BlocBuilder<FetchContactsCubit, FetchContactsState>(
builder: (context, state) {
return switch (state) {
FetchContactsSuccess() => _buildBody(context, state.contacts),
FetchContactsFailure() => Center(child: Text(state.errorMessage)),
_ => Center(
child: CupertinoActivityIndicator(color: Colors.grey, radius: 12),
),
};
},
);
}

Widget \_buildBody(BuildContext context, List<UserModel> contacts) {
return Column(
children: [
if (contacts.isNotEmpty) Gap(20),
Padding(
padding: const EdgeInsets.symmetric(horizontal: 20),
child: _SearchField(
controller: _searchController,
contacts: contacts,
),
),
const Gap(10),
Expanded(child: _ContactsList(contacts: contacts)),
],
);
}
}

// ─── Search Field ───────────────────────────────────────────────
class \_SearchField extends StatelessWidget {
const \_SearchField({required this.controller, required this.contacts});

final TextEditingController controller;
final List<UserModel> contacts;

@override
Widget build(BuildContext context) {
return CustomTextField(
controller: controller,
hint: "search",
validation: (_) => null,
onChange: (_) {
context.read<SearchCubit>().search(
list: contacts,
query: controller.text.trim(),
searchBy: (item) => (item as UserModel).name ?? '',
);
},
suffixIcon: ValueListenableBuilder(
valueListenable: controller,
builder: (context, _, _) {
final hasText = controller.text.trim().isNotEmpty;
return hasText
? InkWell(
onTap: () {
controller.clear();
context.read<SearchCubit>().closeSearch();
},
child: const Icon(Icons.clear_rounded),
)
: const Icon(CupertinoIcons.search, color: AppColors.inputBorder);
},
),
);
}
}

// ─── Contacts List ───────────────────────────────────────────────
class \_ContactsList extends StatelessWidget {
const \_ContactsList({required this.contacts});

final List<UserModel> contacts;

@override
Widget build(BuildContext context) {
return BlocBuilder<SearchCubit, SearchState>(
builder: (context, state) {
final filtered = state is SearchActive
? state.filteredList.cast<UserModel>()
: contacts;

        return ListView.builder(
          itemCount: filtered.length,
          itemBuilder: (_, index) => ContactItem(user: filtered[index]),
        );
      },
    );

}
}
//-----------------------------------------------------------------
import 'package:chattr/core/cubits/search/search_cubit.dart';
import 'package:chattr/core/utils/di/get_it.dart';
import 'package:chattr/core/widgets/custom_appbar.dart';
import 'package:chattr/features/contacts/data/repos/add_to_contacts_repo/add_to_contacts_repo.dart';
import 'package:chattr/features/contacts/presentation/cubits/add_to_contacts_cubit/add_to_contacts_cubit.dart';
import 'package:chattr/features/contacts/presentation/views/contacts_view_body.dart';
import 'package:chattr/features/contacts/presentation/views/widgets/add_contact_bottom_sheet.dart';
import 'package:chattr/features/private_chats/data/repos/add_friend_repo/add_friend_repo.dart';
import 'package:chattr/features/private_chats/presentation/cubits/add_friend_cubit/add_friend_cubit.dart';
import 'package:chattr/features/private_chats/presentation/cubits/fetch_private_chats_cubit/fetch_private_chats_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class ContactsView extends StatelessWidget {
const ContactsView({super.key});

void _showAddContactSheet(BuildContext context) {
showModalBottomSheet(
isScrollControlled: true,
context: context,
builder: (ctx) => Padding(
padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
child: BlocProvider(
create: (_) => AddToContactsCubit(getIt<AddToContactsRepo>()),
child: const AddContactBottomSheet(),
),
),
);
}

@override
Widget build(BuildContext context) {
return GestureDetector(
onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
child: Scaffold(
appBar: CustomAppBar(
title: "Contacts",
actions: [
GestureDetector(
onTap: () => _showAddContactSheet(context),
child: const Icon(Icons.person_add_sharp),
),
Gap(10),
],
),

        body: SafeArea(
          child: MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => SearchCubit()),
              BlocProvider(
                create: (context) => AddFriendCubit(getIt<AddFriendRepo>()),
              ),
              BlocProvider.value(value: getIt<FetchPrivateChatsCubit>()),
            ],
            child: const ContactsViewBody(),
          ),
        ),
      ),
    );

}
}
//-------------------------------------------------------
class GroupMemberModel {
final String groupId;
final String userId;
final DateTime? lastReadAt;
final bool isAdmin;

GroupMemberModel({
required this.groupId,
required this.userId,
this.lastReadAt,
this.isAdmin = false,
});
factory GroupMemberModel.fromJson(Map<String, dynamic> json) =>
GroupMemberModel(
groupId: json['group_id'],
userId: json['user_id'],
isAdmin: json['is_admin'],
lastReadAt: json['last_read_at'] != null
? DateTime.parse(json['last_read_at'])
: null,
);

Map<String, dynamic> toJson() => {
"group_id": groupId,
"user_id": userId,
"is_admin": isAdmin,
};
}
//-------------------------------------------
import 'package:chattr/core/services/hive/hive_type_ids.dart';
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:hive/hive.dart';

part 'group_message_model.g.dart';

@HiveType(typeId: HiveTypeIds.groupMessageStatus)
enum GroupMessageStatus {
@HiveField(0)
sending,
@HiveField(1)
sent,
@HiveField(2)
failed,
@HiveField(3)
deleting,
@HiveField(4)
deleteFailed,
@HiveField(5)
editing,
@HiveField(6)
editingFaild,
}

@HiveType(typeId: HiveTypeIds.groupMessageType)
enum GroupMessageType {
@HiveField(0)
text,
@HiveField(1)
image,
@HiveField(2)
video,
@HiveField(3)
voice,
}

extension MessageTypeParser on String {
GroupMessageType toMessageType() {
switch (this) {
case 'text':
return GroupMessageType.text;

      case 'image':
        return GroupMessageType.image;

      case 'video':
        return GroupMessageType.video;

      case 'voice':
        return GroupMessageType.voice;

      default:
        return GroupMessageType.text;
    }

}
}

extension MessageTypeToJson on GroupMessageType {
String toJson() => name;
}

@HiveType(typeId: HiveTypeIds.groupMessages)
class GroupMessageModel {
@HiveField(0)
final String tempId;
@HiveField(1) // UI only
final String? messageId;
@HiveField(2) // server
final GroupMessageStatus status;
@HiveField(3)
final String groupId;
@HiveField(4)
final String senderId;
@HiveField(5)
final GroupMessageType messageType;
@HiveField(6)
final String content;
@HiveField(7)
final int? mediaDuration;
@HiveField(8)
final DateTime createdAt;
@HiveField(9)
final bool isDeleted;
@HiveField(10)
final UserModel? sender;
@HiveField(11) // ← جديد
final String? localPath;

GroupMessageModel({
required this.tempId,
this.messageId,
this.localPath,
required this.status,
required this.groupId,
required this.senderId,
required this.messageType,
required this.content,
required this.createdAt,
required this.isDeleted,

    required this.sender,
    this.mediaDuration,

});

factory GroupMessageModel.fromJson(Map<String, dynamic> json) {
return GroupMessageModel(
tempId: json['temp_id'], // مؤقت للـ replace فقط
messageId: json['message_id'],
status: GroupMessageStatus.sent,
groupId: json['group_id'],
senderId: json['sender_id'],
messageType: (json['message_type'] as String).toMessageType(),
content: json['content'],
mediaDuration: json['media_duration'],
createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
isDeleted: json['is_deleted'],
sender: null,
);
}

Map<String, dynamic> toJson() {
return {
'temp_id': tempId,
'group_id': groupId,
'sender_id': senderId,
'message_type': messageType.toJson(),
'content': content,
'media_duration': mediaDuration,
'created_at': createdAt.toIso8601String(),
'is_deleted': isDeleted,
};
}

GroupMessageModel copyWith({
String? messageId,
String? localPath,
DateTime? createdAt,
int? mediaDuration,
GroupMessageStatus? status,
String? content,
bool? isDeleted,
}) {
return GroupMessageModel(
tempId: tempId,
messageId: messageId ?? this.messageId,
status: status ?? this.status,
groupId: groupId,
senderId: senderId,
messageType: messageType,
content: content ?? this.content,
mediaDuration: mediaDuration ?? this.mediaDuration,
createdAt: createdAt ?? this.createdAt,
isDeleted: isDeleted ?? this.isDeleted,
localPath: localPath ?? this.localPath,
sender: sender,
);
}
}
//-------------------------------------
import 'package:chattr/core/services/hive/hive_type_ids.dart';
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:hive/hive.dart';

part 'group_model.g.dart';

@HiveType(typeId: HiveTypeIds.groups)
class GroupModel {
@HiveField(0)
String? id;

@HiveField(1)
String? name;

@HiveField(2)
String? createdBy;

@HiveField(3)
DateTime createdAt;

@HiveField(4)
String? image;

@HiveField(5)
String? lastMessage;

@HiveField(6)
DateTime? lastMessageTime;

@HiveField(7)
String? lastMessageId;

@HiveField(8)
int unreadCount;

@HiveField(9)
List<UserInGroup>? members;
@HiveField(10)
String? lastMessageSenderId;

String getLastMessageSenderName({
required String currentUserId,
required String lastMessageSenderId,
}) {
if (lastMessageSenderId == currentUserId) {
return "You";
}

    final sender = members?.firstWhere(
      (member) => member.user.id == lastMessageSenderId,
    );

    return sender?.user.name ?? 'Unknown';

}

GroupModel({
required this.name,
this.lastMessageSenderId,
this.members,
this.id,
this.unreadCount = 0,
this.lastMessageId,
required this.createdBy,
required this.createdAt,
required this.image,
required this.lastMessage,
required this.lastMessageTime,
});

factory GroupModel.fromJson(Map<String, dynamic> json) {
final membersJson = json['members'] as List? ?? [];
final membersList = membersJson.map((m) {
return UserInGroup(
user: UserModel.fromJson(m['user']),
isAdmin: m['is_admin'] ?? false,
);
}).toList();

    return GroupModel(
      name: json['name'],
      unreadCount: json['unreadCount'] ?? 0,
      id: json['group_id'],
      lastMessageId: json['last_message_id'],
      members: membersList,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      createdBy: json['created_by'],
      image: json['image'],
      lastMessage: json['last_message'],
      lastMessageTime:
          DateTime.tryParse(json['last_message_time'] ?? '') ?? DateTime.now(),
      lastMessageSenderId: json['last_message_sender_id'],
    );

}

Map<String, dynamic> toJson() {
return {
'name': name,
'created_at': createdAt.toIso8601String(),
'created_by': createdBy,
'image': image,
};
}

GroupModel copyWith({int? unreadCount}) {
return GroupModel(
id: id,
name: name,
unreadCount: unreadCount ?? this.unreadCount,
createdBy: createdBy,
createdAt: createdAt,
image: image,
members: members,
lastMessage: lastMessage,
lastMessageTime: lastMessageTime,
lastMessageId: lastMessageId,
lastMessageSenderId: lastMessageSenderId,
);
}
}

@HiveType(typeId: HiveTypeIds.usersInGroup)
class UserInGroup {
@HiveField(0)
UserModel user;

@HiveField(1)
bool isAdmin;

UserInGroup({required this.user, required this.isAdmin});
}
//--------------------------------------------------------------
import 'package:chattr/core/services/supabase/supabase_client_manager.dart';
import 'package:chattr/core/services/supabase/supabase_error.dart';
import 'package:chattr/features/group_chats/data/repos/add_and_remove_admin_repo/add_and_remove_admin_repo.dart';
import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddAndRemoveAdminRepoImpl implements AddAndRemoveAdminRepo {
final SupabaseClientManager \_clientManager;

AddAndRemoveAdminRepoImpl(this.\_clientManager);
SupabaseClient get \_client => \_clientManager.client;

@override
Future<Either<SupabaseError, Unit>> addAdminAndRemove({
required String groupId,
required String userId,
required bool isAdmin,
}) async {
try {
await \_client
.from('group_members')
.update({'is_admin': !isAdmin})
.eq('group_id', groupId)
.eq('user_id', userId);
await Future.delayed(const Duration(milliseconds: 1500));
return right(unit);
} catch (e) {
return left(SupabaseError(message: '$e'));
}
}
}
//----------------------------------------------------------------------
import 'package:chattr/core/services/supabase/supabase_error.dart';
import 'package:dartz/dartz.dart';

abstract interface class AddAndRemoveAdminRepo {
Future<Either<SupabaseError, Unit>> addAdminAndRemove({
required String groupId,
required String userId,
required bool isAdmin,
});
}
//-----------------------------------------------------------------------
import 'dart:io';

import 'package:chattr/core/services/supabase/supabase_crud_services.dart';
import 'package:chattr/core/services/supabase/supabase_error.dart';
import 'package:chattr/core/services/supabase/supabase_storage.dart';
import 'package:chattr/features/group_chats/data/models/group_members_model.dart';
import 'package:chattr/features/group_chats/data/models/group_model.dart';
import 'package:chattr/features/group_chats/data/repos/create_group_repo/create_group_repo.dart';
import 'package:dartz/dartz.dart';

class CreateGroupRepoImpl implements CreateGroupRepo {
const CreateGroupRepoImpl({
required SupabaseCrudServices crud,
required SupabaseStorage storage,
}) : \_crud = crud,
\_storage = storage;

final SupabaseCrudServices \_crud;
final SupabaseStorage \_storage;

@override
Future<Either<SupabaseError, String>> uploadGroupImage(File imageFile) async {
try {
final path = await \_storage.uploadImage(
file: imageFile,
storageFile: 'group_image',
);
final url = \_storage.getFileUrl(path: path, storageFile: 'group_image');
return right(url);
} catch (e) {
return left(SupabaseError(message: '$e'));
}
}

@override
Future<Either<SupabaseError, String>> createGroup({
required String groupName,
required String imageUrl,
required String createdBy,
}) async {
try {
final groupData = GroupModel(
createdBy: createdBy,
name: groupName,
createdAt: DateTime.now().toUtc(),
image: imageUrl,
lastMessage: null,
lastMessageTime: null,
);

      final response = await _crud.post(
        table: 'groups',
        data: groupData.toJson(),
      );

      return right(response['group_id'] as String);
    } catch (e) {
      return left(SupabaseError(message: '$e'));
    }

}

@override
Future<Either<SupabaseError, Unit>> addGroupMember({
required String groupId,
required String userId,
}) async {
try {
final member = GroupMemberModel(groupId: groupId, userId: userId);
await \_crud.postWithoutSelect(
table: 'group_members',
data: member.toJson(),
);
return right(unit);
} catch (e) {
return left(SupabaseError(message: '$e'));
}
}
}
//-------------------------------------------------------------------
import 'dart:io';

import 'package:chattr/core/services/supabase/supabase_error.dart';
import 'package:dartz/dartz.dart';

abstract interface class CreateGroupRepo {
Future<Either<SupabaseError, String>> uploadGroupImage(File imageFile);

Future<Either<SupabaseError, String>> createGroup({
required String groupName,
required String imageUrl,
required String createdBy,
});

Future<Either<SupabaseError, Unit>> addGroupMember({
required String groupId,
required String userId,
});
}
//---------------------------------------------------------------
import 'package:chattr/core/services/supabase/supabase_client_manager.dart';
import 'package:chattr/core/services/supabase/supabase_error.dart';
import 'package:chattr/features/group_chats/data/repos/delete_member_repo/delete_member_repo.dart';
import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeleteMemberRepoImpl implements DeleteMemberRepo {
final SupabaseClientManager \_clientManager;
DeleteMemberRepoImpl(this.\_clientManager);
SupabaseClient get \_client => \_clientManager.client;
@override
Future<Either<SupabaseError, Unit>> deleteMember({
required String groupId,
required String userId,
}) async {
try {
await \_client
.from('group_members')
.delete()
.eq('group_id', groupId)
.eq('user_id', userId);

      await Future.delayed(const Duration(seconds: 1));
      return const Right(unit);
    } catch (e) {
      return Left(SupabaseError(message: "$e"));
    }

}
}
//--------------------------------------------------------------------
import 'package:chattr/core/services/supabase/supabase_error.dart';
import 'package:dartz/dartz.dart';

abstract interface class DeleteMemberRepo {
Future<Either<SupabaseError, Unit>> deleteMember({
required String groupId,
required String userId,
});
}
//-----------------------------------------------------
import 'dart:io';

import 'package:chattr/core/services/supabase/supabase_crud_services.dart';
import 'package:chattr/core/services/supabase/supabase_error.dart';
import 'package:chattr/core/services/supabase/supabase_storage.dart';
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:chattr/features/group_chats/data/models/group_members_model.dart';
import 'package:chattr/features/group_chats/data/models/group_model.dart';
import 'package:chattr/features/group_chats/data/repos/edit_group_data_repo/edit_group_data_repo.dart';
import 'package:dartz/dartz.dart';

class EditGroupDataRepoImpl implements EditGroupDataRepo {
final SupabaseCrudServices \_crud;
final SupabaseStorage \_storage;
EditGroupDataRepoImpl({
required SupabaseCrudServices crud,
required SupabaseStorage storage,
}) : \_crud = crud,
\_storage = storage;

@override
Future<Either<SupabaseError, Unit>> editGrroupDataRepo({
required GroupModel groupData,
required String? name,
required List<UserModel> members,
required File? newImageFile,
}) async {
try {
Map<String, dynamic> data = {};

      if (name != null && name.trim().isNotEmpty) {
        data['name'] = name;
      }

      if (newImageFile != null) {
        final String newImagePath = await _storage.updateImage(
          newFile: newImageFile,
          oldPath: groupData.image!,
          storageFile: 'group_image',
        );
        final String imagePath = _storage.getFileUrl(
          path: newImagePath,
          storageFile: 'group_image',
        );
        data['image'] = imagePath;
      }
      if (members.isNotEmpty) {
        for (var m in members) {
          final GroupMemberModel member = GroupMemberModel(
            groupId: groupData.id!,
            userId: m.id!,
          );
          await _crud.postWithoutSelect(
            table: 'group_members',
            data: member.toJson(),
          );
        }
      }

      await _crud.put(
        table: "groups",
        data: data,
        column: "group_id",
        id: groupData.id,
      );
      return const Right(unit);
    } catch (e) {
      return Left(SupabaseError(message: '$e'));
    }

}
}
//-------------------------------------------------
import 'dart:io';

import 'package:chattr/core/services/supabase/supabase_error.dart';
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:chattr/features/group_chats/data/models/group_model.dart';
import 'package:dartz/dartz.dart';

abstract interface class EditGroupDataRepo {
Future<Either<SupabaseError, Unit>> editGrroupDataRepo({
required GroupModel groupData,
required String? name,
required List<UserModel> members,
required File? newImageFile,
});
}
//---------------------------------------------------
import 'package:chattr/core/services/hive/hive_services.dart';
import 'package:chattr/core/services/supabase/supabase_client_manager.dart';
import 'package:chattr/core/services/supabase/supabase_error.dart';
import 'package:chattr/features/group_chats/data/models/group_message_model.dart';
import 'package:chattr/features/group_chats/data/repos/fetch_group_messages_repo/fetch_group_messages_repo.dart';
import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FetchGroupMessagesRepoImpl implements FetchGroupMessagesRepo {
const FetchGroupMessagesRepoImpl({
required SupabaseClientManager clientManager,
}) : \_clientManager = clientManager;

final SupabaseClientManager \_clientManager;
SupabaseClient get \_client => \_clientManager.client;

// ─── Server ─────────────────────────────────────────────────────

@override
Future<Either<SupabaseError, List<GroupMessageModel>>> fetchInitialMessages({
required String groupId,
required int pageSize,
}) async {
try {
final rows = await \_client
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
final rows = await \_client
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
await \_client
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
await \_client
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
await \_client
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
final rows = await \_client
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
//-----------------------------------------------------
import 'package:chattr/core/services/supabase/supabase_error.dart';
import 'package:chattr/features/group_chats/data/models/group_message_model.dart';
import 'package:dartz/dartz.dart';

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
//----------------------------------------------------------------------
import 'package:chattr/core/services/hive/hive_services.dart';
import 'package:chattr/core/services/supabase/supabase_client_manager.dart';
import 'package:chattr/core/services/supabase/supabase_error.dart';
import 'package:chattr/features/group_chats/data/models/group_model.dart';
import 'package:chattr/features/group_chats/data/repos/fetch_groups_repo/fetch_groups_repo.dart';
import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FetchGroupsRepoImpl implements FetchGroupsRepo {
const FetchGroupsRepoImpl(this.\_clientManager);

final SupabaseClientManager \_clientManager;
SupabaseClient get \_client => \_clientManager.client;

@override
Future<Either<SupabaseError, List<String>>> fetchMyGroupIds(
String userId,
) async {
try {
final rows = await \_client
.from('group_members')
.select('group_id')
.eq('user_id', userId);

      final ids = rows.map<String>((e) => e['group_id'] as String).toList();
      return right(ids);
    } catch (e) {
      return left(SupabaseError(message: '$e'));
    }

}

@override
Future<Either<SupabaseError, List<Map<String, dynamic>>>> fetchGroupMembers(
List<String> groupIds,
) async {
try {
final rows = await \_client
.from('group_members')
.select('group_id, is_admin, user:messenger_users(\*)')
.inFilter('group_id', groupIds);

      return right(List<Map<String, dynamic>>.from(rows));
    } catch (e) {
      return left(SupabaseError(message: '$e'));
    }

}

@override
Future<Either<SupabaseError, List<Map<String, dynamic>>>> fetchGroupsData(
List<String> groupIds,
) async {
try {
final rows = await \_client
.from('groups')
.select('\*')
.inFilter('group_id', groupIds);

      return right(List<Map<String, dynamic>>.from(rows));
    } catch (e) {
      return left(SupabaseError(message: '$e'));
    }

}

@override
Future<Either<SupabaseError, Map<String, int>>> fetchUnreadCounts(
String userId,
) async {
try {
final rows = await \_client.rpc(
'get_groups_unread_count',
params: {'p_user_id': userId},
);

      final map = <String, int>{
        for (final e in rows) e['group_id'] as String: e['unread_count'] as int,
      };

      return right(map);
    } catch (e) {
      return left(SupabaseError(message: '$e'));
    }

}

@override
Future<Either<SupabaseError, List<GroupModel>>> getLocalGroups() async {
try {
final groups = await HiveService.getGroups();
return right(groups);
} catch (e) {
return left(SupabaseError(message: '$e'));
}
}

@override
Future<Either<SupabaseError, Unit>> saveGroupsLocally(
List<GroupModel> groups,
) async {
try {
await HiveService.replaceGroups(groups);
return right(unit);
} catch (e) {
return left(SupabaseError(message: '$e'));
}
}
}
//--------------------------------------------------
import 'package:chattr/core/services/supabase/supabase_error.dart';
import 'package:chattr/features/group_chats/data/models/group_model.dart';
import 'package:dartz/dartz.dart';

abstract interface class FetchGroupsRepo {
Future<Either<SupabaseError, List<String>>> fetchMyGroupIds(String userId);

Future<Either<SupabaseError, List<Map<String, dynamic>>>> fetchGroupMembers(
List<String> groupIds,
);

Future<Either<SupabaseError, List<Map<String, dynamic>>>> fetchGroupsData(
List<String> groupIds,
);

Future<Either<SupabaseError, Map<String, int>>> fetchUnreadCounts(
String userId,
);

// ─── Hive ───────────────────────────────────────────────────────
Future<Either<SupabaseError, List<GroupModel>>> getLocalGroups();

Future<Either<SupabaseError, Unit>> saveGroupsLocally(
List<GroupModel> groups,
);
}
//------------------------------------------------------------
import 'dart:io';

import 'package:chattr/core/services/supabase/supabase_crud_services.dart';
import 'package:chattr/core/services/supabase/supabase_error.dart';
import 'package:chattr/core/services/supabase/supabase_storage.dart';
import 'package:chattr/features/group_chats/data/models/group_message_model.dart';
import 'package:chattr/features/group_chats/data/repos/send_group_message_repo/send_group_message_repo.dart';
import 'package:dartz/dartz.dart';

class SendGroupMessageRepoImpl implements SendGroupMessageRepo {
const SendGroupMessageRepoImpl({
required SupabaseCrudServices crud,
required SupabaseStorage storage,
}) : \_crud = crud,
\_storage = storage;

final SupabaseCrudServices \_crud;
final SupabaseStorage \_storage;

@override
Future<Either<SupabaseError, GroupMessageModel>> sendMessage(
GroupMessageModel message,
) async {
try {
final response = await \_crud.post(
table: 'group_messages',
data: message.toJson(),
);

      return right(GroupMessageModel.fromJson(response));
    } catch (e) {
      return left(SupabaseError(message: '$e'));
    }

}

@override
Future<Either<SupabaseError, String>> uploadImage(File imageFile) async {
try {
final path = await \_storage.uploadImage(
file: imageFile,
storageFile: 'group_image',
);
final url = \_storage.getFileUrl(path: path, storageFile: 'group_image');
return right(url);
} catch (e) {
return left(SupabaseError(message: '$e'));
}
}

@override
Future<Either<SupabaseError, String>> uploadAudio(File audioFile) async {
try {
final path = await \_storage.uploadAudio(
file: audioFile,
storageFile: 'chat-audio',
);
final url = \_storage.getFileUrl(path: path, storageFile: 'chat-audio');
return right(url);
} catch (e) {
return left(SupabaseError(message: '$e'));
}
}
}
//----------------------------------------------------------
import 'dart:io';

import 'package:chattr/core/services/supabase/supabase_error.dart';
import 'package:chattr/features/group_chats/data/models/group_message_model.dart';
import 'package:dartz/dartz.dart';

abstract interface class SendGroupMessageRepo {
Future<Either<SupabaseError, GroupMessageModel>> sendMessage(
GroupMessageModel message,
);

Future<Either<SupabaseError, String>> uploadImage(File imageFile);

Future<Either<SupabaseError, String>> uploadAudio(File audioFile);
}
//----------------------------------------------------------------
import 'package:chattr/features/group_chats/data/repos/add_and_remove_admin_repo/add_and_remove_admin_repo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'add_and_remove_admin_state.dart';

class AddAndRemoveAdminCubit extends Cubit<AddAndRemoveAdminState> {
AddAndRemoveAdminCubit({required AddAndRemoveAdminRepo repo})
: \_repo = repo,
super(AddAndRemoveAdminInitial());

final AddAndRemoveAdminRepo \_repo;
int? locaIndex;
Future<void> addAdminAndRemove({
required String groupId,
required String userId,
required bool isAdmin,
}) async {
emit(AddAndRemoveAdminLoading());
final result = await \_repo.addAdminAndRemove(
groupId: groupId,
userId: userId,
isAdmin: isAdmin,
);
result.fold(
(e) => emit(AddAndRemoveAdminFailure(errorMessage: "$e")),
(u) => emit(AddAndRemoveAdminSuccess()),
);
}
}
//-----------------------------------------------------------
part of 'add_and_remove_admin_cubit.dart';

@immutable
sealed class AddAndRemoveAdminState {}

final class AddAndRemoveAdminInitial extends AddAndRemoveAdminState {}

final class AddAndRemoveAdminSuccess extends AddAndRemoveAdminState {}

final class AddAndRemoveAdminLoading extends AddAndRemoveAdminState {
AddAndRemoveAdminLoading();
}

final class AddAndRemoveAdminFailure extends AddAndRemoveAdminState {
final String errorMessage;
AddAndRemoveAdminFailure({required this.errorMessage});
}
//---------------------------------------------------------------
import 'dart:io';

import 'package:chattr/core/services/supabase/supabase_auth_services.dart';
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:chattr/features/group_chats/data/repos/create_group_repo/create_group_repo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'create_group_state.dart';

class CreateGroupCubit extends Cubit<CreateGroupState> {
CreateGroupCubit({required CreateGroupRepo repo, required AuthService auth})
: \_repo = repo,
\_auth = auth,
super(CreateGroupInitial());

final CreateGroupRepo \_repo;
final AuthService \_auth;

Future<void> creatGroup({
required String groupName,
required File groupImageFile,
required List<UserModel> members,
}) async {
emit(CreateGroupLoading());

    final myId = _auth.currentUser!.id;

    // 1️⃣ upload الصورة
    final imageResult = await _repo.uploadGroupImage(groupImageFile);
    if (imageResult.isLeft()) {
      emit(
        CreateGroupfailure(
          errorMessage: imageResult.fold((l) => l.message, (_) => ''),
        ),
      );
      return;
    }
    final imageUrl = imageResult.fold((_) => '', (r) => r);

    // 2️⃣ إنشاء الـ group
    final groupResult = await _repo.createGroup(
      groupName: groupName,
      imageUrl: imageUrl,
      createdBy: myId,
    );
    if (groupResult.isLeft()) {
      emit(
        CreateGroupfailure(
          errorMessage: groupResult.fold((l) => l.message, (_) => ''),
        ),
      );
      return;
    }
    final groupId = groupResult.fold((_) => '', (r) => r);

    // 3️⃣ إضافة الـ members
    for (final member in members) {
      final memberResult = await _repo.addGroupMember(
        groupId: groupId,
        userId: member.id!,
      );
      if (memberResult.isLeft()) {
        emit(
          CreateGroupfailure(
            errorMessage: memberResult.fold((l) => l.message, (_) => ''),
          ),
        );
        return;
      }
    }

    await Future.delayed(const Duration(seconds: 1));
    emit(CreateGroupSuccess());

}
}
//----------------------------------------------------------------
part of 'create_group_cubit.dart';

@immutable
sealed class CreateGroupState {}

final class CreateGroupInitial extends CreateGroupState {}

final class CreateGroupLoading extends CreateGroupState {}

final class CreateGroupSuccess extends CreateGroupState {}

final class CreateGroupfailure extends CreateGroupState {
final String errorMessage;
CreateGroupfailure({required this.errorMessage});
}
//------------------------------------------------------
import 'package:chattr/core/services/supabase/supabase_crud_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'delete_group_state.dart';

class DeleteGroupCubit extends Cubit<DeleteGroupState> {
DeleteGroupCubit(this.\_crud) : super(DeleteGroupCubitInitial());
final SupabaseCrudServices \_crud;
Future<void> deleteGroup({required String groupId}) async {
emit(DeleteGroupCubitLoading());
try {
await \_crud.delete(table: "groups", column: "group_id", id: groupId);
emit(DeleteGroupCubitSucess());
} catch (e) {
emit(DeleteGroupCubitFailure(errorMessage: "$e"));
}
}
}
//---------------------------------------------
part of 'delete_group_cubit.dart';

@immutable
sealed class DeleteGroupState {}

final class DeleteGroupCubitInitial extends DeleteGroupState {}

final class DeleteGroupCubitLoading extends DeleteGroupState {}

final class DeleteGroupCubitSucess extends DeleteGroupState {}

final class DeleteGroupCubitFailure extends DeleteGroupState {
final String errorMessage;
DeleteGroupCubitFailure({required this.errorMessage});
}
//---------------------------------------------------------
import 'package:chattr/features/group_chats/data/repos/delete_member_repo/delete_member_repo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'delete_member_state.dart';

class DeleteMemberCubit extends Cubit<DeleteMemberState> {
DeleteMemberCubit(this.\_repo) : super(DeleteMemberInitial());
final DeleteMemberRepo \_repo;
Future<void> deleteMember({
required String groupId,
required String userId,
}) async {
emit(DeleteMemberLoading());
final result = await \_repo.deleteMember(groupId: groupId, userId: userId);
result.fold(
(e) => emit(DeleteMemberFailure(erroMessage: '$e')),
(u) => emit(DeleteMemberSuccess()),
);
}
}
//--------------------------------------------------------------
part of 'delete_member_cubit.dart';

@immutable
sealed class DeleteMemberState {}

final class DeleteMemberInitial extends DeleteMemberState {}

final class DeleteMemberLoading extends DeleteMemberState {}

final class DeleteMemberSuccess extends DeleteMemberState {}

final class DeleteMemberFailure extends DeleteMemberState {
final String erroMessage;
DeleteMemberFailure({required this.erroMessage});
}
//------------------------------------------------------------
import 'dart:io';

import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:chattr/features/group_chats/data/models/group_model.dart';
import 'package:chattr/features/group_chats/data/repos/edit_group_data_repo/edit_group_data_repo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'edit_group_data_state.dart';

class EditGroupDataCubit extends Cubit<EditGroupDataState> {
EditGroupDataCubit(this.\_editGroupDataRepo) : super(EditGroupDataInitial());
final EditGroupDataRepo \_editGroupDataRepo;
Future<void> editGroupData({
required GroupModel groupData,
required String? name,
required List<UserModel> members,
required File? newImageFile,
}) async {
emit(EditGroupDataLoading());
final result = await \_editGroupDataRepo.editGrroupDataRepo(
groupData: groupData,
name: name,
members: members,
newImageFile: newImageFile,
);
result.fold(
(e) => emit(EditGroupDataFailure(errorMessage: '$e')),
(u) => emit(EditGroupDataSucess()),
);
}
}
//--------------------------------------------------------------------
part of 'edit_group_data_cubit.dart';

@immutable
sealed class EditGroupDataState {}

final class EditGroupDataInitial extends EditGroupDataState {}

final class EditGroupDataLoading extends EditGroupDataState {}

final class EditGroupDataSucess extends EditGroupDataState {}

final class EditGroupDataFailure extends EditGroupDataState {
final String errorMessage;
EditGroupDataFailure({required this.errorMessage});
}
//----------------------------------------------------------------------
import 'dart:async';

import 'package:chattr/core/cache/users_cache.dart';
import 'package:chattr/core/services/hive/hive_services.dart';
import 'package:chattr/core/services/supabase/supabase_auth_services.dart';
import 'package:chattr/core/services/supabase/supabase_client_manager.dart';
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:chattr/features/group_chats/data/models/group_message_model.dart';
import 'package:chattr/features/group_chats/data/repos/fetch_group_messages_repo/fetch_group_messages_repo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'fetch_group_messages_state.dart';

class FetchGroupMessagesCubit extends Cubit<FetchGroupMessagesState> {
FetchGroupMessagesCubit({
required FetchGroupMessagesRepo repo,
required SupabaseClientManager client,
required AuthService auth,
}) : \_repo = repo,
\_auth = auth,
\_clientManager = client,
super(FetchGroupMessagesInitial());

final FetchGroupMessagesRepo \_repo;
final AuthService \_auth;
final SupabaseClientManager \_clientManager;
SupabaseClient get \_client => \_clientManager.client;

final Map<String, List<GroupMessageModel>> \_cache = {};
final Map<String, DateTime?> \_oldestDate = {};
final Map<String, bool> \_hasMoreMap = {};
final Map<String, bool> \_loadingMoreMap = {};
final Map<String, StreamSubscription> \_streams = {};
final Set<String> \_pendingTempIds = {};

static const int \_pageSize = 30;

bool hasMore(String groupId) => \_hasMoreMap[groupId] ?? true;
List<GroupMessageModel>? getMessages(String groupId) => \_cache[groupId];

// ─────────────────────────────────────────────────────────────────
// LOAD INITIAL
// ─────────────────────────────────────────────────────────────────

Future<void> loadInitialMessages({required String groupId}) async {
final alreadyCached = \_cache[groupId]?.isNotEmpty == true;
final alreadySubscribed = \_streams.containsKey(groupId);

    if (alreadyCached && alreadySubscribed) {
      _emit(groupId);
      return;
    }

    if (!alreadyCached) emit(FetchGroupMessagesLoading());

    // 1️⃣ Hive
    if (!alreadyCached) {
      final localResult = await _repo.getLocalMessages(
        groupId: groupId,
        limit: _pageSize,
      );
      localResult.fold((l) => debugPrint('❌ getLocalMessages (group): $l'), (
        local,
      ) {
        if (local.isNotEmpty) {
          _cache[groupId] = List.from(local);
          _emit(groupId);
        }
      });
    }

    // 2️⃣ Server — خارج الـ fold عشان الـ async يشتغل صح
    if (!alreadyCached) {
      final serverResult = await _repo.fetchInitialMessages(
        groupId: groupId,
        pageSize: _pageSize,
      );

      if (serverResult.isLeft()) {
        final err = serverResult.fold((l) => l.message, (_) => '');
        debugPrint('❌ fetchInitialMessages (group): $err');
        if (_cache[groupId]?.isNotEmpty != true) {
          emit(FetchGroupMessagesFailure(errorMessage: err));
        }
      } else {
        final serverMsgs = serverResult.fold(
          (_) => <GroupMessageModel>[],
          (r) => r,
        );

        await _cacheMissingUsers(serverMsgs);
        final enriched = await _attachLocalPaths(serverMsgs);
        _cache[groupId] = _mergeWithCache(_cache[groupId], enriched);

        if (serverMsgs.isNotEmpty) {
          _oldestDate[groupId] = serverMsgs.first.createdAt;
          _hasMoreMap[groupId] = serverMsgs.length == _pageSize;
        } else {
          _hasMoreMap[groupId] = false;
        }

        await _persistAll(enriched);
        _emit(groupId);
      }
    }

    // 3️⃣ Realtime
    if (!alreadySubscribed) _subscribe(groupId);

}

// ─────────────────────────────────────────────────────────────────
// REALTIME — sync بالكامل، مفيش async في الـ snapshot
// ─────────────────────────────────────────────────────────────────

void \_subscribe(String groupId) {
\_cache.putIfAbsent(groupId, () => []);
\_streams[groupId]?.cancel();

    _streams[groupId] = _client
        .from('group_messages')
        .stream(primaryKey: ['message_id'])
        .eq('group_id', groupId)
        .listen((event) {
          if (isClosed) return;
          final incoming = event
              .map<GroupMessageModel>((r) => GroupMessageModel.fromJson(r))
              .toList();
          _processSnapshot(groupId, incoming);
        }, onError: (e) => debugPrint('❌ Group stream error ($groupId): $e'));

}

// ✅ sync بالكامل — fire and forget للـ Hive
void \_processSnapshot(String groupId, List<GroupMessageModel> incoming) {
final list = \_cache[groupId]!;
bool dirty = false;

    for (final msg in incoming) {
      if (_pendingTempIds.contains(msg.tempId)) continue;

      final idx = _findIndex(list, msg);
      final existingPath = idx != -1 ? list[idx].localPath : null;
      final enriched = existingPath != null
          ? msg.copyWith(localPath: existingPath)
          : msg;

      if (idx != -1) {
        final old = list[idx];
        final finalMsg = old.messageId == null
            ? enriched.copyWith(createdAt: old.createdAt)
            : enriched;

        if (_equal(old, finalMsg)) continue;

        list[idx] = finalMsg;
        // ✅ fire and forget
        _repo
            .saveMessageLocally(finalMsg)
            .then((r) => r.fold((l) => debugPrint('save failed: $l'), (_) {}));
      } else {
        list.add(enriched);
        _repo
            .saveMessageLocally(enriched)
            .then((r) => r.fold((l) => debugPrint('save failed: $l'), (_) {}));
      }

      dirty = true;
    }

    if (dirty) _sortAndEmit(groupId);

}

// ─────────────────────────────────────────────────────────────────
// PAGINATION
// ─────────────────────────────────────────────────────────────────

Future<void> loadMoreMessages(String groupId) async {
if (\_hasMoreMap[groupId] != true) return;
if (\_loadingMoreMap[groupId] == true) return;
if (\_oldestDate[groupId] == null) return;

    _loadingMoreMap[groupId] = true;

    try {
      final result = await _repo.fetchMoreMessages(
        groupId: groupId,
        before: _oldestDate[groupId]!,
        pageSize: _pageSize,
      );

      if (result.isLeft()) {
        debugPrint(
          'loadMoreMessages (group) failed: ${result.fold((l) => l.message, (_) => '')}',
        );
        return;
      }

      final msgs = result.fold((_) => <GroupMessageModel>[], (r) => r);

      if (msgs.isEmpty) {
        _hasMoreMap[groupId] = false;
      } else {
        // ✅ async خارج الـ fold
        await _cacheMissingUsers(msgs);

        final reversed = msgs.reversed.toList();
        final existingIds = _cache[groupId]!.map((m) => m.messageId).toSet();
        final fresh = reversed
            .where((m) => !existingIds.contains(m.messageId))
            .toList();

        _cache[groupId]!.insertAll(0, fresh);
        _oldestDate[groupId] = reversed.first.createdAt;
        _hasMoreMap[groupId] = msgs.length == _pageSize;

        await _persistAll(fresh);
      }

      _sortAndEmit(groupId);
    } finally {
      // ✅ دايماً بيتنفذ
      _loadingMoreMap[groupId] = false;
    }

}

// ─────────────────────────────────────────────────────────────────
// MARK AS READ
// ─────────────────────────────────────────────────────────────────

Future<void> markGroupAsRead({required String groupId}) async {
final result = await _repo.markGroupAsRead(
groupId: groupId,
userId: \_auth.currentUser!.id,
);
result.fold((l) => debugPrint('❌ markGroupAsRead: $l'), (_) {});
}

// ─────────────────────────────────────────────────────────────────
// LOCAL OPS
// ─────────────────────────────────────────────────────────────────

void addLocalMessage({
required String groupId,
required GroupMessageModel message,
}) {
\_cache.putIfAbsent(groupId, () => []);
\_cache[groupId]!.add(message);
\_pendingTempIds.add(message.tempId);
\_emit(groupId);
}

Future<void> replaceTempMessage({
required String groupId,
required String tempId,
required GroupMessageModel serverMessage,
}) async {
\_pendingTempIds.remove(tempId);

    final list = _cache[groupId];
    if (list == null) return;

    final idx = list.indexWhere((m) => m.tempId == tempId);

    if (idx == -1) {
      final streamIdx = list.indexWhere(
        (m) => m.messageId == serverMessage.messageId,
      );
      if (streamIdx != -1) {
        final old = list[streamIdx];
        list[streamIdx] = old.copyWith(
          localPath: serverMessage.localPath ?? old.localPath,
          status: GroupMessageStatus.sent,
        );
        _repo
            .saveMessageLocally(list[streamIdx])
            .then((r) => r.fold((l) => debugPrint('save failed: $l'), (_) {}));
        _emit(groupId);
      }
      return;
    }

    final temp = list[idx];
    final updated = serverMessage.copyWith(
      createdAt: temp.createdAt,
      localPath: serverMessage.localPath ?? temp.localPath,
    );

    list[idx] = updated;

    await _repo.deleteMessageLocally(tempId);
    if (serverMessage.messageId != null) {
      await _repo.saveMessageLocally(updated);
    }

    _emit(groupId);

}

void markMessageFailed({required String groupId, required String tempId}) {
\_pendingTempIds.remove(tempId);

    final list = _cache[groupId];
    if (list == null) return;

    final idx = list.indexWhere((m) => m.tempId == tempId);
    if (idx == -1) return;

    list[idx] = list[idx].copyWith(status: GroupMessageStatus.failed);
    _emit(groupId);

}

// ─────────────────────────────────────────────────────────────────
// DELETE
// ─────────────────────────────────────────────────────────────────

Future<void> deleteGroupMessages({
required String groupId,
required List<GroupMessageModel> messages,
}) async {
final list = \_cache[groupId];
if (list == null) return;

    for (final msg in messages) {
      final idx = list.indexWhere((m) => m.messageId == msg.messageId);
      if (idx == -1) continue;

      list[idx] = list[idx].copyWith(status: GroupMessageStatus.deleting);
      _emit(groupId);

      final result = await _repo.deleteMessages([msg.messageId!]);
      result.fold(
        (l) {
          list[idx] = list[idx].copyWith(
            status: GroupMessageStatus.deleteFailed,
          );
        },
        (_) {
          list[idx] = list[idx].copyWith(
            isDeleted: true,
            status: GroupMessageStatus.sent,
          );
        },
      );

      _repo
          .saveMessageLocally(list[idx])
          .then((r) => r.fold((l) => debugPrint('save failed: $l'), (_) {}));
    }

    _emit(groupId);

}

// ─────────────────────────────────────────────────────────────────
// EDIT
// ─────────────────────────────────────────────────────────────────

Future<void> editMessageGroup({
required String groupId,
required GroupMessageModel message,
required String content,
}) async {
final list = \_cache[groupId];
if (list == null) return;

    final idx = list.indexWhere((m) => m.messageId == message.messageId);
    if (idx == -1) return;

    list[idx] = list[idx].copyWith(status: GroupMessageStatus.editing);
    _emit(groupId);

    final result = await _repo.editMessage(
      messageId: message.messageId!,
      content: content,
    );

    result.fold(
      (l) {
        list[idx] = list[idx].copyWith(status: GroupMessageStatus.editingFaild);
      },
      (_) {
        list[idx] = list[idx].copyWith(
          content: content,
          status: GroupMessageStatus.sent,
        );
      },
    );

    _repo
        .saveMessageLocally(list[idx])
        .then((r) => r.fold((l) => debugPrint('save failed: $l'), (_) {}));
    _emit(groupId);

}

// ─────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────

int \_findIndex(List<GroupMessageModel> list, GroupMessageModel msg) {
return list.indexWhere(
(m) =>
(msg.messageId != null && m.messageId == msg.messageId) ||
(msg.tempId.isNotEmpty && m.tempId == msg.tempId),
);
}

bool \_equal(GroupMessageModel a, GroupMessageModel b) {
return a.messageId == b.messageId &&
a.content == b.content &&
a.status == b.status &&
a.isDeleted == b.isDeleted &&
a.localPath == b.localPath;
}

List<GroupMessageModel> \_mergeWithCache(
List<GroupMessageModel>? existing,
List<GroupMessageModel> incoming,
) {
if (existing == null) return incoming;
return incoming.map((msg) {
final cached = existing.firstWhere(
(m) =>
(m.messageId != null && m.messageId == msg.messageId) ||
m.tempId == msg.tempId,
orElse: () => msg,
);
return cached.localPath != null
? msg.copyWith(localPath: cached.localPath)
: msg;
}).toList();
}

Future<List<GroupMessageModel>> \_attachLocalPaths(
List<GroupMessageModel> msgs,
) async {
return Future.wait(
msgs.map((msg) async {
final isMedia =
msg.messageType == GroupMessageType.image ||
msg.messageType == GroupMessageType.voice;
if (!isMedia || msg.messageId == null) return msg;
final saved = await \_repo.getLocalMessage(msg.messageId!);
return saved.fold(
(l) {
debugPrint('getLocalMessage failed: $l');
return msg;
},
(saved) {
if (saved?.localPath == null) return msg;
return msg.copyWith(localPath: saved!.localPath);
},
);
}),
);
}

Future<void> \_cacheMissingUsers(List<GroupMessageModel> msgs) async {
final missing = msgs
.map((m) => m.senderId)
.where((id) => !UsersCache.contains(id))
.toSet()
.toList();

    if (missing.isEmpty) return;

    final result = await _repo.fetchMissingUsers(missing);
    result.fold((l) => debugPrint('fetchMissingUsers failed: $l'), (rows) {
      for (final r in rows) {
        final user = UserModel.fromJson(r);
        UsersCache.addUser(user);
        HiveService.saveUser(user);
      }
    });

}

// ✅ async صح — بيتانتظر في loadInitialMessages و loadMoreMessages
Future<void> _persistAll(List<GroupMessageModel> msgs) async {
for (final m in msgs) {
final result = await \_repo.saveMessageLocally(m);
result.fold((l) => debugPrint('save failed: $l'), (_) {});
}
}

void \_sortAndEmit(String groupId) {
\_cache[groupId]!.sort((a, b) => a.createdAt.compareTo(b.createdAt));
\_emit(groupId);
}

// ✅ groupId في الـ state — بيمنع مشكلة الـ UI بتاع group تاني
void \_emit(String groupId) {
if (isClosed) return;
emit(
FetchGroupMessagesSuccess(
groupId: groupId,
messages: List.unmodifiable(\_cache[groupId] ?? []),
),
);
}

@override
Future<void> close() {
for (final s in \_streams.values) {
s.cancel();
}
return super.close();
}
}
//--------------------------------------------------------------------------
part of 'fetch_group_messages_cubit.dart';

@immutable
sealed class FetchGroupMessagesState {}

final class FetchGroupMessagesInitial extends FetchGroupMessagesState {}

final class FetchGroupMessagesLoading extends FetchGroupMessagesState {}

final class FetchGroupMessagesSuccess extends FetchGroupMessagesState {
final String groupId;
final List<GroupMessageModel> messages;

FetchGroupMessagesSuccess({required this.messages, required this.groupId});
}

final class FetchMoreGroupMessages extends FetchGroupMessagesState {
final List<GroupMessageModel> messages;
FetchMoreGroupMessages({required this.messages});
}

final class FetchGroupMessagesFailure extends FetchGroupMessagesState {
final String errorMessage;
FetchGroupMessagesFailure({required this.errorMessage});
}
//----------------------------------------------------------------------
import 'dart:async';
import 'dart:io';

import 'package:chattr/core/services/supabase/supabase_auth_services.dart';
import 'package:chattr/core/services/supabase/supabase_client_manager.dart';
import 'package:chattr/features/group_chats/data/models/group_model.dart';
import 'package:chattr/features/group_chats/data/repos/fetch_groups_repo/fetch_groups_repo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'fetch_groups_state.dart';

class FetchGroupsCubit extends Cubit<FetchGroupsState> {
FetchGroupsCubit({
required FetchGroupsRepo repo,
required SupabaseClientManager client,
required AuthService auth,
}) : \_repo = repo,
\_auth = auth,
\_clientManager = client,
super(FetchGroupsInitial());

final FetchGroupsRepo \_repo;
final AuthService \_auth;
final SupabaseClientManager \_clientManager;

RealtimeChannel? \_membersChannel;
RealtimeChannel? \_groupsChannel;
RealtimeChannel? \_messagesChannel;
Timer? \_debounceTimer;

List<GroupModel> groupsCache = [];
List<String> \_groupIds = [];

// ─────────────────────────────────────────────────────────────────
// FETCH GROUPS — أول مرة فقط بتعمل loading
// ─────────────────────────────────────────────────────────────────

// ✅ بيمنع إعادة الـ fetch لو الـ cache موجود — نفس fix الـ private chats
Future<void> fetchGroupsIfNeeded() async {
if (groupsCache.isNotEmpty) {
emit(FetchGroupsSuccess(groups: List.from(groupsCache)));
return;
}
await fetchGroups();
}

Future<void> fetchGroups() async {
try {
emit(FetchGroupsLoading());

      // 1️⃣ Hive أولاً
      final localResult = await _repo.getLocalGroups();
      localResult.fold((l) => debugPrint('❌ getLocalGroups: $l'), (local) {
        if (local.isNotEmpty) {
          groupsCache = local;
          emit(FetchGroupsSuccess(groups: List.from(groupsCache)));
        }
      });

      // 2️⃣ Server
      await _fetchMembership();

      // 3️⃣ Realtime
      _listenToMembersChanges();
      _listenToGroupsChanges();
      _listenToMessagesChanges();
    } on AuthException catch (e) {
      emit(FetchGroupsFailure(errorMessage: e.message));
    } on SocketException {
      emit(FetchGroupsFailure(errorMessage: 'No internet connection'));
    } catch (e) {
      emit(FetchGroupsFailure(errorMessage: 'Unexpected error: $e'));
    }

}

// ─────────────────────────────────────────────────────────────────
// FETCH MEMBERSHIP — silent refresh بدون loading
// ─────────────────────────────────────────────────────────────────

Future<void> \_fetchMembership() async {
final myId = \_auth.currentUser!.id;

    // 1️⃣ جيب الـ group IDs
    final idsResult = await _repo.fetchMyGroupIds(myId);
    if (idsResult.isLeft()) {
      final err = idsResult.fold((l) => l.message, (_) => '');
      debugPrint('❌ fetchMyGroupIds: $err');
      if (groupsCache.isNotEmpty && !isClosed) {
        emit(FetchGroupsSuccess(groups: List.from(groupsCache)));
      } else if (!isClosed) {
        emit(FetchGroupsFailure(errorMessage: err));
      }
      return;
    }

    final newGroupIds = idsResult.fold((_) => <String>[], (r) => r);
    final groupsChanged = !_listEquals(_groupIds, newGroupIds);
    _groupIds = newGroupIds;

    if (_groupIds.isEmpty) {
      groupsCache = [];
      await _repo.saveGroupsLocally([]);
      if (!isClosed) emit(FetchGroupsSuccess(groups: []));
      return;
    }

    // 2️⃣ جيب الـ members
    final membersResult = await _repo.fetchGroupMembers(_groupIds);
    if (membersResult.isLeft()) {
      debugPrint(
        '❌ fetchGroupMembers: ${membersResult.fold((l) => l.message, (_) => '')}',
      );
      return;
    }
    final allMembers = membersResult.fold(
      (_) => <Map<String, dynamic>>[],
      (r) => r,
    );

    // 3️⃣ جيب بيانات الـ groups
    final groupsResult = await _repo.fetchGroupsData(_groupIds);
    if (groupsResult.isLeft()) {
      debugPrint(
        '❌ fetchGroupsData: ${groupsResult.fold((l) => l.message, (_) => '')}',
      );
      return;
    }
    final groupsResponse = groupsResult.fold(
      (_) => <Map<String, dynamic>>[],
      (r) => r,
    );

    // 4️⃣ Unread count
    final unreadResult = await _repo.fetchUnreadCounts(myId);
    final unreadMap = unreadResult.fold((_) => <String, int>{}, (r) => r);

    // 5️⃣ بناء الـ models
    final grouped = <String, Map<String, dynamic>>{};
    for (final member in allMembers) {
      final groupId = member['group_id'] as String;
      final userJson = member['user'] as Map<String, dynamic>;
      final isAdmin = member['is_admin'] ?? false;

      grouped.putIfAbsent(
        groupId,
        () => {'group_id': groupId, 'members': <Map<String, dynamic>>[]},
      );
      grouped[groupId]!['members'].add({'user': userJson, 'is_admin': isAdmin});
    }

    for (final group in groupsResponse) {
      final groupId = group['group_id'] as String;
      grouped[groupId]?.addAll(group);
    }

    groupsCache = grouped.values.map((data) {
      final groupId = data['group_id'] as String;
      return GroupModel.fromJson(
        data,
      ).copyWith(unreadCount: unreadMap[groupId] ?? 0);
    }).toList();

    // 6️⃣ Sort
    groupsCache.sort((a, b) {
      final aTime = a.lastMessageTime ?? DateTime(1970);
      final bTime = b.lastMessageTime ?? DateTime(1970);
      return bTime.compareTo(aTime);
    });

    // 7️⃣ Save Hive في الخلفية
    _repo.saveGroupsLocally(groupsCache);

    // 8️⃣ أعد الـ listeners لو الـ groups اتغيرت
    if (groupsChanged) {
      _listenToGroupsChanges();
      _listenToMessagesChanges();
    }

    if (!isClosed) {
      emit(FetchGroupsSuccess(groups: List.from(groupsCache)));
    }

}

// ─────────────────────────────────────────────────────────────────
// REALTIME LISTENERS
// ─────────────────────────────────────────────────────────────────

void \_listenToMembersChanges() {
\_membersChannel?.unsubscribe();

    _membersChannel = _clientManager.client
        .channel('members_${DateTime.now().millisecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'group_members',
          callback: (payload) {
            final newUserId = payload.newRecord['user_id'];
            final oldUserId = payload.oldRecord['user_id'];
            final groupId =
                payload.newRecord['group_id'] ?? payload.oldRecord['group_id'];

            final isCurrentUserAffected =
                newUserId == _auth.currentUser!.id ||
                oldUserId == _auth.currentUser!.id;

            if (isCurrentUserAffected || _groupIds.contains(groupId)) {
              _debouncedFetch();
            }
          },
        )
        .subscribe();

}

void \_listenToGroupsChanges() {
\_groupsChannel?.unsubscribe();
if (\_groupIds.isEmpty) return;

    _groupsChannel = _clientManager.client
        .channel('groups_${DateTime.now().millisecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'groups',
          callback: (payload) {
            final groupId =
                payload.newRecord['group_id'] ?? payload.oldRecord['group_id'];
            if (groupId != null && _groupIds.contains(groupId)) {
              _debouncedFetch();
            }
          },
        )
        .subscribe();

}

void \_listenToMessagesChanges() {
\_messagesChannel?.unsubscribe();
if (\_groupIds.isEmpty) return;

    _messagesChannel = _clientManager.client
        .channel('messages_${DateTime.now().millisecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'group_messages',
          callback: (payload) {
            final groupId = payload.newRecord['group_id'];
            if (groupId != null && _groupIds.contains(groupId)) {
              _debouncedFetch();
            }
          },
        )
        .subscribe();

}

// ─────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────

bool \_listEquals(List<String> a, List<String> b) {
if (a.length != b.length) return false;
final aSet = a.toSet();
final bSet = b.toSet();
return aSet.difference(bSet).isEmpty && bSet.difference(aSet).isEmpty;
}

void \_debouncedFetch() {
\_debounceTimer?.cancel();
\_debounceTimer = Timer(const Duration(milliseconds: 300), \_fetchMembership);
}

// ─────────────────────────────────────────────────────────────────
// DISPOSE
// ─────────────────────────────────────────────────────────────────

@override
Future<void> close() {
\_debounceTimer?.cancel();
\_membersChannel?.unsubscribe();
\_groupsChannel?.unsubscribe();
\_messagesChannel?.unsubscribe();
return super.close();
}
}
//-------------------------------------------------------------------------
part of 'fetch_groups_cubit.dart';

@immutable
sealed class FetchGroupsState {}

final class FetchGroupsInitial extends FetchGroupsState {}

final class FetchGroupsLoading extends FetchGroupsState {}

final class FetchGroupsSuccess extends FetchGroupsState {
final List<GroupModel> groups;

FetchGroupsSuccess({required this.groups,});
}

final class FetchGroupsFailure extends FetchGroupsState {
final String errorMessage;
FetchGroupsFailure({required this.errorMessage});
}
//----------------------------------------------------------------------
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'select_group_members_state.dart';

class SelectGroupMembersCubit extends Cubit<SelectGroupMembersState> {
SelectGroupMembersCubit() : super(SelectGroupMembersInitial());
List<UserModel> selectedMembers = [];
void addMembers({required UserModel user}) {
if (selectedMembers.contains(user)) {
selectedMembers.remove(user);
emit(SuccessDeleteMember());
} else {
selectedMembers.add(user);
emit(SuccessAddMember());
}
}

void cleanMembers() {
selectedMembers = [];
emit(SelectGroupMembersInitial());
}
}
//-----------------------------------------------------------------
part of 'select_group_members_cubit.dart';

@immutable
sealed class SelectGroupMembersState {}

final class SelectGroupMembersInitial extends SelectGroupMembersState {}
final class SuccessAddMember extends SelectGroupMembersState {}
final class SuccessDeleteMember extends SelectGroupMembersState {}
//-------------------------------------------------------------
import 'dart:async';
import 'dart:io';

import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:chattr/features/group_chats/data/models/group_message_model.dart';
import 'package:chattr/features/group_chats/data/repos/send_group_message_repo/send_group_message_repo.dart';
import 'package:chattr/features/group_chats/presentation/cubits/fetch_group_messages_cubit/fetch_group_messages_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

part 'send_group_message_state.dart';

class SendGroupMessageCubit extends Cubit<SendGroupMessageState> {
SendGroupMessageCubit({
required this.fetchCubit,
required SendGroupMessageRepo repo,
}) : \_repo = repo,
super(SendGroupMessageInitial());

final FetchGroupMessagesCubit fetchCubit;
final SendGroupMessageRepo \_repo;

final Set<String> \_inFlight = {};
DateTime? \_lastTextSend;

// ─────────────────────────────────────────────────────────────────
// SEND TEXT
// ─────────────────────────────────────────────────────────────────

Future<void> sendTextMessage({
required String message,
required UserModel sender,
required String senderId,
required String groupId,
}) async {
final trimmed = message.trim();
if (trimmed.isEmpty) return;

    final now = DateTime.now();
    if (_lastTextSend != null &&
        now.difference(_lastTextSend!) < const Duration(milliseconds: 500)) {
      return;
    }
    _lastTextSend = now;

    final tempId = const Uuid().v4();
    if (_inFlight.contains(tempId)) return;
    _inFlight.add(tempId);

    final temp = GroupMessageModel(
      tempId: tempId,
      status: GroupMessageStatus.sending,
      groupId: groupId,
      senderId: senderId,
      sender: sender,
      messageType: GroupMessageType.text,
      content: trimmed,
      createdAt: DateTime.now(),
      isDeleted: false,
    );

    fetchCubit.addLocalMessage(groupId: groupId, message: temp);
    emit(SendGroupMessageSuccess());

    final result = await _repo.sendMessage(temp);
    result.fold(
      (err) {
        fetchCubit.markMessageFailed(groupId: groupId, tempId: tempId);
        emit(SendGroupMessageFailure(errorMessage: err.message));
      },
      (server) {
        fetchCubit.replaceTempMessage(
          groupId: groupId,
          tempId: tempId,
          serverMessage: server.copyWith(createdAt: temp.createdAt),
        );
      },
    );

    _inFlight.remove(tempId);

}

// ─────────────────────────────────────────────────────────────────
// SEND IMAGE
// ─────────────────────────────────────────────────────────────────

Future<void> sendImage({
required File? imageFile,
required UserModel sender,
required String senderId,
required String groupId,
}) async {
if (imageFile == null) return;

    final tempId = const Uuid().v4();
    _inFlight.add(tempId);

    final temp = GroupMessageModel(
      tempId: tempId,
      status: GroupMessageStatus.sending,
      groupId: groupId,
      senderId: senderId,
      sender: sender,
      messageType: GroupMessageType.image,
      content: imageFile.path,
      localPath: imageFile.path,
      createdAt: DateTime.now(),
      isDeleted: false,
    );

    fetchCubit.addLocalMessage(groupId: groupId, message: temp);
    emit(SendGroupMessageSuccess());

    unawaited(
      _uploadAndSend(
        tempId: tempId,
        temp: temp,
        imageFile: imageFile,
        groupId: groupId,
      ),
    );

}

Future<void> \_uploadAndSend({
required String tempId,
required GroupMessageModel temp,
required File imageFile,
required String groupId,
}) async {
final uploadResult = await \_repo.uploadImage(imageFile);

    uploadResult.fold(
      (err) {
        fetchCubit.markMessageFailed(groupId: groupId, tempId: tempId);
        emit(SendGroupMessageFailure(errorMessage: err.message));
        _inFlight.remove(tempId);
      },
      (url) async {
        final sendResult = await _repo.sendMessage(temp.copyWith(content: url));
        sendResult.fold(
          (err) {
            fetchCubit.markMessageFailed(groupId: groupId, tempId: tempId);
            emit(SendGroupMessageFailure(errorMessage: err.message));
          },
          (server) {
            fetchCubit.replaceTempMessage(
              groupId: groupId,
              tempId: tempId,
              serverMessage: server.copyWith(
                createdAt: temp.createdAt,
                localPath: imageFile.path,
              ),
            );
          },
        );
        _inFlight.remove(tempId);
      },
    );

}

// ─────────────────────────────────────────────────────────────────
// SEND VOICE
// ─────────────────────────────────────────────────────────────────

void showLocalVoice({
required UserModel sender,
required String senderId,
required String groupId,
required String audioPath,
required int duration,
}) {
\_inFlight.add(audioPath);

    final temp = GroupMessageModel(
      tempId: audioPath,
      status: GroupMessageStatus.sending,
      groupId: groupId,
      senderId: senderId,
      sender: sender,
      messageType: GroupMessageType.voice,
      content: audioPath,
      mediaDuration: duration,
      createdAt: DateTime.now(),
      isDeleted: false,
    );

    fetchCubit.addLocalMessage(groupId: groupId, message: temp);

}

Future<void> updateVoiceUrl({
required String groupId,
required String localPath,
required String uploadedUrl,
}) async {
final messages = fetchCubit.getMessages(groupId);
if (messages == null) return;

    final idx = messages.indexWhere((m) => m.tempId == localPath);
    if (idx == -1) return;

    final temp = messages[idx];
    final result = await _repo.sendMessage(temp.copyWith(content: uploadedUrl));

    result.fold(
      (err) {
        fetchCubit.markMessageFailed(groupId: groupId, tempId: localPath);
        emit(SendGroupMessageFailure(errorMessage: err.message));
      },
      (server) {
        fetchCubit.replaceTempMessage(
          groupId: groupId,
          tempId: localPath,
          serverMessage: server.copyWith(
            createdAt: temp.createdAt,
            localPath: localPath,
          ),
        );
        emit(SendGroupMessageSuccess());
      },
    );

    _inFlight.remove(localPath);

}

// ─────────────────────────────────────────────────────────────────
// RETRY
// ─────────────────────────────────────────────────────────────────

Future<void> retryMessage(GroupMessageModel failed) async {
if (failed.status != GroupMessageStatus.failed) return;
if (\_inFlight.contains(failed.tempId)) return;

    _inFlight.add(failed.tempId);

    fetchCubit.replaceTempMessage(
      groupId: failed.groupId,
      tempId: failed.tempId,
      serverMessage: failed.copyWith(status: GroupMessageStatus.sending),
    );

    final result = await _repo.sendMessage(
      failed.copyWith(messageId: null, status: GroupMessageStatus.sending),
    );

    result.fold(
      (err) {
        fetchCubit.markMessageFailed(
          groupId: failed.groupId,
          tempId: failed.tempId,
        );
        emit(SendGroupMessageFailure(errorMessage: err.message));
      },
      (server) {
        fetchCubit.replaceTempMessage(
          groupId: failed.groupId,
          tempId: failed.tempId,
          serverMessage: server.copyWith(createdAt: failed.createdAt),
        );
        emit(SendGroupMessageSuccess());
      },
    );

    _inFlight.remove(failed.tempId);

}

Future<void> retryDelete({
required String groupId,
required GroupMessageModel message,
}) async {
if (message.status != GroupMessageStatus.deleteFailed) return;
await fetchCubit.deleteGroupMessages(groupId: groupId, messages: [message]);
}

Future<void> retryEditMessage({
required String groupId,
required GroupMessageModel message,
required String content,
}) async {
if (message.status != GroupMessageStatus.editingFaild) return;
await fetchCubit.editMessageGroup(
groupId: groupId,
message: message,
content: content,
);
}
}
//----------------------------------------------------------
part of 'send_group_message_cubit.dart';

@immutable
sealed class SendGroupMessageState {}

final class SendGroupMessageInitial extends SendGroupMessageState {}

final class SendGroupMessageLoading extends SendGroupMessageState {}

final class SendGroupMessageSuccess extends SendGroupMessageState {}

final class SendGroupMessageFailure extends SendGroupMessageState {
final String errorMessage;
SendGroupMessageFailure({required this.errorMessage});
}
//---------------------------------------------------------------
import 'package:chattr/core/routing/routes.dart';
import 'package:chattr/core/widgets/custom_appbar.dart';
import 'package:chattr/features/contacts/presentation/cubits/fetch_contacts_cubit/fetch_contacts_cubit.dart';
import 'package:chattr/features/group_chats/presentation/views/groups_view/views/groups_view_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class GroupsView extends StatelessWidget {
const GroupsView({super.key});

@override
Widget build(BuildContext context) {
return GestureDetector(
onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
child: Scaffold(
appBar: CustomAppBar(
title: "Groups",
actions: [
GestureDetector(
onTap: () => context.push(
Routes.creatGroup,
extra: context.read<FetchContactsCubit>(),
),
child: Icon(Icons.group_add_rounded),
),
Gap(10),
],
),
body: GroupsViewBody(),
),
);
}
}
//------------------------------------------------------------------
import 'package:chattr/core/cubits/search/search_cubit.dart';
import 'package:chattr/core/helpers/snack_bar.dart';
import 'package:chattr/features/group_chats/presentation/cubits/fetch_groups_cubit/fetch_groups_cubit.dart';
import 'package:chattr/features/group_chats/presentation/views/groups_view/widgets/groups_list.dart';
import 'package:chattr/features/group_chats/presentation/views/groups_view/widgets/groups_search_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class GroupsViewBody extends StatelessWidget {
const GroupsViewBody({super.key});

@override
Widget build(BuildContext context) {
return CustomScrollView(
slivers: [
SliverToBoxAdapter(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Gap(20),
BlocProvider(
create: (context) => SearchCubit(),
child: GroupsSearchBar(),
),
Gap(30),
],
),
),
SliverPadding(
padding: EdgeInsets.fromLTRB(20, 0, 0, 0),
sliver: BlocListener<FetchGroupsCubit, FetchGroupsState>(
listener: (context, state) {
if (state is FetchGroupsFailure) {
CustomSnackBar.error(context, state.errorMessage);
}
},
child: Grouplist(),
),
),
],
);
}
}
//-------------------------------------------------------------------------
import 'package:chattr/core/cubits/pick_image/pick_image_cubit.dart';
import 'package:chattr/core/helpers/snack_bar.dart';
import 'package:chattr/core/themes/app_colors.dart';
import 'package:chattr/core/themes/app_text_styles.dart';
import 'package:chattr/core/utils/validators/auth_validation.dart';
import 'package:chattr/core/widgets/custom_appbar.dart';
import 'package:chattr/core/widgets/custom_button.dart';
import 'package:chattr/core/widgets/custom_text.dart';
import 'package:chattr/core/widgets/image/ui/pick_image.dart';
import 'package:chattr/features/contacts/presentation/cubits/fetch_contacts_cubit/fetch_contacts_cubit.dart';
import 'package:chattr/features/group_chats/presentation/cubits/create_group_cubit/create_group_cubit.dart';
import 'package:chattr/features/group_chats/presentation/cubits/select_group_members_cubit/select_group_members_cubit.dart';
import 'package:chattr/features/group_chats/presentation/views/groups_view/widgets/group_members_list.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class CreatGroup extends StatefulWidget {
const CreatGroup({super.key, required this.contactsCubit});
final FetchContactsCubit contactsCubit;

@override
State<CreatGroup> createState() => \_CreatGroupState();
}

class \_CreatGroupState extends State<CreatGroup> {
late TextEditingController groupNameController;
final \_formKey = GlobalKey<FormState>();
final ValueNotifier<bool> isFormValid = ValueNotifier(false);

@override
void initState() {
groupNameController = TextEditingController();
super.initState();
}

@override
void dispose() {
groupNameController.dispose();
super.dispose();
}

@override
Widget build(BuildContext context) {
return GestureDetector(
onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
child: BlocProvider.value(
value: widget.contactsCubit,
child: Scaffold(
appBar: CustomAppBar(
title: "Create Group",
actions: [],
leading: GestureDetector(
onTap: () => context.pop(),
child: Icon(Icons.arrow_back_ios_new_rounded, size: 17),
),
),

          body: BlocListener<CreateGroupCubit, CreateGroupState>(
            listener: (context, state) {
              if (state is CreateGroupSuccess) {
                context.pop();
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                   CustomSnackBar.success(context, "groupCreatedSuccessfully");
                });

              }
              if (state is CreateGroupfailure) {
                CustomSnackBar.error(context, state.errorMessage);
              }
            },
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 15),
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Gap(40),
                            CustomText(
                              text: "Select Group Image",
                              style: AppTextStyles.headlineSmall,
                            ),
                            Gap(10),
                            PickImageWidget(
                              isProfile: true,
                              defaultImageUrl:
                                  'https://thumbs.dreamstime.com/b/linear-group-icon-customer-service-outline-collection-thin-line-vector-isolated-white-background-138644548.jpg?w=768',
                            ),
                            Gap(20),
                            _GroupDataTextField(
                              controller: groupNameController,
                              hint: "groupname :",
                              onChanged: (v) => isFormValid.value =
                                  _formKey.currentState?.validate() ?? false,
                            ),
                            Gap(40),
                            CustomText(
                              text: "Select Group members",
                              style: AppTextStyles.headlineSmall,
                            ),
                            Gap(10),
                            BlocBuilder<FetchContactsCubit, FetchContactsState>(
                              builder: (context, state) {
                                if (state is FetchContactsSuccess) {
                                  final myContacts = state.contacts;
                                  return GroupMembersList(
                                    myContacts: myContacts,
                                  );
                                } else if (state is FetchContactsFailure) {
                                  return Center(
                                    child: Text(state.errorMessage),
                                  );
                                } else {
                                  return Center(
                                    child: CupertinoActivityIndicator(
                                      radius: 12,
                                      color: Colors.grey,
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                _CreatGroupButton(
                  formKey: _formKey,
                  isFormValid: isFormValid,
                  groupNameController: groupNameController,
                ),
              ],
            ),
          ),
        ),
      ),
    );

}
}

class \_CreatGroupButton extends StatelessWidget {
const \_CreatGroupButton({
required this.formKey,
required this.isFormValid,
required this.groupNameController,
});
final GlobalKey<FormState> formKey;
final ValueNotifier<bool> isFormValid;
final TextEditingController groupNameController;

@override
Widget build(BuildContext context) {
return Padding(
padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
child: ValueListenableBuilder<bool>(
valueListenable: isFormValid,
builder: (context, value, \_) {
return AnimatedContainer(
duration: const Duration(milliseconds: 250),
child: BlocBuilder<PickImageCubit, PickImageState>(
buildWhen: (prev, curr) =>
curr is PickImageSuccess || prev is PickImageSuccess,
builder: (context, state) {
final imagePath = state is PickImageSuccess
? state.imageFile
: null;
return BlocBuilder<
SelectGroupMembersCubit,
SelectGroupMembersState >(
builder: (context, state) {
final selectedMembers = context
.read<SelectGroupMembersCubit>()
.selectedMembers;
return BlocBuilder<CreateGroupCubit, CreateGroupState>(
buildWhen: (prev, curr) =>
curr is CreateGroupLoading ||
prev is CreateGroupLoading,
builder: (context, state) {
final isLoading = state is CreateGroupLoading;
return CustomButton(
onPressed: value && imagePath != null
? () {
context.read<CreateGroupCubit>().creatGroup(
groupImageFile: imagePath,
groupName: groupNameController.text.trim(),
members: selectedMembers,
);
}
: null,
color:
value &&
imagePath != null &&
selectedMembers.isNotEmpty
? null
: AppColors.inputBorder,
padding: EdgeInsets.symmetric(vertical: 10),
raduis: 8,
child: Row(
mainAxisAlignment: MainAxisAlignment.center,
children: [
CustomText(
text: "Creat Group",
style: AppTextStyles.headlineSmall,
),
Gap(5),
isLoading
? CupertinoActivityIndicator(
color: Colors.grey,
radius: 9,
)
: SizedBox.shrink(),
],
),
);
},
);
},
);
},
),
);
},
),
);
}
}

class \_GroupDataTextField extends StatelessWidget {
const \_GroupDataTextField({
required this.hint,

    this.controller,
    this.onChanged,

});
final String hint;

final TextEditingController? controller;
final Function(String)? onChanged;

@override
Widget build(BuildContext context) {
return TextFormField(
autovalidateMode: AutovalidateMode.onUserInteraction,
validator: AuthValidation.required,
onChanged: onChanged,
controller: controller,
style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
decoration: InputDecoration(
hintStyle: TextStyle(color: AppColors.textHint),
hintText: hint,
filled: true,
fillColor: Colors.transparent,
contentPadding: const EdgeInsets.symmetric(
horizontal: 16,
vertical: 14,
),
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(10),
borderSide: BorderSide(color: AppColors.inputBorder, width: 1.2),
),
focusedBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(10),
borderSide: BorderSide(color: AppColors.border, width: 1.2),
),
),
);
}
}
//------------------------------------------------------------------
import 'package:chattr/core/themes/app_colors.dart';
import 'package:chattr/core/themes/app_text_styles.dart';
import 'package:chattr/core/widgets/custom_text.dart';
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:chattr/features/group_chats/presentation/cubits/select_group_members_cubit/select_group_members_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class GroupMembersList extends StatelessWidget {
const GroupMembersList({super.key, required this.myContacts});

final List<UserModel> myContacts;

@override
Widget build(BuildContext context) {
return ListView.builder(
shrinkWrap: true,
itemCount: myContacts.length,
physics: const NeverScrollableScrollPhysics(),

      itemBuilder: (context, index) {
        return BlocBuilder<SelectGroupMembersCubit, SelectGroupMembersState>(
          builder: (context, state) {
            final isSelected = context
                .read<SelectGroupMembersCubit>()
                .selectedMembers
                .contains(myContacts[index]);
            return CheckboxListTile(
              value: isSelected,

              onChanged: (value) {
                context.read<SelectGroupMembersCubit>().addMembers(
                  user: myContacts[index],
                );
              },
              activeColor: AppColors.primary,
              checkColor: Colors.white,
              checkboxShape: CircleBorder(),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              dense: true,
              visualDensity: VisualDensity.compact,
              title: CustomText(
                text: myContacts[index].name ?? '',
                style: AppTextStyles.bodySmall,
              ),
              subtitle: CustomText(
               text: myContacts[index].isOnLine == true ? 'Online' : 'Offline',
                style: AppTextStyles.bodySmall.copyWith(
                  fontSize: 9
                ),
              ),
              secondary:



               CircleAvatar(
                radius: 20,
                backgroundImage: NetworkImage(
                  myContacts[index].image ?? "https://i.pravatar.cc/150?img=3",
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            );
          },
        );
      },
    );

}
}
//-----------------------------------------------------------------
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chattr/core/cubits/fetch_current_user_data/fetch_current_user_data_cubit.dart';
import 'package:chattr/core/routing/router_models.dart';
import 'package:chattr/core/routing/routes.dart';
import 'package:chattr/core/themes/app_colors.dart';
import 'package:chattr/core/themes/app_text_styles.dart';
import 'package:chattr/core/widgets/custom_text.dart';
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:chattr/features/group_chats/data/models/group_model.dart';
import 'package:chattr/features/group_chats/presentation/cubits/fetch_groups_cubit/fetch_groups_cubit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class Grouplist extends StatelessWidget {
const Grouplist({super.key});

@override
Widget build(BuildContext context) {
return BlocBuilder<FetchGroupsCubit, FetchGroupsState>(
builder: (context, state) {
final UserModel? currentUser = context
.select<FetchCurrentUserDataCubit, UserModel?>(
(cubit) => cubit.currentUser,
);

        if (currentUser == null) {
          return const SliverFillRemaining(
            child: Center(child: CupertinoActivityIndicator()),
          );
        }

        if (state is FetchGroupsSuccess) {
          final List<GroupModel> myGroups = state.groups;

          return SliverList(
            delegate: SliverChildBuilderDelegate(childCount: myGroups.length, (
              context,
              index,
            ) {
              final String? lastMessageTime =
                  myGroups[index].lastMessageTime == null
                  ? null
                  : DateFormat('jm').format(myGroups[index].lastMessageTime!);
              String? senderName;

              if (myGroups[index].lastMessage != null) {
                senderName = myGroups[index].getLastMessageSenderName(
                  currentUserId: currentUser.id!,
                  lastMessageSenderId: myGroups[index].lastMessageSenderId!,
                );
              }

              return Stack(
                children: [
                  GestureDetector(
                    onTap: () {
                      final groupData = GroupChatParams(
                        groupData: myGroups[index],
                        currentUser: currentUser,
                        memberData: myGroups[index].members!,
                      );
                      context.push(Routes.groupMessages, extra: groupData);
                    },
                    child: Container(
                      color: Colors.transparent,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _GroupProfileImage(group: myGroups[index]),
                            Gap(20),
                            _GroupNameAndLastMessage(
                              group: myGroups[index],
                              senderName: senderName,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _UnreadCount(
                    group: myGroups[index],
                    lastMessageTime: lastMessageTime,
                  ),
                ],
              );
            }),
          );
        } else if (state is FetchGroupsFailure) {
          return SliverFillRemaining(child: Text(state.errorMessage));
        } else {
          return SliverFillRemaining(
            child: Center(child: CupertinoActivityIndicator()),
          );
        }
      },
    );

}
}

class \_UnreadCount extends StatelessWidget {
const \_UnreadCount({required this.group, required this.lastMessageTime});

final GroupModel group;
final String? lastMessageTime;

@override
Widget build(BuildContext context) {
return Positioned(
bottom: 20,
right: 10,
child: group.unreadCount > 0
? CircleAvatar(
radius: 10,
backgroundColor: AppColors.primary,
child: CustomText(
text: group.unreadCount.toString(),
style: AppTextStyles.bodySmall,
),
)
: lastMessageTime != null
? CustomText(
text: lastMessageTime!,
style: AppTextStyles.bodySmall.copyWith(fontSize: 9),
)
: SizedBox.fromSize(),
);
}
}

class \_GroupNameAndLastMessage extends StatelessWidget {
const \_GroupNameAndLastMessage({
required this.group,
required this.senderName,
});

final GroupModel group;
final String? senderName;

@override
Widget build(BuildContext context) {
return Flexible(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
CustomText(text: group.name ?? '', style: AppTextStyles.bodyMedium),
CustomText(
minFontSize: 12,
style: AppTextStyles.bodySmall,
text: group.lastMessage == null
? 'Start the conversation 💬'
: "$senderName: ${group.lastMessage}",
),
],
),
);
}
}

class \_GroupProfileImage extends StatelessWidget {
const \_GroupProfileImage({required this.group});

final GroupModel group;

@override
Widget build(BuildContext context) {
return CircleAvatar(
radius: 20,
child: ClipOval(
child: CachedNetworkImage(
height: 100,
width: 100,
fit: BoxFit.fill,
imageUrl:
group.image ??
'https://static.thenounproject.com/png/1856610-200.png',
placeholder: (context, url) =>
CupertinoActivityIndicator(color: Colors.white54, radius: 9),
errorWidget: (context, url, error) => const Icon(
Icons.image_not_supported_outlined,
color: Colors.red,
size: 40,
),
),
),
);
}
}
//-------------------------------------------------------------------------

import 'package:chattr/core/cubits/search/search_cubit.dart';
import 'package:chattr/core/themes/app_colors.dart';
import 'package:chattr/core/widgets/custom_text_field.dart';
import 'package:chattr/features/group_chats/data/models/group_model.dart';
import 'package:chattr/features/group_chats/presentation/cubits/fetch_groups_cubit/fetch_groups_cubit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class GroupsSearchBar extends StatefulWidget {
const GroupsSearchBar({super.key});

@override
State<GroupsSearchBar> createState() => \_GroupsSearchBarState();
}

class \_GroupsSearchBarState extends State<GroupsSearchBar> {
late TextEditingController \_searchController;

@override
void initState() {
\_searchController = TextEditingController();
super.initState();
}

@override
void dispose() {
super.dispose();
\_searchController.dispose();
}

@override
Widget build(BuildContext context) {
return BlocBuilder<FetchGroupsCubit, FetchGroupsState>(
builder: (context, state) {
List<GroupModel> chats = [];
if (state is FetchGroupsSuccess) {
chats = state.groups;
}

        return chats.isNotEmpty
            ? Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: CustomTextField(
                  controller: _searchController,
                  hint: "search",
                  validation: (v) {
                    return null;
                  },
                  onChange: (value) => context.read<SearchCubit>().search(
                    list: chats,
                    query: value,
                    searchBy: (item) => item.name,
                  ),

                  suffixIcon: Icon(
                    CupertinoIcons.search,
                    color: AppColors.inputBorder,
                  ),
                ),
              )
            : SizedBox.shrink();
      },
    );

}
}
//-----------------------------------------------------------------------
import 'package:chattr/core/cubits/select_messages/select_messages_cubit.dart';
import 'package:chattr/core/routing/router_models.dart';
import 'package:chattr/core/routing/routes.dart';
import 'package:chattr/core/themes/app_text_styles.dart';
import 'package:chattr/core/utils/di/get_it.dart';
import 'package:chattr/core/utils/extensions/responsive.dart';
import 'package:chattr/core/widgets/custom_appbar.dart';
import 'package:chattr/core/widgets/custom_text.dart';
import 'package:chattr/features/contacts/presentation/cubits/fetch_contacts_cubit/fetch_contacts_cubit.dart';
import 'package:chattr/features/group_chats/data/models/group_message_model.dart';
import 'package:chattr/features/group_chats/data/repos/send_group_message_repo/send_group_message_repo.dart';
import 'package:chattr/features/group_chats/presentation/cubits/fetch_group_messages_cubit/fetch_group_messages_cubit.dart';
import 'package:chattr/features/group_chats/presentation/cubits/fetch_groups_cubit/fetch_groups_cubit.dart';
import 'package:chattr/features/group_chats/presentation/cubits/send_group_message_cubit/send_group_message_cubit.dart';
import 'package:chattr/features/group_chats/presentation/views/group_messages_view/views/group_messages_view_body.dart';
import 'package:chattr/features/group_chats/presentation/views/group_messages_view/widgets/edit_message_bottom_sheet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class GroupMessagesView extends StatelessWidget {
const GroupMessagesView({super.key, required this.groupData});
final GroupChatParams groupData;

@override
Widget build(BuildContext context) {
return MultiBlocProvider(
providers: [
BlocProvider.value(value: getIt<FetchContactsCubit>()),
BlocProvider.value(value: getIt<FetchGroupsCubit>()),
BlocProvider.value(value: getIt<FetchGroupMessagesCubit>()),
BlocProvider(
create: (context) => SendGroupMessageCubit(
fetchCubit: getIt<FetchGroupMessagesCubit>(),
repo: getIt<SendGroupMessageRepo>(),
),
),
],
child: BlocBuilder<FetchGroupsCubit, FetchGroupsState>(
builder: (context, state) {
GroupChatParams updatedGroupData = groupData;
if (state is FetchGroupsSuccess) {
final updatedGroup = state.groups
.where((g) => g.id == groupData.groupData.id)
.firstOrNull;

            updatedGroupData = GroupChatParams(
              groupData: updatedGroup!,
              currentUser: groupData.currentUser,
              memberData: updatedGroup.members ?? [],
            );
            final List<String> membres = updatedGroupData.memberData
                .map((u) => u.user.name ?? '')
                .toList();
            return GestureDetector(
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              child: Scaffold(
                appBar: _GroupMessagesViewAppbar(
                  groupmembers: membres,
                  groupData: updatedGroupData,
                ),

                body: GroupMessageViewBody(
                  groupData: updatedGroupData.groupData,
                  currentUser: updatedGroupData.currentUser,
                ),
              ),
            );
          } else if (state is FetchGroupsFailure) {
            return Center(
              child: CustomText(
                text: state.errorMessage,
                style: AppTextStyles.headlineSmall,
              ),
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );

}
}

class \_GroupMessagesViewAppbar extends StatelessWidget
implements PreferredSizeWidget {
const \_GroupMessagesViewAppbar({
required this.groupmembers,
required this.groupData,
});

final List<String> groupmembers;
final GroupChatParams groupData;

@override
Widget build(BuildContext context) {
void deletemessage() {
final selected = context
.read<SelectMessagesCubit>()
.selectedMessages
.cast<GroupMessageModel>();

      context.read<FetchGroupMessagesCubit>().deleteGroupMessages(
        groupId: groupData.groupData.id!,
        messages: selected,
      );

      context.read<SelectMessagesCubit>().clearSelection();
    }

    return CustomAppBar(
      title: groupData.groupData.name ?? '',
      titleItems: [
        SizedBox(
          width: context.screenWidth * 0.5,
          child: CustomText(
            style: AppTextStyles.bodySmall,
            text: groupmembers.join(', '),
          ),
        ),
      ],
      leading: GestureDetector(
        onTap: () => context.pop(),
        child: Icon(Icons.arrow_back_ios_new_rounded, size: 15),
      ),
      actions: [
        BlocBuilder<SelectMessagesCubit, SelectMessagesState>(
          builder: (context, state) {
            final List<GroupMessageModel> selectedmessages = context
                .read<SelectMessagesCubit>()
                .selectedMessages
                .cast();

            return selectedmessages.isNotEmpty
                ? Row(
                    children: [
                      selectedmessages.length == 1 &&
                              selectedmessages[0].messageType ==
                                  GroupMessageType.text
                          ? InkWell(
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled:
                                      true, // مهم علشان ياخد مساحة كبيرة
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(20),
                                    ),
                                  ),
                                  builder: (ctx) => BlocProvider.value(
                                    value: context.read<SelectMessagesCubit>(),

                                    child: EditGroupMessageButtomSheet(
                                      groupId: groupData.groupData.id!,
                                      message: selectedmessages[0].content,
                                    ),
                                  ),
                                );
                              },
                              child: Icon(Icons.edit, size: 20),
                            )
                          : SizedBox.shrink(),

                      Gap(10),
                      context.read<SelectMessagesCubit>().containMedia()
                          ? SizedBox.shrink()
                          : InkWell(
                              onTap: () {
                                context
                                    .read<SelectMessagesCubit>()
                                    .copyMessages();
                              },
                              child: Icon(Icons.copy, size: 20),
                            ),
                      Gap(5),
                      InkWell(
                        onTap: deletemessage,
                        child: Icon(Icons.delete_outlined, size: 25),
                      ),
                      Gap(10),
                    ],
                  )
                : Padding(
                    padding: EdgeInsets.only(right: 15),
                    child: InkWell(
                      onTap: () {
                        final GroupChatParams thisGroupData = GroupChatParams(
                          currentUser: groupData.currentUser,
                          groupData: groupData.groupData,
                          memberData: groupData.memberData,
                          fetchGroupsCubit: context.read<FetchGroupsCubit>(),
                        );
                        context.push(
                          Routes.viewGroupMembers,
                          extra: thisGroupData,
                        );
                      },
                      child: Icon(CupertinoIcons.group_solid),
                    ),
                  );
          },
        ),
      ],
    );

}

@override
Size get preferredSize => Size.fromHeight(kToolbarHeight);
}
//-------------------------------------------------------------------
import 'package:chattr/core/helpers/snack_bar.dart';
import 'package:chattr/core/widgets/message/chat_message_list.dart';
import 'package:chattr/core/widgets/message/send_message_field.dart';
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:chattr/features/group_chats/data/models/group_model.dart';
import 'package:chattr/features/group_chats/presentation/cubits/fetch_group_messages_cubit/fetch_group_messages_cubit.dart';
import 'package:chattr/features/group_chats/presentation/cubits/send_group_message_cubit/send_group_message_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class GroupMessageViewBody extends StatefulWidget {
  const GroupMessageViewBody({
    super.key,
    required this.groupData,
    required this.currentUser,
  });

  final GroupModel groupData;
  final UserModel currentUser;

  @override
  State<GroupMessageViewBody> createState() => _GroupMessageViewBodyState();
}

class _GroupMessageViewBodyState extends State<GroupMessageViewBody> {
  final ScrollController _scrollController = ScrollController();
  bool _isPaginating = false;
  bool _userScrolledUp = false;
  int _prevMessageCount = 0;
  int _lastMarkedUnread = -1;
  bool _initialScrollDone = false;

  String get _groupId => widget.groupData.id as String;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<FetchGroupMessagesCubit>().loadInitialMessages(
        groupId: _groupId,
      );
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;

    if (pos.pixels <= 100 && !_isPaginating) {
      final cubit = context.read<FetchGroupMessagesCubit>();
      if (cubit.hasMore(_groupId)) {
        _isPaginating = true;
        cubit.loadMoreMessages(_groupId).then((_) => _isPaginating = false);
      }
    }

    _userScrolledUp = pos.pixels < pos.maxScrollExtent - 100;
  }

  void _scrollToBottom() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        final max = _scrollController.position.maxScrollExtent;
        if (max <= 0) return;
        _scrollController.jumpTo(max);
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (!_scrollController.hasClients) return;
          final newMax = _scrollController.position.maxScrollExtent;
          if (newMax > max) _scrollController.jumpTo(newMax);
        });
      });
    });
  }

  void _handleNewMessages(FetchGroupMessagesSuccess state) {
    final messages = state.messages;

    final unreadCount = widget.groupData.unreadCount;
    if (unreadCount > 0 && unreadCount != _lastMarkedUnread) {
      _lastMarkedUnread = unreadCount;
      context.read<FetchGroupMessagesCubit>().markGroupAsRead(
        groupId: _groupId,
      );
    }

    if (messages.length > _prevMessageCount) {
      _prevMessageCount = messages.length;

      if (!_initialScrollDone) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || !_scrollController.hasClients) return;
              final max = _scrollController.position.maxScrollExtent;
              if (max > 0) {
                _initialScrollDone = true;
                _scrollController.jumpTo(max);
              }
            });
          });
        });
        return;
      }

      if (!_userScrolledUp) _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SendGroupMessageCubit, SendGroupMessageState>(
      listener: (context, state) {
        if (state is SendGroupMessageSuccess) {
          _scrollToBottom();
        } else if (state is SendGroupMessageFailure) {
          CustomSnackBar.error(context, state.errorMessage);
        }
      },
      child: BlocListener<FetchGroupMessagesCubit, FetchGroupMessagesState>(
        listenWhen: (_, curr) {
          if (curr is FetchGroupMessagesLoading) return false;
          if (curr is! FetchGroupMessagesSuccess) return false;
          return curr.groupId == widget.groupData.id;
        },
        listener: (context, state) {
          if (state is FetchGroupMessagesSuccess) _handleNewMessages(state);
        },
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  const SliverToBoxAdapter(child: Gap(20)),
                  ChatMessagesList(
                    currentUser: widget.currentUser,
                    scrollController: _scrollController,
                    chatData: widget.groupData,
                  ),
                ],
              ),
            ),
            SendMessageField(
              chatData: widget.groupData,
              curruntUser: widget.currentUser,
            ),
          ],
        ),
      ),
    );
  }
}

//--------------------------------------------------------------------
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chattr/core/cubits/pick_image/pick_image_cubit.dart';
import 'package:chattr/core/helpers/snack_bar.dart';
import 'package:chattr/core/routing/router_models.dart';
import 'package:chattr/core/routing/routes.dart';
import 'package:chattr/core/themes/app_colors.dart';
import 'package:chattr/core/themes/app_text_styles.dart';
import 'package:chattr/core/utils/di/get_it.dart';
import 'package:chattr/core/widgets/custom_appbar.dart';
import 'package:chattr/core/widgets/custom_button.dart';
import 'package:chattr/core/widgets/custom_text.dart';
import 'package:chattr/core/widgets/custom_text_field.dart';
import 'package:chattr/core/widgets/image/ui/pick_image.dart';
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:chattr/features/contacts/presentation/cubits/fetch_contacts_cubit/fetch_contacts_cubit.dart';
import 'package:chattr/features/group_chats/data/models/group_model.dart';
import 'package:chattr/features/group_chats/presentation/cubits/add_and_remove_admin_cubit/add_and_remove_admin_cubit.dart';
import 'package:chattr/features/group_chats/presentation/cubits/delete_group_cubit/delete_group_cubit.dart';
import 'package:chattr/features/group_chats/presentation/cubits/delete_member_cubit/delete_member_cubit.dart';
import 'package:chattr/features/group_chats/presentation/cubits/edit_group_data_cubit/edit_group_data_cubit.dart';
import 'package:chattr/features/group_chats/presentation/cubits/fetch_groups_cubit/fetch_groups_cubit.dart';
import 'package:chattr/features/group_chats/presentation/cubits/select_group_members_cubit/select_group_members_cubit.dart';
import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ViewGroupMembers extends StatelessWidget {
const ViewGroupMembers({super.key, required this.groupData});
final GroupChatParams groupData;

@override
Widget build(BuildContext context) {
return BlocProvider.value(
value: groupData.fetchGroupsCubit!,
child: BlocBuilder<FetchGroupsCubit, FetchGroupsState>(
builder: (context, state) {
GroupChatParams updatedGroupData = groupData;

          if (state is FetchGroupsSuccess) {
            final GroupModel? updatedGroup = state.groups.firstWhereOrNull(
              (g) => g.id == groupData.groupData.id,
            );
            if (updatedGroup == null) {
              return Scaffold(
                appBar: AppBar(
                  leading: InkWell(
                    onTap: () => context.pop(),
                    child: Icon(CupertinoIcons.arrow_left),
                  ),
                ),
                body: Center(child: CustomText(text: "Group not found")),
              );
            }

            updatedGroupData = GroupChatParams(
              groupData: updatedGroup,
              currentUser: groupData.currentUser,
              memberData: updatedGroup.members ?? [],
            );
            final List<UserInGroup> members = List<UserInGroup>.from(
              updatedGroupData.memberData,
            );

            // ترتيب: Owner → Admins → Normal members
            final owner = members.firstWhere(
              (e) => e.user.id == updatedGroupData.groupData.createdBy,
            );
            final admins = members
                .where((e) => e.isAdmin && e.user.id != owner.user.id)
                .toList();
            final normalUsers = members.where((e) => !e.isAdmin).toList();

            members
              ..clear()
              ..add(owner)
              ..addAll(admins)
              ..addAll(normalUsers);

            final curruntUser = updatedGroupData.currentUser;
            final isCurruntUserAdmin = members
                .firstWhere((e) => e.user.id == curruntUser.id)
                .isAdmin;

            return MultiBlocListener(
              listeners: [
                BlocListener<AddAndRemoveAdminCubit, AddAndRemoveAdminState>(
                  listener: (context, state) {
                    if (state is AddAndRemoveAdminFailure) {
                      CustomSnackBar.error(context, state.errorMessage);
                    }
                  },
                ),
                BlocListener<DeleteMemberCubit, DeleteMemberState>(
                  listener: (context, state) {
                    if (state is DeleteMemberFailure) {
                      CustomSnackBar.error(context, state.erroMessage);
                    }
                  },
                ),
              ],
              child: Scaffold(
                appBar: CustomAppBar(
                  leading: GestureDetector(
                    onTap: () => context.pop(),
                    child: Icon(Icons.arrow_back_ios_new_rounded, size: 17),
                  ),
                  title: "Group Members",
                  actions: [
                    InkWell(
                      onTap: !isCurruntUserAdmin
                          ? null
                          : () {
                              context.pushReplacement(
                                Routes.editGroup,
                                extra: updatedGroupData,
                              );
                            },
                      child: isCurruntUserAdmin
                          ? Icon(CupertinoIcons.gear_alt)
                          : SizedBox.shrink(),
                    ),
                    Gap(10),
                  ],
                ),
                body: ListView.builder(
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    return _AdminBadge(
                      member: member,
                      isCurruntUserAdmin: isCurruntUserAdmin,
                      updatedGroupData: updatedGroupData,
                    );
                  },
                ),
              ),
            );
          } else if (state is FetchGroupsFailure) {
            return Scaffold(
              appBar: AppBar(
                leading: InkWell(
                  onTap: () => context.pop(),
                  child: Icon(Icons.arrow_back_ios_new_rounded, size: 17),
                ),
              ),
              body: Center(child: Text(state.errorMessage)),
            );
          } else {
            return Scaffold(
              body: Center(
                child: CupertinoActivityIndicator(
                  color: Colors.grey,
                  radius: 12,
                ),
              ),
            );
          }
        },
      ),
    );

}
}

class \_AdminBadge extends StatefulWidget {
const \_AdminBadge({
required this.member,
required this.isCurruntUserAdmin,
required this.updatedGroupData,
});

final UserInGroup member;
final bool isCurruntUserAdmin;
final GroupChatParams updatedGroupData;

@override
State<\_AdminBadge> createState() => \_\_AdminBadgeState();
}

class \_\_AdminBadgeState extends State<\_AdminBadge> {
bool isLoadingAdmin = false;
bool isLoadingDelete = false;

@override
Widget build(BuildContext context) {
final member = widget.member;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),

        //  Avatar
        leading: CircleAvatar(
          radius: 20,
          child: ClipOval(
            child: CachedNetworkImage(
              height: 100,
              width: 100,
              fit: BoxFit.fill,
              imageUrl:
                  member.user.image ??
                  'https://static.thenounproject.com/png/1856610-200.png',
              placeholder: (context, url) =>
                  CupertinoActivityIndicator(color: Colors.white54, radius: 9),
              errorWidget: (context, url, error) => const Icon(
                Icons.image_not_supported_outlined,
                color: Colors.red,
                size: 40,
              ),
            ),
          ),
        ),

        //  Name
        title: Text(
          member.user.name ?? '',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),

        //  Admin Badge
        subtitle: member.isAdmin
            ? Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "admin",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber,
                    ),
                  ),
                ),
              )
            : null,

        //  Actions
        trailing:
            widget.isCurruntUserAdmin &&
                member.user.id != widget.updatedGroupData.groupData.createdBy
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ///Toggle Admin
                  Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: isLoadingAdmin
                          ? null
                          : () async {
                              setState(() => isLoadingAdmin = true);

                              try {
                                await context
                                    .read<AddAndRemoveAdminCubit>()
                                    .addAdminAndRemove(
                                      groupId:
                                          widget.updatedGroupData.groupData.id!,
                                      userId: member.user.id!,
                                      isAdmin: member.isAdmin,
                                    );
                              } finally {
                                if (mounted) {
                                  setState(() => isLoadingAdmin = false);
                                }
                              }
                            },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: isLoadingAdmin
                            ? const CupertinoActivityIndicator(radius: 6)
                            : Icon(
                                member.isAdmin
                                    ? Icons.person_remove
                                    : Icons.person_add,
                                size: 18,
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  /// Delete
                  Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: isLoadingDelete
                          ? null
                          : () async {
                              setState(() => isLoadingDelete = true);

                              try {
                                await context
                                    .read<DeleteMemberCubit>()
                                    .deleteMember(
                                      groupId:
                                          widget.updatedGroupData.groupData.id!,
                                      userId: member.user.id!,
                                    );
                              } finally {
                                if (mounted) {
                                  setState(() => isLoadingDelete = false);
                                }
                              }
                            },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: isLoadingDelete
                            ? const CupertinoActivityIndicator(radius: 6)
                            : const Icon(
                                CupertinoIcons.delete,
                                size: 18,
                                color: Colors.red,
                              ),
                      ),
                    ),
                  ),
                ],
              )
            : member.user.id == widget.updatedGroupData.groupData.createdBy
            ? Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  "Creator",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );

}
}

//-----------------------------
class EditGroup extends StatefulWidget {
const EditGroup({super.key, required this.groupData});
final GroupChatParams groupData;

@override
State<EditGroup> createState() => \_EditGroupState();
}

class \_EditGroupState extends State<EditGroup> {
late TextEditingController groupNameController;

final \_formKey = GlobalKey<FormState>();
@override
void initState() {
groupNameController = TextEditingController();
super.initState();
}

@override
void dispose() {
groupNameController.dispose();
super.dispose();
}

@override
Widget build(BuildContext context) {
return GestureDetector(
onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
child: MultiBlocProvider(
providers: [
BlocProvider.value(value: getIt<FetchContactsCubit>()),
BlocProvider.value(value: getIt<FetchGroupsCubit>()),
],
child: Scaffold(
appBar: CustomAppBar(
leading: GestureDetector(
onTap: () => context.pop(),
child: Icon(Icons.arrow_back_ios_new_rounded, size: 17),
),
title: "Edit Group",

            actions: [
              BlocBuilder<DeleteGroupCubit, DeleteGroupState>(
                buildWhen: (prev, curr) =>
                    curr is DeleteGroupCubitLoading ||
                    prev is DeleteGroupCubitLoading,

                builder: (context, state) {
                  final isLoading = state is DeleteGroupCubitLoading;
                  return InkWell(
                    onTap: isLoading
                        ? null
                        : () {
                            context.read<DeleteGroupCubit>().deleteGroup(
                              groupId: widget.groupData.groupData.id!,
                            );
                          },
                    child: isLoading
                        ? CupertinoActivityIndicator(radius: 9)
                        : Icon(CupertinoIcons.delete),
                  );
                },
              ),
              Gap(10),
            ],
          ),
          body: MultiBlocListener(
            listeners: [
              BlocListener<PickImageCubit, PickImageState>(
                listener: (context, state) {
                  if (state is PickImageFailure) {
                    CustomSnackBar.error(context, state.errorMessage);
                  }
                },
              ),
              BlocListener<EditGroupDataCubit, EditGroupDataState>(
                listener: (context, state) {
                  if (state is EditGroupDataSucess) {
                    CustomSnackBar.success(
                      context,
                      "update group data succesfully",
                    );
                    context.pop();
                  }
                  if (state is EditGroupDataFailure) {
                    CustomSnackBar.error(context, state.errorMessage);
                  }
                },
              ),

              BlocListener<DeleteGroupCubit, DeleteGroupState>(
                listener: (context, state) {
                  if (state is DeleteGroupCubitSucess) {
                    CustomSnackBar.success(
                      context,
                      "group deleted successfully",
                    );
                    context.pop();
                    context.pop();
                  }
                  if (state is DeleteGroupCubitFailure) {
                    CustomSnackBar.error(context, state.errorMessage);
                  }
                },
              ),
            ],
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      child: CustomScrollView(
                        slivers: [
                          SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Gap(20),
                                CustomText(
                                  text: "Change Photo",
                                  style: AppTextStyles.headlineSmall,
                                ),
                                Gap(20),

                                /// select new image
                                PickImageWidget(
                                  defaultImageUrl:
                                      widget.groupData.groupData.image,
                                  isProfile: true,
                                ),

                                Gap(20),
                                CustomText(
                                  text: "Change Group Name",
                                  style: AppTextStyles.headlineSmall,
                                ),
                                Gap(5),

                                ///change name
                                CustomTextField(
                                  hint: widget.groupData.groupData.name!,
                                  validation: (v) {
                                    return null;
                                  },
                                  controller: groupNameController,
                                ),

                                /// add members
                                Gap(15),
                                Divider(),
                                Gap(5),
                                CustomText(text: "Add Members"),
                                Gap(5),
                              ],
                            ),
                          ),

                          BlocBuilder<FetchContactsCubit, FetchContactsState>(
                            builder: (context, state) {
                              if (state is FetchContactsSuccess) {
                                final myContacts = state.contacts;
                                return _AddMembers(
                                  myContact: myContacts,
                                  groupData: widget.groupData,
                                );
                              } else if (state is FetchContactsFailure) {
                                return SliverFillRemaining(
                                  child: Center(
                                    child: Text(state.errorMessage),
                                  ),
                                );
                              } else {
                                return SliverFillRemaining(
                                  child: Center(
                                    child: CupertinoActivityIndicator(
                                      radius: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  /// svae changes button
                  _SaveChangesButton(
                    groupNameController: groupNameController,
                    groupData: widget.groupData.groupData,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

}
}
//------------------------------------------------------

class \_AddMembers extends StatelessWidget {
const \_AddMembers({required this.myContact, required this.groupData});
final List<UserModel> myContact;
final GroupChatParams groupData;

@override
Widget build(BuildContext context) {
final groupMemberIds = groupData.memberData
.map((e) => e.user.id)
.toSet(); // ← Set للبحث الأسرع

    // 2️⃣ فلتر الأعضاء اللي مش موجودين
    final List<UserModel> restMembers = myContact
        .where((user) => !groupMemberIds.contains(user.id))
        .toList();

    return SliverList(
      delegate: SliverChildBuilderDelegate(childCount: restMembers.length, (
        context,
        index,
      ) {
        return BlocBuilder<SelectGroupMembersCubit, SelectGroupMembersState>(
          builder: (context, state) {
            final selectedMembers = context
                .read<SelectGroupMembersCubit>()
                .selectedMembers
                .contains(restMembers[index]);
            return Container(
              margin: const EdgeInsets.fromLTRB(0, 6, 20, 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
              ),
              child: CheckboxListTile(
                value: selectedMembers,

                onChanged: (value) {
                  context.read<SelectGroupMembersCubit>().addMembers(
                    user: restMembers[index],
                  );
                },
                activeColor: AppColors.primary,
                checkColor: Colors.white,
                checkboxShape: CircleBorder(),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                dense: true,
                visualDensity: VisualDensity.compact,
                title: CustomText(
                  text: restMembers[index].name ?? "",
                  style: AppTextStyles.headlineSmall,
                ),
                subtitle: CustomText(
                  text: "Online",
                  style: AppTextStyles.bodySmall,
                ),
                secondary: CircleAvatar(
                  radius: 20,
                  child: ClipOval(
                    child: CachedNetworkImage(
                      height: 100,
                      width: 100,
                      fit: BoxFit.fill,
                      imageUrl:
                          restMembers[index].image ??
                          'https://i.pravatar.cc/150?img=3',
                      placeholder: (context, url) => CupertinoActivityIndicator(
                        color: Colors.white54,
                        radius: 9,
                      ),
                      errorWidget: (context, url, error) => const Icon(
                        Icons.image_not_supported_outlined,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  ),
                ),

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          },
        );
      }),
    );

}
}

//----------------------------------
class \_SaveChangesButton extends StatelessWidget {
const \_SaveChangesButton({
required this.groupNameController,
required this.groupData,
});

final TextEditingController groupNameController;
final GroupModel groupData;

@override
Widget build(BuildContext context) {
return ValueListenableBuilder<TextEditingValue>(
valueListenable: groupNameController,
builder: (context, value, \_) {
final isEmpty = value.text.trim().isEmpty;
return Padding(
padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
child: BlocBuilder<PickImageCubit, PickImageState>(
builder: (context, state) {
final imageFile = context.read<PickImageCubit>().imageFile;
return BlocBuilder<
SelectGroupMembersCubit,
SelectGroupMembersState >(
builder: (context, state) {
final addedMembers = context
.read<SelectGroupMembersCubit>()
.selectedMembers;

                  return BlocBuilder<EditGroupDataCubit, EditGroupDataState>(
                    buildWhen: (prev, curr) =>
                        curr is EditGroupDataLoading ||
                        prev is EditGroupDataLoading,
                    builder: (context, state) {
                      final isLoading = state is EditGroupDataLoading;
                      return CustomButton(
                        color:
                            isEmpty && imageFile == null && addedMembers.isEmpty
                            ? AppColors.border
                            : null,
                        onPressed:
                            (!isEmpty ||
                                    imageFile != null ||
                                    addedMembers.isNotEmpty) &&
                                !isLoading
                            ? () {
                                final members = context
                                    .read<SelectGroupMembersCubit>()
                                    .selectedMembers;
                                context
                                    .read<EditGroupDataCubit>()
                                    .editGroupData(
                                      groupData: groupData,
                                      name: groupNameController.text.trim(),
                                      newImageFile: imageFile,
                                      members: members,
                                    );
                              }
                            : null,
                        raduis: 10,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CustomText(text: "save"),
                            Gap(10),
                            isLoading
                                ? CupertinoActivityIndicator(
                                    color: Colors.grey,
                                    radius: 10,
                                  )
                                : SizedBox.shrink(),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );

}
}
//---------------------------------------------------------------------
import 'package:chattr/core/cubits/select_messages/select_messages_cubit.dart';
import 'package:chattr/core/themes/app_colors.dart';
import 'package:chattr/core/themes/app_text_styles.dart';
import 'package:chattr/core/widgets/custom_button.dart';
import 'package:chattr/core/widgets/custom_text.dart';
import 'package:chattr/core/widgets/custom_text_field.dart';
import 'package:chattr/features/group_chats/data/models/group_message_model.dart';
import 'package:chattr/features/group_chats/presentation/cubits/fetch_group_messages_cubit/fetch_group_messages_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class EditGroupMessageButtomSheet extends StatefulWidget {
const EditGroupMessageButtomSheet({
super.key,
required this.message,
required this.groupId,
});
final String message;
final String groupId;

@override
EditGroupMessageButtomSheetState createState() =>
EditGroupMessageButtomSheetState();
}

class EditGroupMessageButtomSheetState
extends State<EditGroupMessageButtomSheet> {
late TextEditingController controller;
void \_editmessage() {
final List<GroupMessageModel> selected = context
.read<SelectMessagesCubit>()
.selectedMessages
.cast<GroupMessageModel>();
context.read<FetchGroupMessagesCubit>().editMessageGroup(
groupId: widget.groupId,
message: selected[0],
content: controller.text.trim(),
);
context.read<SelectMessagesCubit>().clearSelection();
}

@override
void initState() {
controller = TextEditingController(text: widget.message);
super.initState();
}

@override
Widget build(BuildContext context) {
return Padding(
padding: EdgeInsets.only(
bottom: MediaQuery.of(context).viewInsets.bottom, // علشان الكيبورد
left: 16,
right: 16,
top: 20,
),
child: SingleChildScrollView(
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
CustomText(
text: "Edit Message",
style: AppTextStyles.headlineSmall,
),
Gap(5),
CustomTextField(
hint: "",
controller: controller,
maxLines: 4,
validation: (v) {
return null;
},
),
Gap(20),
ValueListenableBuilder<TextEditingValue>(
valueListenable: controller,
builder: (context, value, child) {
final bool isChanged =
value.text.trim() != widget.message &&
value.text.trim().isNotEmpty;
return CustomButton(
onPressed: isChanged
? () {
\_editmessage();
context.pop();
}
: null,
color: isChanged ? AppColors.primary : AppColors.inputBorder,
raduis: 10,
child: Row(
mainAxisAlignment: MainAxisAlignment.center,
children: [CustomText( text: "SAVE",style: AppTextStyles.headlineSmall,)],
),
);
},
),
Gap(10),
],
),
),
);
}
}
//------------------------------------------------------------------

import 'package:chattr/core/services/hive/hive_type_ids.dart';
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:hive/hive.dart';

part 'private_chat_model.g.dart';

@HiveType(typeId: HiveTypeIds.privateChats)
class PrivateChatModel {
@HiveField(0)
final String? chatId;

@HiveField(1)
final List<String>? members;

@HiveField(2)
final String? lastMessage;

@HiveField(3)
final DateTime? lastMessageTime;

@HiveField(4)
final DateTime createdAt;

@HiveField(5)
final UserModel? friend;

@HiveField(6)
final String? membersId;
@HiveField(7)
final String? lastMessageSenderId;

// مش محتاج HiveField — بيتحسب runtime بس
final int unreadCount;

PrivateChatModel({
this.chatId,
required this.members,
required this.membersId,
required this.lastMessage,
required this.lastMessageTime,
required this.createdAt,
this.lastMessageSenderId,
this.friend,
this.unreadCount = 0,
});

factory PrivateChatModel.fromJson(
Map<String, dynamic> json,
UserModel friend,
) {
return PrivateChatModel(
chatId: json['chat_id'] ?? '',
membersId: json['members_id'] ?? '',
members: (json['members'] as List<dynamic>?)
?.map((e) => e.toString())
.toList(),
lastMessage: json['last_message'] ?? '',
lastMessageTime: DateTime.tryParse(json['last_message_time'] ?? ''),
createdAt: DateTime.tryParse(json['created_at'])!,
friend: friend,
unreadCount: 0,
lastMessageSenderId: json['last_message_sender_id'] ?? '',
);
}

Map<String, dynamic> toJson() {
return {
'members_id': membersId,
'members': members ?? [],
'last_message': lastMessage,
'last_message_time': lastMessageTime,
'created_at': createdAt.toIso8601String(),
};
}

PrivateChatModel copyWith({
List<String>? members,
String? lastMessage,
String? lastMessageSenderId,
DateTime? lastMessageTime,
DateTime? createdAt,
UserModel? friend,
int? unreadCount,
}) {
return PrivateChatModel(
chatId: chatId,
membersId: membersId,
members: members ?? this.members,
lastMessage: lastMessage ?? this.lastMessage,
lastMessageTime: lastMessageTime ?? this.lastMessageTime,
createdAt: createdAt ?? this.createdAt,
friend: friend ?? this.friend,
lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
unreadCount: unreadCount ?? this.unreadCount,
);
}
}
//------------------------------------------------------
import 'package:chattr/core/services/hive/hive_type_ids.dart';
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'private_message_model.g.dart';

@HiveType(typeId: HiveTypeIds.privateMessageStatus)
enum PrivateMessageStatus {
@HiveField(0)
sending,
@HiveField(1)
sent,
@HiveField(2)
failed,
@HiveField(3)
deleting,
@HiveField(4)
deleteFailed,
@HiveField(5)
editing,
@HiveField(6)
editingFaild,
}

@HiveType(typeId: HiveTypeIds.privateMessageType)
enum PrivateMessageType {
@HiveField(0)
text,
@HiveField(1)
image,
@HiveField(2)
video,
@HiveField(3)
voice,
}

extension MessageTypeParser on String {
PrivateMessageType toPrivateMessageType() {
switch (this) {
case 'text':
return PrivateMessageType.text;
case 'image':
return PrivateMessageType.image;
case 'video':
return PrivateMessageType.video;
case 'voice':
return PrivateMessageType.voice;
default:
return PrivateMessageType.text;
}
}
}

extension MessageTypeToJson on PrivateMessageType {
String toJson() => name;
}

@HiveType(typeId: HiveTypeIds.privateMessages)
class PrivateMessageModel {
@HiveField(0)
final String tempId;

@HiveField(1)
final String? messageId;

@HiveField(2)
final String chatId;

@HiveField(3)
final String senderId;

@HiveField(4)
final PrivateMessageStatus privateMessageStatus;

@HiveField(5)
final PrivateMessageType privateMessageType;

@HiveField(6)
final String content;

@HiveField(7)
final DateTime createdAt;

@HiveField(8)
final bool isDeleted;

@HiveField(9)
final bool? read;

@HiveField(10)
final UserModel? sender;

@HiveField(11) // ← جديد
final String? localPath;
@HiveField(12)
final int? mediaDuration;

PrivateMessageModel({
required this.tempId,
this.messageId,
required this.chatId,
required this.senderId,

    required this.privateMessageStatus,
    required this.privateMessageType,
    required this.content,
    required this.createdAt,
    required this.isDeleted,
    this.read,
    this.sender,
    this.localPath,
    this.mediaDuration,

});

factory PrivateMessageModel.fromJson(Map<String, dynamic> json) {
return PrivateMessageModel(
tempId:
json['temp_id'] ??
const Uuid().v4(), // لو ما في temp_id، نولد واحد جديد
messageId: json['message_id'],
chatId: json['chat_id'],
senderId: json['sender_id'],
privateMessageStatus: PrivateMessageStatus.sent,
privateMessageType: (json['message_type'] as String)
.toPrivateMessageType(),
content: json['content'] ?? '',
mediaDuration: json['media_duration'],
createdAt: DateTime.parse(json['created_at']),
isDeleted: json['is_deleted'] ?? false,
read: json['read'] ?? false,
sender: null, // لاحقًا تحط بيانات UserModel لو متاحة
);
}

Map<String, dynamic> toJson() {
return {
'temp_id': tempId,
'chat_id': chatId,
'sender_id': senderId,
'media_duration': mediaDuration,
'message_type': privateMessageType.toJson(),
'content': content,
'created_at': createdAt.toIso8601String(),
'is_deleted': isDeleted,
'read': read,
};
}

PrivateMessageModel copyWith({
String? tempId,
String? messageId,
String? content,
PrivateMessageStatus? privateMessageStatus,
bool? isDeleted,
bool? read,
UserModel? sender,
String? localPath,
DateTime? createdAt,
int? mediaDuration,
}) {
return PrivateMessageModel(
tempId: tempId ?? this.tempId,
messageId: messageId ?? this.messageId,
chatId: chatId,
senderId: senderId,
privateMessageStatus: privateMessageStatus ?? this.privateMessageStatus,
privateMessageType: privateMessageType,
content: content ?? this.content,
createdAt: createdAt ?? this.createdAt,
isDeleted: isDeleted ?? this.isDeleted,
read: read ?? this.read,
sender: sender ?? this.sender,
localPath: localPath ?? this.localPath,
mediaDuration: mediaDuration ?? this.mediaDuration,
);
}
}
//------------------------------------------------------------------
import 'package:chattr/core/services/hive/hive_services.dart';
import 'package:chattr/core/services/supabase/supabase_client_manager.dart';
import 'package:chattr/core/services/supabase/supabase_crud_services.dart';
import 'package:chattr/core/services/supabase/supabase_error.dart';
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:chattr/features/private_chats/data/models/private_chat_model.dart';
import 'package:chattr/features/private_chats/data/repos/add_friend_repo/add_friend_repo.dart';
import 'package:dartz/dartz.dart';

class AddFriendRepoImpl implements AddFriendRepo {
final SupabaseCrudServices \_crud;
final SupabaseClientManager \_client;
AddFriendRepoImpl(this.\_crud, this.\_client);

@override
Future<Either<SupabaseError, PrivateChatModel>> addFriend(
String email,
) async {
try {
final myId = \_client.client.auth.currentUser?.id;

      // 1. Verify friend exists
      final friendData = await _crud.getByFilter(
        table: 'messenger_users',
        filterColumn: 'email',
        filterValue: email,
      );

      if (friendData == null) {
        return Left(SupabaseError(message: 'User not found'));
      }

      final friendId = friendData['id'] as String;

      // 2. Prevent adding yourself
      if (friendId == myId) {
        return Left(SupabaseError(message: 'You cannot add yourself'));
      }

      // 3. Check if chat already exists
      final existing = await _crud.getByFilter(
        table: 'private_chats',
        filterColumn: 'members_id',
        filterValue: '$myId-$friendId',
      );

      if (existing != null) {
        return Left(SupabaseError(message: 'Chat already exists'));
      }
      final chatData = PrivateChatModel(
        members: [myId!, friendId],
        membersId: '$myId-$friendId',
        lastMessage: null,
        lastMessageTime: null,
        createdAt: DateTime.now().toUtc(),
      );

      // 4. Create chat
      final response = await _crud.post(
        table: 'private_chats',
        data: chatData.toJson(),
      );

      final friend = UserModel.fromJson(friendData);
      await HiveService.saveUser(friend);
      final chat = PrivateChatModel.fromJson(response, friend);
      await Future.delayed(const Duration(seconds: 1), () {});
      return Right(chat);
    } catch (e) {
      return Left(SupabaseError(message: "$e"));
    }

}
}
//----------------------------------------------------------------
import 'package:chattr/core/services/supabase/supabase_error.dart';
import 'package:chattr/features/private_chats/data/models/private_chat_model.dart';
import 'package:dartz/dartz.dart';

abstract interface class AddFriendRepo {
Future<Either<SupabaseError, PrivateChatModel>> addFriend(String email);
}
//------------------------------------------------------------------
import 'package:chattr/core/services/hive/hive_services.dart';
import 'package:chattr/core/services/supabase/supabase_auth_services.dart';
import 'package:chattr/core/services/supabase/supabase_client_manager.dart';
import 'package:chattr/core/services/supabase/supabase_error.dart';
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:chattr/features/private_chats/data/models/private_chat_model.dart';
import 'package:chattr/features/private_chats/data/repos/fetch_private_chats_repo/fetch_private_chat_repo.dart';
import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FetchPrivateChatRepoImpl implements FetchPrivateChatRepo {
final AuthService \_auth;
final SupabaseClientManager client;

FetchPrivateChatRepoImpl(this.\_auth, this.client);
SupabaseClient get \_client => client.client;

@override
Future<Either<SupabaseError, Map<String, UserModel>>> fetchFriendsData(
List<String> friendIds,
) async {
try {
if (friendIds.isEmpty) return const Right({});

      final response = await _client
          .from('messenger_users')
          .select()
          .inFilter('id', friendIds);

      return right({for (final u in response) u['id']: UserModel.fromJson(u)});
    } catch (e) {
      return Left(SupabaseError(message: "$e"));
    }

}

@override
Future<Either<String, List<PrivateChatModel>>> getLocalChats() async {
try {
final chats = await HiveService.getPrivateChats();
return Right(chats);
} catch (e) {
return Left('$e');
}
}

@override
Future<Either<String, Unit>> saveChatsLocally(
List<PrivateChatModel> chats,
) async {
try {
await HiveService.clearChats();
for (final chat in chats) {
await HiveService.savePrivateChat(chat);
}
return const Right(unit);
} catch (e) {
return Left('$e');
}
}

@override
Future<Either<SupabaseError, List<PrivateChatModel>>>
fetchChatsFromServer() async {
try {
final myId = \_auth.currentUser!.id;

      final response = await _client
          .from('private_chats')
          .select()
          .contains('members', [myId])
          .order('last_message_time', ascending: false);

      if (response.isEmpty) {
        await HiveService.clearChats();
        return right([]);
      }

      final friendIds = <String>{};
      for (final chat in response) {
        final members = List<String>.from(chat['members']);
        final friendId = members.firstWhere(
          (id) => id != myId,
          orElse: () => '',
        );
        if (friendId.isNotEmpty) friendIds.add(friendId);
      }

      // ✅ استخرج الـ usersMap قبل الـ map وتحقق من الـ error
      final usersMapResult = await fetchFriendsData(friendIds.toList());

      if (usersMapResult.isLeft()) {
        return Left(
          SupabaseError(
            message: usersMapResult.fold((l) => l.message, (_) => ''),
          ),
        );
      }

      final usersMap = usersMapResult.fold(
        (_) => <String, UserModel>{},
        (r) => r,
      );

      final chats = response.map<PrivateChatModel>((chat) {
        final members = List<String>.from(chat['members']);
        final friendId = members.firstWhere(
          (id) => id != myId,
          orElse: () => '',
        );
        // ✅ friend جوا الـ map مباشرة — مش late خارجها
        final friend = usersMap[friendId]!;
        return PrivateChatModel.fromJson(chat, friend);
      }).toList();

      await saveChatsLocally(chats);
      return Right(chats);
    } catch (e) {
      return Left(SupabaseError(message: '$e'));
    }

}
}
//-------------------------------------------------------------
import 'package:chattr/core/services/supabase/supabase_error.dart';
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:chattr/features/private_chats/data/models/private_chat_model.dart';
import 'package:dartz/dartz.dart';

abstract interface class FetchPrivateChatRepo {
Future<Either<SupabaseError, List<PrivateChatModel>>> fetchChatsFromServer();

Future<Either<String, List<PrivateChatModel>>> getLocalChats();

Future<Either<String, Unit>> saveChatsLocally(List<PrivateChatModel> chats);

Future<Either<SupabaseError, Map<String, UserModel>>> fetchFriendsData(
List<String> friendIds,
);
}
//-------------------------------------------------------------------
import 'package:chattr/core/services/hive/hive_services.dart';
import 'package:chattr/core/services/supabase/supabase_client_manager.dart';
import 'package:chattr/core/services/supabase/supabase_error.dart';
import 'package:chattr/features/private_chats/data/models/private_message_model.dart';
import 'package:chattr/features/private_chats/data/repos/fetch_private_messages_repo/fetch_private_messages_repo.dart';
import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FetchPrivateMessagesRepoImpl implements FetchPrivateMessagesRepo {
final SupabaseClientManager client;
FetchPrivateMessagesRepoImpl(this.client);
SupabaseClient get \_client => client.client;

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
await \_client
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
await \_client
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
final rows = await \_client
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
final rows = await \_client
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
await \_client
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
//----------------------------------------------------------------
import 'package:chattr/core/services/supabase/supabase_error.dart';
import 'package:chattr/features/private_chats/data/models/private_message_model.dart';
import 'package:dartz/dartz.dart';

abstract interface class FetchPrivateMessagesRepo {
Future<Either<SupabaseError, List<PrivateMessageModel>>>
fetchInitialMessages({required String chatId, required int pageSize});

/// جيب الصفحة التالية (pagination)
Future<Either<SupabaseError, List<PrivateMessageModel>>> fetchMoreMessages({
required String chatId,
required DateTime before,
required int pageSize,
});

/// حدّث الرسايل المحددة كـ read في DB
Future<Either<SupabaseError, Unit>> markMessagesAsRead(
List<String> messageIds,
);

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
Future<Either<String, PrivateMessageModel?>> getLocalMessage(
String messageId,
);
}
//-------------------------------------------------------------
import 'dart:io';

import 'package:chattr/core/services/supabase/supabase_crud_services.dart';
import 'package:chattr/core/services/supabase/supabase_error.dart';
import 'package:chattr/core/services/supabase/supabase_storage.dart';
import 'package:chattr/features/private_chats/data/models/private_message_model.dart';
import 'package:chattr/features/private_chats/data/repos/send_private_message_repo/send_private_message_repo.dart';
import 'package:dartz/dartz.dart';

class SendPrivateMessageRepoImpl implements SendPrivateMessageRepo {
const SendPrivateMessageRepoImpl({
required SupabaseCrudServices crud,
required SupabaseStorage storage,
}) : \_crud = crud,
\_storage = storage;

final SupabaseCrudServices \_crud;
final SupabaseStorage \_storage;

@override
Future<Either<SupabaseError, PrivateMessageModel>> sendMessage(
PrivateMessageModel message,
) async {
try {
final response = await \_crud.post(
table: 'message',
data: message.toJson(),
);
return right(PrivateMessageModel.fromJson(response));
} catch (e) {
return left(SupabaseError(message: e.toString()));
}
}

@override
Future<Either<SupabaseError, String>> uploadImage(File imageFile) async {
try {
final path = await \_storage.uploadImage(
file: imageFile,
storageFile: 'chat_images',
);
final url = \_storage.getFileUrl(path: path, storageFile: 'chat_images');
return right(url);
} catch (e) {
return left(SupabaseError(message: e.toString()));
}
}

@override
Future<Either<SupabaseError, String>> uploadAudio(File audioFile) async {
try {
final path = await \_storage.uploadAudio(
file: audioFile,
storageFile: 'chat-audio',
);
final url = \_storage.getFileUrl(path: path, storageFile: 'chat-audio');
return right(url);
} catch (e) {
return left(SupabaseError(message: e.toString()));
}
}
}
//--------------------------------------------------------------
import 'dart:io';

import 'package:chattr/core/services/supabase/supabase_error.dart';
import 'package:chattr/features/private_chats/data/models/private_message_model.dart';
import 'package:dartz/dartz.dart';

abstract interface class SendPrivateMessageRepo {
Future<Either<SupabaseError, PrivateMessageModel>> sendMessage(
PrivateMessageModel message,
);

Future<Either<SupabaseError, String>> uploadImage(File imageFile);

Future<Either<SupabaseError, String>> uploadAudio(File audioFile);
}
//------------------------------------------------------------------
import 'package:chattr/features/private_chats/data/models/private_chat_model.dart';
import 'package:chattr/features/private_chats/data/repos/add_friend_repo/add_friend_repo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'add_friend_state.dart';

class AddFriendCubit extends Cubit<AddFriendState> {
AddFriendCubit(this.\_repo) : super(AddFriendInitial());
final AddFriendRepo \_repo;

Future<void> addFriend({required String email}) async {
emit(AddFriendLoading());
final result = await \_repo.addFriend(email);
result.fold(
(l) => emit(AddFriendFailure(errMessage: l.message)),
(r) => emit(AddFriendSuccess(chat: r)),
);
}
}
//--------------------------------------------------------------------
part of 'add_friend_cubit.dart';

@immutable
sealed class AddFriendState {}

final class AddFriendInitial extends AddFriendState {}

final class AddFriendLoading extends AddFriendState {}

final class AddFriendSuccess extends AddFriendState {
final PrivateChatModel chat;
AddFriendSuccess({required this.chat});
}

final class AddFriendFailure extends AddFriendState {
final String errMessage;

AddFriendFailure({required this.errMessage});
}
//---------------------------------------------------------------------
import 'dart:async';
import 'dart:io';

import 'package:chattr/core/services/supabase/supabase_client_manager.dart';
import 'package:chattr/features/private_chats/data/models/private_chat_model.dart';
import 'package:chattr/features/private_chats/data/repos/fetch_private_chats_repo/fetch_private_chat_repo.dart';
import 'package:chattr/features/private_chats/presentation/cubits/fetch_private_messages_cubit/fetch_private_messages_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'fetch_private_chats_state.dart';

class FetchPrivateChatsCubit extends Cubit<FetchPrivateChatsState> {
FetchPrivateChatsCubit({
required this.fetchMessages,
required FetchPrivateChatRepo repo,
required this.client,
}) : \_repo = repo,
super(FetchPrivateChatsInitial());

final FetchPrivateMessagesCubit fetchMessages;
final FetchPrivateChatRepo \_repo;
final SupabaseClientManager client;
SupabaseClient get \_client => client.client;

RealtimeChannel? \_privateChatsChannel;
RealtimeChannel? \_presenceChannel;
Timer? \_debounceTimer;

List<PrivateChatModel> privateChatsCache = [];

// ─────────────────────────────────────────────────────────────────
// FETCH CHATS
// ─────────────────────────────────────────────────────────────────

Future<void> fetchPrivateChats() async {
if (privateChatsCache.isNotEmpty) {
emit(FetchPrivateChatsSuccess(chats: List.from(privateChatsCache)));
// خليه يحدّث في الخلفية من غير loading
await \_fetchFromServer();
return;
}
try {
emit(FetchPrivateChatsloading());

      // 1️⃣ Hive أولاً
      final localResult = await _repo.getLocalChats();

      if (localResult.isLeft()) {
        emit(
          FetchChatsFailure(
            errorMessage: localResult.fold((l) => l, (_) => ''),
          ),
        );
        return;
      } else {
        final r = localResult.fold((_) => <PrivateChatModel>[], (r) => r);
        if (r.isNotEmpty) {
          privateChatsCache = r;
          await _loadMessagesAndUpdateUnread(privateChatsCache);
          if (!isClosed) {
            emit(FetchPrivateChatsSuccess(chats: List.from(privateChatsCache)));
          }
        }
      }

      // 2️⃣ Server
      await _fetchFromServer();

      // 3️⃣ Realtime
      _listenToChatsChanges();
      _listenToFriendsPresence();
    } on AuthException catch (e) {
      emit(FetchChatsFailure(errorMessage: e.message));
    } on SocketException {
      emit(FetchChatsFailure(errorMessage: 'No internet connection'));
    } catch (e) {
      emit(FetchChatsFailure(errorMessage: '$e'));
    }

}
// ─────────────────────────────────────────────────────────────────
// FETCH FROM SERVER
// ─────────────────────────────────────────────────────────────────

Future<void> \_fetchFromServer() async {
final result = await \_repo.fetchChatsFromServer();

    if (result.isLeft()) {
      final err = result.fold((l) => l.message, (_) => '');
      emit(FetchChatsFailure(errorMessage: err));
      return;
    }

    final r = result.fold((_) => <PrivateChatModel>[], (r) => r);

    if (r.isEmpty) {
      privateChatsCache = [];
      if (!isClosed) emit(FetchPrivateChatsSuccess(chats: []));
      return;
    }

    privateChatsCache = r;
    await _loadMessagesAndUpdateUnread(privateChatsCache);
    _listenToFriendsPresence();

    if (!isClosed) {
      emit(FetchPrivateChatsSuccess(chats: List.from(privateChatsCache)));
    }

}
// ─────────────────────────────────────────────────────────────────
// CORE — حمّل رسايل كل chat واحسب الـ unread count
// ─────────────────────────────────────────────────────────────────

Future<void> \_loadMessagesAndUpdateUnread(
List<PrivateChatModel> chats,
) async {
await Future.wait(
chats.map((chat) async {
if (chat.chatId == null) return;
await fetchMessages.loadInitialMessages(chatId: chat.chatId!);
}),
);

    for (var i = 0; i < privateChatsCache.length; i++) {
      final chatId = privateChatsCache[i].chatId;
      if (chatId == null) continue;
      final unread = fetchMessages.getUnreadCount(chatId);
      debugPrint('🟡 _loadMessagesAndUpdateUnread: $chatId → $unread');
      privateChatsCache[i] = privateChatsCache[i].copyWith(unreadCount: unread);
    }

}

// ─────────────────────────────────────────────────────────────────
// UNREAD
// ─────────────────────────────────────────────────────────────────

void refreshUnreadCount(String chatId) {
final idx = privateChatsCache.indexWhere((c) => c.chatId == chatId);
if (idx == -1) return;
final unread = fetchMessages.getUnreadCount(chatId);
debugPrint('🔵 refreshUnreadCount: $chatId → $unread');
privateChatsCache[idx] = privateChatsCache[idx].copyWith(
unreadCount: unread,
);

    if (!isClosed) {
      emit(FetchPrivateChatsSuccess(chats: List.from(privateChatsCache)));
    }

}

// ─────────────────────────────────────────────────────────────────
// FRIENDS PRESENCE — stream واحد لكل الـ friends
// ─────────────────────────────────────────────────────────────────

void \_listenToFriendsPresence() {
\_presenceChannel?.unsubscribe();

    final friendIds = privateChatsCache
        .map((c) => c.friend?.id)
        .whereType<String>()
        .toList();

    if (friendIds.isEmpty) return;

    _presenceChannel = _client
        .channel('friends_presence')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messenger_users',
          callback: (payload) {
            final updatedId = payload.newRecord['id'] as String?;
            if (updatedId == null) return;
            if (!friendIds.contains(updatedId)) return;

            final idx = privateChatsCache.indexWhere(
              (c) => c.friend?.id == updatedId,
            );
            if (idx == -1) return;

            final updatedFriend = privateChatsCache[idx].friend?.copyWith(
              isOnLine: payload.newRecord['is_online'] as bool?,
              lastSeen: payload.newRecord['last_seen'] != null
                  ? DateTime.tryParse(payload.newRecord['last_seen'] as String)
                  : null,
            );

            if (updatedFriend == null) return;

            privateChatsCache[idx] = privateChatsCache[idx].copyWith(
              friend: updatedFriend,
            );

            if (!isClosed) {
              emit(
                FetchPrivateChatsSuccess(chats: List.from(privateChatsCache)),
              );
            }
          },
        )
        .subscribe();

}

// ─────────────────────────────────────────────────────────────────
// CHATS REALTIME
// ─────────────────────────────────────────────────────────────────

void \_listenToChatsChanges() {
\_privateChatsChannel?.unsubscribe();

    _privateChatsChannel = _client
        .channel('private_chats_${DateTime.now().millisecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'private_chats',
          callback: (payload) {
            final chatId =
                payload.newRecord['chat_id'] ?? payload.oldRecord['chat_id'];
            debugPrint('📡 Realtime chats: $chatId');
            _debouncedFetch();
          },
        )
        .subscribe();

}

void \_debouncedFetch() {
\_debounceTimer?.cancel();
\_debounceTimer = Timer(const Duration(milliseconds: 300), \_fetchFromServer);
}

// ─────────────────────────────────────────────────────────────────
// DISPOSE
// ─────────────────────────────────────────────────────────────────

@override
Future<void> close() {
\_debounceTimer?.cancel();
\_privateChatsChannel?.unsubscribe();
\_presenceChannel?.unsubscribe();
return super.close();
}
}
//------------------------------------------------------------------
part of 'fetch_private_chats_cubit.dart';

@immutable
sealed class FetchPrivateChatsState {}

final class FetchPrivateChatsInitial extends FetchPrivateChatsState {}

final class FetchPrivateChatsloading extends FetchPrivateChatsState {}

final class FetchPrivateChatsSuccess extends FetchPrivateChatsState {
final List<PrivateChatModel> chats;

FetchPrivateChatsSuccess({required this.chats});
}

final class FetchChatsFailure extends FetchPrivateChatsState {
final String errorMessage;
FetchChatsFailure({required this.errorMessage});
}
//------------------------------------------------------------------
import 'dart:async';

import 'package:chattr/core/cache/users_cache.dart';
import 'package:chattr/core/services/hive/hive_services.dart';
import 'package:chattr/core/services/supabase/supabase_auth_services.dart';
import 'package:chattr/core/services/supabase/supabase_client_manager.dart';
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:chattr/features/private_chats/data/models/private_message_model.dart';
import 'package:chattr/features/private_chats/data/repos/fetch_private_messages_repo/fetch_private_messages_repo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'fetch_private_messages_state.dart';

class FetchPrivateMessagesCubit extends Cubit<FetchPrivateMessagesState> {
FetchPrivateMessagesCubit({
required FetchPrivateMessagesRepo repo,
required this.client,
required AuthService auth,
}) : \_repo = repo,
\_auth = auth,
super(FetchPrivateMessagesInitial());

final FetchPrivateMessagesRepo \_repo;
final SupabaseClientManager client;
final AuthService \_auth;
SupabaseClient get \_client => client.client;
String get \_myId => \_auth.currentUser!.id;

final Map<String, List<PrivateMessageModel>> \_cache = {};
final Map<String, DateTime?> \_oldestDate = {};
final Map<String, bool> \_hasMoreMap = {};
final Map<String, bool> \_loadingMoreMap = {};
final Map<String, StreamSubscription> \_streams = {};

// tempIds اللي لسه upload — الـ stream يتجاهلهم تماماً
final Set<String> \_pendingTempIds = {};

// reference للـ FetchPrivateChatsCubit عشان نحدّث الـ unread count
dynamic \_chatsCubit;
void setChatsCubit(dynamic cubit) => \_chatsCubit = cubit;

static const int \_pageSize = 30;

bool hasMore(String chatId) => \_hasMoreMap[chatId] ?? true;
List<PrivateMessageModel>? getMessages(String chatId) => \_cache[chatId];

/// عدد الرسايل الغير مقروءة اللي مش أنا اللي بعتها
int getUnreadCount(String chatId) {
final msgs = \_cache[chatId];
if (msgs == null) return 0;
return msgs.where((m) => m.read == false && m.senderId != \_myId).length;
}

// ─────────────────────────────────────────────────────────────────
// LOAD INITIAL
// ─────────────────────────────────────────────────────────────────

Future<void> loadInitialMessages({required String chatId}) async {
final alreadyCached = \_cache[chatId]?.isNotEmpty == true;
final alreadySubscribed = \_streams.containsKey(chatId);

    if (alreadyCached && alreadySubscribed) {
      _emit(chatId);
      return;
    }

    if (!alreadyCached) emit(FetchPrivateMessagesLoading());

    // 1️⃣ Hive — لو مفيش cache
    if (!alreadyCached) {
      final localResult = await _repo.getLocalMessages(
        chatId: chatId,
        limit: _pageSize,
      );
      localResult.fold(
        (l) {
          debugPrint('❌ getLocalMessages: $l');
          if (_cache[chatId]?.isNotEmpty != true) {
            emit(FetchPrivateMessagesfailure(errMessage: l.toString()));
          }
        },
        (local) {
          if (local.isNotEmpty) {
            _cache[chatId] = List.from(local);
            _emit(chatId);
          }
        },
      );
    }

    // 2️⃣ Server — بس لو أول مرة
    // ✅ استخرج الـ value خارج الـ fold عشان الـ async يشتغل صح
    if (!alreadyCached) {
      final serverResult = await _repo.fetchInitialMessages(
        chatId: chatId,
        pageSize: _pageSize,
      );

      if (serverResult.isLeft()) {
        final err = serverResult.fold((l) => l.toString(), (_) => '');
        debugPrint('❌ fetchInitialMessages: $err');
        if (_cache[chatId]?.isNotEmpty != true) {
          emit(FetchPrivateMessagesfailure(errMessage: err));
        }
      } else {
        final serverMsgs = serverResult.fold(
          (_) => <PrivateMessageModel>[],
          (r) => r,
        );

        // كل الـ async خارج الـ fold تماماً
        await _fetchMissingUsers(serverMsgs);
        final enriched = await _attachLocalPaths(serverMsgs);
        final merged = _mergeWithCache(_cache[chatId], enriched);
        _cache[chatId] = merged;

        if (serverMsgs.isNotEmpty) {
          _oldestDate[chatId] = serverMsgs.first.createdAt;
          _hasMoreMap[chatId] = serverMsgs.length == _pageSize;
        } else {
          _hasMoreMap[chatId] = false;
        }

        await _persistAll(enriched);
        _emit(chatId);
      }
    }

    // 3️⃣ Realtime — بس لو مش مشترك
    if (!alreadySubscribed) _subscribe(chatId);

}

// ─────────────────────────────────────────────────────────────────
// REALTIME
// ─────────────────────────────────────────────────────────────────

void \_subscribe(String chatId) {
\_cache.putIfAbsent(chatId, () => []);
\_streams[chatId]?.cancel();

    _streams[chatId] = _client
        .from('message')
        .stream(primaryKey: ['message_id'])
        .eq('chat_id', chatId)
        .listen((event) {
          if (isClosed) return;
          final incoming = event
              .map<PrivateMessageModel>((r) => PrivateMessageModel.fromJson(r))
              .toList();
          _processSnapshot(chatId, incoming);
        }, onError: (e) => debugPrint('❌ Realtime stream error ($chatId): $e'));

}

// ✅ مش async — sync بالكامل عشان الـ stream events تتعالج بالترتيب
void \_processSnapshot(String chatId, List<PrivateMessageModel> incoming) {
final list = \_cache[chatId]!;
bool dirty = false;

    for (final msg in incoming) {
      if (_pendingTempIds.contains(msg.tempId)) continue;

      final idx = _findIndex(list, msg);
      final existingPath = idx != -1 ? list[idx].localPath : null;
      final enriched = existingPath != null
          ? msg.copyWith(localPath: existingPath)
          : msg;

      if (idx != -1) {
        final old = list[idx];

        var finalMsg = old.messageId == null
            ? enriched.copyWith(createdAt: old.createdAt)
            : enriched;

        final isMine = finalMsg.senderId == _myId;
        if (!isMine && old.read == true && finalMsg.read != true) {
          finalMsg = finalMsg.copyWith(read: true);
        }

        if (_equal(old, finalMsg)) continue;

        list[idx] = finalMsg;
        // ✅ fire and forget — مش بنبلوك الـ stream
        _repo
            .saveMessageLocally(finalMsg)
            .then(
              (r) =>
                  r.fold((l) => debugPrint('save message failed: $l'), (_) {}),
            );
      } else {
        list.add(enriched);
        _repo
            .saveMessageLocally(enriched)
            .then(
              (r) =>
                  r.fold((l) => debugPrint('save message failed: $l'), (_) {}),
            );
      }

      dirty = true;
    }

    if (dirty) _sortAndEmit(chatId);

}

// ─────────────────────────────────────────────────────────────────
// PAGINATION
// ─────────────────────────────────────────────────────────────────

Future<void> loadMoreMessages(String chatId) async {
if (\_hasMoreMap[chatId] != true) return;
if (\_loadingMoreMap[chatId] == true) return;
if (\_oldestDate[chatId] == null) return;

    _loadingMoreMap[chatId] = true;

    try {
      final result = await _repo.fetchMoreMessages(
        chatId: chatId,
        before: _oldestDate[chatId]!,
        pageSize: _pageSize,
      );

      // ✅ استخرج الـ value خارج الـ fold — مفيش async جوا fold
      if (result.isLeft()) {
        debugPrint(
          'loadMoreMessages failed: ${result.fold((l) => l, (_) => '')}',
        );
        return;
      }

      final msgs = result.fold((_) => <PrivateMessageModel>[], (r) => r);

      if (msgs.isEmpty) {
        _hasMoreMap[chatId] = false;
      } else {
        // ✅ كل الـ async هنا خارج الـ fold
        await _fetchMissingUsers(msgs);

        final reversed = msgs.reversed.toList();
        final existingIds = _cache[chatId]!.map((m) => m.messageId).toSet();
        final fresh = reversed
            .where((m) => !existingIds.contains(m.messageId))
            .toList();

        _cache[chatId]!.insertAll(0, fresh);
        _oldestDate[chatId] = reversed.first.createdAt;
        _hasMoreMap[chatId] = msgs.length == _pageSize;

        await _persistAll(fresh);
      }

      _sortAndEmit(chatId);
    } finally {
      // ✅ دايماً بيتنفذ حتى لو في error — مش بيتأخر زي ما كان
      _loadingMoreMap[chatId] = false;
    }

}

// ─────────────────────────────────────────────────────────────────
// OPTIMISTIC LOCAL OPS
// ─────────────────────────────────────────────────────────────────

void addLocalMessage({
required String chatId,
required PrivateMessageModel message,
}) {
\_cache.putIfAbsent(chatId, () => []);
\_cache[chatId]!.add(message);
\_pendingTempIds.add(message.tempId);
\_emit(chatId);
}

Future<void> replaceTempMessage({
required String chatId,
required String tempId,
required PrivateMessageModel serverMessage,
}) async {
\_pendingTempIds.remove(tempId);

    final list = _cache[chatId];
    if (list == null) return;

    final idx = list.indexWhere((m) => m.tempId == tempId);

    if (idx == -1) {
      // الـ stream سبق وحط الرسالة — عدّل بس الـ status والـ localPath
      final streamIdx = list.indexWhere(
        (m) => m.messageId == serverMessage.messageId,
      );
      if (streamIdx != -1) {
        final old = list[streamIdx];
        list[streamIdx] = old.copyWith(
          localPath: serverMessage.localPath ?? old.localPath,
          privateMessageStatus: PrivateMessageStatus.sent,
        );
        final result = await _repo.saveMessageLocally(list[streamIdx]);
        result.fold((l) => debugPrint('save message failed: $l'), (_) {});
        _emit(chatId);
      }
      return;
    }

    final temp = list[idx];
    final updated = serverMessage.copyWith(
      createdAt: temp.createdAt,
      localPath: serverMessage.localPath ?? temp.localPath,
    );

    list[idx] = updated;

    await _repo.deleteMessageLocally(tempId);
    if (serverMessage.messageId != null) {
      final result = await _repo.saveMessageLocally(updated);
      result.fold((l) => debugPrint('save message failed: $l'), (_) {});
    }

    _emit(chatId);

}

void markMessageFailed({required String chatId, required String tempId}) {
\_pendingTempIds.remove(tempId);

    final list = _cache[chatId];
    if (list == null) return;

    final idx = list.indexWhere((m) => m.tempId == tempId);
    if (idx == -1) return;

    list[idx] = list[idx].copyWith(
      privateMessageStatus: PrivateMessageStatus.failed,
    );
    _emit(chatId);

}

// ─────────────────────────────────────────────────────────────────
// MARK AS READ
// ─────────────────────────────────────────────────────────────────

Future<void> markAllAsRead({required String chatId}) async {
final list = \_cache[chatId];
if (list == null) return;

    final unread = list
        .where(
          (m) => m.read == false && m.senderId != _myId && m.messageId != null,
        )
        .toList();

    if (unread.isEmpty) return;

    // 1. Cache + Hive فوراً (optimistic)
    for (var i = 0; i < list.length; i++) {
      if (list[i].read == false && list[i].senderId != _myId) {
        list[i] = list[i].copyWith(read: true);
        final result = await _repo.saveMessageLocally(list[i]);
        result.fold((l) => debugPrint('save message failed: $l'), (_) {});
      }
    }
    _emit(chatId);

    // 2. حدّث الـ unread count قبل الـ DB
    _chatsCubit?.refreshUnreadCount(chatId);

    try {
      final ids = unread.map((m) => m.messageId!).toList();
      debugPrint('🔵 updating ${ids.length} messages to read=true: $ids');
      await _repo.markMessagesAsRead(ids);
      debugPrint('🟢 DB update done');
    } catch (e) {
      debugPrint('❌ DB error: $e');
    }

}

// ─────────────────────────────────────────────────────────────────
// DELETE
// ─────────────────────────────────────────────────────────────────

Future<void> deletePrivateMessages({
required String chatId,
required List<PrivateMessageModel> messages,
}) async {
final list = \_cache[chatId];
if (list == null) return;

    for (final msg in messages) {
      final idx = list.indexWhere((m) => m.messageId == msg.messageId);
      if (idx == -1) continue;

      list[idx] = list[idx].copyWith(
        privateMessageStatus: PrivateMessageStatus.deleting,
      );
      _emit(chatId);

      final result = await _repo.deleteMessages([msg.messageId!]);
      result.fold(
        (l) {
          list[idx] = list[idx].copyWith(
            privateMessageStatus: PrivateMessageStatus.deleteFailed,
          );
        },
        (_) {
          list[idx] = list[idx].copyWith(
            isDeleted: true,
            privateMessageStatus: PrivateMessageStatus.sent,
          );
        },
      );

      // fire and forget
      _repo
          .saveMessageLocally(list[idx])
          .then(
            (r) => r.fold((l) => debugPrint('save message failed: $l'), (_) {}),
          );
    }

    _emit(chatId);

}

// ─────────────────────────────────────────────────────────────────
// EDIT
// ─────────────────────────────────────────────────────────────────

Future<void> editPrivateMessage({
required String chatId,
required PrivateMessageModel message,
required String content,
}) async {
final list = \_cache[chatId];
if (list == null) return;

    final idx = list.indexWhere((m) => m.messageId == message.messageId);
    if (idx == -1) return;

    list[idx] = list[idx].copyWith(
      privateMessageStatus: PrivateMessageStatus.editing,
    );
    _emit(chatId);

    final result = await _repo.editMessage(
      messageId: message.messageId!,
      content: content,
    );

    result.fold(
      (l) {
        list[idx] = list[idx].copyWith(
          privateMessageStatus: PrivateMessageStatus.editingFaild,
        );
      },
      (_) {
        list[idx] = list[idx].copyWith(
          content: content,
          privateMessageStatus: PrivateMessageStatus.sent,
        );
      },
    );

    // fire and forget
    _repo
        .saveMessageLocally(list[idx])
        .then(
          (r) => r.fold((l) => debugPrint('save message failed: $l'), (_) {}),
        );
    _emit(chatId);

}

// ─────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────

int \_findIndex(List<PrivateMessageModel> list, PrivateMessageModel msg) {
return list.indexWhere(
(m) =>
(msg.messageId != null && m.messageId == msg.messageId) ||
(msg.tempId.isNotEmpty && m.tempId == msg.tempId),
);
}

bool \_equal(PrivateMessageModel a, PrivateMessageModel b) {
return a.messageId == b.messageId &&
a.content == b.content &&
a.privateMessageStatus == b.privateMessageStatus &&
a.isDeleted == b.isDeleted &&
a.read == b.read &&
a.localPath == b.localPath;
}

Future<void> \_fetchMissingUsers(List<PrivateMessageModel> msgs) async {
final missing = msgs
.map((m) => m.senderId)
.where((id) => !UsersCache.contains(id))
.toSet();

    if (missing.isEmpty) return;

    final rows = await _client
        .from('messenger_users')
        .select()
        .inFilter('id', missing.toList());

    for (final r in rows) {
      final user = UserModel.fromJson(r);
      UsersCache.addUser(user);
      await HiveService.saveUser(user);
    }

}

List<PrivateMessageModel> \_mergeWithCache(
List<PrivateMessageModel>? existing,
List<PrivateMessageModel> incoming,
) {
if (existing == null) return incoming;
return incoming.map((msg) {
final cached = existing.firstWhere(
(m) =>
(m.messageId != null && m.messageId == msg.messageId) ||
m.tempId == msg.tempId,
orElse: () => msg,
);
if (cached.read == true && msg.read != true) {
return msg.copyWith(read: true);
}
return msg;
}).toList();
}

Future<List<PrivateMessageModel>> \_attachLocalPaths(
List<PrivateMessageModel> msgs,
) async {
return Future.wait(
msgs.map((msg) async {
final isMedia =
msg.privateMessageType == PrivateMessageType.image ||
msg.privateMessageType == PrivateMessageType.voice;
if (!isMedia || msg.messageId == null) return msg;
final saved = await \_repo.getLocalMessage(msg.messageId!);
return saved.fold(
(l) {
debugPrint('get local message failed: $l');
return msg;
},
(saved) {
if (saved?.localPath == null) return msg;
return msg.copyWith(localPath: saved!.localPath);
},
);
}),
);
}

// ✅ async صح — بيتانتظر في loadInitialMessages و loadMoreMessages
Future<void> _persistAll(List<PrivateMessageModel> msgs) async {
for (final m in msgs) {
final result = await \_repo.saveMessageLocally(m);
result.fold((l) => debugPrint('save message failed: $l'), (_) {});
}
}

void \_sortAndEmit(String chatId) {
\_cache[chatId]!.sort((a, b) => a.createdAt.compareTo(b.createdAt));
\_emit(chatId);
}

void \_emit(String chatId) {
if (isClosed) return;
emit(
FetchPrivateMessagesSuccess(
chatId: chatId, // ← ضيف دي
messages: List.unmodifiable(\_cache[chatId] ?? []),
),
);
}

@override
Future<void> close() {
for (final s in \_streams.values) {
s.cancel();
}
return super.close();
}
}
//-------------------------------------------------------------------------
part of 'fetch_private_messages_cubit.dart';

@immutable
sealed class FetchPrivateMessagesState {
const FetchPrivateMessagesState();
}

final class FetchPrivateMessagesInitial extends FetchPrivateMessagesState {}

final class FetchPrivateMessagesLoading extends FetchPrivateMessagesState {}

final class FetchPrivateMessagesSuccess extends FetchPrivateMessagesState {
final List<PrivateMessageModel> messages;
final String chatId; // ← ضيف دي

const FetchPrivateMessagesSuccess({
required this.messages,
required this.chatId,
});
}

final class FetchPrivateMessagesfailure extends FetchPrivateMessagesState {
final String errMessage;
const FetchPrivateMessagesfailure({required this.errMessage});
}
//-------------------------------------------------------------------
import 'dart:async';
import 'dart:io';

import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:chattr/features/private_chats/data/models/private_message_model.dart';
import 'package:chattr/features/private_chats/data/repos/send_private_message_repo/send_private_message_repo.dart';
import 'package:chattr/features/private_chats/presentation/cubits/fetch_private_messages_cubit/fetch_private_messages_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

part 'send_private_message_state.dart';

class SendPrivateMessageCubit extends Cubit<SendPrivateMessageState> {
SendPrivateMessageCubit({
required this.fetchCubit,
required SendPrivateMessageRepo repo,
}) : \_repo = repo,
super(SendPrivateMessageInitial());

final FetchPrivateMessagesCubit fetchCubit;
final SendPrivateMessageRepo \_repo;

final Set<String> \_inFlight = {};
DateTime? \_lastTextSend;

// ─── SEND TEXT ───────────────────────────────────────────────────

Future<void> sendTextMessage({
required String message,
required UserModel sender,
required String senderId,
required String chatId,
}) async {
final trimmed = message.trim();
if (trimmed.isEmpty) return;

    final now = DateTime.now();
    if (_lastTextSend != null &&
        now.difference(_lastTextSend!) < const Duration(milliseconds: 500)) {
      return;
    }
    _lastTextSend = now;

    final tempId = const Uuid().v4();
    if (_inFlight.contains(tempId)) return;
    _inFlight.add(tempId);

    final temp = PrivateMessageModel(
      tempId: tempId,
      privateMessageStatus: PrivateMessageStatus.sending,
      chatId: chatId,
      senderId: senderId,
      sender: sender,
      privateMessageType: PrivateMessageType.text,
      content: trimmed,
      createdAt: DateTime.now(),
      read: false,
      isDeleted: false,
    );

    fetchCubit.addLocalMessage(chatId: chatId, message: temp);
    emit(SendPrivateMessageSuccess());

    final result = await _repo.sendMessage(temp);

    result.fold(
      (err) {
        fetchCubit.markMessageFailed(chatId: chatId, tempId: tempId);
        emit(SendPrivateMessageFailure(errorMessage: err.message));
      },
      (server) {
        fetchCubit.replaceTempMessage(
          chatId: chatId,
          tempId: tempId,
          serverMessage: server.copyWith(createdAt: temp.createdAt),
        );
      },
    );

    _inFlight.remove(tempId);

}

// ─── SEND IMAGE ──────────────────────────────────────────────────

Future<void> sendImage({
required File imageFile,
required UserModel sender,
required String senderId,
required String chatId,
}) async {
final tempId = const Uuid().v4();
\_inFlight.add(tempId);

    final temp = PrivateMessageModel(
      tempId: tempId,
      privateMessageStatus: PrivateMessageStatus.sending,
      chatId: chatId,
      senderId: senderId,
      sender: sender,
      privateMessageType: PrivateMessageType.image,
      content: imageFile.path,
      localPath: imageFile.path,
      createdAt: DateTime.now(),
      read: false,
      isDeleted: false,
    );

    fetchCubit.addLocalMessage(chatId: chatId, message: temp);
    emit(SendPrivateMessageSuccess());

    unawaited(
      _uploadAndSendImage(
        tempId: tempId,
        temp: temp,
        imageFile: imageFile,
        chatId: chatId,
      ),
    );

}

Future<void> \_uploadAndSendImage({
required String tempId,
required PrivateMessageModel temp,
required File imageFile,
required String chatId,
}) async {
final uploadResult = await \_repo.uploadImage(imageFile);

    await uploadResult.fold(
      (err) async {
        fetchCubit.markMessageFailed(chatId: chatId, tempId: tempId);
        emit(SendPrivateMessageFailure(errorMessage: err.message));
      },
      (url) async {
        final sendResult = await _repo.sendMessage(temp.copyWith(content: url));
        sendResult.fold(
          (err) {
            fetchCubit.markMessageFailed(chatId: chatId, tempId: tempId);
            emit(SendPrivateMessageFailure(errorMessage: err.message));
          },
          (server) {
            fetchCubit.replaceTempMessage(
              chatId: chatId,
              tempId: tempId,
              serverMessage: server.copyWith(
                createdAt: temp.createdAt,
                localPath: imageFile.path,
              ),
            );
          },
        );
      },
    );

    _inFlight.remove(tempId);

}

// ─── SEND VOICE ──────────────────────────────────────────────────

void showLocalVoice({
required UserModel sender,
required String senderId,
required String chatId,
required String audioPath,
required int duration,
}) {
\_inFlight.add(audioPath);

    final temp = PrivateMessageModel(
      tempId: audioPath,
      privateMessageStatus: PrivateMessageStatus.sending,
      chatId: chatId,
      senderId: senderId,
      sender: sender,
      read: false,
      privateMessageType: PrivateMessageType.voice,
      content: audioPath,
      mediaDuration: duration,
      createdAt: DateTime.now(),
      isDeleted: false,
    );

    fetchCubit.addLocalMessage(chatId: chatId, message: temp);

}

Future<void> updateVoiceUrl({
required String chatId,
required String localPath,
required String uploadedUrl,
}) async {
final messages = fetchCubit.getMessages(chatId);
if (messages == null) return;

    final idx = messages.indexWhere((m) => m.tempId == localPath);
    if (idx == -1) return;

    final temp = messages[idx];
    final result = await _repo.sendMessage(temp.copyWith(content: uploadedUrl));

    result.fold(
      (err) {
        fetchCubit.markMessageFailed(chatId: chatId, tempId: localPath);
        emit(SendPrivateMessageFailure(errorMessage: err.message));
      },
      (server) {
        fetchCubit.replaceTempMessage(
          chatId: chatId,
          tempId: localPath,
          serverMessage: server.copyWith(
            createdAt: temp.createdAt,
            localPath: localPath,
          ),
        );
        emit(SendPrivateMessageSuccess());
      },
    );

    _inFlight.remove(localPath);

}

// ─── RETRY ───────────────────────────────────────────────────────

Future<void> retryMessage(PrivateMessageModel failed) async {
if (failed.privateMessageStatus != PrivateMessageStatus.failed) return;
if (\_inFlight.contains(failed.tempId)) return;

    _inFlight.add(failed.tempId);

    fetchCubit.replaceTempMessage(
      chatId: failed.chatId,
      tempId: failed.tempId,
      serverMessage: failed.copyWith(
        privateMessageStatus: PrivateMessageStatus.sending,
      ),
    );

    final result = await _repo.sendMessage(
      failed.copyWith(
        messageId: null,
        privateMessageStatus: PrivateMessageStatus.sending,
      ),
    );

    result.fold(
      (err) {
        fetchCubit.markMessageFailed(
          chatId: failed.chatId,
          tempId: failed.tempId,
        );
        emit(SendPrivateMessageFailure(errorMessage: err.message));
      },
      (server) {
        fetchCubit.replaceTempMessage(
          chatId: failed.chatId,
          tempId: failed.tempId,
          serverMessage: server.copyWith(createdAt: failed.createdAt),
        );
        emit(SendPrivateMessageSuccess());
      },
    );

    _inFlight.remove(failed.tempId);

}

Future<void> retryDelete({
required String chatId,
required PrivateMessageModel message,
}) async {
if (message.privateMessageStatus != PrivateMessageStatus.deleteFailed) {
return;
}
await fetchCubit.deletePrivateMessages(chatId: chatId, messages: [message]);
}

Future<void> retryEditMessage({
required String chatId,
required PrivateMessageModel message,
required String content,
}) async {
if (message.privateMessageStatus != PrivateMessageStatus.editingFaild) {
return;
}
await fetchCubit.editPrivateMessage(
chatId: chatId,
message: message,
content: content,
);
}
}
//---------------------------------------------------------------------
part of 'send_private_message_cubit.dart';

@immutable
sealed class SendPrivateMessageState {}

final class SendPrivateMessageInitial extends SendPrivateMessageState {}

final class SendPrivateMessageLoading extends SendPrivateMessageState {}

final class SendPrivateMessageSuccess extends SendPrivateMessageState {}

final class SendPrivateMessageFailure extends SendPrivateMessageState {
final String errorMessage;

SendPrivateMessageFailure({required this.errorMessage});
}

final class CancelSendImageState extends SendPrivateMessageState {}
//--------------------------------------------------------------------------
import 'package:chattr/core/cubits/search/search_cubit.dart';
import 'package:chattr/core/utils/di/get_it.dart';
import 'package:chattr/core/widgets/custom_appbar.dart';
import 'package:chattr/features/private_chats/data/repos/add_friend_repo/add_friend_repo.dart';
import 'package:chattr/features/private_chats/presentation/cubits/add_friend_cubit/add_friend_cubit.dart';
import 'package:chattr/features/private_chats/presentation/views/private_chats_view/private_chats_view_body.dart';
import 'package:chattr/features/private_chats/presentation/views/private_chats_view/widgets/add_friend_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class PrivateChatsView extends StatelessWidget {
const PrivateChatsView({super.key});
void showAddFriendBottomSheet(BuildContext context) {
showModalBottomSheet(
context: context,
isScrollControlled: true,
builder: (sheetContext) {
return Padding(
padding: EdgeInsets.only(
bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
),
child: BlocProvider(
create: (\_) => AddFriendCubit(getIt<AddFriendRepo>()),
child: const AddFriendBottomSheet(),
),
);
},
);
}

@override
Widget build(BuildContext context) {
return GestureDetector(
onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
child: MultiBlocProvider(
providers: [

          BlocProvider(create: (context) => SearchCubit()),
        ],
        child: Scaffold(
          appBar: CustomAppBar(
            title: 'Private Chats',
            actions: [
              GestureDetector(
                onTap: () => showAddFriendBottomSheet(context),
                child: const Icon(Icons.add_comment),
              ),
              Gap(10),
            ],
          ),
          body: const SafeArea(child: PrivateChatsViewBody()),
        ),
      ),
    );

}
}
//---------------------------------------------------------------------------
import 'package:chattr/core/cubits/search/search_cubit.dart';
import 'package:chattr/features/private_chats/presentation/cubits/fetch_private_chats_cubit/fetch_private_chats_cubit.dart';
import 'package:chattr/features/private_chats/presentation/views/private_chats_view/widgets/private_chats_list.dart';
import 'package:chattr/features/private_chats/presentation/views/private_chats_view/widgets/private_chats_search_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class PrivateChatsViewBody extends StatelessWidget {
const PrivateChatsViewBody({super.key});

@override
Widget build(BuildContext context) {
return CustomScrollView(
slivers: [
SliverToBoxAdapter(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Gap(20),
BlocProvider.value(
value: context.read<SearchCubit>(),
child: ChatSearchBar(),
),
Gap(30),
],
),
),
SliverPadding(
padding: EdgeInsets.symmetric(horizontal: 20),
sliver: BlocListener<FetchPrivateChatsCubit, FetchPrivateChatsState>(
listener: (BuildContext context, FetchPrivateChatsState state) {
if (state is FetchChatsFailure) {
// CustomSnackBar.error(context, state.errorMessage);
}
},
child: PrivateChatsList(),
),
),
],
);
}
}
//-------------------------------------------------------------
import 'package:chattr/core/themes/app_text_styles.dart';
import 'package:chattr/core/widgets/custom_text.dart';
import 'package:chattr/features/private_chats/data/models/private_chat_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// بياخد الـ unreadCount من الـ PrivateChatModel مباشرة —
/// مش محتاج BlocBuilder خالص
class UnreadCountBadge extends StatelessWidget {
const UnreadCountBadge({super.key, required this.chat});

final PrivateChatModel chat;

@override
Widget build(BuildContext context) {

    final count = chat.unreadCount;

    if (count == 0) {
      return chat.lastMessageTime == null
          ? const SizedBox.shrink()
          : SizedBox(
              width: 50,
              child: CustomText(
                text: DateFormat.jm().format(chat.lastMessageTime!),
                style: AppTextStyles.bodySmall.copyWith(fontSize: 9),
              ),
            );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: CustomText(
       style: AppTextStyles.bodySmall,
        text: count > 99 ? '99+' : '$count',
        align: TextAlign.center,
      ),
    );

}
}
//----------------------------------------------------------------------
import 'package:chattr/core/cubits/search/search_cubit.dart';
import 'package:chattr/core/themes/app_colors.dart';
import 'package:chattr/core/widgets/custom_text_field.dart';
import 'package:chattr/features/private_chats/data/models/private_chat_model.dart';
import 'package:chattr/features/private_chats/presentation/cubits/fetch_private_chats_cubit/fetch_private_chats_cubit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ChatSearchBar extends StatefulWidget {
const ChatSearchBar({super.key});

@override
State<ChatSearchBar> createState() => \_ChatSearchBarState();
}

class \_ChatSearchBarState extends State<ChatSearchBar> {
late TextEditingController \_searchController;

@override
void initState() {
\_searchController = TextEditingController();
super.initState();
}

@override
void dispose() {
super.dispose();
\_searchController.dispose();
}

@override
Widget build(BuildContext context) {
return BlocBuilder<FetchPrivateChatsCubit, FetchPrivateChatsState>(
builder: (context, state) {
List<PrivateChatModel>chats=[];
if(state is FetchPrivateChatsSuccess){
chats=state.chats;
}

        return chats.isNotEmpty?
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: CustomTextField(
            controller: _searchController,
            hint: "search",
            validation: (v) {
              return null;
            },
            onChange: (value) => context.read<SearchCubit>().search(list: chats, query: value, searchBy: (item) => item.name,),

            suffixIcon: Icon(CupertinoIcons.search, color: AppColors.inputBorder),
          ),
        ):SizedBox.shrink();
      },
    );

}
}
//------------------------------------------------------------------------
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chattr/core/cubits/fetch_current_user_data/fetch_current_user_data_cubit.dart';
import 'package:chattr/core/cubits/search/search_cubit.dart';
import 'package:chattr/core/routing/router_models.dart';
import 'package:chattr/core/routing/routes.dart';
import 'package:chattr/core/themes/app_text_styles.dart';
import 'package:chattr/core/widgets/custom_text.dart';
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:chattr/features/private_chats/data/models/private_chat_model.dart';
import 'package:chattr/features/private_chats/presentation/cubits/fetch_private_chats_cubit/fetch_private_chats_cubit.dart';
import 'package:chattr/features/private_chats/presentation/views/private_chats_view/widgets/unread_count_badge.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

class PrivateChatsList extends StatelessWidget {
const PrivateChatsList({super.key});

@override
Widget build(BuildContext context) {
return BlocBuilder<FetchPrivateChatsCubit, FetchPrivateChatsState>(
buildWhen: (prev, curr) {
// متبنيش على loading لو في chats موجودة قبل كده
if (curr is FetchPrivateChatsloading &&
prev is FetchPrivateChatsSuccess) {
return false;
}
return true;
},
builder: (context, state) {
if (state is FetchPrivateChatsSuccess) {
final currentUser = context
.select<FetchCurrentUserDataCubit, UserModel?>(
(cubit) => cubit.currentUser,
);

          if (currentUser == null) {
            return const SliverFillRemaining(
              child: Center(child: CupertinoActivityIndicator()),
            );
          }

          final privateChats = state.chats;

          if (privateChats.isEmpty) {
            return const SliverFillRemaining(
              child: Center(
                child: CustomText(
                  text: '💬 No chats yet',
                  style: AppTextStyles.headlineMedium,
                ),
              ),
            );
          }

          return BlocBuilder<SearchCubit, SearchState>(
            builder: (context, state) {
              final isSearchActive = state is SearchActive;

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  childCount: isSearchActive
                      ? state.filteredList.length
                      : privateChats.length,
                  (context, index) {
                    final chat = isSearchActive
                        ? state.filteredList[index] as PrivateChatModel
                        : privateChats[index];
                    return _ChatListItem(
                      key: ValueKey(chat.chatId),
                      chat: chat,
                      currentUser: currentUser,
                    );
                  },
                ),
              );
            },
          );
        }

        if (state is FetchChatsFailure) {
          return SliverFillRemaining(
            child: Center(
              child: CustomText(
                text: state.errorMessage,
                style: AppTextStyles.bodySmall,
              ),
            ),
          );
        }

        return SliverFillRemaining(
          child: Center(
            child: CupertinoActivityIndicator(color: Colors.grey, radius: 12),
          ),
        );
      },
    );

}
}

// ─────────────────────────────────────────────────────────────────────────────
// SINGLE CHAT ITEM — widget منفصل عشان الـ rebuild يكون isolated
// ─────────────────────────────────────────────────────────────────────────────

class \_ChatListItem extends StatelessWidget {
const \_ChatListItem({
super.key,
required this.chat,
required this.currentUser,
});

final PrivateChatModel chat;
final UserModel currentUser;

@override
Widget build(BuildContext context) {
final privateChatParams = PrivateChatParams(
chatData: chat,
curruntUser: currentUser,

    );

    return GestureDetector(
      onTap: () =>
          context.push(Routes.privateChatsBody, extra: privateChatParams),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 15),
        child: Row(
          children: [
            _ChatAvatar(
              imageUrl: chat.friend?.image,
              isOnline: chat.friend?.isOnLine ?? false,
            ),
            const Gap(20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomText(
                    text: chat.friend?.name ?? '',
                    style: AppTextStyles.bodyMedium,
                  ),
                  const Gap(4),
                  _LastMessageText(
                    message: chat.lastMessage ?? '',
                    senderId: chat.lastMessageSenderId ?? '',
                    currentUserId: currentUser.id ?? '',
                    friendName: chat.friend?.name ?? '',
                  ),
                ],
              ),
            ),
            UnreadCountBadge(chat: chat),
          ],
        ),
      ),
    );

}
}

// ─────────────────────────────────────────────────────────────────────────────
// LAST MESSAGE TEXT
// ─────────────────────────────────────────────────────────────────────────────

class \_LastMessageText extends StatelessWidget {
const \_LastMessageText({
required this.message,
required this.senderId,
required this.currentUserId,
required this.friendName,
});

final String message;
final String senderId;
final String currentUserId;
final String friendName;

@override
Widget build(BuildContext context) {
if (message.isEmpty) {
return const CustomText(
style: TextStyle(color: Colors.grey, fontSize: 10),
text: '💬 Start your first conversation',
);
}

    final isMe = senderId == currentUserId;
    final prefix = isMe ? 'You: ' : '$friendName: ';
    final isRtl = Bidi.detectRtlDirectionality(message);

    return RichText(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
      text: TextSpan(
        style: const TextStyle(color: Colors.grey, fontSize: 10),
        children: [
          TextSpan(
            text: prefix,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(text: message),
        ],
      ),
    );

}
}

// ─────────────────────────────────────────────────────────────────────────────
// AVATAR
// ─────────────────────────────────────────────────────────────────────────────

class \_ChatAvatar extends StatelessWidget {
const \_ChatAvatar({required this.imageUrl, required this.isOnline});

final String? imageUrl;
final bool isOnline;

@override
Widget build(BuildContext context) {
return Stack(
children: [
Container(
width: 50,
height: 50,
padding: const EdgeInsets.all(2),
decoration: BoxDecoration(
shape: BoxShape.circle,
gradient: LinearGradient(
colors: [
const Color.fromARGB(255, 26, 102, 234).withOpacity(0.7),
const Color.fromARGB(255, 64, 198, 251).withOpacity(0.7),
],
),
),
child: ClipRRect(
borderRadius: BorderRadius.circular(30),
child: CachedNetworkImage(
imageUrl: imageUrl ?? '',
fit: BoxFit.cover,
placeholder: (_, _) => Container(
color: Colors.grey.shade200,
child: const Center(
child: SizedBox(
width: 18,
height: 18,
child: CircularProgressIndicator(strokeWidth: 2),
),
),
),
errorWidget: (_, _, \_) => Container(
color: Colors.grey.shade300,
child: const Icon(Icons.person, color: Colors.grey, size: 26),
),
),
),
),
if (isOnline)
Positioned(
bottom: 2,
right: 2,
child: Container(
width: 10,
height: 10,
decoration: BoxDecoration(
color: Colors.green,
shape: BoxShape.circle,
border: Border.all(color: Colors.white, width: 1.5),
),
),
),
],
);
}
}
//----------------------------------------------------------
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

static String \_formatLastSeen(DateTime lastSeen) {
final diff = DateTime.now().difference(lastSeen);
if (diff.inMinutes < 1) return 'just now';
if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
if (diff.inDays == 1) return 'yesterday';
return '${diff.inDays} days ago';
}
}
//-----------------------------------------------------------------------
import 'package:chattr/core/helpers/snack_bar.dart';
import 'package:chattr/core/themes/app_colors.dart';
import 'package:chattr/core/themes/app_text_styles.dart';
import 'package:chattr/core/utils/validators/auth_validation.dart';
import 'package:chattr/core/widgets/custom_button.dart';
import 'package:chattr/core/widgets/custom_text.dart';
import 'package:chattr/core/widgets/custom_text_field.dart';
import 'package:chattr/features/private_chats/presentation/cubits/add_friend_cubit/add_friend_cubit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class AddFriendBottomSheet extends StatefulWidget {
const AddFriendBottomSheet({super.key});

@override
State<AddFriendBottomSheet> createState() => \_AddFriendBottomSheetState();
}

class \_AddFriendBottomSheetState extends State<AddFriendBottomSheet> {
final GlobalKey<FormState> \_formKey = GlobalKey<FormState>();
late TextEditingController \_emailController;

@override
void initState() {
super.initState();
\_emailController = TextEditingController();
}

@override
void dispose() {
\_emailController.dispose();
super.dispose();
}

@override
Widget build(BuildContext context) {
return BlocListener<AddFriendCubit, AddFriendState>(
listener: (context, state) {
if (state is AddFriendFailure) {
CustomSnackBar.error(context, state.errMessage);
context.pop();
}
if (state is AddFriendSuccess) {
context.pop();
}
},
child: GestureDetector(
onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
child: Container(
decoration: const BoxDecoration(
color: AppColors.surface,
borderRadius: BorderRadius.only(
topLeft: Radius.circular(22),
topRight: Radius.circular(22),
),
),
padding: const EdgeInsets.symmetric(horizontal: 20),
child: Form(
key: \_formKey,
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
mainAxisSize: MainAxisSize.min,
children: [
const Gap(7),
Center(
child: Container(
height: 5,
width: 50,
decoration: BoxDecoration(
color: AppColors.border,
borderRadius: BorderRadius.circular(10),
),
),
),
Row(
children: [
CustomText(
text: 'Add Friend Email',
style: AppTextStyles.headlineSmall,
),
const Spacer(),
const Icon(Icons.qr_code_scanner, color: AppColors.primary),
],
),
const Gap(15),
CustomTextField(
controller: \_emailController,
hint: 'Email',
borderColor: AppColors.inputBorder,
textStyle: AppTextStyles.bodySmall,
validation: AuthValidation.email,
),
const Gap(10),
\_AddButton(
formKey: \_formKey,
emailController: \_emailController,
),
const Gap(20),
],
),
),
),
),
);
}
}

class \_AddButton extends StatelessWidget {
const \_AddButton({
required GlobalKey<FormState> formKey,
required TextEditingController emailController,
}) : \_formKey = formKey,
\_emailController = emailController;

final GlobalKey<FormState> \_formKey;
final TextEditingController \_emailController;

@override
Widget build(BuildContext context) {
return BlocBuilder<AddFriendCubit, AddFriendState>(
buildWhen: (prev, curr) =>
curr is AddFriendLoading || prev is AddFriendLoading,
builder: (context, state) {
final isLoading = state is AddFriendLoading;
return CustomButton(
onPressed: () {
if (\_formKey.currentState!.validate()) {
context.read<AddFriendCubit>().addFriend(
email: \_emailController.text.trim(),
);
}
},
raduis: 7,
child: Row(
mainAxisAlignment: MainAxisAlignment.center,
children: [
const CustomText(text: 'Add Friend'),
const Gap(5),
if (isLoading)
const CupertinoActivityIndicator(color: Colors.grey, radius: 8),
],
),
);
},
);
}
}
//-------------------------------------------------------------------------
import 'package:chattr/core/cubits/audio_cubit/audio_cubit.dart';
import 'package:chattr/core/cubits/pick_image/pick_image_cubit.dart';
import 'package:chattr/core/cubits/select_messages/select_messages_cubit.dart';
import 'package:chattr/core/services/supabase/supabase_storage.dart';
import 'package:chattr/core/utils/di/get_it.dart';
import 'package:chattr/core/widgets/custom_appbar.dart';
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:chattr/features/private_chats/data/models/private_message_model.dart';
import 'package:chattr/features/private_chats/data/repos/send_private_message_repo/send_private_message_repo.dart';
import 'package:chattr/features/private_chats/presentation/cubits/fetch_private_chats_cubit/fetch_private_chats_cubit.dart';
import 'package:chattr/features/private_chats/presentation/cubits/fetch_private_messages_cubit/fetch_private_messages_cubit.dart';
import 'package:chattr/features/private_chats/presentation/cubits/send_private_message_cubit/send_private_message_cubit.dart';
import 'package:chattr/features/private_chats/presentation/views/private_chat_body_view/private_chat_body_view_body.dart';
import 'package:chattr/features/private_chats/presentation/views/private_chats_view/widgets/online_status_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class PrivateChatBodyView extends StatelessWidget {
const PrivateChatBodyView({
super.key,
required this.chatData,
required this.user,
});
final dynamic chatData;
final UserModel user;

void deletemessage({
required List<dynamic> selected,
required BuildContext context,
}) {
context.read<FetchPrivateMessagesCubit>().deletePrivateMessages(
chatId: chatData.chatId!,
messages: selected.cast<PrivateMessageModel>(),
);

    context.read<SelectMessagesCubit>().clearSelection();

}

@override
Widget build(BuildContext context) {
return GestureDetector(
onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
child: MultiBlocProvider(
providers: [
BlocProvider(create: (context) => SelectMessagesCubit()),
BlocProvider.value(value: getIt<FetchPrivateMessagesCubit>()),

          BlocProvider.value(value: getIt<FetchPrivateChatsCubit>()),
          BlocProvider(
            create: (context) => SendPrivateMessageCubit(
              fetchCubit: getIt<FetchPrivateMessagesCubit>(),
              repo: getIt<SendPrivateMessageRepo>(),
            ),
          ),
          BlocProvider(
            create: (context) => AudioCubit(getIt<SupabaseStorage>()),
          ),
          BlocProvider(create: (context) => PickImageCubit()),
        ],
        child: Scaffold(
          appBar: CustomAppBar(
            title: chatData.friend.name ?? "",
            titleItems: [OnlineStatusWidget(chatId: chatData.chatId!)],
            leading: GestureDetector(
              onTap: () => context.pop(),
              child: Icon(Icons.arrow_back_ios_new_rounded, size: 15),
            ),
            actions: [
              BlocBuilder<SelectMessagesCubit, SelectMessagesState>(
                builder: (context, state) {
                  final selectedmessages = context
                      .read<SelectMessagesCubit>()
                      .selectedMessages;

                  return selectedmessages.isNotEmpty
                      ? Row(
                          children: [
                            context.read<SelectMessagesCubit>().containMedia()
                                ? SizedBox.shrink()
                                : InkWell(
                                    onTap: () {
                                      context
                                          .read<SelectMessagesCubit>()
                                          .copyMessages();
                                    },
                                    child: Icon(Icons.copy, size: 20),
                                  ),
                            Gap(5),
                            InkWell(
                              onTap: () => deletemessage(
                                selected: selectedmessages,
                                context: context,
                              ),
                              child: Icon(Icons.delete_outlined, size: 25),
                            ),
                            Gap(10),
                          ],
                        )
                      : SizedBox.shrink();
                },
              ),
            ],
          ),
          body: PrivateChatBodyViewBody(chatData: chatData, curruntUser: user),
        ),
      ),
    );

}
}
//-----------------------------------------------------------------
import 'package:chattr/core/helpers/snack_bar.dart';
import 'package:chattr/core/themes/app_colors.dart';
import 'package:chattr/core/themes/app_text_styles.dart';
import 'package:chattr/core/utils/extensions/responsive.dart';
import 'package:chattr/core/widgets/custom_text.dart';
import 'package:chattr/core/widgets/message/chat_message_list.dart';
import 'package:chattr/core/widgets/message/send_message_field.dart';
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:chattr/features/private_chats/presentation/cubits/fetch_private_messages_cubit/fetch_private_messages_cubit.dart';
import 'package:chattr/features/private_chats/presentation/cubits/send_private_message_cubit/send_private_message_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class PrivateChatBodyViewBody extends StatefulWidget {
  const PrivateChatBodyViewBody({
    super.key,
    required this.chatData,
    required this.curruntUser,
  });

  final dynamic chatData;
  final UserModel curruntUser;

  @override
  State<PrivateChatBodyViewBody> createState() =>
      _PrivateChatBodyViewBodyState();
}

class _PrivateChatBodyViewBodyState extends State<PrivateChatBodyViewBody> {
  final ScrollController _scrollController = ScrollController();
  bool _isPaginating = false;
  bool _userScrolledUp = false;
  int _prevMessageCount = 0;
  int _lastMarkedUnread = -1;
  bool _initialScrollDone = false;

  String get _chatId => widget.chatData.chatId as String;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<FetchPrivateMessagesCubit>().loadInitialMessages(
        chatId: widget.chatData.chatId!,
      );
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;

    if (pos.pixels <= 100 && !_isPaginating) {
      final cubit = context.read<FetchPrivateMessagesCubit>();
      if (cubit.hasMore(_chatId)) {
        _isPaginating = true;
        cubit.loadMoreMessages(_chatId).then((_) => _isPaginating = false);
      }
    }

    _userScrolledUp = pos.pixels < pos.maxScrollExtent - 100;
  }

  void _scrollToBottom() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        final max = _scrollController.position.maxScrollExtent;
        if (max <= 0) return;
        _scrollController.jumpTo(max);
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (!_scrollController.hasClients) return;
          final newMax = _scrollController.position.maxScrollExtent;
          if (newMax > max) _scrollController.jumpTo(newMax);
        });
      });
    });
  }

  void _handleNewMessages(FetchPrivateMessagesSuccess state) {
    final messages = state.messages;

    final unreadCount = context
        .read<FetchPrivateMessagesCubit>()
        .getUnreadCount(_chatId);

    if (unreadCount > 0 && unreadCount != _lastMarkedUnread) {
      _lastMarkedUnread = unreadCount;
      context.read<FetchPrivateMessagesCubit>().markAllAsRead(chatId: _chatId);
    }

    if (messages.length > _prevMessageCount) {
      _prevMessageCount = messages.length;

      if (!_initialScrollDone) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || !_scrollController.hasClients) return;
              final max = _scrollController.position.maxScrollExtent;
              if (max > 0) {
                _initialScrollDone = true;
                _scrollController.jumpTo(max);
              }
            });
          });
        });
        return;
      }

      if (!_userScrolledUp) _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SendPrivateMessageCubit, SendPrivateMessageState>(
      listener: (context, state) {
        if (state is SendPrivateMessageSuccess) {
          _scrollToBottom();
        } else if (state is SendPrivateMessageFailure) {
          CustomSnackBar.error(context, state.errorMessage);
        }
      },
      child: BlocListener<FetchPrivateMessagesCubit, FetchPrivateMessagesState>(
        listenWhen: (_, curr) {
          if (curr is FetchPrivateMessagesLoading) return false;
          if (curr is! FetchPrivateMessagesSuccess) return false;
          return curr.chatId == widget.chatData.chatId;
        },
        listener: (context, state) {
          if (state is FetchPrivateMessagesSuccess) _handleNewMessages(state);
        },
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        const Gap(40),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 25),
                          child: Container(
                            width: context.responsiveWidth(
                              percentage: 0.8,
                              min: context.screenWidth * 0.4,
                              max: 500,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.lock,
                                  size: 18,
                                  color: Colors.grey,
                                ),
                                const Gap(5),
                                Flexible(
                                  child: CustomText(
                                    maxLines: 1,
                                    text:
                                        '"Messages in this chat are end-to-end encrypted."',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Gap(30),
                      ],
                    ),
                  ),
                  ChatMessagesList(
                    chatData: widget.chatData,
                    currentUser: widget.curruntUser,
                    scrollController: _scrollController,
                  ),
                ],
              ),
            ),
            SendMessageField(
              chatData: widget.chatData,
              curruntUser: widget.curruntUser,
            ),
          ],
        ),
      ),
    );
  }
}

//---------------------------------------------------------------------------
import 'package:chattr/core/cubits/pick_image/pick_image_cubit.dart';
import 'package:chattr/core/themes/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ImageViewContainer extends StatelessWidget {
const ImageViewContainer({super.key});

@override
Widget build(BuildContext context) {
return BlocBuilder<PickImageCubit, PickImageState>(
builder: (context, state) {
final imageFile = context.read<PickImageCubit>().imageFile;

        return imageFile != null
            ? Container(
                height: 100,
                margin: EdgeInsets.only(bottom: 10),
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(10),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 50,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(imageFile, fit: BoxFit.cover),
                          ),
                        ),
                        Positioned(
                          right: -4,
                          top: -3,
                          child: GestureDetector(
                            onTap: () =>
                                context.read<PickImageCubit>().deleteImage(),
                            child: Container(
                              padding: EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.7),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                size: 13.5,
                                Icons.close_rounded,
                                color: AppColors.border,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            : SizedBox.fromSize();
      },
    );

}
}
//-------------------------------------------------------------------
import 'dart:ui';

import 'package:chattr/core/themes/app_colors.dart';
import 'package:chattr/features/contacts/presentation/views/contacts_view.dart';
import 'package:chattr/features/group_chats/presentation/views/groups_view/views/groups_view.dart';
import 'package:chattr/features/private_chats/presentation/views/private_chats_view/private_chats_view.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class Root extends StatefulWidget {
const Root({super.key});

@override
State<Root> createState() => \_RootState();
}

class \_RootState extends State<Root> {
int currentIndex = 0;

final List<Widget> pages = const [
PrivateChatsView(),
GroupsView(),

    ContactsView(),

];

final List<\_NavItem> items = const [
\_NavItem(Icons.chat, Icons.chat_outlined, "Chats"),

    _NavItem(CupertinoIcons.group_solid, CupertinoIcons.group, "Groups"),
    _NavItem(
      Icons.contact_page_rounded,
      Icons.contact_page_outlined,
      'contacts',
    ),

];

void onTap(int index) {
if (index == currentIndex) return;
setState(() => currentIndex = index);
}

@override
Widget build(BuildContext context) {
return SafeArea(
child: Stack(
children: [
IndexedStack(index: currentIndex, children: pages),
Positioned(
bottom: 20,
left: 14,
right: 14,
child: _ModernNavBar(
currentIndex: currentIndex,
items: items,
onTap: onTap,
),
),
],
),
);
}
}

class \_ModernNavBar extends StatelessWidget {
final int currentIndex;
final List<\_NavItem> items;
final Function(int) onTap;

const \_ModernNavBar({
required this.currentIndex,
required this.items,
required this.onTap,
});

@override
Widget build(BuildContext context) {
return ClipRRect(
borderRadius: BorderRadius.circular(40),
child: BackdropFilter(
filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
child: Container(
height: 65,
decoration: BoxDecoration(
color: Colors.white.withOpacity(0.05),
borderRadius: BorderRadius.circular(30),
boxShadow: AppColors.shadowMd,
),
child: Row(
mainAxisAlignment: MainAxisAlignment.spaceAround,
children: List.generate(items.length, (index) {
final isSelected = index == currentIndex;

              return GestureDetector(
                onTap: () => onTap(index),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Icon(
                    isSelected ? items[index].activeIcon : items[index].icon,
                    color: isSelected ? AppColors.primary : Colors.grey,
                    size: 28,
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );

}
}

class \_NavItem {
final IconData activeIcon;
final IconData icon;
final String label;

const \_NavItem(this.activeIcon, this.icon, this.label);
}
//---------------------------------------------------------------------
import 'package:chattr/core/routing/router.dart';
import 'package:flutter/material.dart';

class ChattrApp extends StatelessWidget {
const ChattrApp({super.key});

// This widget is the root of your application.
@override
Widget build(BuildContext context) {
return MaterialApp.router(
title: 'Flutter Demo',
theme: ThemeData(
brightness: Brightness.dark,
scaffoldBackgroundColor: Color(0xff121212),
),
debugShowCheckedModeBanner: false,
themeMode: ThemeMode.dark,
routerConfig: AppRouter.router,
);
}
}

//---------------------------------------------------------------------
import 'package:chattr/chattr_app.dart';
import 'package:chattr/core/services/hive/hive_services.dart';
import 'package:chattr/core/services/supabase/supabase_constants.dart';
import 'package:chattr/core/utils/di/get_it.dart';
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:chattr/features/group_chats/data/models/group_message_model.dart';
import 'package:chattr/features/group_chats/data/models/group_model.dart';
import 'package:chattr/features/private_chats/data/models/private_chat_model.dart';
import 'package:chattr/features/private_chats/data/models/private_message_model.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
// Initialize Supabase

await Hive.initFlutter();
WidgetsFlutterBinding.ensureInitialized();

setUpGetIt();
await Supabase.initialize(
url: SupabaseConstants.url,
anonKey: SupabaseConstants.anonKey,
);

Hive.registerAdapter(UserModelAdapter());
Hive.registerAdapter(PrivateChatModelAdapter());
Hive.registerAdapter(PrivateMessageModelAdapter());
Hive.registerAdapter(PrivateMessageStatusAdapter());
Hive.registerAdapter(PrivateMessageTypeAdapter());
Hive.registerAdapter(GroupMessageModelAdapter());
Hive.registerAdapter(GroupMessageStatusAdapter());
Hive.registerAdapter(GroupMessageTypeAdapter());
Hive.registerAdapter(GroupModelAdapter());
Hive.registerAdapter(UserInGroupAdapter());

await Hive.openBox<UserModel>(HiveService.userBoxName);
await Hive.openBox<PrivateChatModel>(HiveService.privateChatsBoxName);
await Hive.openBox<PrivateMessageModel>(HiveService.privateMessageBoxName);
await Hive.openBox<GroupModel>(HiveService.groupsBoxName);
await Hive.openBox<GroupMessageModel>(HiveService.groupsMessagesBoxName);

runApp(const ChattrApp());
}
//-----------------------------------------------------------------------
