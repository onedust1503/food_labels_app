// lib/pages/workout/workout_plan_detail_page.dart
// ✅ v5.2 - 增加 debug 資訊和延遲確保資料同步
// 🔧 v5.2 修復：訓練完成後增加延遲確保 Firebase 同步
// 🔧 v5.2 修復：增加詳細 debug 資訊
// 🔧 v5.1 修復：orElse 中的日期計算問題
// 🔧 v5.1 修復：週進度條顯示問題
// 🔧 v5.1 修復：isToday 判斷改為直接比較
// 🔥 v5.0 新增：PlanProgress 整體進度顯示
// 🔥 v5.0 新增：WeeklyProgress 週進度追蹤
// 🔥 v5.0 保留：WorkoutDateHelper 統一日期處理
// 🔥 v5.0 保留：6 種完成狀態系統

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/workout_model.dart';
import '../../models/completion_status.dart';
import '../../models/plan_progress.dart';
import '../../services/unified_workout_service.dart';
import '../../services/workout_progress_service.dart';
import '../../services/workout_completion_service.dart';
import '../../components/completion_status_badge.dart';
import '../../utils/workout_date_helper.dart';
import 'workout_plan_execution_page.dart';

class WorkoutPlanDetailPage extends StatefulWidget {
  final WorkoutPlanModel plan;

  const WorkoutPlanDetailPage({super.key, required this.plan});

  @override
  State<WorkoutPlanDetailPage> createState() => _WorkoutPlanDetailPageState();
}

class _WorkoutPlanDetailPageState extends State<WorkoutPlanDetailPage>
    with SingleTickerProviderStateMixin {
  final UnifiedWorkoutService _workoutService = UnifiedWorkoutService();
  final WorkoutProgressService _progressService = WorkoutProgressService();
  final WorkoutCompletionService _completionService = WorkoutCompletionService();

  // 🔥 v5.0：使用新的進度模型
  PlanProgress? _planProgress;
  bool _isLoading = true;
  late AnimationController _animController;
  
  // 今日資訊
  late int _todayWeekday;
  late String _todayEnglish;
  late String _todayFullName;
  late String _todayShortName;
  late DateTime _planStartDateOnly;
  late DateTime _todayDateOnly; // 🔧 v5.1：新增

  // 🎨 Soft UI 配色
  static const Color _primaryOrange = Color(0xFFFF9800);
  static const Color _lightOrange = Color(0xFFFFF3E0);
  static const Color _darkOrange = Color(0xFFF57C00);
  static const Color _bgColor = Color(0xFFF8F9FA);
  static const Color _cardColor = Color(0xFFFFFFFF);
  static const Color _textPrimary = Color(0xFF2D3748);
  static const Color _textSecondary = Color(0xFF718096);
  static const Color _disabledColor = Color(0xFFCBD5E0);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    final now = DateTime.now();
    _todayWeekday = WorkoutDateHelper.getTodayWeekday();
    _todayEnglish = WorkoutDateHelper.getTodayEnglish();
    _todayFullName = WorkoutDateHelper.getTodayFullChinese();
    _todayShortName = WorkoutDateHelper.getShortChinese(_todayWeekday);
    _todayDateOnly = DateTime(now.year, now.month, now.day); // 🔧 v5.1
    
    _planStartDateOnly = DateTime(
      widget.plan.startDate.year,
      widget.plan.startDate.month,
      widget.plan.startDate.day,
    );
    
    _loadProgress();
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadProgress() async {
    try {
      debugPrint('🔄 開始載入進度...');
      debugPrint('   計畫ID: ${widget.plan.id}');
      debugPrint('   計畫訓練日數: ${widget.plan.days.length}');
      for (var day in widget.plan.days) {
        debugPrint('   - ${day.dayOfWeek}');
      }
      
      final progress = await _progressService.getPlanProgress(widget.plan);
      
      debugPrint('✅ 進度載入完成');
      debugPrint('   總訓練天數: ${progress.totalTrainingDays}');
      debugPrint('   已完成天數: ${progress.completedDays}');
      debugPrint('   本週應完成: ${progress.currentWeek.shouldComplete}');
      debugPrint('   本週已完成: ${progress.currentWeek.completed}');
      debugPrint('   週進度天數: ${progress.currentWeek.days.length}');
      
      // 🔧 v5.2：打印每天的狀態
      for (var day in progress.currentWeek.days) {
        debugPrint('   ${day.dayName}: ${day.status.name} (completed: ${day.isCompleted}, isToday: ${day.isToday})');
      }
      
      if (mounted) {
        setState(() {
          _planProgress = progress;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ 載入進度失敗: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  /// 獲取今日推薦訓練
  WorkoutPlanDay? _getTodayRecommendedWorkout() {
    for (var day in widget.plan.days) {
      if (WorkoutDateHelper.isSameWeekday(day.dayOfWeek, _todayEnglish)) {
        return day;
      }
    }
    return null;
  }
  
  /// 🔧 v5.1：修正 - 檢查指定星期幾是否是今天
  bool _isDayToday(String dayOfWeek) {
    return WorkoutDateHelper.isSameWeekday(dayOfWeek, _todayEnglish);
  }
  
  /// 🔧 v5.1：修正 - 檢查指定星期幾在本週的日期是否在計畫開始後
  bool _isDayAfterPlanStart(String dayOfWeek) {
    final dayDate = WorkoutDateHelper.getDateForWeekdayString(dayOfWeek);
    if (dayDate == null) return false;
    final dayDateOnly = DateTime(dayDate.year, dayDate.month, dayDate.day);
    return !dayDateOnly.isBefore(_planStartDateOnly);
  }
  
  /// 檢查今天是否已完成
  bool _isTodayCompleted() {
    if (_planProgress == null) return false;
    
    // 🔧 v5.1：直接從 days 中找今天
    for (final day in _planProgress!.currentWeek.days) {
      if (day.isToday && day.isCompleted) {
        return true;
      }
    }
    return false;
  }
  
  /// 檢查今天是否在計畫開始後
  bool _isTodayAfterPlanStart() {
    return !_todayDateOnly.isBefore(_planStartDateOnly);
  }

  @override
  Widget build(BuildContext context) {
    final todayWorkout = _getTodayRecommendedWorkout();
    final isTodayCompleted = _isTodayCompleted();
    final isTodayAfterPlanStart = _isTodayAfterPlanStart();
    
    return Scaffold(
      backgroundColor: _bgColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Column(
              children: [
                // 🔥 v5.0：整體進度卡片
                _buildProgressCard(),
                const SizedBox(height: 8),
                
                // 今日推薦
                if (todayWorkout != null && !isTodayCompleted && isTodayAfterPlanStart)
                  _buildTodayRecommendationCard(todayWorkout),
                
                // 🔥 v5.0：週進度條
                _buildWeeklyProgressBar(),
                const SizedBox(height: 16),
                _buildSectionTitle('訓練日程'),
                const SizedBox(height: 12),
              ],
            ),
          ),
          _isLoading
              ? const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(color: _primaryOrange),
                    ),
                  ),
                )
              : _buildDaysList(),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  // 🔥 v5.0：整體進度卡片
  Widget _buildProgressCard() {
    final progress = _planProgress;
    final totalDays = widget.plan.days.length;
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 計畫描述
            if (widget.plan.description != null &&
                widget.plan.description!.isNotEmpty) ...[
              Text(
                widget.plan.description!,
                style: TextStyle(
                  fontSize: 14,
                  color: _textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 日期和頻率
            Row(
              children: [
                _buildInfoChip(
                  icon: Icons.calendar_today,
                  label: _formatDateRange(),
                  color: _primaryOrange,
                ),
                const SizedBox(width: 12),
                _buildInfoChip(
                  icon: Icons.repeat,
                  label: '每週 $totalDays 天',
                  color: Colors.blue,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 🔥 v5.0：進度條
            if (progress != null && !progress.isOngoing) ...[
              _buildOverallProgressBar(progress),
              const SizedBox(height: 20),
            ],

            // 統計卡片
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.check_circle_outline,
                    value: progress?.progressText ?? '0 次',
                    label: progress?.isOngoing == true ? '累計完成' : '整體進度',
                    color: CompletionStatus.fromType(CompletionStatusType.onTime).color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.timeline,
                    value: '${progress?.onTimePercent ?? 0}%',
                    label: '準時率',
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.timer,
                    value: '${progress?.avgDuration ?? 0}',
                    label: '平均時長',
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 🔥 v5.0：整體進度條
  Widget _buildOverallProgressBar(PlanProgress progress) {
    final rate = progress.completionRate;
    final color = ProgressDisplayHelper.getProgressColor(rate);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '整體進度',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _textPrimary,
              ),
            ),
            Text(
              '${progress.completionPercent}%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            // 背景
            Container(
              height: 10,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.15),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            // 進度
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              height: 10,
              width: MediaQuery.of(context).size.width * 0.85 * rate,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.7)],
                ),
                borderRadius: BorderRadius.circular(5),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '${progress.completedDays} / ${progress.totalTrainingDays} 次 • ${ProgressDisplayHelper.getProgressDescription(rate)}',
          style: TextStyle(
            fontSize: 11,
            color: _textSecondary,
          ),
        ),
      ],
    );
  }

  // 🔥 v5.1：修正週進度條
  Widget _buildWeeklyProgressBar() {
    final weeklyProgress = _planProgress?.currentWeek;
    
    // 🔧 v5.1：如果沒有載入進度，手動生成週資料
    List<_WeekDayData> weekDays = [];
    final weekStart = WorkoutDateHelper.getWeekStart(DateTime.now());
    
    // 取得計畫的訓練日
    final trainingWeekdays = widget.plan.days
        .map((d) => WorkoutDateHelper.parseWeekday(d.dayOfWeek))
        .whereType<int>()
        .toSet();
    
    debugPrint('🔍 訓練日 weekdays: $trainingWeekdays');
    
    for (int i = 0; i < 7; i++) {
      final date = weekStart.add(Duration(days: i));
      final weekday = date.weekday;
      final isTrainingDay = trainingWeekdays.contains(weekday);
      final dateOnly = DateTime(date.year, date.month, date.day);
      final isToday = dateOnly.isAtSameMomentAs(_todayDateOnly);
      final isAfterPlanStart = !dateOnly.isBefore(_planStartDateOnly);
      final isPast = dateOnly.isBefore(_todayDateOnly);
      
      // 從進度資料中找完成狀態
      CompletionStatusType status = CompletionStatusType.pending;
      bool isCompleted = false;
      
      if (weeklyProgress != null && weeklyProgress.days.isNotEmpty) {
        final dayProgress = weeklyProgress.days.firstWhere(
          (d) => d.date.weekday == weekday,
          orElse: () => PlanDayProgress.fromWeekday(
            weekday: weekday,
            date: date,
            isTrainingDay: isTrainingDay,
            isAfterPlanStart: isAfterPlanStart,
            status: CompletionStatusType.pending,
          ),
        );
        status = dayProgress.status;
        isCompleted = dayProgress.isCompleted;
      } else if (isTrainingDay) {
        // 沒有進度資料時，根據日期判斷狀態
        if (!isAfterPlanStart) {
          status = CompletionStatusType.pending;
        } else if (isToday) {
          status = CompletionStatusType.dueToday;
        } else if (isPast) {
          status = CompletionStatusType.overdue;
        } else {
          status = CompletionStatusType.pending;
        }
      }
      
      weekDays.add(_WeekDayData(
        weekday: weekday,
        date: date,
        isTrainingDay: isTrainingDay,
        isToday: isToday,
        isAfterPlanStart: isAfterPlanStart,
        status: status,
        isCompleted: isCompleted,
      ));
    }
    
    // 計算本週應完成和已完成
    final shouldComplete = weekDays.where((d) => d.isTrainingDay && d.isAfterPlanStart).length;
    final completed = weekDays.where((d) => d.isTrainingDay && d.isCompleted).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 標題行
            Row(
              children: [
                Icon(Icons.calendar_view_week, size: 18, color: _primaryOrange),
                const SizedBox(width: 8),
                Text(
                  '本週訓練',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _primaryOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$completed / $shouldComplete 完成',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _primaryOrange,
                    ),
                  ),
                ),
                const Spacer(),
                _buildCompactLegend(),
              ],
            ),
            const SizedBox(height: 16),
            
            // 週日期顯示
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: weekDays.map((day) => _buildDayCircleNew(day)).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // 🔧 v5.1：新的單日圓圈
  Widget _buildDayCircleNew(_WeekDayData day) {
    final status = CompletionStatus.fromType(day.status);
    final shortName = WorkoutDateHelper.getShortChinese(day.weekday);

    return Column(
      children: [
        // 今日指示器
        if (day.isToday)
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _primaryOrange,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              '今天',
              style: TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        else
          const SizedBox(height: 18),
        
        // 日期圓圈
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: day.isCompleted 
                ? status.color 
                : day.isTrainingDay && day.isAfterPlanStart
                    ? status.backgroundColor
                    : Colors.grey.withOpacity(0.1),
            shape: BoxShape.circle,
            border: !day.isCompleted && day.isTrainingDay && day.isAfterPlanStart
                ? Border.all(
                    color: status.color,
                    width: day.isToday ? 3 : 2,
                  )
                : !day.isCompleted && day.isTrainingDay && !day.isAfterPlanStart
                    ? Border.all(color: _disabledColor, width: 1)
                    : null,
            boxShadow: day.isToday && !day.isCompleted && day.isAfterPlanStart
                ? [BoxShadow(color: status.color.withOpacity(0.3), blurRadius: 8, spreadRadius: 1)]
                : day.isCompleted
                    ? [BoxShadow(color: status.color.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))]
                    : null,
          ),
          child: Center(
            child: day.isCompleted
                ? Icon(status.icon, size: 18, color: Colors.white)
                : day.isTrainingDay
                    ? Icon(
                        !day.isAfterPlanStart
                            ? Icons.lock_clock
                            : day.status == CompletionStatusType.dueToday 
                                ? Icons.play_arrow 
                                : day.status == CompletionStatusType.overdue
                                    ? Icons.warning_amber
                                    : Icons.fitness_center,
                        size: 16,
                        color: day.isAfterPlanStart ? status.color : _disabledColor,
                      )
                    : null,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          shortName,
          style: TextStyle(
            fontSize: 11,
            color: day.isToday
                ? _primaryOrange
                : day.isTrainingDay && day.isAfterPlanStart
                    ? _textPrimary
                    : _textSecondary,
            fontWeight: day.isToday || (day.isTrainingDay && day.isAfterPlanStart) 
                ? FontWeight.w600 
                : FontWeight.normal,
          ),
        ),
        
        // 狀態標籤
        if (day.isCompleted && day.status == CompletionStatusType.makeup)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '補做',
              style: TextStyle(fontSize: 8, color: status.color, fontWeight: FontWeight.w500),
            ),
          )
        else if (!day.isAfterPlanStart && day.isTrainingDay && !day.isCompleted)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '未開始',
              style: TextStyle(fontSize: 8, color: _disabledColor, fontWeight: FontWeight.w500),
            ),
          ),
      ],
    );
  }
  
  Widget _buildCompactLegend() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLegendDot(CompletionStatusType.onTime, '準時'),
        const SizedBox(width: 8),
        _buildLegendDot(CompletionStatusType.early, '提前'),
        const SizedBox(width: 8),
        _buildLegendDot(CompletionStatusType.makeup, '補做'),
      ],
    );
  }
  
  Widget _buildLegendDot(CompletionStatusType type, String label) {
    final status = CompletionStatus.fromType(type);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: status.color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 9, color: _textSecondary)),
      ],
    );
  }
  
  Widget _buildTodayRecommendationCard(WorkoutPlanDay todayWorkout) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_primaryOrange, _darkOrange],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _primaryOrange.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.today, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '今日建議訓練',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_todayShortName - ${todayWorkout.exercises.length} 個動作',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () => _startWorkout(todayWorkout),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _primaryOrange,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_arrow, size: 18),
                  SizedBox(width: 4),
                  Text('開始', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 160,
      floating: false,
      pinned: true,
      backgroundColor: _primaryOrange,
      foregroundColor: Colors.white,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          widget.plan.planName,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_primaryOrange, _darkOrange],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -30, top: -30,
                child: Container(
                  width: 150, height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              Positioned(
                left: -20, bottom: -20,
                child: Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),
              ),
              Positioned(
                right: 24, bottom: 60,
                child: Icon(Icons.fitness_center, size: 48, color: Colors.white.withOpacity(0.3)),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.plan.status == 'active')
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'complete',
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: CompletionStatus.fromType(CompletionStatusType.onTime).color),
                    const SizedBox(width: 12),
                    const Text('標記為完成'),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'complete') _markAsCompleted();
            },
          ),
      ],
    );
  }

  Widget _buildInfoChip({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: _textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(
            width: 4, height: 20,
            decoration: BoxDecoration(
              color: _primaryOrange,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildDaysList() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final day = widget.plan.days[index];
          return AnimatedBuilder(
            animation: _animController,
            builder: (context, child) {
              final delay = index * 0.1;
              final animValue = Curves.easeOutBack.transform(
                ((_animController.value - delay) / (1 - delay)).clamp(0.0, 1.0),
              );
              return Transform.translate(
                offset: Offset(0, 30 * (1 - animValue)),
                child: Opacity(
                  opacity: animValue.clamp(0.0, 1.0),
                  child: _buildDayCard(day, index),
                ),
              );
            },
          );
        },
        childCount: widget.plan.days.length,
      ),
    );
  }

  // 🔧 v5.1：修正 _buildDayCard
  Widget _buildDayCard(WorkoutPlanDay day, int index) {
    // 🔧 v5.1：直接計算而不是依賴可能為空的 days
    final dayWeekday = WorkoutDateHelper.parseWeekday(day.dayOfWeek) ?? 1;
    final dayDate = WorkoutDateHelper.getDateForWeekdayString(day.dayOfWeek) ?? DateTime.now();
    final dayDateOnly = DateTime(dayDate.year, dayDate.month, dayDate.day);
    
    // 🔧 v5.1：直接計算 isToday，不依賴 PlanDayProgress
    final isToday = _isDayToday(day.dayOfWeek);
    final isAfterPlanStart = _isDayAfterPlanStart(day.dayOfWeek);
    final isPast = dayDateOnly.isBefore(_todayDateOnly);
    
    // 從進度中查找完成狀態
    bool isCompleted = false;
    CompletionStatusType statusType = CompletionStatusType.pending;
    
    if (_planProgress != null && _planProgress!.currentWeek.days.isNotEmpty) {
      final dayProgress = _planProgress!.currentWeek.days.firstWhere(
        (d) => d.date.weekday == dayWeekday,
        orElse: () => PlanDayProgress.fromWeekday(
          weekday: dayWeekday,
          date: dayDate,
          isTrainingDay: true,
          isAfterPlanStart: isAfterPlanStart,
          status: CompletionStatusType.pending,
        ),
      );
      isCompleted = dayProgress.isCompleted;
      statusType = dayProgress.status;
    } else {
      // 沒有進度資料時，根據日期判斷
      if (!isAfterPlanStart) {
        statusType = CompletionStatusType.pending;
      } else if (isToday) {
        statusType = CompletionStatusType.dueToday;
      } else if (isPast) {
        statusType = CompletionStatusType.overdue;
      } else {
        statusType = CompletionStatusType.pending;
      }
    }
    
    final status = CompletionStatus.fromType(statusType);
    final fullName = WorkoutDateHelper.normalizeToChinese(day.dayOfWeek);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(20),
          border: isToday && !isCompleted && isAfterPlanStart
              ? Border.all(color: status.color, width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: isToday && !isCompleted && isAfterPlanStart
                  ? status.color.withOpacity(0.15)
                  : Colors.black.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // 標題區
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isCompleted
                      ? [status.color.withOpacity(0.08), status.color.withOpacity(0.03)]
                      : [_primaryOrange.withOpacity(0.08), _lightOrange.withOpacity(0.5)],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  // 日期標籤
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isCompleted
                            ? [status.color, status.color.withOpacity(0.8)]
                            : [_primaryOrange, _darkOrange],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: (isCompleted ? status.color : _primaryOrange).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isCompleted)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(status.icon, size: 14, color: Colors.white),
                          ),
                        Text(
                          fullName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // 動作數量
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.list_alt, size: 14, color: _textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          '${day.exercises.length} 個動作',
                          style: TextStyle(fontSize: 12, color: _textSecondary),
                        ),
                      ],
                    ),
                  ),
                  
                  // 🔧 v5.1：修正今日標記 - 只有真的是今天才顯示
                  if (isToday && !isCompleted && isAfterPlanStart) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: status.color,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '今天',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],

                  const Spacer(),

                  // 狀態標籤
                  if (!isAfterPlanStart && !isCompleted)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _disabledColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.schedule, size: 14, color: _disabledColor),
                          const SizedBox(width: 4),
                          Text(
                            '未開始',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _disabledColor),
                          ),
                        ],
                      ),
                    )
                  else if (isCompleted)
                    CompletionStatusBadge(statusType: statusType, compact: true)
                  else if (statusType == CompletionStatusType.overdue)
                    CompletionStatusBadge(statusType: statusType, compact: true),
                ],
              ),
            ),

            // 動作列表
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ...day.exercises.asMap().entries.map((entry) {
                    return _buildExerciseItem(entry.value, entry.key + 1);
                  }),

                  const SizedBox(height: 16),

                  // 開始訓練按鈕
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => _startWorkout(day),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isCompleted 
                            ? status.color.withOpacity(0.9)
                            : _primaryOrange,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(isCompleted ? Icons.replay : Icons.play_arrow, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            isCompleted 
                                ? '再次訓練' 
                                : (isToday && isAfterPlanStart ? '開始今日訓練' : '開始訓練'),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseItem(PlannedExercise exercise, int index) {
    final categoryInfo = _getCategoryInfo(exercise.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_primaryOrange.withOpacity(0.2), _lightOrange]),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$index',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _darkOrange),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: categoryInfo['color'].withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(categoryInfo['icon'], color: categoryInfo['color'], size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.name,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  _getExerciseDetails(exercise),
                  style: TextStyle(fontSize: 13, color: _textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getCategoryInfo(String? type) {
    switch (type) {
      case 'weight_training':
        return {'icon': Icons.fitness_center, 'color': Colors.red};
      case 'cardio':
        return {'icon': Icons.directions_run, 'color': Colors.blue};
      case 'yoga':
        return {'icon': Icons.self_improvement, 'color': Colors.purple};
      case 'stretching':
        return {'icon': Icons.accessibility_new, 'color': Colors.teal};
      default:
        return {'icon': Icons.sports_gymnastics, 'color': _primaryOrange};
    }
  }

  String _getExerciseDetails(PlannedExercise exercise) {
    List<String> details = [];
    if (exercise.sets != null && exercise.reps != null) {
      details.add('${exercise.sets} 組 × ${exercise.reps} 次');
    } else if (exercise.sets != null) {
      details.add('${exercise.sets} 組');
    }
    if (exercise.duration != null) {
      details.add('${exercise.duration} 分鐘');
    }
    return details.isEmpty ? '自訂訓練' : details.join(' • ');
  }

  String _formatDateRange() {
    final start = WorkoutDateHelper.formatDateChinese(widget.plan.startDate);
    final end = widget.plan.endDate != null
        ? WorkoutDateHelper.formatDateChinese(widget.plan.endDate!)
        : '持續進行';
    return '$start - $end';
  }

  Future<void> _startWorkout(WorkoutPlanDay day) async {
    if (widget.plan.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [Icon(Icons.error_outline, color: Colors.white), SizedBox(width: 8), Text('計畫 ID 不存在')],
          ),
          backgroundColor: Colors.red[400],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final isScheduledToday = WorkoutDateHelper.isSameWeekday(day.dayOfWeek, _todayEnglish);
    
    if (!isScheduledToday) {
      final confirmed = await _showScheduleWarningDialog(day);
      if (confirmed != true) return;
    }

    HapticFeedback.mediumImpact();

    final exercisesData = day.exercises.map((e) => {
      'name': e.name,
      'category': e.primaryMuscleGroup ?? e.type ?? '其他',
      'type': e.type ?? 'weight_training',
      'sets': e.sets ?? 3,
      'reps': e.reps ?? 12,
      'restSec': 90,
      'notes': e.notes,
    }).toList();

    final dayFullName = WorkoutDateHelper.normalizeToChinese(day.dayOfWeek);

    final result = await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            WorkoutPlanExecutionPage(
          planId: widget.plan.id!,
          planName: widget.plan.planName,
          dayOfWeek: dayFullName,
          exercises: exercisesData,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero)
                .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );

    // 🔧 v5.2：不管返回什麼都重新載入，並增加延遲確保 Firebase 同步
    if (mounted) {
      // 等待 Firebase 同步
      await Future.delayed(const Duration(milliseconds: 500));
      debugPrint('🔄 訓練結束，重新載入進度...');
      await _loadProgress();
    }
  }
  
  Future<bool?> _showScheduleWarningDialog(WorkoutPlanDay day) {
    final weekday = WorkoutDateHelper.parseWeekday(day.dayOfWeek) ?? 1;
    final scheduledDay = WorkoutDateHelper.getShortChinese(weekday);
    final makeupStatus = CompletionStatus.fromType(CompletionStatusType.makeup);
    
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: makeupStatus.backgroundColor, shape: BoxShape.circle),
              child: Icon(Icons.schedule, color: makeupStatus.color, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('訓練日提醒', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 15, color: _textPrimary, height: 1.6),
                children: [
                  const TextSpan(text: '今天是 '),
                  TextSpan(text: _todayShortName, style: TextStyle(fontWeight: FontWeight.bold, color: _primaryOrange)),
                  const TextSpan(text: '\n您選擇的是 '),
                  TextSpan(text: scheduledDay, style: TextStyle(fontWeight: FontWeight.bold, color: makeupStatus.color)),
                  const TextSpan(text: ' 的訓練'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: makeupStatus.backgroundColor, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: makeupStatus.color, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '此次訓練將記錄為「$scheduledDay」的補做訓練',
                      style: TextStyle(fontSize: 13, color: _textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('取消', style: TextStyle(color: _textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [Icon(Icons.play_arrow, size: 18), SizedBox(width: 4), Text('仍要執行')],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _markAsCompleted() async {
    final successStatus = CompletionStatus.fromType(CompletionStatusType.onTime);
    
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: successStatus.backgroundColor, shape: BoxShape.circle),
                child: Icon(Icons.check_circle, color: successStatus.color),
              ),
              const SizedBox(width: 12),
              const Text('確認完成'),
            ],
          ),
          content: const Text('確定要將此訓練計畫標記為已完成嗎？\n完成後將無法再次執行此計畫。', style: TextStyle(height: 1.5)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('取消', style: TextStyle(color: _textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: successStatus.color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('確定完成'),
            ),
          ],
        ),
      );

      if (confirmed == true && widget.plan.id != null) {
        await _workoutService.markPlanAsCompleted(widget.plan.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [Icon(Icons.celebration, color: Colors.white), SizedBox(width: 8), Text('🎉 恭喜完成訓練計畫！')],
              ),
              backgroundColor: successStatus.color,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失敗：$e'), backgroundColor: Colors.red[400], behavior: SnackBarBehavior.floating),
        );
      }
    }
  }
}

// 🔧 v5.1：新增輔助類
class _WeekDayData {
  final int weekday;
  final DateTime date;
  final bool isTrainingDay;
  final bool isToday;
  final bool isAfterPlanStart;
  final CompletionStatusType status;
  final bool isCompleted;

  _WeekDayData({
    required this.weekday,
    required this.date,
    required this.isTrainingDay,
    required this.isToday,
    required this.isAfterPlanStart,
    required this.status,
    required this.isCompleted,
  });
}