// lib/pages/coach/coach_plan_detail_page.dart
// 🎯 教練端計畫詳情頁 v1.5
// ✅ v1.4 所有功能
// ✅ v1.5: 整合編輯頁 v1.1，移除舊的調整彈窗

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../models/completion_status.dart';
import '../../utils/workout_date_helper.dart';
import 'coach_plan_edit_page.dart';

class CoachPlanDetailPage extends StatefulWidget {
  final String planId;
  final Map<String, dynamic> planData;
  final String traineeId;

  const CoachPlanDetailPage({
    super.key,
    required this.planId,
    required this.planData,
    required this.traineeId,
  });

  @override
  State<CoachPlanDetailPage> createState() => _CoachPlanDetailPageState();
}

class _CoachPlanDetailPageState extends State<CoachPlanDetailPage>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late TabController _tabController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // 使用 state 管理 planData
  late Map<String, dynamic> _planData;

  // 學員資料
  String _traineeName = '載入中...';
  
  // 週統計數據
  Map<String, dynamic> _weeklyStats = {};
  
  // 備註輸入
  final TextEditingController _noteController = TextEditingController();
  bool _isAddingNote = false;

  // 用於強制刷新 FutureBuilder
  int _refreshKey = 0;

  @override
  void initState() {
    super.initState();
    
    _planData = Map<String, dynamic>.from(widget.planData);
    
    _tabController = TabController(length: 2, vsync: this);
    
    _animationController = AnimationController(
      duration: AppAnimations.normal,
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    _animationController.forward();
    _loadTraineeName();
    _loadWeeklyStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadTraineeName() async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(widget.traineeId)
          .get();
      
      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _traineeName = data['displayName'] ?? '未命名學員';
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('載入學員名稱失敗: $e');
    }
  }

  Future<void> _loadWeeklyStats() async {
    try {
      final weekStart = WorkoutDateHelper.getWeekStart();
      final weekEnd = WorkoutDateHelper.getWeekEnd();
      
      final snapshot = await _firestore
          .collection('workoutCompletions')
          .where('planId', isEqualTo: widget.planId)
          .where('userId', isEqualTo: widget.traineeId)
          .where('actualDate', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
          .where('actualDate', isLessThanOrEqualTo: Timestamp.fromDate(weekEnd))
          .get();
      
      int totalCompleted = snapshot.docs.length;
      int onTimeCount = 0;
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['isOnSchedule'] == true) {
          onTimeCount++;
        }
      }
      
      final daysData = _planData['days'];
      int totalDays = 0;
      if (daysData is List) {
        totalDays = daysData.length;
      } else if (daysData is Map) {
        totalDays = daysData.length;
      }
      
      if (mounted) {
        setState(() {
          _weeklyStats = {
            'totalDays': totalDays,
            'completedCount': totalCompleted,
            'onTimeCount': onTimeCount,
            'completionRate': totalDays > 0 ? totalCompleted / totalDays : 0.0,
            'onTimeRate': totalCompleted > 0 ? onTimeCount / totalCompleted : 0.0,
          };
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('載入週統計失敗: $e');
    }
  }

  Future<void> _reloadPlanData() async {
    try {
      final doc = await _firestore
          .collection('workoutPlans')
          .doc(widget.planId)
          .get();
      
      if (doc.exists && mounted) {
        setState(() {
          _planData = doc.data() as Map<String, dynamic>;
          _refreshKey++;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('重新載入計畫數據失敗: $e');
    }
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

  /// 進入編輯頁面
  Future<void> _goToEditPage() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => CoachPlanEditPage(
          planId: widget.planId,
          planData: _planData,
          traineeId: widget.traineeId,
          traineeName: _traineeName,
        ),
      ),
    );

    // 如果編輯完成，更新數據
    if (result != null && result['updated'] == true) {
      if (result['days'] != null) {
        setState(() {
          _planData['days'] = result['days'];
          if (result['version'] != null) {
            _planData['version'] = result['version'];
          }
          _refreshKey++;
        });
      } else {
        await _reloadPlanData();
      }
      await _loadWeeklyStats();
      
      final version = result['version'];
      _showSnackBar('計畫已更新${version != null ? ' (v$version)' : ''}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final planName = _planData['planName'] ?? '未命名計畫';
    final version = _planData['version'] as int?;
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              planName,
              style: AppTextStyles.h4.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (version != null)
              Text(
                'v$version',
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white70,
                ),
              ),
          ],
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
        actions: [
          // 編輯按鈕
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: _goToEditPage,
            tooltip: '編輯計畫',
          ),
        ],
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
              icon: Icon(Icons.calendar_today, size: 20),
              text: '本週進度',
            ),
            Tab(
              icon: Icon(Icons.note_alt, size: 20),
              text: '教練備註',
            ),
          ],
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            _buildTraineeInfoBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildWeeklyProgressTab(),
                  _buildCoachNotesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 學員資訊條
  Widget _buildTraineeInfoBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: AppShadows.small,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.person, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _traineeName,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '學員',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          // 編輯計畫按鈕（主要）
          _buildQuickActionButton(
            icon: Icons.edit,
            label: '編輯',
            color: AppColors.coach,
            onTap: _goToEditPage,
          ),
          const SizedBox(width: 8),
          // 訊息按鈕
          _buildQuickActionButton(
            icon: Icons.chat_bubble_outline,
            label: '訊息',
            color: AppColors.primary,
            onTap: () => _showSnackBar('即將開放訊息功能'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================
  // 📊 Tab 1: 本週進度
  // ===========================================================

  Widget _buildWeeklyProgressTab() {
    final daysData = _planData['days'];
    List<Map<String, dynamic>> daysList = [];
    
    if (daysData is List) {
      daysList = daysData.map((d) => Map<String, dynamic>.from(d as Map)).toList();
    } else if (daysData is Map) {
      daysList = (daysData as Map<String, dynamic>).values
          .map((d) => Map<String, dynamic>.from(d as Map))
          .toList();
    }

    final planDays = daysList
        .map((d) => d['dayOfWeek']?.toString() ?? '')
        .where((d) => d.isNotEmpty)
        .toList();

    return FutureBuilder<WeeklyCompletionSummary>(
      key: ValueKey(_refreshKey),
      future: _getWeeklyPlanProgress(
        planId: widget.planId,
        planDays: planDays,
        userId: widget.traineeId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.coach),
            ),
          );
        }

        final summary = snapshot.data ?? WeeklyCompletionSummary(
          planId: widget.planId,
          planName: '',
          totalDays: planDays.length,
        );

        return RefreshIndicator(
          onRefresh: () async {
            await _reloadPlanData();
            await _loadWeeklyStats();
          },
          color: AppColors.coach,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWeeklySummaryCard(summary),
                const SizedBox(height: 20),
                
                Row(
                  children: [
                    Text(
                      '本週訓練安排',
                      style: AppTextStyles.h4.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _goToEditPage,
                      icon: Icon(Icons.edit, size: 16, color: AppColors.coach),
                      label: Text(
                        '編輯計畫',
                        style: TextStyle(color: AppColors.coach),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                ...daysList.asMap().entries.map((entry) {
                  final index = entry.key;
                  final day = entry.value;
                  final dayOfWeek = day['dayOfWeek']?.toString() ?? '';
                  final normalizedDay = WorkoutDateHelper.normalizeToChinese(dayOfWeek);
                  
                  final dayInfo = summary.dayProgress.firstWhere(
                    (d) => d.dayOfWeek == normalizedDay,
                    orElse: () => DayCompletionInfo(
                      dayOfWeek: normalizedDay,
                      date: DateTime.now(),
                      hasPlannedWorkout: true,
                      status: CompletionStatusType.pending,
                    ),
                  );
                  
                  return _buildDayCard(day, dayInfo, index);
                }),
                
                const SizedBox(height: 100),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<WeeklyCompletionSummary> _getWeeklyPlanProgress({
    required String planId,
    required List<String> planDays,
    required String userId,
  }) async {
    try {
      final weekStart = WorkoutDateHelper.getWeekStart();
      final weekEnd = WorkoutDateHelper.getWeekEnd();
      
      final snapshot = await _firestore
          .collection('workoutCompletions')
          .where('planId', isEqualTo: planId)
          .where('userId', isEqualTo: userId)
          .where('actualDate', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
          .where('actualDate', isLessThanOrEqualTo: Timestamp.fromDate(weekEnd))
          .get();
      
      final Map<String, WorkoutCompletionRecord> completionMap = {};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final record = WorkoutCompletionRecord.fromFirestore(data, doc.id);
        final normalizedDay = WorkoutDateHelper.normalizeToChinese(record.planDayOfWeek);
        completionMap[normalizedDay] = record;
      }
      
      int completedOnTime = 0;
      int completedMakeup = 0;
      int completedEarly = 0;
      int overdue = 0;
      int pending = 0;
      int dueToday = 0;
      
      final List<DayCompletionInfo> dayProgress = [];
      
      for (final dayStr in planDays) {
        final normalizedDay = WorkoutDateHelper.normalizeToChinese(dayStr);
        final plannedDate = WorkoutDateHelper.getDateForWeekdayString(normalizedDay);
        
        if (plannedDate == null) continue;
        
        final record = completionMap[normalizedDay];
        CompletionStatusType status;
        
        if (record != null) {
          status = record.statusType;
        } else {
          if (WorkoutDateHelper.isToday(plannedDate)) {
            status = CompletionStatusType.dueToday;
          } else if (WorkoutDateHelper.isPast(plannedDate)) {
            status = CompletionStatusType.overdue;
          } else {
            status = CompletionStatusType.pending;
          }
        }
        
        switch (status) {
          case CompletionStatusType.onTime:
            completedOnTime++;
            break;
          case CompletionStatusType.makeup:
            completedMakeup++;
            break;
          case CompletionStatusType.early:
            completedEarly++;
            break;
          case CompletionStatusType.overdue:
            overdue++;
            break;
          case CompletionStatusType.pending:
            pending++;
            break;
          case CompletionStatusType.dueToday:
            dueToday++;
            break;
        }
        
        dayProgress.add(DayCompletionInfo(
          dayOfWeek: normalizedDay,
          date: plannedDate,
          hasPlannedWorkout: true,
          status: status,
          completionRecord: record,
        ));
      }
      
      return WeeklyCompletionSummary(
        planId: planId,
        planName: _planData['planName'] ?? '',
        totalDays: planDays.length,
        completedOnTime: completedOnTime,
        completedMakeup: completedMakeup,
        completedEarly: completedEarly,
        overdue: overdue,
        pending: pending,
        dueToday: dueToday,
        dayProgress: dayProgress,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('獲取週進度失敗: $e');
      return WeeklyCompletionSummary(
        planId: planId,
        planName: '',
        totalDays: planDays.length,
      );
    }
  }

  Widget _buildWeeklySummaryCard(WeeklyCompletionSummary summary) {
    final completionRate = summary.completionRate;
    final onTimeRate = summary.onTimeRate;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.medium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: AppColors.secondaryGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.analytics, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '本週完成度',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    '${(completionRate * 100).toStringAsFixed(0)}%',
                    style: AppTextStyles.h2.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.getProgressColor(completionRate),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '按時率',
                    style: AppTextStyles.caption,
                  ),
                  Text(
                    '${(onTimeRate * 100).toStringAsFixed(0)}%',
                    style: AppTextStyles.h4.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _getOnTimeRateColor(onTimeRate * 100),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: completionRate,
              backgroundColor: AppColors.divider,
              valueColor: AlwaysStoppedAnimation<Color>(
                AppColors.getProgressColor(completionRate),
              ),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 16),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                '${summary.completedOnTime + summary.completedEarly}',
                '準時完成',
                AppColors.success,
                Icons.check_circle,
              ),
              _buildStatItem(
                '${summary.completedMakeup}',
                '補做完成',
                AppColors.warning,
                Icons.update,
              ),
              _buildStatItem(
                '${summary.overdue}',
                '待補做',
                AppColors.error,
                Icons.schedule,
              ),
              _buildStatItem(
                '${summary.pending + summary.dueToday}',
                '待完成',
                AppColors.textTertiary,
                Icons.pending_actions,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, Color color, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: AppTextStyles.h4.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }

  Color _getOnTimeRateColor(double rate) {
    if (rate >= 80) return AppColors.success;
    if (rate >= 50) return AppColors.warning;
    return AppColors.error;
  }

  Widget _buildDayCard(
    Map<String, dynamic> day, 
    DayCompletionInfo dayInfo,
    int index,
  ) {
    final dayOfWeek = day['dayOfWeek']?.toString() ?? '';
    final normalizedDay = WorkoutDateHelper.normalizeToChinese(dayOfWeek);
    final exercises = day['exercises'];
    List<Map<String, dynamic>> exerciseList = [];
    
    if (exercises is List) {
      exerciseList = exercises.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }

    final status = dayInfo.status != null 
        ? CompletionStatus.fromType(dayInfo.status!)
        : CompletionStatus.fromType(CompletionStatusType.pending);
    final isCompleted = status.isCompleted;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: status.color.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: AppShadows.small,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: status.backgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(status.icon, color: status.color, size: 24),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  normalizedDay,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: status.backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status.shortLabel,
                  style: AppTextStyles.caption.copyWith(
                    color: status.color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${exerciseList.length} 個動作',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          children: [
            if (isCompleted && dayInfo.completionRecord != null)
              _buildCompletionDetails(dayInfo.completionRecord!),
            
            ...exerciseList.asMap().entries.map((entry) {
              final exerciseIndex = entry.key;
              final exercise = entry.value;
              return _buildExerciseItem(exercise, exerciseIndex, status.color);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionDetails(WorkoutCompletionRecord record) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.success.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.success, size: 18),
              const SizedBox(width: 8),
              Text(
                '完成記錄',
                style: AppTextStyles.label.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (record.actualDate != null)
                Text(
                  DateFormat('MM/dd HH:mm').format(record.actualDate!),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildDetailChip(Icons.timer, '${record.duration} 分鐘'),
              _buildDetailChip(Icons.local_fire_department, 
                '${record.calories.toStringAsFixed(0)} 卡'),
              _buildDetailChip(Icons.repeat, '${record.setCount} 組'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          text,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildExerciseItem(
    Map<String, dynamic> exercise, 
    int index,
    Color accentColor,
  ) {
    final name = exercise['name'] ?? '未命名運動';
    final type = exercise['type']?.toString() ?? '';
    final sets = exercise['sets'];
    final reps = exercise['reps'];
    final weight = exercise['weight'];
    final categoryColor = _getCategoryColor(type);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: categoryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: categoryColor.withOpacity(0.15),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: categoryColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: AppTextStyles.caption.copyWith(
                  color: categoryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (sets != null && reps != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '$sets 組 × $reps 次',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                      if (weight != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${weight}kg',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (type.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: categoryColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                type,
                style: AppTextStyles.caption.copyWith(
                  color: categoryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case '胸部': return const Color(0xFFE57373);
      case '背部': return const Color(0xFF64B5F6);
      case '腿部': return const Color(0xFFFFB74D);
      case '肩膀': return const Color(0xFFBA68C8);
      case '手臂': return AppColors.coach;
      case '腹肌': return const Color(0xFF4DB6AC);
      case '有氧': return const Color(0xFFF06292);
      default: return AppColors.textSecondary;
    }
  }

  // ===========================================================
  // 📝 Tab 2: 教練備註
  // ===========================================================

  Widget _buildCoachNotesTab() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore
          .collection('workoutPlans')
          .doc(widget.planId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.coach),
            ),
          );
        }

        List<Map<String, dynamic>> notes = [];
        
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final coachNotes = data['coachNotes'];
          
          if (coachNotes is List) {
            notes = coachNotes
                .map((n) => n as Map<String, dynamic>)
                .toList();
            notes.sort((a, b) {
              final aTime = a['createdAt'] as Timestamp?;
              final bTime = b['createdAt'] as Timestamp?;
              if (aTime == null || bTime == null) return 0;
              return bTime.compareTo(aTime);
            });
          }
        }

        return Column(
          children: [
            _buildAddNoteSection(),
            Expanded(
              child: notes.isEmpty
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: _buildEmptyNotesState(),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: notes.length,
                      itemBuilder: (context, index) {
                        return _buildNoteCard(notes[index], index);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAddNoteSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: AppShadows.small,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '新增備註',
            style: AppTextStyles.label.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _noteController,
                  decoration: InputDecoration(
                    hintText: '輸入給學員的備註或建議...',
                    hintStyle: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textTertiary,
                    ),
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  maxLines: 2,
                  minLines: 1,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  gradient: AppColors.secondaryGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: AppShadows.small,
                ),
                child: IconButton(
                  icon: _isAddingNote
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.send, color: Colors.white),
                  onPressed: _isAddingNote ? null : _addNote,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyNotesState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.note_alt_outlined,
                size: 64,
                color: AppColors.info,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '尚無備註',
              style: AppTextStyles.h4.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '新增備註來給學員建議或提醒',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteCard(Map<String, dynamic> note, int index) {
    final content = note['content'] as String? ?? '';
    final createdAt = note['createdAt'] as Timestamp?;
    final isAdjustmentNotice = note['isAdjustmentNotice'] == true;
    final version = note['version'] as int?;
    final dateStr = createdAt != null
        ? DateFormat('yyyy/MM/dd HH:mm').format(createdAt.toDate())
        : '未知時間';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.small,
        border: Border.all(
          color: isAdjustmentNotice 
              ? AppColors.warning.withOpacity(0.3)
              : AppColors.divider,
          width: isAdjustmentNotice ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isAdjustmentNotice
                      ? AppColors.warning.withOpacity(0.1)
                      : AppColors.coach.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isAdjustmentNotice ? Icons.tune : Icons.edit_note,
                  color: isAdjustmentNotice ? AppColors.warning : AppColors.coach,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              if (isAdjustmentNotice) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '計畫調整',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.warning,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
                if (version != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.warning,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'v$version',
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  dateStr,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, 
                  color: AppColors.error.withOpacity(0.7), size: 20),
                onPressed: () => _deleteNote(note),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: AppTextStyles.bodyMedium.copyWith(
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addNote() async {
    final content = _noteController.text.trim();
    if (content.isEmpty) {
      _showSnackBar('請輸入備註內容', isError: true);
      return;
    }

    setState(() => _isAddingNote = true);

    try {
      final note = {
        'content': content,
        'createdAt': Timestamp.now(),
        'coachId': FirebaseAuth.instance.currentUser?.uid,
      };

      await _firestore
          .collection('workoutPlans')
          .doc(widget.planId)
          .update({
        'coachNotes': FieldValue.arrayUnion([note]),
      });

      _noteController.clear();
      _showSnackBar('備註已新增');
    } catch (e) {
      _showSnackBar('新增失敗：$e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isAddingNote = false);
      }
    }
  }

  Future<void> _deleteNote(Map<String, dynamic> note) async {
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
              child: Icon(Icons.delete, color: AppColors.error, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('刪除備註'),
          ],
        ),
        content: const Text('確定要刪除這則備註嗎？'),
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
        await _firestore
            .collection('workoutPlans')
            .doc(widget.planId)
            .update({
          'coachNotes': FieldValue.arrayRemove([note]),
        });
        _showSnackBar('備註已刪除');
      } catch (e) {
        _showSnackBar('刪除失敗：$e', isError: true);
      }
    }
  }
}