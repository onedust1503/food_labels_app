// lib/services/coach_dashboard_service.dart
// 🎯 教練儀表板服務 v1.0
// ✅ 整合所有教練主頁需要的數據：待回覆、學員進度、待處理事項

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// 待處理事項類型
enum PendingActionType {
  needsHelp,      // 學員需要協助
  planExpiring,   // 計畫即將到期
  noActivity,     // 學員長時間無活動
  newRequest,     // 新配對請求
}

/// 待處理事項
class PendingAction {
  final PendingActionType type;
  final String traineeId;
  final String traineeName;
  final String title;
  final String subtitle;
  final String? sessionId;        // 如果是需要協助，存儲 sessionId
  final String? helpMessage;      // 協助訊息
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

  /// 獲取圖標
  String get iconEmoji {
    switch (type) {
      case PendingActionType.needsHelp:
        return '🔴';
      case PendingActionType.planExpiring:
        return '📅';
      case PendingActionType.noActivity:
        return '⚠️';
      case PendingActionType.newRequest:
        return '👋';
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
      case PendingActionType.newRequest:
        return '處理請求';
    }
  }

  /// 優先級（數字越小越優先）
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
    }
  }
}

/// 儀表板統計數據
class DashboardStats {
  final int totalStudents;
  final int activeStudents;      // 本週有訓練
  final int needsHelpCount;      // 待回覆數量
  final int needsAttentionCount; // 需要關注
  final int pendingRequests;     // 待處理配對請求
  final int expiringPlans;       // 即將到期的計畫

  DashboardStats({
    this.totalStudents = 0,
    this.activeStudents = 0,
    this.needsHelpCount = 0,
    this.needsAttentionCount = 0,
    this.pendingRequests = 0,
    this.expiringPlans = 0,
  });

  /// 總待處理數量
  int get totalPending => needsHelpCount + pendingRequests + expiringPlans;

  /// 是否有緊急事項
  bool get hasUrgent => needsHelpCount > 0;
}

/// 教練儀表板服務
class CoachDashboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _currentUserId => _auth.currentUser?.uid;

  // ========== 獲取儀表板統計 ==========

  /// 獲取完整的儀表板統計數據
  Future<DashboardStats> getDashboardStats() async {
    if (_currentUserId == null) {
      debugPrint('❌ getDashboardStats: currentUserId 為 null');
      return DashboardStats();
    }

    try {
      debugPrint('🔍 開始獲取儀表板統計...');
      
      // 並行獲取所有數據
      final results = await Future.wait([
        _getStudentIds(),
        _getPendingRequestsCount(),
        _getExpiringPlansCount(),
      ]);

      final studentIds = results[0] as List<String>;
      final pendingRequests = results[1] as int;
      final expiringPlans = results[2] as int;

      debugPrint('📊 學員數: ${studentIds.length}, 待處理請求: $pendingRequests, 到期計畫: $expiringPlans');

      // 獲取學員相關統計
      int activeCount = 0;
      int needsHelpCount = 0;
      int needsAttentionCount = 0;

      // 計算本週開始日期
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekStartDate = DateTime(weekStart.year, weekStart.month, weekStart.day);

      debugPrint('🔍 本週開始日期: $weekStartDate');

      for (final studentId in studentIds) {
        debugPrint('🔍 處理學員: $studentId');
        
        try {
          // 檢查本週是否有訓練（查詢子集合）
          final weekCompletions = await _firestore
              .collection('users')
              .doc(studentId)
              .collection('workoutCompletions')
              .where('actualDate', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStartDate))
              .limit(1)
              .get();

          if (weekCompletions.docs.isNotEmpty) {
            activeCount++;
          } else {
            needsAttentionCount++;
          }
        } catch (e) {
          debugPrint('⚠️ 查詢學員 $studentId 的訓練完成記錄失敗: $e');
          // 查詢失敗時，標記為需要關注
          needsAttentionCount++;
        }

        // 檢查是否有未解決的協助請求（🔥 優先服務器，失敗時回退緩存）
        try {
          QuerySnapshot helpRequests;
          try {
            helpRequests = await _firestore
                .collection('workoutSessions')
                .where('userId', isEqualTo: studentId)
                .where('feedback.needHelp', isEqualTo: true)
                .get(const GetOptions(source: Source.server));
          } catch (e) {
            debugPrint('⚠️ 服務器查詢失敗，使用緩存: $e');
            helpRequests = await _firestore
                .collection('workoutSessions')
                .where('userId', isEqualTo: studentId)
                .where('feedback.needHelp', isEqualTo: true)
                .get();
          }

          debugPrint('🔍 學員 $studentId 的協助請求數: ${helpRequests.docs.length}');

          for (final doc in helpRequests.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final feedback = data['feedback'] as Map<String, dynamic>?;
            final helpResolved = feedback?['helpResolved'] ?? false;
            debugPrint('🔍 協助請求 ${doc.id}: needHelp=true, helpResolved=$helpResolved');
            if (!helpResolved) {
              needsHelpCount++;
            }
          }
        } catch (e) {
          debugPrint('⚠️ 查詢學員 $studentId 的協助請求失敗: $e');
        }
      }

      debugPrint('✅ 統計完成: 活躍=$activeCount, 需協助=$needsHelpCount, 需關注=$needsAttentionCount');

      return DashboardStats(
        totalStudents: studentIds.length,
        activeStudents: activeCount,
        needsHelpCount: needsHelpCount,
        needsAttentionCount: needsAttentionCount,
        pendingRequests: pendingRequests,
        expiringPlans: expiringPlans,
      );
    } catch (e) {
      debugPrint('❌ 獲取儀表板統計失敗: $e');
      return DashboardStats();
    }
  }

  // ========== 獲取待處理事項 ==========

  /// 獲取所有待處理事項（按優先級排序）
  Future<List<PendingAction>> getPendingActions() async {
    if (_currentUserId == null) return [];

    try {
      final List<PendingAction> actions = [];

      // 1. 獲取需要協助的訓練
      final helpActions = await _getNeedsHelpActions();
      actions.addAll(helpActions);

      // 2. 獲取新配對請求
      final requestActions = await _getNewRequestActions();
      actions.addAll(requestActions);

      // 3. 獲取即將到期的計畫
      final expiringActions = await _getExpiringPlanActions();
      actions.addAll(expiringActions);

      // 4. 獲取長時間無活動的學員
      final inactiveActions = await _getInactiveStudentActions();
      actions.addAll(inactiveActions);

      // 按優先級和時間排序
      actions.sort((a, b) {
        final priorityCompare = a.priority.compareTo(b.priority);
        if (priorityCompare != 0) return priorityCompare;
        return b.createdAt.compareTo(a.createdAt);  // 較新的在前
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
        // 獲取學員名稱
        final userDoc = await _firestore.collection('users').doc(studentId).get();
        final userName = userDoc.data()?['displayName'] ?? '學員';

        // 查詢未解決的協助請求（🔥 優先服務器，失敗時回退緩存）
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
          debugPrint('⚠️ 服務器查詢失敗，使用緩存: $e');
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
          if (helpResolved) continue;  // 跳過已解決的

          final helpMessage = feedback['helpMessage']?.toString() ?? '';
          final workoutName = data['name']?.toString() ?? '訓練';
          final endedAt = (data['endedAt'] as Timestamp?)?.toDate() ?? DateTime.now();

          debugPrint('✅ 找到未解決的協助請求: $workoutName, 訊息: $helpMessage');

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
        
        // 獲取請求者名稱
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
      final sevenDaysLater = now.add(const Duration(days: 7));

      final plans = await _firestore
          .collection('workoutPlans')
          .where('coachId', isEqualTo: _currentUserId)
          .where('status', isEqualTo: 'active')
          .get();

      for (final doc in plans.docs) {
        final data = doc.data();
        final endDate = (data['endDate'] as Timestamp?)?.toDate();
        
        if (endDate == null) continue;
        
        // 檢查是否在7天內到期
        if (endDate.isAfter(now) && endDate.isBefore(sevenDaysLater)) {
          final traineeId = data['traineeId'] ?? '';
          final planName = data['planName'] ?? '訓練計畫';
          
          // 獲取學員名稱
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

  /// 獲取長時間無活動的學員（超過7天）
  Future<List<PendingAction>> _getInactiveStudentActions() async {
    final List<PendingAction> actions = [];
    
    try {
      final studentIds = await _getStudentIds();
      final now = DateTime.now();
      final sevenDaysAgo = now.subtract(const Duration(days: 7));

      for (final studentId in studentIds) {
        try {
          // 檢查最近的訓練記錄（查詢子集合）
          final recentWorkouts = await _firestore
              .collection('users')
              .doc(studentId)
              .collection('workoutCompletions')
              .orderBy('actualDate', descending: true)
              .limit(1)
              .get();

          DateTime? lastWorkout;
          if (recentWorkouts.docs.isNotEmpty) {
            lastWorkout = (recentWorkouts.docs.first.data()['actualDate'] as Timestamp?)?.toDate();
          }

          // 如果超過7天沒訓練
          if (lastWorkout == null || lastWorkout.isBefore(sevenDaysAgo)) {
            final userDoc = await _firestore.collection('users').doc(studentId).get();
            final userName = userDoc.data()?['displayName'] ?? '學員';

            final daysInactive = lastWorkout != null 
                ? now.difference(lastWorkout).inDays 
                : 999;

            // 只顯示真正長時間無活動的（避免新學員被標記）
            if (daysInactive >= 7 && daysInactive < 999) {
              actions.add(PendingAction(
                type: PendingActionType.noActivity,
                traineeId: studentId,
                traineeName: userName,
                title: '$userName 已${daysInactive}天未訓練',
                subtitle: '建議發送關心訊息',
                createdAt: lastWorkout ?? now.subtract(const Duration(days: 30)),
                extraData: {'daysInactive': daysInactive},
              ));
            }
          }
        } catch (e) {
          // 🔥 v3.2：單個學員查詢失敗不影響其他學員
          debugPrint('⚠️ 查詢學員 $studentId 的活動記錄失敗: $e');
        }
      }
    } catch (e) {
      debugPrint('❌ 獲取無活動學員失敗: $e');
    }

    return actions;
  }

  // ========== 輔助方法 ==========

  /// 獲取所有學員 ID
  Future<List<String>> _getStudentIds() async {
    if (_currentUserId == null) {
      debugPrint('❌ _getStudentIds: currentUserId 為 null');
      return [];
    }

    try {
      debugPrint('🔍 查詢學員列表，教練ID: $_currentUserId');
      
      final pairs = await _firestore
          .collection('pairs')
          .where('coachId', isEqualTo: _currentUserId)
          .where('status', isEqualTo: 'active')
          .get();

      debugPrint('🔍 找到 ${pairs.docs.length} 個配對記錄');
      
      for (final doc in pairs.docs) {
        debugPrint('🔍 配對: ${doc.id} => ${doc.data()}');
      }

      final studentIds = pairs.docs
          .map((doc) => doc.data()['traineeId'] as String?)
          .where((id) => id != null && id.isNotEmpty)
          .cast<String>()
          .toList();
      
      debugPrint('✅ 學員ID列表: $studentIds');
      return studentIds;
    } catch (e) {
      debugPrint('❌ 獲取學員列表失敗: $e');
      return [];
    }
  }

  /// 獲取待處理配對請求數量
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

  /// 獲取即將到期計畫數量
  Future<int> _getExpiringPlansCount() async {
    if (_currentUserId == null) return 0;

    try {
      final now = DateTime.now();
      final sevenDaysLater = now.add(const Duration(days: 7));

      final plans = await _firestore
          .collection('workoutPlans')
          .where('coachId', isEqualTo: _currentUserId)
          .where('status', isEqualTo: 'active')
          .get();

      int count = 0;
      for (final doc in plans.docs) {
        final endDate = (doc.data()['endDate'] as Timestamp?)?.toDate();
        if (endDate != null && endDate.isAfter(now) && endDate.isBefore(sevenDaysLater)) {
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
}