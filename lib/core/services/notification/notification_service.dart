import 'dart:convert';
import 'dart:developer';
import 'package:chattr/core/routing/router.dart';
import 'package:chattr/core/routing/router_models.dart';
import 'package:chattr/core/routing/routes.dart';
import 'package:chattr/core/services/hive/hive_services.dart';
import 'package:chattr/core/services/supabase/supabase_client_manager.dart';
import 'package:chattr/core/services/supabase/supabase_crud_services.dart';
import 'package:chattr/core/utils/di/get_it.dart';
import 'package:chattr/features/auth/data/models/user_model.dart';
import 'package:chattr/features/group_chats/data/models/group_model.dart';
import 'package:chattr/features/private_chats/data/models/private_chat_model.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  final SupabaseClientManager client;
  NotificationService({required this.client});
  SupabaseClient get _client => client.client;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  final AndroidNotificationChannel _androidChannel =
      const AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'This channel is used for important notifications.',
        importance: Importance.max,
        playSound: true,
      );

  Future<void> init() async {
    // 1. طلب الصلاحيات
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      log('User granted permission');

      // 2. إعداد الإشعارات المحلية (Local Notifications)
      await _initLocalNotifications();

      // 3. الاستماع للإشعارات والتطبيق مفتوح (Foreground)
      _listenToForegroundMessages();
      await _setupNotificationClickHandlers();
      // 4. جلب الـ Token الحالي وطباعته
      String? token = await getDeviceToken();
      log('FCM Token: $token');
 

      // 5. الاستماع لتغيير الـ Token (زي ما قفشتني فيها 🫡)
      _messaging.onTokenRefresh.listen((newToken) async {
        log('FCM Token Refreshed: $newToken');

        // جلب اليوزر الحالي من Supabase Client
        final currentUser = _client.auth.currentUser;
        if (currentUser != null) {
          // استخدام دالة put اللي إنت عاملها في الـ Crud Services
          await getIt<SupabaseCrudServices>().put(
            table: 'messenger_users',
            data: {'fcm_token': newToken},
            column: 'id',
            id: currentUser.id,
          );
        }
      });
    } else {
      log('User declined or has not accepted permission');
    }
  }

  Future<void> _setupNotificationClickHandlers() async {
    // 1. حالة الـ Terminated (الأبلكيشن كان مقفول تماماً واليوزر داس على الإشعار)
    RemoteMessage? initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationRouting(initialMessage.data);
    }

    // 2. حالة الـ Background (الأبلكيشن في الخلفية)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationRouting(message.data);
    });
  }

  Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_androidChannel);

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          // الـ Payload هنا بيكون String، هنحوله لـ Map
          // إحنا بعتناه من الـ Edge Function كـ String، فلازم نعمله Parse
          // في الـ Edge Function بعتنا data: { chatId, type }
          // فممكن نعدل دالة الـ show تحت عشان تبعت الـ data صح
          try {
            // تنويه: في دالة _listenToForegroundMessages تحت، لازم نخلي الـ payload هو jsonEncode(message.data)
            final data = jsonDecode(response.payload!);
            _handleNotificationRouting(data);
          } catch (e) {
            log('Error parsing payload: $e');
          }
        }
      },
    );
  }

  void _listenToForegroundMessages() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        // 1. نجيب الـ ID بتاع الشات اللي جاي في الإشعار
        final incomingChatId = message.data['chatId'];

        // 2. نقارنه بالشات المفتوح حالياً
        if (AppRouter.activeChatId != null &&
            AppRouter.activeChatId == incomingChatId) {
          log(
            'Notification suppressed: User is already inside chat -> $incomingChatId',
          );
          // بنعمل return عشان نوقف الدالة ومتكملش الكود اللي تحت وتظهر الإشعار
          return;
        }
        log('Received a foreground message: ${notification.title}');

        _localNotifications.show(
          id: notification.hashCode,
          title: notification.title,
          body: notification.body,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              _androidChannel.id,
              _androidChannel.name,
              channelDescription: _androidChannel.description,
              icon: android.smallIcon,
              importance: Importance.max,
              priority: Priority.high,
              playSound: true,
            ),
            iOS: const DarwinNotificationDetails(),
          ),
          payload: jsonEncode(message.data),
        );
      }
    });
  }

  void _handleNotificationRouting(Map<String, dynamic> data) async {
    final String? type = data['type'];
    final String? chatId = data['chatId'];

    if (type == null || chatId == null) return;

    log('Routing to $type with ID: $chatId');

    if (type == 'private_message') {
      final PrivateChatModel? chat = await HiveService.getPrivateChat(chatId);
      final String userId = _client.auth.currentUser!.id;
      final UserModel? currentUser = await HiveService.getUser(userId);
      if (chat != null && currentUser != null) {
        final PrivateChatParams chatData = PrivateChatParams(
          chatData: chat,
          curruntUser: currentUser,
        );
        AppRouter.router.push(Routes.privateChatsBody, extra: chatData);
      }
    } else if (type == 'group_message') {
      final GroupModel? chat = await HiveService.getGroup(chatId);
      final String userId = _client.auth.currentUser!.id;
      final UserModel? currentUser = await HiveService.getUser(userId);
      if (chat != null && currentUser != null) {
        final GroupChatParams groupData = GroupChatParams(
          groupData: chat,
          currentUser: currentUser,
          memberData: chat.members!,
        );

        AppRouter.router.push(Routes.groupMessages, extra: groupData);
      }
    }
  }

  Future<String?> getDeviceToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      log('Error getting FCM token: $e');
      return null;
    }
  }
}
