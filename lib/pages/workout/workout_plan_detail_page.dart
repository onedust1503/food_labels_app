// lib/pages/workout/workout_plan_detail_page.dart
// ✅ v3.1 - 混合模式進度追蹤 + 防呆提示
// 🔥 v3 新增：記錄計畫日 + 實際日
// 🔥 v3 新增：防呆提示（非計畫日執行時）
// 🔥 v3 新增：今日建議訓練提示
// 🔥 v3 新增：按時執行標記（⚡ 標示）
// 🔥 v3.1 修正：字段名匹配 - 支援多種 key 格式（星期一/週一/monday）

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/workout_model.dart';
import '../../services/unified_workout_service.dart';
import '../../services/workout_progress_service.dart';
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

  // 🔥 v3 新增：混合模式完成資料
  Map<String, Map<String, dynamic>> _weeklyCompletions = {};
  Map<String, int> _completions = {};
  bool _isLoadingProgress = true;
  late AnimationController _animController;
  
  // 🔥 v3 新增：今日星期
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
  static const Color _successGreen = Color(0xFF48BB78);
  static const Color _warningYellow = Color(0xFFECC94B);  // 🔥 v3 新增

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
  
  // 🔥 v3 新增：weekday 到 key 的映射
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
    
    // 🔥 v3 新增：計算今日星期
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
        // 🔥 v3：使用混合模式獲取本週完成情況
        final weeklyData = await _workoutService.getWeeklyPlanCompletions(widget.plan.id!);
        final progress = await _progressService.getWeeklyCompletion(widget.plan.id!);
        
        setState(() {
          _weeklyCompletions = weeklyData;
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
  
  // 🔥 v3 新增：獲取今日建議訓練
  WorkoutPlanDay? _getTodayRecommendedWorkout() {
    for (var day in widget.plan.days) {
      if (day.dayOfWeek == _todayKey) {
        return day;
      }
    }
    return null;
  }
  
  // 🔥 v3.1 修正：檢查某天是否已完成 - 支援多種 key 格式
  bool _isDayCompleted(String dayKey) {
    // UnifiedWorkoutService.getWeeklyPlanCompletions 返回的 key 是 planDayOfWeek (如 "星期一")
    final fullName = _dayFullNames[dayKey];  // "星期一"
    final shortName = _dayNames[dayKey];     // "週一"
    
    // 🔥 v3.1：按優先級嘗試不同 key 格式
    // 1. 先檢查完整名稱 "星期一"
    if (fullName != null && _weeklyCompletions.containsKey(fullName)) {
      return _weeklyCompletions[fullName]?['completed'] == true;
    }
    // 2. 再檢查簡短名稱 "週一"
    if (shortName != null && _weeklyCompletions.containsKey(shortName)) {
      return _weeklyCompletions[shortName]?['completed'] == true;
    }
    // 3. 最後檢查英文 key "monday"
    if (_weeklyCompletions.containsKey(dayKey)) {
      return _weeklyCompletions[dayKey]?['completed'] == true;
    }
    
    // 兼容舊資料（從 WorkoutProgressService 讀取）
    return (_completions[dayKey] ?? 0) > 0;
  }
  
  // 🔥 v3.1 修正：獲取完成詳情 - 支援多種 key 格式
  Map<String, dynamic>? _getCompletionDetail(String dayKey) {
    final fullName = _dayFullNames[dayKey];  // "星期一"
    final shortName = _dayNames[dayKey];     // "週一"
    
    // 🔥 v3.1：按優先級嘗試不同 key 格式
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
                
                // 🔥 v3 新增：今日建議訓練卡片
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
  
  // 🔥 v3 新增：今日建議訓練卡片
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

  // ========== 🎨 SliverAppBar ==========
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
              // 裝飾圖案
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
              // 圖標
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'complete',
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: _successGreen),
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

  // ========== 📋 計畫資訊卡片 ==========
  Widget _buildPlanInfoCard() {
    int totalCompletions =
        _completions.values.fold(0, (sum, count) => sum + count);
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
            // 描述
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

            // 日期和天數
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

            // 統計數據
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.check_circle_outline,
                    value: '$totalCompletions',
                    label: '累計完成',
                    color: _successGreen,
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

  // ========== 📊 週進度條 ==========
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
                // 🔥 v3 新增：圖例說明
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _successGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text('按時', style: TextStyle(fontSize: 10, color: _textSecondary)),
                    const SizedBox(width: 8),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _warningYellow,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text('補做', style: TextStyle(fontSize: 10, color: _textSecondary)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: days.map((day) {
                final isTrainingDay = planDays.contains(day);
                final isCompleted = _isDayCompleted(day);
                final isToday = day == _todayKey;
                final completionDetail = _getCompletionDetail(day);
                final isOnSchedule = completionDetail?['isOnSchedule'] ?? true;

                return Column(
                  children: [
                    // 🔥 v3 新增：今日指示器
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
                    
                    // 日期圓圈
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        // 🔥 v3：根據是否按時執行顯示不同顏色
                        color: isCompleted
                            ? (isOnSchedule ? _successGreen : _warningYellow)
                            : isTrainingDay
                                ? _primaryOrange.withOpacity(0.15)
                                : Colors.grey.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: isToday && !isCompleted
                            ? Border.all(color: _primaryOrange, width: 3)
                            : isTrainingDay && !isCompleted
                                ? Border.all(color: _primaryOrange, width: 2)
                                : null,
                        boxShadow: isToday && !isCompleted
                            ? [
                                BoxShadow(
                                  color: _primaryOrange.withOpacity(0.3),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: isCompleted
                            ? const Icon(Icons.check, size: 18, color: Colors.white)
                            : isTrainingDay
                                ? Icon(
                                    isToday ? Icons.play_arrow : Icons.fitness_center,
                                    size: 16,
                                    color: _primaryOrange,
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
                    
                    // 🔥 v3 新增：非按時執行提示
                    if (isCompleted && !isOnSchedule)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          completionDetail?['actualDayOfWeek'] ?? '',
                          style: TextStyle(
                            fontSize: 8,
                            color: _warningYellow,
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

  // ========== 📝 Section Title ==========
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

  // ========== 📅 訓練日列表 ==========
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

  Widget _buildDayCard(WorkoutPlanDay day, int index) {
    // 🔥 v3：使用混合模式資料
    final isCompleted = _isDayCompleted(day.dayOfWeek);
    final completionDetail = _getCompletionDetail(day.dayOfWeek);
    final isOnSchedule = completionDetail?['isOnSchedule'] ?? true;
    final isToday = day.dayOfWeek == _todayKey;
    int completionCount = _completions[day.dayOfWeek] ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(20),
          // 🔥 v3：今日訓練高亮邊框
          border: isToday && !isCompleted
              ? Border.all(color: _primaryOrange, width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: isToday && !isCompleted
                  ? _primaryOrange.withOpacity(0.15)
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
                          (isOnSchedule ? _successGreen : _warningYellow).withOpacity(0.08),
                          (isOnSchedule ? _successGreen : _warningYellow).withOpacity(0.03),
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
                            ? [
                                isOnSchedule ? _successGreen : _warningYellow,
                                isOnSchedule ? _successGreen.withOpacity(0.8) : _warningYellow.withOpacity(0.8),
                              ]
                            : [_primaryOrange, _darkOrange],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: (isCompleted
                                  ? (isOnSchedule ? _successGreen : _warningYellow)
                                  : _primaryOrange)
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
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.check, size: 14, color: Colors.white),
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
                  
                  // 🔥 v3 新增：今日標記
                  if (isToday && !isCompleted) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _primaryOrange,
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

                  // 🔥 v3：更新完成徽章（顯示是否按時）
                  if (isCompleted)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: (isOnSchedule ? _successGreen : _warningYellow).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: (isOnSchedule ? _successGreen : _warningYellow).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isOnSchedule ? Icons.verified : Icons.schedule,
                            size: 14,
                            color: isOnSchedule ? _successGreen : _warningYellow,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isOnSchedule ? '已完成' : '補做',
                            style: TextStyle(
                              fontSize: 12,
                              color: isOnSchedule ? _successGreen : _warningYellow,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (completionCount > 1) ...[
                            const SizedBox(width: 4),
                            Text(
                              '×$completionCount',
                              style: TextStyle(
                                fontSize: 11,
                                color: isOnSchedule ? _successGreen : _warningYellow,
                              ),
                            ),
                          ],
                        ],
                      ),
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

                  // 🔥 開始訓練按鈕（v3：已完成顯示「再次訓練」）
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => _startWorkout(day),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isCompleted 
                            ? (isOnSchedule ? _successGreen : _warningYellow).withOpacity(0.9)
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
                            isCompleted ? '再次訓練' : (isToday ? '開始今日訓練' : '開始訓練'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
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
          // 序號
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

          // 類型圖標
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

          // 動作資訊
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

  // ========== 🚀 開始訓練 - v3.0 含防呆提示 ==========
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

    // 🔥 v3 新增：檢查是否為今日計畫訓練
    final isScheduledToday = day.dayOfWeek == _todayKey;
    
    if (!isScheduledToday) {
      // 🔥 v3 新增：顯示防呆提示對話框
      final confirmed = await _showScheduleWarningDialog(day);
      if (confirmed != true) {
        return;  // 用戶取消
      }
    }

    // 🔥 觸覺回饋
    HapticFeedback.mediumImpact();

    // 🔥 轉換 exercises 格式 - 適配新版 WorkoutPlanExecutionPage v5.0
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

    // 🔥 導航到新版執行頁面
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

    // ✅ 重新載入進度
    if (result == true || result == null) {
      _loadProgress();
    }
  }
  
  // 🔥 v3 新增：訓練日提醒對話框
  Future<bool?> _showScheduleWarningDialog(WorkoutPlanDay day) {
    final scheduledDay = _dayNames[day.dayOfWeek] ?? day.dayOfWeek;
    
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _warningYellow.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.schedule, color: _warningYellow, size: 24),
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
                      color: _warningYellow,
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
                color: _lightOrange.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: _primaryOrange, size: 18),
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

  // ========== ✅ 標記完成 ==========
  Future<void> _markAsCompleted() async {
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
                  color: _successGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle, color: _successGreen),
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
                backgroundColor: _successGreen,
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
              backgroundColor: _successGreen,
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