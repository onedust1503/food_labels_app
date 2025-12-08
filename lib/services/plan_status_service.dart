// lib/services/plan_status_service.dart
// 🔧 計畫狀態管理服務 v1.0
// ✅ 自動檢查計畫到期
// ✅ 自動更新計畫狀態
// ✅ 防呆機制

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/workout_model.dart';

/// 計畫狀態枚舉
enum PlanStatusType {
  /// 進行中
  active,
  
  /// 已完成（手動標記或到期自動完成）
  completed,
  
  /// 已暫停
  paused,
  
  /// 已取消/刪除
  cancelled,
  
  /// 未開始（開始日期還沒到）
  notStarted,
  
  /// 已過期（結束日期已過，自動標記）
  expired,
}

/// 計畫狀態資訊
class PlanStatusInfo {
  final PlanStatusType status;
  final String label;
  final String description;
  final bool canExecute;       // 是否可以執行訓練
  final bool canEdit;          // 是否可以編輯
  final bool shouldAutoUpdate; // 是否需要自動更新 Firebase
  
  const PlanStatusInfo({
    required this.status,
    required this.label,
    required this.description,
    required this.canExecute,
    required this.canEdit,
    this.shouldAutoUpdate = false,
  });
  
  /// 進行中
  static const active = PlanStatusInfo(
    status: PlanStatusType.active,
    label: '進行中',
    description: '計畫正在執行中',
    canExecute: true,
    canEdit: true,
  );
  
  /// 已完成
  static const completed = PlanStatusInfo(
    status: PlanStatusType.completed,
    label: '已完成',
    description: '計畫已完成',
    canExecute: false,
    canEdit: false,
  );
  
  /// 已暫停
  static const paused = PlanStatusInfo(
    status: PlanStatusType.paused,
    label: '已暫停',
    description: '計畫已暫停，可以恢復',
    canExecute: false,
    canEdit: true,
  );
  
  /// 已取消
  static const cancelled = PlanStatusInfo(
    status: PlanStatusType.cancelled,
    label: '已取消',
    description: '計畫已取消',
    canExecute: false,
    canEdit: false,
  );
  
  /// 未開始
  static const notStarted = PlanStatusInfo(
    status: PlanStatusType.notStarted,
    label: '未開始',
    description: '計畫尚未開始',
    canExecute: false,
    canEdit: true,
  );
  
  /// 已過期（需要自動更新）
  static const expired = PlanStatusInfo(
    status: PlanStatusType.expired,
    label: '已結束',
    description: '計畫已到期結束',
    canExecute: false,
    canEdit: false,
    shouldAutoUpdate: true,
  );
}

/// 計畫狀態管理服務
class PlanStatusService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  String? get _currentUserId => _auth.currentUser?.uid;
  
  // ============================================================
  // 🔥 狀態檢查
  // ============================================================
  
  /// 檢查計畫狀態（根據日期和 Firebase 狀態）
  PlanStatusInfo checkPlanStatus(WorkoutPlanModel plan) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // 1. 先檢查 Firebase 中的狀態
    final firebaseStatus = plan.status?.toLowerCase() ?? 'active';
    
    switch (firebaseStatus) {
      case 'completed':
        return PlanStatusInfo.completed;
      case 'paused':
        return PlanStatusInfo.paused;
      case 'cancelled':
        return PlanStatusInfo.cancelled;
    }
    
    // 2. 檢查開始日期（是否還沒開始）
    final startDate = DateTime(
      plan.startDate.year,
      plan.startDate.month,
      plan.startDate.day,
    );
    
    if (today.isBefore(startDate)) {
      return PlanStatusInfo.notStarted;
    }
    
    // 3. 檢查結束日期（是否已過期）
    if (plan.endDate != null) {
      final endDate = DateTime(
        plan.endDate!.year,
        plan.endDate!.month,
        plan.endDate!.day,
      );
      
      // 結束日期已過 → 自動標記為已結束
      if (today.isAfter(endDate)) {
        return PlanStatusInfo.expired;
      }
    }
    
    // 4. 正常進行中
    return PlanStatusInfo.active;
  }
  
  /// 檢查是否可以執行訓練
  bool canExecutePlan(WorkoutPlanModel plan) {
    final statusInfo = checkPlanStatus(plan);
    return statusInfo.canExecute;
  }
  
  /// 獲取不能執行的原因
  String? getExecutionBlockReason(WorkoutPlanModel plan) {
    final statusInfo = checkPlanStatus(plan);
    
    if (statusInfo.canExecute) return null;
    
    switch (statusInfo.status) {
      case PlanStatusType.completed:
        return '此計畫已完成，無法再執行訓練';
      case PlanStatusType.paused:
        return '此計畫已暫停，請先恢復計畫';
      case PlanStatusType.cancelled:
        return '此計畫已取消';
      case PlanStatusType.notStarted:
        final startDate = plan.startDate;
        return '此計畫尚未開始，開始日期：${startDate.month}/${startDate.day}';
      case PlanStatusType.expired:
        return '此計畫已到期結束';
      default:
        return null;
    }
  }
  
  // ============================================================
  // 🔥 自動更新狀態
  // ============================================================
  
  /// 檢查並自動更新單個計畫狀態
  /// 返回是否有更新
  Future<bool> checkAndUpdatePlanStatus(WorkoutPlanModel plan) async {
    if (plan.id == null) return false;
    
    final statusInfo = checkPlanStatus(plan);
    
    // 如果需要自動更新（已過期）
    if (statusInfo.shouldAutoUpdate) {
      try {
        await _firestore.collection('workoutPlans').doc(plan.id).update({
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
          'autoCompletedReason': 'expired', // 記錄自動完成原因
        });
        
        if (kDebugMode) {
          debugPrint('✅ 計畫自動標記為完成: ${plan.planName} (已到期)');
        }
        
        return true;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ 自動更新計畫狀態失敗: $e');
        }
      }
    }
    
    return false;
  }
  
  /// 批量檢查並更新計畫狀態
  /// 返回更新的計畫數量
  Future<int> checkAndUpdateAllPlansStatus(List<WorkoutPlanModel> plans) async {
    int updatedCount = 0;
    
    for (final plan in plans) {
      final updated = await checkAndUpdatePlanStatus(plan);
      if (updated) updatedCount++;
    }
    
    if (kDebugMode && updatedCount > 0) {
      debugPrint('📊 共自動更新 $updatedCount 個計畫狀態');
    }
    
    return updatedCount;
  }
  
  // ============================================================
  // 🔥 手動狀態操作
  // ============================================================
  
  /// 暫停計畫
  Future<void> pausePlan(String planId) async {
    if (_currentUserId == null) throw Exception('用戶未登入');
    
    await _firestore.collection('workoutPlans').doc(planId).update({
      'status': 'paused',
      'pausedAt': FieldValue.serverTimestamp(),
    });
    
    if (kDebugMode) {
      debugPrint('⏸️ 計畫已暫停: $planId');
    }
  }
  
  /// 恢復計畫
  Future<void> resumePlan(String planId) async {
    if (_currentUserId == null) throw Exception('用戶未登入');
    
    await _firestore.collection('workoutPlans').doc(planId).update({
      'status': 'active',
      'resumedAt': FieldValue.serverTimestamp(),
    });
    
    if (kDebugMode) {
      debugPrint('▶️ 計畫已恢復: $planId');
    }
  }
  
  /// 手動完成計畫
  Future<void> completePlan(String planId) async {
    if (_currentUserId == null) throw Exception('用戶未登入');
    
    await _firestore.collection('workoutPlans').doc(planId).update({
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
      'autoCompletedReason': null, // 清除自動完成標記
    });
    
    if (kDebugMode) {
      debugPrint('✅ 計畫已手動完成: $planId');
    }
  }
  
  /// 取消計畫
  Future<void> cancelPlan(String planId) async {
    if (_currentUserId == null) throw Exception('用戶未登入');
    
    await _firestore.collection('workoutPlans').doc(planId).update({
      'status': 'cancelled',
      'cancelledAt': FieldValue.serverTimestamp(),
    });
    
    if (kDebugMode) {
      debugPrint('❌ 計畫已取消: $planId');
    }
  }
  
  // ============================================================
  // 🔥 計畫到期提醒（可選功能）
  // ============================================================
  
  /// 檢查計畫是否即將到期（7天內）
  bool isPlanExpiringSoon(WorkoutPlanModel plan, {int daysThreshold = 7}) {
    if (plan.endDate == null) return false;
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endDate = DateTime(
      plan.endDate!.year,
      plan.endDate!.month,
      plan.endDate!.day,
    );
    
    final daysRemaining = endDate.difference(today).inDays;
    return daysRemaining >= 0 && daysRemaining <= daysThreshold;
  }
  
  /// 獲取計畫剩餘天數
  int? getDaysRemaining(WorkoutPlanModel plan) {
    if (plan.endDate == null) return null;
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endDate = DateTime(
      plan.endDate!.year,
      plan.endDate!.month,
      plan.endDate!.day,
    );
    
    return endDate.difference(today).inDays;
  }
  
  /// 獲取計畫剩餘天數文字
  String getDaysRemainingText(WorkoutPlanModel plan) {
    final days = getDaysRemaining(plan);
    
    if (days == null) return '持續進行';
    if (days < 0) return '已結束';
    if (days == 0) return '今天結束';
    if (days == 1) return '明天結束';
    if (days <= 7) return '剩餘 $days 天';
    return '剩餘 $days 天';
  }
}