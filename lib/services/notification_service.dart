// lib/services/notification_service.dart
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isInitialized = false;

  /// 初始化通知服務
  Future<void> initialize() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Taipei'));

    // 🆕 檢查並請求權限（會顯示對話框）
    await _requestExactAlarmPermission();

    await _initializeLocalNotifications();
    await _initializeFirebaseMessaging();

    _isInitialized = true;
    print('✅ NotificationService 初始化完成');
  }

  /// 🆕 請求精確鬧鐘權限（改進版 - 顯示自訂對話框）
  Future<void> _requestExactAlarmPermission() async {
    try {
      PermissionStatus status = await Permission.scheduleExactAlarm.status;
      
      print('📱 精確鬧鐘權限狀態: $status');
      
      if (status.isDenied || status.isPermanentlyDenied) {
        // 🆕 顯示說明對話框
        bool? userConfirmed = await _showPermissionDialog();
        
        if (userConfirmed == true) {
          // 用戶同意後，導向設定頁面
          await openAppSettings();
          print('📱 已導向設定頁面');
        } else {
          print('⚠️ 用戶拒絕開啟權限');
        }
      } else if (status.isGranted) {
        print('✅ 精確鬧鐘權限已存在');
      }
    } catch (e) {
      print('⚠️ 檢查精確鬧鐘權限時發生錯誤: $e');
    }
  }

  /// 🆕 顯示權限說明對話框
  Future<bool?> _showPermissionDialog() async {
    final context = navigatorKey.currentContext;
    if (context == null) {
      print('⚠️ 無法顯示對話框：context 為 null');
      return false;
    }

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,  // 🔒 不允許點擊外部關閉
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.alarm, color: Colors.orange.shade700, size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '需要精確鬧鐘權限',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '為了讓定時提醒功能正常運作，需要開啟「精確鬧鐘」權限。',
                style: TextStyle(fontSize: 15, height: 1.5),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          '權限用途：',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• 準時提醒喝水\n'
                      '• 準時提醒運動\n'
                      '• 準時提醒用餐',
                      style: TextStyle(fontSize: 13, height: 1.6),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);  // 返回 false
              },
              child: Text(
                '稍後再說',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(true);  // 返回 true
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('前往設定'),
            ),
          ],
        );
      },
    );
  }

  /// 檢查是否有精確鬧鐘權限
  Future<bool> hasExactAlarmPermission() async {
    try {
      PermissionStatus status = await Permission.scheduleExactAlarm.status;
      return status.isGranted;
    } catch (e) {
      print('⚠️ 檢查權限時發生錯誤: $e');
      return true;
    }
  }

  /// 🆕 手動請求權限（給頁面按鈕使用）
  Future<bool> requestExactAlarmPermission() async {
    bool? userConfirmed = await _showPermissionDialog();
    
    if (userConfirmed == true) {
      await openAppSettings();
      
      // 等待用戶從設定返回
      await Future.delayed(const Duration(seconds: 2));
      
      // 重新檢查權限
      return await hasExactAlarmPermission();
    }
    
    return false;
  }

  /// 引導用戶開啟精確鬧鐘權限
  Future<void> openAlarmSettings() async {
    await openAppSettings();
  }

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
    
    print('✅ 本地通知初始化完成');
  }

  Future<void> _initializeFirebaseMessaging() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ 用戶已授予推送通知權限');
      await _saveFCMToken();
      _firebaseMessaging.onTokenRefresh.listen(_onTokenRefresh);
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
      
      RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageOpenedApp(initialMessage);
      }
    } else {
      print('❌ 用戶拒絕推送通知權限');
    }
  }

  Future<void> _saveFCMToken() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      String? userId = _auth.currentUser?.uid;

      if (token != null && userId != null) {
        await _firestore.collection('users').doc(userId).update({
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        });
        print('✅ FCM Token 已儲存: ${token.substring(0, 20)}...');
      }
    } catch (e) {
      print('❌ 儲存 FCM Token 失敗: $e');
    }
  }

  void _onTokenRefresh(String newToken) {
    print('🔄 FCM Token 已更新');
    _saveFCMToken();
  }

  void _handleForegroundMessage(RemoteMessage message) {
    print('📨 收到前台訊息: ${message.notification?.title}');
    
    if (message.notification != null) {
      _showNotification(
        title: message.notification!.title ?? '新通知',
        body: message.notification!.body ?? '',
        payload: message.data['chatId'] ?? message.data['type'] ?? '',
      );
    }
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    print('🔔 用戶點擊了通知: ${message.notification?.title}');
  }

  void _onNotificationTapped(NotificationResponse response) {
    print('🔔 本地通知被點擊: ${response.payload}');
  }

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
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      playSound: true,
      enableVibration: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _localNotifications.show(
        DateTime.now().millisecond,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
      print('✅ 通知已發送: $title');
    } catch (e) {
      print('❌ 發送通知失敗: $e');
    }
  }

  Future<void> sendTestNotification() async {
    print('🧪 準備發送測試通知...');
    await _showNotification(
      title: '🔔 測試通知',
      body: '這是一條測試通知，如果你看到這個，表示通知系統運作正常！',
      payload: 'test',
    );
  }

  // ========== 定時提醒功能 ==========

  Future<void> scheduleWaterReminders({
    required List<int> hours,
  }) async {
    print('💧 設定喝水提醒: $hours');
    
    bool hasPermission = await hasExactAlarmPermission();
    if (!hasPermission) {
      print('⚠️ 沒有精確鬧鐘權限，無法設定定時提醒');
      return;
    }
    
    await cancelWaterReminders();

    for (int i = 0; i < hours.length; i++) {
      int hour = hours[i];
      final tz.TZDateTime scheduledDate = _nextInstanceOfTime(hour, 0);
      
      print('📅 排程喝水提醒 ${i + 1}: $hour:00 (${scheduledDate.toString()})');

      await _localNotifications.zonedSchedule(
        1000 + i,
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
    print('✅ 喝水提醒設定完成');
  }

  Future<void> scheduleWorkoutReminder({
    required int hour,
    required int minute,
    required String message,
  }) async {
    print('🏋️ 設定運動提醒: $hour:$minute');
    
    bool hasPermission = await hasExactAlarmPermission();
    if (!hasPermission) {
      print('⚠️ 沒有精確鬧鐘權限，無法設定定時提醒');
      return;
    }
    
    final tz.TZDateTime scheduledDate = _nextInstanceOfTime(hour, minute);
    
    print('📅 排程運動提醒: $hour:$minute (${scheduledDate.toString()})');

    await _localNotifications.zonedSchedule(
      2000,
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
    print('✅ 運動提醒設定完成');
  }

  Future<void> scheduleMealReminders({
    required List<MealReminder> meals,
  }) async {
    print('🍽️ 設定飲食提醒');
    
    bool hasPermission = await hasExactAlarmPermission();
    if (!hasPermission) {
      print('⚠️ 沒有精確鬧鐘權限，無法設定定時提醒');
      return;
    }
    
    await cancelMealReminders();

    for (int i = 0; i < meals.length; i++) {
      MealReminder meal = meals[i];
      final tz.TZDateTime scheduledDate = _nextInstanceOfTime(
        meal.hour,
        meal.minute,
      );
      
      print('📅 排程飲食提醒: ${meal.mealName} ${meal.hour}:${meal.minute} (${scheduledDate.toString()})');

      await _localNotifications.zonedSchedule(
        3000 + i,
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
    print('✅ 飲食提醒設定完成');
  }

  // ========== 取消提醒 ==========

  Future<void> cancelWaterReminders() async {
    for (int i = 0; i < 100; i++) {
      await _localNotifications.cancel(1000 + i);
    }
    print('🗑️ 已取消所有喝水提醒');
  }

  Future<void> cancelWorkoutReminder() async {
    await _localNotifications.cancel(2000);
    print('🗑️ 已取消運動提醒');
  }

  Future<void> cancelMealReminders() async {
    for (int i = 0; i < 100; i++) {
      await _localNotifications.cancel(3000 + i);
    }
    print('🗑️ 已取消所有飲食提醒');
  }

  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
    print('🗑️ 已取消所有通知');
  }

  // ========== 輔助方法 ==========

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

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  Future<String?> getFCMToken() async {
    return await _firebaseMessaging.getToken();
  }
}

// ========== 數據模型 ==========

class MealReminder {
  final String mealName;
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