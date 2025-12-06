// lib/pages/workout/workout_plan_detail_page.dart
// ✅ v4.0 - 整合 6 種完成狀態系統
// 🔥 v4 新增：使用 CompletionStatus 模型
// 🔥 v4 新增：使用 CompletionStatusBadge 元件
// 🔥 v4 新增：支援準時、提前、補做、今日待做、逾期、待完成
// 🔥 v3.1 保留：混合模式進度追蹤 + 防呆提示

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/workout_model.dart';
import '../../models/completion_status.dart';
import '../../services/unified_workout_service.dart';
import '../../services/workout_progress_service.dart';
import '../../services/workout_completion_service.dart';
import '../../components/completion_status_badge.dart';
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

  // 🔥 v4：混合模式完成資料（含狀態類型）
  Map<String, Map<String, dynamic>> _weeklyCompletions = {};
  Map<String, int> _completions = {};
  bool _isLoadingProgress = true;
  late AnimationController _animController;
  
  // 今日星期
  late String _todayKey;
  late String _todayDisplayName;

  // 🎨 Soft UI 配色
  static const Color _primaryOrange = Color(0xFFFF9800);
  static const Color _lightOrange = Color(0xFFFFF3E0);
  static const Color _darkOrange = Color(0xFFF57C00);
  static const Color _bgColor = Color(0xFFF8F9FA);
  static const Color _cardColor = Color(0xFFFFFFFF);
  static const Color _textPrimary = Color(0xFF2D3748);
  static const Color _textSecondary = Color(0xFF718096);

  final Map<String, String> _dayNames = {
    'monday': '週一',
    'tuesday': '週二',
    'wednesday': '週三',
    'thursday': '週四',
    'friday': '週五',
    'saturday': '週六',
    'sunday': '週日',
  };

  final Map<String, String> _dayFullNames = {
    'monday': '星期一',
    'tuesday': '星期二',
    'wednesday': '星期三',
    'thursday': '星期四',
    'friday': '星期五',
    'saturday': '星期六',
    'sunday': '星期日',
  };
  
  final List<String> _weekdayKeys = [
    '', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    final now = DateTime.now();
    _todayKey = _weekdayKeys[now.weekday];
    _todayDisplayName = _dayNames[_todayKey] ?? '';
    
    _loadProgress();
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadProgress() async {
    if (widget.plan.id != null) {
      try {
        final weeklyData = await _workoutService.getWeeklyPlanCompletions(widget.plan.id!);
        final progress = await _progressService.getWeeklyCompletion(widget.plan.id!);
        
        // 🔥 v4：為每個完成記錄計算狀態類型
        final enrichedWeeklyData = <String, Map<String, dynamic>>{};
        weeklyData.forEach((key, value) {
          final planDayOfWeek = value['planDayOfWeek'] ?? key;
          final actualDate = value['actualDate'] as DateTime?;
          
          CompletionStatusType? statusType;
          if (value['completed'] == true && actualDate != null) {
            statusType = _completionService.calculateStatus(
              planDayOfWeek: planDayOfWeek,
              actualDate: actualDate,
              referenceDate: actualDate,
            );
          }
          
          enrichedWeeklyData[key] = {
            ...value,
            'statusType': statusType,
          };
        });
        
        setState(() {
          _weeklyCompletions = enrichedWeeklyData;
          _completions = progress;
          _isLoadingProgress = false;
        });
      } catch (e) {
        setState(() => _isLoadingProgress = false);
      }
    } else {
      setState(() => _isLoadingProgress = false);
    }
  }
  
  WorkoutPlanDay? _getTodayRecommendedWorkout() {
    for (var day in widget.plan.days) {
      if (day.dayOfWeek == _todayKey) {
        return day;
      }
    }
    return null;
  }
  
  // 🔥 v4：檢查某天是否已完成
  bool _isDayCompleted(String dayKey) {
    final fullName = _dayFullNames[dayKey];
    final shortName = _dayNames[dayKey];
    
    if (fullName != null && _weeklyCompletions.containsKey(fullName)) {
      return _weeklyCompletions[fullName]?['completed'] == true;
    }
    if (shortName != null && _weeklyCompletions.containsKey(shortName)) {
      return _weeklyCompletions[shortName]?['completed'] == true;
    }
    if (_weeklyCompletions.containsKey(dayKey)) {
      return _weeklyCompletions[dayKey]?['completed'] == true;
    }
    
    return (_completions[dayKey] ?? 0) > 0;
  }
  
  // 🔥 v4：獲取完成詳情（含狀態類型）
  Map<String, dynamic>? _getCompletionDetail(String dayKey) {
    final fullName = _dayFullNames[dayKey];
    final shortName = _dayNames[dayKey];
    
    if (fullName != null && _weeklyCompletions.containsKey(fullName)) {
      return _weeklyCompletions[fullName];
    }
    if (shortName != null && _weeklyCompletions.containsKey(shortName)) {
      return _weeklyCompletions[shortName];
    }
    if (_weeklyCompletions.containsKey(dayKey)) {
      return _weeklyCompletions[dayKey];
    }
    
    return null;
  }
  
  // 🔥 v4 新增：獲取某天的狀態類型
  CompletionStatusType _getDayStatusType(String dayKey, bool isPlanned) {
    final completionDetail = _getCompletionDetail(dayKey);
    final isCompleted = _isDayCompleted(dayKey);
    final isToday = dayKey == _todayKey;
    final today = DateTime.now().weekday;
    final dayIndex = _weekdayKeys.indexOf(dayKey);
    final isPast = dayIndex > 0 && dayIndex < today;
    
    if (isCompleted && completionDetail != null) {
      // 已完成：使用計算的狀態類型
      final statusType = completionDetail['statusType'] as CompletionStatusType?;
      if (statusType != null) {
        return statusType;
      }
      // 向後相容：使用 isOnSchedule
      final isOnSchedule = completionDetail['isOnSchedule'] ?? true;
      return isOnSchedule ? CompletionStatusType.onTime : CompletionStatusType.makeup;
    }
    
    if (!isPlanned) {
      return CompletionStatusType.pending; // 非訓練日
    }
    
    // 未完成的訓練日
    if (isToday) {
      return CompletionStatusType.dueToday;
    } else if (isPast) {
      return CompletionStatusType.overdue;
    } else {
      return CompletionStatusType.pending;
    }
  }

  @override
  Widget build(BuildContext context) {
    final todayWorkout = _getTodayRecommendedWorkout();
    final isTodayCompleted = _isDayCompleted(_todayKey);
    
    return Scaffold(
      backgroundColor: _bgColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildPlanInfoCard(),
                const SizedBox(height: 8),
                
                if (todayWorkout != null && !isTodayCompleted)
                  _buildTodayRecommendationCard(todayWorkout),
                
                _buildWeeklyProgressBar(),
                const SizedBox(height: 16),
                _buildSectionTitle('訓練日程'),
                const SizedBox(height: 12),
              ],
            ),
          ),
          _isLoadingProgress
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
              child: const Icon(
                Icons.today,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '今日建議訓練',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_dayNames[todayWorkout.dayOfWeek]} - ${todayWorkout.exercises.length} 個動作',
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
                right: -30,
                top: -30,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              Positioned(
                left: -20,
                bottom: -20,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),
              ),
              Positioned(
                right: 24,
                bottom: 60,
                child: Icon(
                  Icons.fitness_center,
                  size: 48,
                  color: Colors.white.withOpacity(0.3),
                ),
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

  Widget _buildPlanInfoCard() {
    int totalCompletions = _completions.values.fold(0, (sum, count) => sum + count);
    int totalDays = widget.plan.days.length;

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

            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.check_circle_outline,
                    value: '$totalCompletions',
                    label: '累計完成',
                    color: CompletionStatus.fromType(CompletionStatusType.onTime).color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.fitness_center,
                    value: '$totalDays',
                    label: '訓練天數',
                    color: _primaryOrange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.sports_gymnastics,
                    value: '${_getTotalExercises()}',
                    label: '總動作數',
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

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
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
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: _textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // 🔥 v4：更新週進度條 - 使用 6 種狀態顏色
  Widget _buildWeeklyProgressBar() {
    final days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    final planDays = widget.plan.days.map((d) => d.dayOfWeek).toSet();

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
                const Spacer(),
                // 🔥 v4：使用 StatusLegend 或簡化圖例
                _buildCompactLegend(),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: days.map((day) {
                final isTrainingDay = planDays.contains(day);
                final isToday = day == _todayKey;
                final statusType = _getDayStatusType(day, isTrainingDay);
                final status = CompletionStatus.fromType(statusType);
                final isCompleted = statusType == CompletionStatusType.onTime ||
                                    statusType == CompletionStatusType.early ||
                                    statusType == CompletionStatusType.makeup;

                return Column(
                  children: [
                    // 今日指示器
                    if (isToday)
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
                    
                    // 🔥 v4：日期圓圈 - 使用狀態顏色
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isCompleted 
                            ? status.color 
                            : isTrainingDay
                                ? status.backgroundColor
                                : Colors.grey.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: !isCompleted && isTrainingDay
                            ? Border.all(
                                color: status.color,
                                width: isToday ? 3 : 2,
                              )
                            : null,
                        boxShadow: isToday && !isCompleted
                            ? [
                                BoxShadow(
                                  color: status.color.withOpacity(0.3),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : isCompleted
                                ? [
                                    BoxShadow(
                                      color: status.color.withOpacity(0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                      ),
                      child: Center(
                        child: isCompleted
                            ? Icon(status.icon, size: 18, color: Colors.white)
                            : isTrainingDay
                                ? Icon(
                                    statusType == CompletionStatusType.dueToday 
                                        ? Icons.play_arrow 
                                        : statusType == CompletionStatusType.overdue
                                            ? Icons.warning_amber
                                            : Icons.fitness_center,
                                    size: 16,
                                    color: status.color,
                                  )
                                : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _dayNames[day] ?? '',
                      style: TextStyle(
                        fontSize: 11,
                        color: isToday
                            ? _primaryOrange
                            : isTrainingDay
                                ? _textPrimary
                                : _textSecondary,
                        fontWeight: isToday || isTrainingDay ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    
                    // 🔥 v4：顯示狀態標籤（補做時顯示實際日期）
                    if (isCompleted && statusType == CompletionStatusType.makeup)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          _getCompletionDetail(day)?['actualDayOfWeek'] ?? '補做',
                          style: TextStyle(
                            fontSize: 8,
                            color: status.color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
  
  // 🔥 v4：簡化圖例
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
          decoration: BoxDecoration(
            color: status.color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(fontSize: 9, color: _textSecondary),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: _primaryOrange,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _textPrimary,
            ),
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

  // 🔥 v4：更新日卡片 - 使用新的狀態系統
  Widget _buildDayCard(WorkoutPlanDay day, int index) {
    final isCompleted = _isDayCompleted(day.dayOfWeek);
    final isToday = day.dayOfWeek == _todayKey;
    final statusType = _getDayStatusType(day.dayOfWeek, true);
    final status = CompletionStatus.fromType(statusType);
    int completionCount = _completions[day.dayOfWeek] ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(20),
          border: isToday && !isCompleted
              ? Border.all(color: status.color, width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: isToday && !isCompleted
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
                      ? [
                          status.color.withOpacity(0.08),
                          status.color.withOpacity(0.03),
                        ]
                      : [
                          _primaryOrange.withOpacity(0.08),
                          _lightOrange.withOpacity(0.5),
                        ],
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
                          color: (isCompleted ? status.color : _primaryOrange)
                              .withOpacity(0.3),
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
                          _dayFullNames[day.dayOfWeek] ?? day.dayOfWeek,
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
                  
                  // 今日標記
                  if (isToday && !isCompleted) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: status.color,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '今天',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],

                  const Spacer(),

                  // 🔥 v4：使用 CompletionStatusBadge
                  if (isCompleted)
                    CompletionStatusBadge(
                      statusType: statusType,
                      compact: true,
                    )
                  else if (statusType == CompletionStatusType.overdue)
                    CompletionStatusBadge(
                      statusType: statusType,
                      compact: true,
                    ),
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
                        shadowColor: _primaryOrange.withOpacity(0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
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
                            child: Icon(
                              isCompleted ? Icons.replay : Icons.play_arrow,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            isCompleted 
                                ? '再次訓練' 
                                : (isToday ? '開始今日訓練' : '開始訓練'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                          if (completionCount > 1) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '×$completionCount',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
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
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_primaryOrange.withOpacity(0.2), _lightOrange],
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$index',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _darkOrange,
                ),
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
            child: Icon(
              categoryInfo['icon'],
              color: categoryInfo['color'],
              size: 20,
            ),
          ),
          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getExerciseDetails(exercise),
                  style: TextStyle(fontSize: 13, color: _textSecondary),
                ),
                if (exercise.notes != null && exercise.notes!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lightbulb_outline, size: 12, color: Colors.blue[600]),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            exercise.notes!,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue[700],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
    final start = _formatDate(widget.plan.startDate);
    final end = widget.plan.endDate != null
        ? _formatDate(widget.plan.endDate!)
        : '持續進行';
    return '$start - $end';
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}';
  }

  int _getTotalExercises() {
    return widget.plan.days.fold(0, (sum, day) => sum + day.exercises.length);
  }

  Future<void> _startWorkout(WorkoutPlanDay day) async {
    if (widget.plan.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 8),
              Text('計畫 ID 不存在'),
            ],
          ),
          backgroundColor: Colors.red[400],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final isScheduledToday = day.dayOfWeek == _todayKey;
    
    if (!isScheduledToday) {
      final confirmed = await _showScheduleWarningDialog(day);
      if (confirmed != true) {
        return;
      }
    }

    HapticFeedback.mediumImpact();

    final List<Map<String, dynamic>> exercisesData = day.exercises.map((e) {
      return {
        'name': e.name,
        'category': e.primaryMuscleGroup ?? e.type ?? '其他',
        'type': e.type ?? 'weight_training',
        'sets': e.sets ?? 3,
        'reps': e.reps ?? 12,
        'restSec': 90,
        'notes': e.notes,
      };
    }).toList();

    final result = await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            WorkoutPlanExecutionPage(
          planId: widget.plan.id!,
          planName: widget.plan.planName,
          dayOfWeek: _dayFullNames[day.dayOfWeek] ?? day.dayOfWeek,
          exercises: exercisesData,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );

    if (result == true || result == null) {
      _loadProgress();
    }
  }
  
  Future<bool?> _showScheduleWarningDialog(WorkoutPlanDay day) {
    final scheduledDay = _dayNames[day.dayOfWeek] ?? day.dayOfWeek;
    final makeupStatus = CompletionStatus.fromType(CompletionStatusType.makeup);
    
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: makeupStatus.backgroundColor,
                shape: BoxShape.circle,
              ),
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
                style: TextStyle(
                  fontSize: 15,
                  color: _textPrimary,
                  height: 1.6,
                ),
                children: [
                  const TextSpan(text: '今天是 '),
                  TextSpan(
                    text: _todayDisplayName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _primaryOrange,
                    ),
                  ),
                  const TextSpan(text: '\n'),
                  const TextSpan(text: '您選擇的是 '),
                  TextSpan(
                    text: scheduledDay,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: makeupStatus.color,
                    ),
                  ),
                  const TextSpan(text: ' 的訓練'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: makeupStatus.backgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: makeupStatus.color, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '此次訓練將記錄為「$scheduledDay」的補做訓練',
                      style: TextStyle(
                        fontSize: 13,
                        color: _textSecondary,
                      ),
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
            child: Text(
              '取消',
              style: TextStyle(color: _textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.play_arrow, size: 18),
                SizedBox(width: 4),
                Text('仍要執行', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
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
                decoration: BoxDecoration(
                  color: successStatus.backgroundColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle, color: successStatus.color),
              ),
              const SizedBox(width: 12),
              const Text('確認完成'),
            ],
          ),
          content: const Text(
            '確定要將此訓練計畫標記為已完成嗎？\n完成後將無法再次執行此計畫。',
            style: TextStyle(height: 1.5),
          ),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
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
                children: [
                  Icon(Icons.celebration, color: Colors.white),
                  SizedBox(width: 8),
                  Text('🎉 恭喜完成訓練計畫！'),
                ],
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
          SnackBar(
            content: Text('操作失敗：$e'),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}