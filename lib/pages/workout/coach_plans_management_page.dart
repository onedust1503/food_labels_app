// lib/pages/workout/coach_plans_management_page.dart
// 🎯 教練端訓練計畫管理 v2.1
// ✨ 明亮版莫蘭迪風格
// ✅ 從 workoutCompletions 頂層集合讀取進度
// ✅ 混合模式標記（綠色按時/黃色補做）
// ✅ 真實完成率統計
// ✅ v2.1: 整合新的計畫詳情頁面

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../coach/coach_plan_detail_page.dart'; // 🔥 新增 import

class CoachPlansManagementPage extends StatefulWidget {
  const CoachPlansManagementPage({super.key});

  @override
  State<CoachPlansManagementPage> createState() => _CoachPlansManagementPageState();
}

class _CoachPlansManagementPageState extends State<CoachPlansManagementPage>
    with TickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late TabController _tabController;
  
  // 🔥 動畫控制
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    _animationController = AnimationController(
      duration: AppAnimations.normal,
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AppColors.error : AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentCoachId = _auth.currentUser?.uid;
    
    if (currentCoachId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('訓練計畫管理')),
        body: const Center(child: Text('請先登入')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          '訓練計畫管理',
          style: AppTextStyles.h3.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.secondaryGradient,
          ),
        ),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          indicatorSize: TabBarIndicatorSize.label,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: AppTextStyles.label.copyWith(
            fontWeight: FontWeight.bold,
          ),
          tabs: const [
            Tab(
              icon: Icon(Icons.play_circle_outline, size: 20),
              text: '進行中',
            ),
            Tab(
              icon: Icon(Icons.archive_outlined, size: 20),
              text: '已結束',
            ),
          ],
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildPlansList(isActive: true, coachId: currentCoachId),
            _buildPlansList(isActive: false, coachId: currentCoachId),
          ],
        ),
      ),
    );
  }

  // 📋 計畫列表（移除 orderBy 避免索引問題）
  Widget _buildPlansList({required bool isActive, required String coachId}) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('workoutPlans')
          .where('coachId', isEqualTo: coachId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.coach),
            ),
          );
        }

        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(isActive);
        }

        // 🔥 手動排序並過濾
        final allPlans = snapshot.data!.docs.toList();
        allPlans.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aDate = _getDateTime(aData['createdAt']);
          final bDate = _getDateTime(bData['createdAt']);
          return bDate.compareTo(aDate);
        });

        // 過濾進行中/已完成
        final plans = allPlans.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status'] ?? 'active';
          
          DateTime? endDate;
          try {
            if (data['endDate'] != null) {
              endDate = _getDateTime(data['endDate']);
            }
          } catch (e) {
            if (kDebugMode) debugPrint('解析結束日期失敗: $e');
          }
          
          final isExpired = endDate != null && endDate.isBefore(DateTime.now());
          
          if (isActive) {
            return status != 'completed' && !isExpired;
          } else {
            return status == 'completed' || isExpired;
          }
        }).toList();

        if (plans.isEmpty) {
          return _buildEmptyState(isActive);
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          color: AppColors.coach,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: plans.length,
            itemBuilder: (context, index) {
              return _buildPlanCard(plans[index], isActive: isActive);
            },
          ),
        );
      },
    );
  }

  // 🎨 錯誤狀態
  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.error,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '載入失敗',
            style: AppTextStyles.h4.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // 🎨 空狀態
  Widget _buildEmptyState(bool isActive) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: (isActive ? AppColors.coach : AppColors.textTertiary).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isActive ? Icons.assignment_outlined : Icons.archive_outlined,
              size: 64,
              color: isActive ? AppColors.coach : AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isActive ? '尚無進行中的計畫' : '尚無已結束的計畫',
            style: AppTextStyles.h4.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (isActive) ...[
            const SizedBox(height: 8),
            Text(
              '創建新計畫來開始指導學員',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 🎴 計畫卡片 - 莫蘭迪風格
  Widget _buildPlanCard(DocumentSnapshot doc, {required bool isActive}) {
    final data = doc.data() as Map<String, dynamic>;
    final planId = doc.id;
    final planName = data['planName'] ?? '未命名計畫';
    final traineeId = data['traineeId'] as String;
    final description = data['description'] as String?;
    
    // 解析日期
    DateTime startDate = _getDateTime(data['startDate'] ?? data['createdAt']);
    DateTime? endDate;
    if (data['endDate'] != null) {
      endDate = _getDateTime(data['endDate']);
    }
    
    // 計算訓練天數和動作數
    final daysData = data['days'];
    List<Map<String, dynamic>> daysList = [];
    
    if (daysData is List) {
      daysList = daysData.map((d) => d as Map<String, dynamic>).toList();
    } else if (daysData is Map) {
      daysList = (daysData as Map<String, dynamic>).values
          .map((d) => d as Map<String, dynamic>)
          .toList();
    }
    
    final totalExercises = daysList.fold<int>(
      0,
      (sum, day) {
        final exercises = day['exercises'];
        if (exercises is List) {
          return sum + exercises.length;
        }
        return sum;
      },
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppShadows.medium,
        border: Border.all(
          color: isActive 
              ? AppColors.coach.withOpacity(0.2) 
              : AppColors.textTertiary.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _viewPlanDetail(planId, data, traineeId),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🎯 標題列
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: isActive
                            ? AppColors.secondaryGradient
                            : LinearGradient(
                                colors: [
                                  AppColors.textTertiary,
                                  AppColors.textTertiary.withOpacity(0.7),
                                ],
                              ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: AppShadows.small,
                      ),
                      child: Icon(
                        isActive ? Icons.fitness_center : Icons.archive,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            planName,
                            style: AppTextStyles.h4.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          // 學員名稱
                          _buildTraineeChip(traineeId),
                        ],
                      ),
                    ),
                    // 🔥 v2.2: 進行中和已結束都顯示選單
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: AppColors.textSecondary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      onSelected: (value) {
                        if (value == 'delete') {
                          _deletePlan(planId, planName);
                        } else if (value == 'end') {
                          _markAsEnded(planId, planName);
                        } else if (value == 'reactivate') {
                          _reactivatePlan(planId, planName);
                        }
                      },
                      itemBuilder: (context) => isActive
                          ? [
                              // 進行中：可標記結束、刪除
                              PopupMenuItem(
                                value: 'end',
                                child: Row(
                                  children: [
                                    Icon(Icons.archive, 
                                      color: AppColors.warning, size: 20),
                                    const SizedBox(width: 12),
                                    const Text('標記為已結束'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, 
                                      color: AppColors.error, size: 20),
                                    const SizedBox(width: 12),
                                    const Text('刪除計畫'),
                                  ],
                                ),
                              ),
                            ]
                          : [
                              // 已結束：可重新啟用、刪除
                              PopupMenuItem(
                                value: 'reactivate',
                                child: Row(
                                  children: [
                                    Icon(Icons.play_circle, 
                                      color: AppColors.success, size: 20),
                                    const SizedBox(width: 12),
                                    const Text('重新啟用'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, 
                                      color: AppColors.error, size: 20),
                                    const SizedBox(width: 12),
                                    const Text('刪除計畫'),
                                  ],
                                ),
                              ),
                            ],
                    ),
                  ],
                ),
                
                // 📝 說明
                if (description != null && description.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.info.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, 
                          size: 16, color: AppColors.info),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            description,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.info,
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 16),
                
                // 📊 統計資訊
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      _buildStatChip(
                        Icons.calendar_today, 
                        '${daysList.length} 天',
                        AppColors.primary,
                      ),
                      const SizedBox(width: 12),
                      _buildStatChip(
                        Icons.fitness_center, 
                        '$totalExercises 動作',
                        AppColors.warning,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 📅 日期範圍
                Row(
                  children: [
                    Icon(Icons.event_available, 
                      size: 16, color: AppColors.textTertiary),
                    const SizedBox(width: 8),
                    Text(
                      '${_formatDate(startDate)} - ${endDate != null ? _formatDate(endDate) : "持續中"}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    // 🔥 v2.2: 已結束標籤
                    if (!isActive) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.textTertiary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '已結束',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textTertiary,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                // ✅ 進度區（只在進行中顯示）
                if (isActive) ...[
                  const SizedBox(height: 16),
                  _buildProgressSection(planId, traineeId, daysList.length),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🏷️ 學員名稱標籤
  Widget _buildTraineeChip(String traineeId) {
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('users').doc(traineeId).get(),
      builder: (context, snapshot) {
        String traineeName = '載入中...';
        if (snapshot.hasData && snapshot.data!.exists) {
          final userData = snapshot.data!.data() as Map<String, dynamic>;
          traineeName = userData['displayName'] ?? '未命名學員';
        } else if (snapshot.connectionState == ConnectionState.done) {
          traineeName = '未知學員';
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person, size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                traineeName,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 🏷️ 統計標籤
  Widget _buildStatChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppTextStyles.label.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // 📊 進度區（從 workoutCompletions 讀取）
  Widget _buildProgressSection(String planId, String traineeId, int totalDays) {
    return StreamBuilder<QuerySnapshot>(
      // 🔥 關鍵：從 workoutCompletions 頂層集合讀取
      stream: _firestore
          .collection('workoutCompletions')
          .where('planId', isEqualTo: planId)
          .where('userId', isEqualTo: traineeId)
          .snapshots(),
      builder: (context, snapshot) {
        int totalCompletions = 0;
        int onScheduleCount = 0;
        int makeupCount = 0;

        if (snapshot.hasData) {
          totalCompletions = snapshot.data!.docs.length;
          
          for (final doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['isOnSchedule'] == true) {
              onScheduleCount++;
            } else {
              makeupCount++;
            }
          }
        }

        final progress = totalDays > 0
            ? (totalCompletions / (totalDays * 4)).clamp(0.0, 1.0) // 假設4週
            : 0.0;

        final onScheduleRate = totalCompletions > 0
            ? (onScheduleCount / totalCompletions * 100).round()
            : 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 標題與統計
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '完成進度',
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Row(
                  children: [
                    // 按時完成
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$onScheduleCount',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 補做完成
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.warning,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$makeupCount',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.warning,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            
            // 進度條
            Stack(
              children: [
                // 背景
                Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                // 按時完成（綠色）
                FractionallySizedBox(
                  widthFactor: progress.clamp(0.0, 1.0),
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      gradient: AppColors.successGradient,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.success.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // 按時率
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '總完成 $totalCompletions 次',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getOnScheduleColor(onScheduleRate).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '按時率 $onScheduleRate%',
                    style: AppTextStyles.caption.copyWith(
                      color: _getOnScheduleColor(onScheduleRate),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Color _getOnScheduleColor(int rate) {
    if (rate >= 80) return AppColors.success;
    if (rate >= 50) return AppColors.warning;
    return AppColors.error;
  }

  // 👁️ 查看計畫詳情 - 🔥 v2.1 改用新的詳情頁面
  Future<void> _viewPlanDetail(
    String planId, 
    Map<String, dynamic> data, 
    String traineeId,
  ) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CoachPlanDetailPage(
          planId: planId,
          planData: data,
          traineeId: traineeId,
        ),
      ),
    );
  }

  // ✅ 標記完成
  // 🔥 v2.2: 標記為已結束
  Future<void> _markAsEnded(String planId, String planName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.archive, color: AppColors.warning),
            ),
            const SizedBox(width: 12),
            const Text('標記為已結束'),
          ],
        ),
        content: Text('確定要將「$planName」標記為已結束嗎？\n\n計畫將移至「已結束」分類，之後可以重新啟用。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              '取消',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('確定結束'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestore.collection('workoutPlans').doc(planId).update({
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
        });
        _showSnackBar('計畫已結束');
      } catch (e) {
        _showSnackBar('操作失敗：$e', isError: true);
      }
    }
  }

  // 🔥 v2.2: 重新啟用計畫
  Future<void> _reactivatePlan(String planId, String planName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.play_circle, color: AppColors.success),
            ),
            const SizedBox(width: 12),
            const Text('重新啟用'),
          ],
        ),
        content: Text('確定要重新啟用「$planName」嗎？\n\n計畫將移回「進行中」分類。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              '取消',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('重新啟用'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestore.collection('workoutPlans').doc(planId).update({
          'status': 'active',
          'completedAt': FieldValue.delete(),
        });
        _showSnackBar('計畫已重新啟用！');
      } catch (e) {
        _showSnackBar('操作失敗：$e', isError: true);
      }
    }
  }

  // 🗑️ 刪除計畫
  Future<void> _deletePlan(String planId, String planName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.warning, color: AppColors.error),
            ),
            const SizedBox(width: 12),
            const Text('確認刪除'),
          ],
        ),
        content: Text('確定要刪除「$planName」嗎？\n\n此操作無法復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              '取消',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestore.collection('workoutPlans').doc(planId).delete();
        _showSnackBar('已刪除計畫');
      } catch (e) {
        _showSnackBar('刪除失敗：$e', isError: true);
      }
    }
  }

  // 🔧 輔助方法
  DateTime _getDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    } else if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy/MM/dd').format(date);
  }
}

// ✅ PlanDetailSheet 已移除，改用 CoachPlanDetailPage