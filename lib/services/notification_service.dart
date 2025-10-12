// lib/services/notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  bool _isInitialized = false;

  /// 初始化通知服務
  Future<void> initialize() async {
    if (_isInitialized) return;

    // 初始化時區
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Taipei'));

    // 初始化本地通知
    await _initializeLocalNotifications();

    // 初始化 Firebase 推送通知
    await _initializeFirebaseMessaging();

    _isInitialized = true;
  }

  /// 初始化本地通知
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  /// 初始化 Firebase 推送通知
  Future<void> _initializeFirebaseMessaging() async {
    // 請求推送通知權限
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('用戶已授予推送通知權限');

      // 獲取 FCM Token
      String? token = await _firebaseMessaging.getToken();
      print('FCM Token: $token');
      // TODO: 將 token 儲存到 Firestore，供教練發送通知使用

      // 監聽前台訊息
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // 監聽背景訊息點擊
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
    }
  }

  /// 處理前台訊息
  void _handleForegroundMessage(RemoteMessage message) {
    print('收到前台訊息: ${message.notification?.title}');
    
    // 在前台顯示本地通知
    if (message.notification != null) {
      _showNotification(
        title: message.notification!.title ?? '新通知',
        body: message.notification!.body ?? '',
        payload: message.data.toString(),
      );
    }
  }

  /// 處理訊息點擊（從背景或關閉狀態）
  void _handleMessageOpenedApp(RemoteMessage message) {
    print('用戶點擊了通知: ${message.notification?.title}');
    // TODO: 根據 message.data 導航到特定頁面
  }

  /// 通知被點擊的回調
  void _onNotificationTapped(NotificationResponse response) {
    print('本地通知被點擊: ${response.payload}');
    // TODO: 根據 payload 導航到特定頁面
  }

  /// 顯示即時通知
  Future<void> _showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'general_channel',
      '一般通知',
      channelDescription: '一般通知頻道',
      importance: Importance.high,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecond,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  // ========== 定時提醒功能 ==========

  /// 設定喝水提醒
  Future<void> scheduleWaterReminders({
    required List<int> hours, // 例如 [10, 14, 18]
  }) async {
    // 先取消舊的提醒
    await cancelWaterReminders();

    for (int i = 0; i < hours.length; i++) {
      int hour = hours[i];
      
      final tz.TZDateTime scheduledDate = _nextInstanceOfTime(hour, 0);

      await _localNotifications.zonedSchedule(
        1000 + i, // 通知ID (1000-1099 為喝水提醒)
        '💧 該喝水了！',
        '保持水分充足，對健康很重要哦！',
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'water_channel',
            '喝水提醒',
            channelDescription: '定時喝水提醒',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  /// 設定運動提醒
  Future<void> scheduleWorkoutReminder({
    required int hour,
    required int minute,
    required String message,
  }) async {
    final tz.TZDateTime scheduledDate = _nextInstanceOfTime(hour, minute);

    await _localNotifications.zonedSchedule(
      2000, // 通知ID (2000 為運動提醒)
      '🏋️ 運動時間到！',
      message,
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'workout_channel',
          '運動提醒',
          channelDescription: '運動訓練提醒',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// 設定飲食提醒
  Future<void> scheduleMealReminders({
    required List<MealReminder> meals,
  }) async {
    // 先取消舊的提醒
    await cancelMealReminders();

    for (int i = 0; i < meals.length; i++) {
      MealReminder meal = meals[i];
      final tz.TZDateTime scheduledDate = _nextInstanceOfTime(
        meal.hour,
        meal.minute,
      );

      await _localNotifications.zonedSchedule(
        3000 + i, // 通知ID (3000-3099 為飲食提醒)
        '🍽️ ${meal.mealName}時間到！',
        meal.message,
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'meal_channel',
            '飲食提醒',
            channelDescription: '用餐時間提醒',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  // ========== 取消提醒 ==========

  /// 取消所有喝水提醒
  Future<void> cancelWaterReminders() async {
    for (int i = 0; i < 100; i++) {
      await _localNotifications.cancel(1000 + i);
    }
  }

  /// 取消運動提醒
  Future<void> cancelWorkoutReminder() async {
    await _localNotifications.cancel(2000);
  }

  /// 取消所有飲食提醒
  Future<void> cancelMealReminders() async {
    for (int i = 0; i < 100; i++) {
      await _localNotifications.cancel(3000 + i);
    }
  }

  /// 取消所有通知
  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  // ========== 輔助方法 ==========

  /// 計算下一個指定時間的實例
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // 如果時間已過，則設定為明天
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }
}

// ========== 數據模型 ==========

class MealReminder {
  final String mealName; // 早餐、午餐、晚餐
  final int hour;
  final int minute;
  final String message;

  MealReminder({
    required this.mealName,
    required this.hour,
    required this.minute,
    required this.message,
  });
}