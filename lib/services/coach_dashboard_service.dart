// lib/services/coach_dashboard_service.dart
// 🎯 教練儀表板服務 v2.0
// ✅ v2.0 新增：智能異常判斷、正面通知、動態計算標準
// ✅ v1.0 整合所有教練主頁需要的數據：待回覆、學員進度、待處理事項

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// 待處理事項類型
enum PendingActionType {
  needsHelp,      // 學員需要協助（🔴 緊急）
  planExpiring,   // 計畫即將到期（🟡 警告）
  noActivity,     // 學員長時間無活動（🟡 警告）
  lowCompletion,  // 完成率偏低（🟡 警告）🆕
  lowOnTimeRate,  // 按時率偏低（🟡 警告）🆕
  newRequest,     // 新配對請求（🟢 一般）
  goalAchieved,   // 學員達成目標（🎉 正面）🆕
  personalRecord, // 學員創下個人紀錄（🎉 正面）🆕
}

/// 🆕 v2.0：通知優先級
enum NotificationPriority {
  urgent,   // 🔴 緊急 - 需要立即處理
  warning,  // 🟡 警告 - 需要關注
  normal,   // 🟢 一般 - 普通通知
  positive, // 🎉 正面 - 好消息
}

/// 待處理事項
class PendingAction {
  final PendingActionType type;
  final String traineeId;
  final String traineeName;
  final String title;
  final String subtitle;
  final String? sessionId;
  final String? helpMessage;
  final DateTime createdAt;
  final Map<String, dynamic>? extraData;

  PendingAction({
    required this.type,
    required this.traineeId,
    required this.traineeName,
    required this.title,
    required this.subtitle,
    this.sessionId,
    this.helpMessage,
    required this.createdAt,
    this.extraData,
  });

  /// 獲取優先級
  NotificationPriority get priorityLevel {
    switch (type) {
      case PendingActionType.needsHelp:
        return NotificationPriority.urgent;
      case PendingActionType.planExpiring:
      case PendingActionType.noActivity:
      case PendingActionType.lowCompletion:
      case PendingActionType.lowOnTimeRate:
        return NotificationPriority.warning;
      case PendingActionType.newRequest:
        return NotificationPriority.normal;
      case PendingActionType.goalAchieved:
      case PendingActionType.personalRecord:
        return NotificationPriority.positive;
    }
  }

  /// 獲取圖標
  String get iconEmoji {
    switch (type) {
      case PendingActionType.needsHelp:
        return '🔴';
      case PendingActionType.planExpiring:
        return '📅';
      case PendingActionType.noActivity:
        return '⚠️';
      case PendingActionType.lowCompletion:
        return '📉';
      case PendingActionType.lowOnTimeRate:
        return '⏰';
      case PendingActionType.newRequest:
        return '👋';
      case PendingActionType.goalAchieved:
        return '🎉';
      case PendingActionType.personalRecord:
        return '🏆';
    }
  }

  /// 獲取行動按鈕文字
  String get actionText {
    switch (type) {
      case PendingActionType.needsHelp:
        return '立即回覆';
      case PendingActionType.planExpiring:
        return '查看計畫';
      case PendingActionType.noActivity:
        return '發送訊息';
      case PendingActionType.lowCompletion:
        return '關心學員';
      case PendingActionType.lowOnTimeRate:
        return '調整計畫';
      case PendingActionType.newRequest:
        return '處理請求';
      case PendingActionType.goalAchieved:
        return '發送鼓勵';
      case PendingActionType.personalRecord:
        return '恭喜學員';
    }
  }

  /// 優先級排序值（數字越小越優先）
  int get priority {
    switch (type) {
      case PendingActionType.needsHelp:
        return 0;  // 最高優先
      case PendingActionType.newRequest:
        return 1;
      case PendingActionType.planExpiring:
        return 2;
      case PendingActionType.noActivity:
        return 3;
      case PendingActionType.lowCompletion:
        return 4;
      case PendingActionType.lowOnTimeRate:
        return 5;
      case PendingActionType.goalAchieved:
        return 6;
      case PendingActionType.personalRecord:
        return 7;
    }
  }

  /// 🆕 是否為正面通知
  bool get isPositive => 
      type == PendingActionType.goalAchieved || 
      type == PendingActionType.personalRecord;
}

/// 🆕 v2.0：學員狀態評估結果
class StudentStatusAssessment {
  final String traineeId;
  final String traineeName;
  final bool needsAttention;
  final List<String> warningReasons;
  final List<String> positiveReasons;
  final int weeklyCompletions;
  final int weeklyTarget;
  final double onTimeRate;
  final int totalCompletions; // 樣本量
  final int daysSinceLastWorkout;
  final int planFrequency; // 計畫中的每週訓練天數

  StudentStatusAssessment({
    required this.traineeId,
    required this.traineeName,
    this.needsAttention = false,
    this.warningReasons = const [],
    this.positiveReasons = const [],
    this.weeklyCompletions = 0,
    this.weeklyTarget = 0,
    this.onTimeRate = 0.0,
    this.totalCompletions = 0,
    this.daysSinceLastWorkout = 0,
    this.planFrequency = 3,
  });

  /// 完成率
  double get completionRate => 
      weeklyTarget > 0 ? weeklyCompletions / weeklyTarget : 0.0;
}

/// 儀表板統計數據
class DashboardStats {
  final int totalStudents;
  final int activeStudents;
  final int needsHelpCount;
  final int needsAttentionCount;
  final int pendingRequests;
  final int expiringPlans;
  final int goalAchievedCount;  // 🆕 達成目標數

  DashboardStats({
    this.totalStudents = 0,
    this.activeStudents = 0,
    this.needsHelpCount = 0,
    this.needsAttentionCount = 0,
    this.pendingRequests = 0,
    this.expiringPlans = 0,
    this.goalAchievedCount = 0,
  });

  int get totalPending => needsHelpCount + pendingRequests + expiringPlans;
  bool get hasUrgent => needsHelpCount > 0;
}

/// 🆕 v2.0：異常判斷配置（可調整閾值）
class AlertThresholds {
  // 🔴 緊急標準
  static const int helpRequestMaxAge = 48; // 協助請求超過48小時未處理
  
  // 🟡 警告標準 - 無活動
  static const int inactivityMultiplier = 2; // 無活動天數 = 計畫頻率 × 此倍數
  static const int minInactivityDays = 5; // 最少無活動天數
  static const int maxInactivityDays = 14; // 最多無活動天數（避免新學員誤報）
  
  // 🟡 警告標準 - 完成率
  static const double lowCompletionRate = 0.5; // 完成率低於 50%
  static const int completionCheckDayOfWeek = 3; // 週三後才檢查（1=週一）
  
  // 🟡 警告標準 - 按時率
  static const double lowOnTimeRate = 0.6; // 按時率低於 60%
  static const int minSampleSize = 3; // 最少完成次數才計算按時率
  
  // 🟡 警告標準 - 計畫到期
  static const int planExpiringDays = 7; // 7天內到期
  
  // 🎉 正面標準
  static const double goalAchievedRate = 1.0; // 完成率達 100%
  static const double excellentOnTimeRate = 0.9; // 按時率達 90%
}

/// 教練儀表板服務 v2.0
class CoachDashboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _currentUserId => _auth.currentUser?.uid;

  // ========== 獲取儀表板統計 ==========

  Future<DashboardStats> getDashboardStats() async {
    if (_currentUserId == null) {
      debugPrint('❌ getDashboardStats: currentUserId 為 null');
      return DashboardStats();
    }

    try {
      debugPrint('🔍 開始獲取儀表板統計...');
      
      final results = await Future.wait([
        _getStudentIds(),
        _getPendingRequestsCount(),
        _getExpiringPlansCount(),
      ]);

      final studentIds = results[0] as List<String>;
      final pendingRequests = results[1] as int;
      final expiringPlans = results[2] as int;

      debugPrint('📊 學員數: ${studentIds.length}, 待處理請求: $pendingRequests, 到期計畫: $expiringPlans');

      int activeCount = 0;
      int needsHelpCount = 0;
      int needsAttentionCount = 0;
      int goalAchievedCount = 0;

      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekStartDate = DateTime(weekStart.year, weekStart.month, weekStart.day);

      for (final studentId in studentIds) {
        try {
          // 🆕 v2.0：使用智能評估
          final assessment = await _assessStudentStatus(studentId, weekStartDate);
          
          if (assessment.weeklyCompletions > 0) {
            activeCount++;
          }
          
          if (assessment.needsAttention) {
            needsAttentionCount++;
          }
          
          // 檢查是否達成目標
          if (assessment.completionRate >= AlertThresholds.goalAchievedRate &&
              assessment.weeklyTarget > 0) {
            goalAchievedCount++;
          }

          // 檢查協助請求
          final helpCount = await _getUnresolvedHelpCount(studentId);
          needsHelpCount += helpCount;
          
        } catch (e) {
          debugPrint('⚠️ 處理學員 $studentId 時發生錯誤: $e');
          needsAttentionCount++;
        }
      }

      debugPrint('✅ 統計完成: 活躍=$activeCount, 需協助=$needsHelpCount, 需關注=$needsAttentionCount, 達標=$goalAchievedCount');

      return DashboardStats(
        totalStudents: studentIds.length,
        activeStudents: activeCount,
        needsHelpCount: needsHelpCount,
        needsAttentionCount: needsAttentionCount,
        pendingRequests: pendingRequests,
        expiringPlans: expiringPlans,
        goalAchievedCount: goalAchievedCount,
      );
    } catch (e) {
      debugPrint('❌ 獲取儀表板統計失敗: $e');
      return DashboardStats();
    }
  }

  // ========== 🆕 v2.0：智能學員狀態評估 ==========

  Future<StudentStatusAssessment> _assessStudentStatus(
    String studentId,
    DateTime weekStartDate,
  ) async {
    String traineeName = '學員';
    List<String> warningReasons = [];
    List<String> positiveReasons = [];
    
    try {
      // 獲取學員名稱
      final userDoc = await _firestore.collection('users').doc(studentId).get();
      traineeName = userDoc.data()?['displayName'] ?? '學員';

      // 獲取學員的計畫
      final plans = await _firestore
          .collection('workoutPlans')
          .where('traineeId', isEqualTo: studentId)
          .where('status', isEqualTo: 'active')
          .get();

      // 計算計畫中的每週訓練天數
      int planFrequency = 3; // 預設
      int weeklyTarget = 0;
      
      for (final plan in plans.docs) {
        final days = plan.data()['days'];
        if (days is List) {
          weeklyTarget += days.length;
        } else if (days is Map) {
          weeklyTarget += days.length;
        }
      }
      
      if (weeklyTarget > 0) {
        planFrequency = weeklyTarget;
      }

      // 獲取本週完成記錄
      final weekCompletions = await _firestore
          .collection('workoutCompletions')
          .where('userId', isEqualTo: studentId)
          .where('actualDate', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStartDate))
          .get();

      final weeklyCompletions = weekCompletions.docs.length;

      // 獲取總完成記錄（計算按時率）
      final allCompletions = await _firestore
          .collection('workoutCompletions')
          .where('userId', isEqualTo: studentId)
          .orderBy('actualDate', descending: true)
          .limit(20)  // 最近20次
          .get();

      final totalCompletions = allCompletions.docs.length;
      int onTimeCount = 0;
      DateTime? lastWorkoutDate;

      for (final doc in allCompletions.docs) {
        final data = doc.data();
        if (data['isOnSchedule'] == true) {
          onTimeCount++;
        }
        if (lastWorkoutDate == null && data['actualDate'] != null) {
          lastWorkoutDate = (data['actualDate'] as Timestamp).toDate();
        }
      }

      final onTimeRate = totalCompletions > 0 ? onTimeCount / totalCompletions : 0.0;
      final completionRate = weeklyTarget > 0 ? weeklyCompletions / weeklyTarget : 0.0;
      
      // 計算距離上次訓練的天數
      final now = DateTime.now();
      final daysSinceLastWorkout = lastWorkoutDate != null
          ? now.difference(lastWorkoutDate).inDays
          : 999;

      // ============ 🆕 智能判斷邏輯 ============

      bool needsAttention = false;

      // 📌 判斷 1：無活動（動態計算）
      // 無活動天數標準 = 計畫頻率 × 2，但在 5-14 天範圍內
      final inactivityThreshold = (planFrequency * AlertThresholds.inactivityMultiplier)
          .clamp(AlertThresholds.minInactivityDays, AlertThresholds.maxInactivityDays);
      
      if (daysSinceLastWorkout >= inactivityThreshold && daysSinceLastWorkout < 999) {
        needsAttention = true;
        warningReasons.add('已 $daysSinceLastWorkout 天未訓練');
      }

      // 📌 判斷 2：完成率偏低（考慮星期幾）
      // 只有過了週三才檢查，避免週一週二誤報
      final dayOfWeek = now.weekday;
      if (dayOfWeek >= AlertThresholds.completionCheckDayOfWeek) {
        if (completionRate < AlertThresholds.lowCompletionRate && weeklyTarget > 0) {
          needsAttention = true;
          final percent = (completionRate * 100).toStringAsFixed(0);
          warningReasons.add('本週完成率 $percent%');
        }
      }

      // 📌 判斷 3：按時率偏低（考慮樣本量）
      // 只有完成次數 >= 3 次才計算
      if (totalCompletions >= AlertThresholds.minSampleSize) {
        if (onTimeRate < AlertThresholds.lowOnTimeRate) {
          needsAttention = true;
          final percent = (onTimeRate * 100).toStringAsFixed(0);
          warningReasons.add('按時率 $percent%');
        }
      }

      // 📌 正面判斷：達成目標
      if (completionRate >= AlertThresholds.goalAchievedRate && weeklyTarget > 0) {
        positiveReasons.add('本週目標達成！');
      }

      // 📌 正面判斷：優秀按時率
      if (totalCompletions >= AlertThresholds.minSampleSize &&
          onTimeRate >= AlertThresholds.excellentOnTimeRate) {
        positiveReasons.add('按時率優秀 ${(onTimeRate * 100).toStringAsFixed(0)}%');
      }

      return StudentStatusAssessment(
        traineeId: studentId,
        traineeName: traineeName,
        needsAttention: needsAttention,
        warningReasons: warningReasons,
        positiveReasons: positiveReasons,
        weeklyCompletions: weeklyCompletions,
        weeklyTarget: weeklyTarget,
        onTimeRate: onTimeRate,
        totalCompletions: totalCompletions,
        daysSinceLastWorkout: daysSinceLastWorkout,
        planFrequency: planFrequency,
      );
    } catch (e) {
      debugPrint('❌ 評估學員 $studentId 狀態失敗: $e');
      return StudentStatusAssessment(
        traineeId: studentId,
        traineeName: traineeName,
        needsAttention: true,
        warningReasons: ['無法獲取狀態'],
      );
    }
  }

  /// 獲取未解決的協助請求數量
  Future<int> _getUnresolvedHelpCount(String studentId) async {
    try {
      final sessions = await _firestore
          .collection('workoutSessions')
          .where('userId', isEqualTo: studentId)
          .where('feedback.needHelp', isEqualTo: true)
          .get();

      int count = 0;
      for (final doc in sessions.docs) {
        final data = doc.data();
        final feedback = data['feedback'] as Map<String, dynamic>?;
        final helpResolved = feedback?['helpResolved'] ?? false;
        if (!helpResolved) {
          count++;
        }
      }
      return count;
    } catch (e) {
      return 0;
    }
  }

  // ========== 獲取待處理事項 ==========

  Future<List<PendingAction>> getPendingActions() async {
    if (_currentUserId == null) return [];

    try {
      final List<PendingAction> actions = [];

      // 1. 🔴 獲取需要協助的訓練（最高優先）
      final helpActions = await _getNeedsHelpActions();
      actions.addAll(helpActions);

      // 2. 🟢 獲取新配對請求
      final requestActions = await _getNewRequestActions();
      actions.addAll(requestActions);

      // 3. 🟡 獲取即將到期的計畫
      final expiringActions = await _getExpiringPlanActions();
      actions.addAll(expiringActions);

      // 4. 🟡 獲取需要關注的學員（智能判斷）
      final attentionActions = await _getAttentionNeededActions();
      actions.addAll(attentionActions);

      // 5. 🎉 獲取正面通知（達成目標等）
      final positiveActions = await _getPositiveActions();
      actions.addAll(positiveActions);

      // 按優先級和時間排序
      actions.sort((a, b) {
        final priorityCompare = a.priority.compareTo(b.priority);
        if (priorityCompare != 0) return priorityCompare;
        return b.createdAt.compareTo(a.createdAt);
      });

      return actions;
    } catch (e) {
      debugPrint('❌ 獲取待處理事項失敗: $e');
      return [];
    }
  }

  /// 獲取需要協助的訓練
  Future<List<PendingAction>> _getNeedsHelpActions() async {
    final List<PendingAction> actions = [];
    
    try {
      final studentIds = await _getStudentIds();
      
      for (final studentId in studentIds) {
        final userDoc = await _firestore.collection('users').doc(studentId).get();
        final userName = userDoc.data()?['displayName'] ?? '學員';

        QuerySnapshot sessions;
        try {
          sessions = await _firestore
              .collection('workoutSessions')
              .where('userId', isEqualTo: studentId)
              .where('feedback.needHelp', isEqualTo: true)
              .orderBy('endedAt', descending: true)
              .limit(10)
              .get(const GetOptions(source: Source.server));
        } catch (e) {
          sessions = await _firestore
              .collection('workoutSessions')
              .where('userId', isEqualTo: studentId)
              .where('feedback.needHelp', isEqualTo: true)
              .orderBy('endedAt', descending: true)
              .limit(10)
              .get();
        }

        for (final doc in sessions.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final feedback = data['feedback'] as Map<String, dynamic>?;
          
          if (feedback == null) continue;
          
          final helpResolved = feedback['helpResolved'] ?? false;
          if (helpResolved) continue;

          final helpMessage = feedback['helpMessage']?.toString() ?? '';
          final workoutName = data['name']?.toString() ?? '訓練';
          final endedAt = (data['endedAt'] as Timestamp?)?.toDate() ?? DateTime.now();

          actions.add(PendingAction(
            type: PendingActionType.needsHelp,
            traineeId: studentId,
            traineeName: userName,
            title: '$userName 需要協助',
            subtitle: helpMessage.isNotEmpty ? helpMessage : workoutName,
            sessionId: doc.id,
            helpMessage: helpMessage,
            createdAt: endedAt,
            extraData: {
              'workoutName': workoutName,
              'planName': data['planName'],
            },
          ));
        }
      }
    } catch (e) {
      debugPrint('❌ 獲取需要協助事項失敗: $e');
    }

    return actions;
  }

  /// 獲取新配對請求
  Future<List<PendingAction>> _getNewRequestActions() async {
    final List<PendingAction> actions = [];
    
    try {
      final requests = await _firestore
          .collection('pairRequests')
          .where('toUserId', isEqualTo: _currentUserId)
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .get();

      for (final doc in requests.docs) {
        final data = doc.data();
        final fromUserId = data['fromUserId'] ?? data['studentId'] ?? '';
        
        String requesterName = '學員';
        if (fromUserId.isNotEmpty) {
          final userDoc = await _firestore.collection('users').doc(fromUserId).get();
          requesterName = userDoc.data()?['displayName'] ?? '學員';
        }

        final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

        actions.add(PendingAction(
          type: PendingActionType.newRequest,
          traineeId: fromUserId,
          traineeName: requesterName,
          title: '新配對請求',
          subtitle: '$requesterName 想成為您的學員',
          createdAt: createdAt,
          extraData: {'requestId': doc.id},
        ));
      }
    } catch (e) {
      debugPrint('❌ 獲取配對請求失敗: $e');
    }

    return actions;
  }

  /// 獲取即將到期的計畫（7天內）
  Future<List<PendingAction>> _getExpiringPlanActions() async {
    final List<PendingAction> actions = [];
    
    try {
      final now = DateTime.now();
      final expiringDate = now.add(Duration(days: AlertThresholds.planExpiringDays));

      final plans = await _firestore
          .collection('workoutPlans')
          .where('coachId', isEqualTo: _currentUserId)
          .where('status', isEqualTo: 'active')
          .get();

      for (final doc in plans.docs) {
        final data = doc.data();
        final endDate = (data['endDate'] as Timestamp?)?.toDate();
        
        if (endDate == null) continue;
        
        if (endDate.isAfter(now) && endDate.isBefore(expiringDate)) {
          final traineeId = data['traineeId'] ?? '';
          final planName = data['planName'] ?? '訓練計畫';
          
          String traineeName = '學員';
          if (traineeId.isNotEmpty) {
            final userDoc = await _firestore.collection('users').doc(traineeId).get();
            traineeName = userDoc.data()?['displayName'] ?? '學員';
          }

          final daysLeft = endDate.difference(now).inDays;

          actions.add(PendingAction(
            type: PendingActionType.planExpiring,
            traineeId: traineeId,
            traineeName: traineeName,
            title: '計畫即將到期',
            subtitle: '$planName（${daysLeft}天後）',
            createdAt: endDate,
            extraData: {
              'planId': doc.id,
              'planName': planName,
              'daysLeft': daysLeft,
            },
          ));
        }
      }
    } catch (e) {
      debugPrint('❌ 獲取到期計畫失敗: $e');
    }

    return actions;
  }

  /// 🆕 v2.0：獲取需要關注的學員（智能判斷）
  Future<List<PendingAction>> _getAttentionNeededActions() async {
    final List<PendingAction> actions = [];
    
    try {
      final studentIds = await _getStudentIds();
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekStartDate = DateTime(weekStart.year, weekStart.month, weekStart.day);

      for (final studentId in studentIds) {
        try {
          final assessment = await _assessStudentStatus(studentId, weekStartDate);
          
          if (!assessment.needsAttention) continue;

          // 根據警告原因創建對應的事項
          for (final reason in assessment.warningReasons) {
            PendingActionType actionType;
            
            if (reason.contains('未訓練')) {
              actionType = PendingActionType.noActivity;
            } else if (reason.contains('完成率')) {
              actionType = PendingActionType.lowCompletion;
            } else if (reason.contains('按時率')) {
              actionType = PendingActionType.lowOnTimeRate;
            } else {
              actionType = PendingActionType.noActivity;
            }

            actions.add(PendingAction(
              type: actionType,
              traineeId: assessment.traineeId,
              traineeName: assessment.traineeName,
              title: '${assessment.traineeName} 需要關注',
              subtitle: reason,
              createdAt: now.subtract(Duration(days: assessment.daysSinceLastWorkout)),
              extraData: {
                'weeklyCompletions': assessment.weeklyCompletions,
                'weeklyTarget': assessment.weeklyTarget,
                'onTimeRate': assessment.onTimeRate,
                'daysSinceLastWorkout': assessment.daysSinceLastWorkout,
              },
            ));
          }
        } catch (e) {
          debugPrint('⚠️ 處理學員 $studentId 時發生錯誤: $e');
        }
      }
    } catch (e) {
      debugPrint('❌ 獲取需關注學員失敗: $e');
    }

    return actions;
  }

  /// 🆕 v2.0：獲取正面通知
  Future<List<PendingAction>> _getPositiveActions() async {
    final List<PendingAction> actions = [];
    
    try {
      final studentIds = await _getStudentIds();
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekStartDate = DateTime(weekStart.year, weekStart.month, weekStart.day);

      for (final studentId in studentIds) {
        try {
          final assessment = await _assessStudentStatus(studentId, weekStartDate);
          
          // 本週達成目標
          if (assessment.completionRate >= AlertThresholds.goalAchievedRate &&
              assessment.weeklyTarget > 0) {
            actions.add(PendingAction(
              type: PendingActionType.goalAchieved,
              traineeId: assessment.traineeId,
              traineeName: assessment.traineeName,
              title: '🎉 ${assessment.traineeName} 達成本週目標！',
              subtitle: '完成 ${assessment.weeklyCompletions}/${assessment.weeklyTarget} 次訓練',
              createdAt: now,
              extraData: {
                'weeklyCompletions': assessment.weeklyCompletions,
                'weeklyTarget': assessment.weeklyTarget,
              },
            ));
          }
        } catch (e) {
          debugPrint('⚠️ 處理學員 $studentId 正面通知時發生錯誤: $e');
        }
      }
    } catch (e) {
      debugPrint('❌ 獲取正面通知失敗: $e');
    }

    return actions;
  }

  // ========== 輔助方法 ==========

  Future<List<String>> _getStudentIds() async {
    if (_currentUserId == null) return [];

    try {
      final pairs = await _firestore
          .collection('pairs')
          .where('coachId', isEqualTo: _currentUserId)
          .where('status', isEqualTo: 'active')
          .get();

      return pairs.docs
          .map((doc) => doc.data()['traineeId'] as String?)
          .where((id) => id != null && id.isNotEmpty)
          .cast<String>()
          .toList();
    } catch (e) {
      debugPrint('❌ 獲取學員列表失敗: $e');
      return [];
    }
  }

  Future<int> _getPendingRequestsCount() async {
    if (_currentUserId == null) return 0;

    try {
      final requests = await _firestore
          .collection('pairRequests')
          .where('toUserId', isEqualTo: _currentUserId)
          .where('status', isEqualTo: 'pending')
          .get();

      return requests.docs.length;
    } catch (e) {
      return 0;
    }
  }

  Future<int> _getExpiringPlansCount() async {
    if (_currentUserId == null) return 0;

    try {
      final now = DateTime.now();
      final expiringDate = now.add(Duration(days: AlertThresholds.planExpiringDays));

      final plans = await _firestore
          .collection('workoutPlans')
          .where('coachId', isEqualTo: _currentUserId)
          .where('status', isEqualTo: 'active')
          .get();

      int count = 0;
      for (final doc in plans.docs) {
        final endDate = (doc.data()['endDate'] as Timestamp?)?.toDate();
        if (endDate != null && endDate.isAfter(now) && endDate.isBefore(expiringDate)) {
          count++;
        }
      }

      return count;
    } catch (e) {
      return 0;
    }
  }

  /// 標記協助請求為已解決
  Future<void> markHelpAsResolved(String sessionId) async {
    try {
      await _firestore.collection('workoutSessions').doc(sessionId).update({
        'feedback.helpResolved': true,
        'feedback.helpResolvedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ 已標記協助請求為已解決: $sessionId');
    } catch (e) {
      debugPrint('❌ 標記失敗: $e');
      rethrow;
    }
  }

  /// 🆕 v2.0：獲取學員詳細狀態評估（供外部使用）
  Future<StudentStatusAssessment> getStudentAssessment(String studentId) async {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartDate = DateTime(weekStart.year, weekStart.month, weekStart.day);
    
    return _assessStudentStatus(studentId, weekStartDate);
  }
}