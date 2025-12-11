// lib/services/positive_notification_service.dart
// 🎯 正面通知與週報服務 v1.0
// ✅ 學員達成目標通知
// ✅ 個人紀錄通知
// ✅ 週報總結功能

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// 成就類型
enum AchievementType {
  weeklyGoal,        // 本週目標達成
  monthlyStreak,     // 連續訓練紀錄
  personalRecord,    // 個人紀錄（重量、次數等）
  firstWorkout,      // 首次訓練
  consistentTraining,// 持續穩定訓練
  nutritionGoal,     // 營養目標達成
}

/// 成就記錄
class Achievement {
  final String id;
  final String traineeId;
  final String traineeName;
  final AchievementType type;
  final String title;
  final String description;
  final Map<String, dynamic>? data;
  final DateTime achievedAt;
  final bool notified;  // 是否已通知教練

  Achievement({
    required this.id,
    required this.traineeId,
    required this.traineeName,
    required this.type,
    required this.title,
    required this.description,
    this.data,
    required this.achievedAt,
    this.notified = false,
  });

  String get emoji {
    switch (type) {
      case AchievementType.weeklyGoal:
        return '🎯';
      case AchievementType.monthlyStreak:
        return '🔥';
      case AchievementType.personalRecord:
        return '🏆';
      case AchievementType.firstWorkout:
        return '🌟';
      case AchievementType.consistentTraining:
        return '💪';
      case AchievementType.nutritionGoal:
        return '🥗';
    }
  }

  factory Achievement.fromFirestore(Map<String, dynamic> data, String docId) {
    return Achievement(
      id: docId,
      traineeId: data['traineeId'] ?? '',
      traineeName: data['traineeName'] ?? '',
      type: AchievementType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => AchievementType.weeklyGoal,
      ),
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      data: data['data'],
      achievedAt: (data['achievedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notified: data['notified'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'traineeId': traineeId,
      'traineeName': traineeName,
      'type': type.name,
      'title': title,
      'description': description,
      'data': data,
      'achievedAt': Timestamp.fromDate(achievedAt),
      'notified': notified,
    };
  }
}

/// 週報摘要
class WeeklyReport {
  final String coachId;
  final DateTime weekStart;
  final DateTime weekEnd;
  final int totalStudents;
  final int activeStudents;
  final int goalAchievers;         // 達成目標人數
  final int improvedStudents;      // 有進步的人數
  final int needsAttentionCount;   // 需關注人數
  final List<Achievement> achievements;
  final List<StudentWeeklySummary> studentSummaries;

  WeeklyReport({
    required this.coachId,
    required this.weekStart,
    required this.weekEnd,
    this.totalStudents = 0,
    this.activeStudents = 0,
    this.goalAchievers = 0,
    this.improvedStudents = 0,
    this.needsAttentionCount = 0,
    this.achievements = const [],
    this.studentSummaries = const [],
  });

  /// 整體活躍率
  double get activeRate => totalStudents > 0 ? activeStudents / totalStudents : 0;

  /// 目標達成率
  double get goalRate => totalStudents > 0 ? goalAchievers / totalStudents : 0;

  /// 週報標題
  String get title {
    final month = weekStart.month;
    final day = weekStart.day;
    return '$month/$day - ${weekEnd.month}/${weekEnd.day} 週報';
  }

  /// 週報摘要文字
  String get summary {
    final parts = <String>[];
    
    if (goalAchievers > 0) {
      parts.add('🎯 $goalAchievers 位學員達成目標');
    }
    if (achievements.isNotEmpty) {
      final records = achievements.where((a) => a.type == AchievementType.personalRecord).length;
      if (records > 0) {
        parts.add('🏆 $records 個新紀錄');
      }
    }
    if (needsAttentionCount > 0) {
      parts.add('⚠️ $needsAttentionCount 位需要關注');
    }
    
    return parts.isEmpty ? '本週表現平穩' : parts.join(' · ');
  }
}

/// 學員週摘要
class StudentWeeklySummary {
  final String traineeId;
  final String traineeName;
  final int completedWorkouts;
  final int targetWorkouts;
  final double onTimeRate;
  final bool achievedGoal;
  final List<String> highlights;  // 亮點
  final List<String> concerns;    // 需關注

  StudentWeeklySummary({
    required this.traineeId,
    required this.traineeName,
    this.completedWorkouts = 0,
    this.targetWorkouts = 0,
    this.onTimeRate = 0.0,
    this.achievedGoal = false,
    this.highlights = const [],
    this.concerns = const [],
  });

  double get completionRate => targetWorkouts > 0 ? completedWorkouts / targetWorkouts : 0;
}

/// 正面通知服務
class PositiveNotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _currentUserId => _auth.currentUser?.uid;

  // ========== 成就檢測 ==========

  /// 檢查學員成就（在訓練完成時調用）
  Future<List<Achievement>> checkAchievements({
    required String traineeId,
    required String traineeName,
  }) async {
    final achievements = <Achievement>[];

    try {
      // 1. 檢查本週目標達成
      final weeklyGoal = await _checkWeeklyGoal(traineeId, traineeName);
      if (weeklyGoal != null) achievements.add(weeklyGoal);

      // 2. 檢查連續訓練紀錄
      final streak = await _checkStreak(traineeId, traineeName);
      if (streak != null) achievements.add(streak);

      // 3. 檢查個人紀錄（需要額外參數，這裡略過）

      // 儲存成就到 Firebase
      for (final achievement in achievements) {
        await _saveAchievement(achievement);
      }

      return achievements;
    } catch (e) {
      debugPrint('❌ 檢查成就失敗: $e');
      return [];
    }
  }

  /// 檢查本週目標達成
  Future<Achievement?> _checkWeeklyGoal(String traineeId, String traineeName) async {
    try {
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekStartDate = DateTime(weekStart.year, weekStart.month, weekStart.day);

      // 獲取學員計畫
      final plans = await _firestore
          .collection('workoutPlans')
          .where('traineeId', isEqualTo: traineeId)
          .where('status', isEqualTo: 'active')
          .get();

      int weeklyTarget = 0;
      for (final plan in plans.docs) {
        final days = plan.data()['days'];
        if (days is List) {
          weeklyTarget += days.length;
        } else if (days is Map) {
          weeklyTarget += days.length;
        }
      }

      if (weeklyTarget == 0) return null;

      // 獲取本週完成次數
      final completions = await _firestore
          .collection('workoutCompletions')
          .where('userId', isEqualTo: traineeId)
          .where('actualDate', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStartDate))
          .get();

      final completedCount = completions.docs.length;

      // 檢查是否達成（且本週還沒記錄過）
      if (completedCount >= weeklyTarget) {
        // 檢查是否已經記錄過本週的達成
        final existingAchievement = await _firestore
            .collection('achievements')
            .where('traineeId', isEqualTo: traineeId)
            .where('type', isEqualTo: AchievementType.weeklyGoal.name)
            .where('achievedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStartDate))
            .get();

        if (existingAchievement.docs.isEmpty) {
          return Achievement(
            id: '',
            traineeId: traineeId,
            traineeName: traineeName,
            type: AchievementType.weeklyGoal,
            title: '🎯 本週目標達成！',
            description: '$traineeName 完成了本週 $weeklyTarget 次訓練目標',
            data: {
              'completed': completedCount,
              'target': weeklyTarget,
            },
            achievedAt: now,
          );
        }
      }

      return null;
    } catch (e) {
      debugPrint('❌ 檢查週目標失敗: $e');
      return null;
    }
  }

  /// 檢查連續訓練紀錄
  Future<Achievement?> _checkStreak(String traineeId, String traineeName) async {
    try {
      // 獲取最近30天的訓練記錄
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      
      final completions = await _firestore
          .collection('workoutCompletions')
          .where('userId', isEqualTo: traineeId)
          .where('actualDate', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
          .orderBy('actualDate', descending: true)
          .get();

      if (completions.docs.isEmpty) return null;

      // 計算連續訓練週數
      final Set<int> weeksWithWorkout = {};
      for (final doc in completions.docs) {
        final date = (doc.data()['actualDate'] as Timestamp).toDate();
        final weekNumber = _getWeekNumber(date);
        weeksWithWorkout.add(weekNumber);
      }

      final consecutiveWeeks = weeksWithWorkout.length;

      // 達到里程碑時發送通知
      final milestones = [2, 4, 8, 12];  // 連續 2, 4, 8, 12 週
      
      for (final milestone in milestones) {
        if (consecutiveWeeks >= milestone) {
          // 檢查是否已記錄過此里程碑
          final existing = await _firestore
              .collection('achievements')
              .where('traineeId', isEqualTo: traineeId)
              .where('type', isEqualTo: AchievementType.monthlyStreak.name)
              .where('data.milestone', isEqualTo: milestone)
              .get();

          if (existing.docs.isEmpty) {
            return Achievement(
              id: '',
              traineeId: traineeId,
              traineeName: traineeName,
              type: AchievementType.monthlyStreak,
              title: '🔥 連續 $milestone 週訓練！',
              description: '$traineeName 已連續 $milestone 週保持訓練',
              data: {
                'consecutiveWeeks': consecutiveWeeks,
                'milestone': milestone,
              },
              achievedAt: DateTime.now(),
            );
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint('❌ 檢查連續訓練失敗: $e');
      return null;
    }
  }

  int _getWeekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final days = date.difference(firstDayOfYear).inDays;
    return (days / 7).ceil();
  }

  /// 儲存成就
  Future<void> _saveAchievement(Achievement achievement) async {
    try {
      await _firestore.collection('achievements').add(achievement.toFirestore());
      debugPrint('✅ 成就已儲存: ${achievement.title}');
    } catch (e) {
      debugPrint('❌ 儲存成就失敗: $e');
    }
  }

  // ========== 獲取成就 ==========

  /// 獲取教練學員的最新成就（未通知的）
  Future<List<Achievement>> getUnnotifiedAchievements() async {
    if (_currentUserId == null) return [];

    try {
      // 先獲取教練的學員列表
      final pairs = await _firestore
          .collection('pairs')
          .where('coachId', isEqualTo: _currentUserId)
          .where('status', isEqualTo: 'active')
          .get();

      final studentIds = pairs.docs
          .map((doc) => doc.data()['traineeId'] as String?)
          .where((id) => id != null)
          .cast<String>()
          .toList();

      if (studentIds.isEmpty) return [];

      // 獲取這些學員的未通知成就
      final achievements = <Achievement>[];
      
      for (final studentId in studentIds) {
        final docs = await _firestore
            .collection('achievements')
            .where('traineeId', isEqualTo: studentId)
            .where('notified', isEqualTo: false)
            .orderBy('achievedAt', descending: true)
            .limit(5)
            .get();

        for (final doc in docs.docs) {
          achievements.add(Achievement.fromFirestore(doc.data(), doc.id));
        }
      }

      // 按時間排序
      achievements.sort((a, b) => b.achievedAt.compareTo(a.achievedAt));

      return achievements;
    } catch (e) {
      debugPrint('❌ 獲取未通知成就失敗: $e');
      return [];
    }
  }

  /// 標記成就為已通知
  Future<void> markAchievementAsNotified(String achievementId) async {
    try {
      await _firestore.collection('achievements').doc(achievementId).update({
        'notified': true,
        'notifiedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ 標記成就失敗: $e');
    }
  }

  // ========== 週報功能 ==========

  /// 生成週報
  Future<WeeklyReport> generateWeeklyReport() async {
    if (_currentUserId == null) {
      return WeeklyReport(
        coachId: '',
        weekStart: DateTime.now(),
        weekEnd: DateTime.now(),
      );
    }

    try {
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 6));
      final weekStartDate = DateTime(weekStart.year, weekStart.month, weekStart.day);
      final weekEndDate = DateTime(weekEnd.year, weekEnd.month, weekEnd.day, 23, 59, 59);

      // 獲取學員列表
      final pairs = await _firestore
          .collection('pairs')
          .where('coachId', isEqualTo: _currentUserId)
          .where('status', isEqualTo: 'active')
          .get();

      final studentIds = pairs.docs
          .map((doc) => doc.data()['traineeId'] as String?)
          .where((id) => id != null)
          .cast<String>()
          .toList();

      final totalStudents = studentIds.length;
      int activeStudents = 0;
      int goalAchievers = 0;
      int needsAttention = 0;
      final studentSummaries = <StudentWeeklySummary>[];

      for (final studentId in studentIds) {
        final summary = await _generateStudentWeeklySummary(
          studentId,
          weekStartDate,
          weekEndDate,
        );
        studentSummaries.add(summary);

        if (summary.completedWorkouts > 0) activeStudents++;
        if (summary.achievedGoal) goalAchievers++;
        if (summary.concerns.isNotEmpty) needsAttention++;
      }

      // 獲取本週成就
      final achievements = <Achievement>[];
      for (final studentId in studentIds) {
        final docs = await _firestore
            .collection('achievements')
            .where('traineeId', isEqualTo: studentId)
            .where('achievedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStartDate))
            .where('achievedAt', isLessThanOrEqualTo: Timestamp.fromDate(weekEndDate))
            .get();

        for (final doc in docs.docs) {
          achievements.add(Achievement.fromFirestore(doc.data(), doc.id));
        }
      }

      return WeeklyReport(
        coachId: _currentUserId!,
        weekStart: weekStartDate,
        weekEnd: weekEndDate,
        totalStudents: totalStudents,
        activeStudents: activeStudents,
        goalAchievers: goalAchievers,
        needsAttentionCount: needsAttention,
        achievements: achievements,
        studentSummaries: studentSummaries,
      );
    } catch (e) {
      debugPrint('❌ 生成週報失敗: $e');
      return WeeklyReport(
        coachId: _currentUserId!,
        weekStart: DateTime.now(),
        weekEnd: DateTime.now(),
      );
    }
  }

  /// 生成學員週摘要
  Future<StudentWeeklySummary> _generateStudentWeeklySummary(
    String traineeId,
    DateTime weekStart,
    DateTime weekEnd,
  ) async {
    try {
      // 獲取學員名稱
      final userDoc = await _firestore.collection('users').doc(traineeId).get();
      final traineeName = userDoc.data()?['displayName'] ?? '學員';

      // 獲取計畫目標
      final plans = await _firestore
          .collection('workoutPlans')
          .where('traineeId', isEqualTo: traineeId)
          .where('status', isEqualTo: 'active')
          .get();

      int targetWorkouts = 0;
      for (final plan in plans.docs) {
        final days = plan.data()['days'];
        if (days is List) {
          targetWorkouts += days.length;
        } else if (days is Map) {
          targetWorkouts += days.length;
        }
      }

      // 獲取本週完成
      final completions = await _firestore
          .collection('workoutCompletions')
          .where('userId', isEqualTo: traineeId)
          .where('actualDate', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
          .where('actualDate', isLessThanOrEqualTo: Timestamp.fromDate(weekEnd))
          .get();

      final completedWorkouts = completions.docs.length;
      int onTimeCount = 0;

      for (final doc in completions.docs) {
        if (doc.data()['isOnSchedule'] == true) {
          onTimeCount++;
        }
      }

      final onTimeRate = completedWorkouts > 0 ? onTimeCount / completedWorkouts : 0.0;
      final achievedGoal = targetWorkouts > 0 && completedWorkouts >= targetWorkouts;

      // 生成亮點和關注點
      final highlights = <String>[];
      final concerns = <String>[];

      if (achievedGoal) {
        highlights.add('達成本週目標 ✅');
      }
      if (onTimeRate >= 0.8) {
        highlights.add('按時率優秀 ${(onTimeRate * 100).toStringAsFixed(0)}%');
      }
      if (completedWorkouts == 0) {
        concerns.add('本週尚未訓練');
      } else if (targetWorkouts > 0 && completedWorkouts < targetWorkouts * 0.5) {
        concerns.add('完成率偏低 ${(completedWorkouts / targetWorkouts * 100).toStringAsFixed(0)}%');
      }

      return StudentWeeklySummary(
        traineeId: traineeId,
        traineeName: traineeName,
        completedWorkouts: completedWorkouts,
        targetWorkouts: targetWorkouts,
        onTimeRate: onTimeRate,
        achievedGoal: achievedGoal,
        highlights: highlights,
        concerns: concerns,
      );
    } catch (e) {
      debugPrint('❌ 生成學員週摘要失敗: $e');
      return StudentWeeklySummary(
        traineeId: traineeId,
        traineeName: '學員',
      );
    }
  }
}