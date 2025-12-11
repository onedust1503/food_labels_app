// lib/pages/workout/workout_plan_list_page.dart
// ✅ v3.0 - 已結束計畫收合區
// 🔧 v3.0 新增：已結束計畫分離顯示（收合/展開）
// 🔧 v3.0 新增：「查看全部」底部彈出完整列表
// 🔧 v3.0 新增：灰色主題區分已結束計畫
// 🔥 v2.0：統一使用 UnifiedWorkoutService
// 🔥 v2.0：使用 WorkoutProgressService 獲取進度
// 🔥 v2.0：優化進度顯示（本週完成次數）
// 🔥 v2.0：現代化 UI/UX 設計

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/unified_workout_service.dart';
import '../../services/workout_progress_service.dart';
import '../../models/workout_model.dart';
import 'workout_plan_detail_page.dart';

class WorkoutPlanListPage extends StatefulWidget {
  const WorkoutPlanListPage({super.key});

  @override
  State<WorkoutPlanListPage> createState() => _WorkoutPlanListPageState();
}

class _WorkoutPlanListPageState extends State<WorkoutPlanListPage>
    with SingleTickerProviderStateMixin {
  final UnifiedWorkoutService _workoutService = UnifiedWorkoutService();
  final WorkoutProgressService _progressService = WorkoutProgressService();

  List<WorkoutPlanModel> _plans = [];
  Map<String, Map<String, int>> _planProgressCache = {};
  bool _isLoading = true;
  late AnimationController _animController;
  
  // 🔧 v3.0 新增：已結束計畫展開狀態
  bool _isEndedExpanded = false;

  // 🎨 Soft UI 配色
  static const Color _primaryOrange = Color(0xFFFF9800);
  static const Color _lightOrange = Color(0xFFFFF3E0);
  static const Color _darkOrange = Color(0xFFF57C00);
  static const Color _bgColor = Color(0xFFF8F9FA);
  static const Color _cardColor = Color(0xFFFFFFFF);
  static const Color _textPrimary = Color(0xFF2D3748);
  static const Color _textSecondary = Color(0xFF718096);
  static const Color _successGreen = Color(0xFF48BB78);
  
  // 🔧 v3.0 新增配色
  static const Color _endedGrey = Color(0xFF9CA3AF);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadPlans();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // 🔧 v3.0 修改：載入所有計畫（含已結束）
  Future<void> _loadPlans() async {
    setState(() => _isLoading = true);
    try {
      // 🔧 v3.0：改用 getAllMyPlans 獲取所有計畫
      final plans = await _workoutService.getAllMyPlans();

      // 預先載入所有計畫的進度
      final progressCache = <String, Map<String, int>>{};
      for (final plan in plans) {
        if (plan.id != null) {
          progressCache[plan.id!] = await _loadPlanProgress(plan);
        }
      }

      setState(() {
        _plans = plans;
        _planProgressCache = progressCache;
        _isLoading = false;
      });

      _animController.forward(from: 0);
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('載入失敗：$e', Colors.red);
    }
  }

  Future<Map<String, int>> _loadPlanProgress(WorkoutPlanModel plan) async {
    try {
      final totalDays = _progressService.calculateTotalDays(plan);
      final completedDays =
          plan.id != null ? await _progressService.getCompletedDays(plan.id!) : 0;
      final weeklyCompletions =
          plan.id != null ? await _progressService.getWeeklyCompletion(plan.id!) : <String, int>{};
      final thisWeekCount = weeklyCompletions.values.fold(0, (a, b) => a + b);

      return {
        'totalDays': totalDays,
        'completedDays': completedDays,
        'thisWeekCount': thisWeekCount,
      };
    } catch (e) {
      return {
        'totalDays': plan.days.length,
        'completedDays': 0,
        'thisWeekCount': 0,
      };
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == Colors.red ? Icons.error_outline : Icons.check_circle,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
  
  // 🔧 v3.0 新增：判斷計畫是否已結束
  bool _isPlanEnded(WorkoutPlanModel plan) {
    // 檢查狀態
    if (plan.status == 'completed' || 
        plan.status == 'cancelled' || 
        plan.status == 'expired') {
      return true;
    }
    
    // 檢查日期
    if (plan.endDate != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final endDate = plan.endDate!;
      final endDateOnly = DateTime(endDate.year, endDate.month, endDate.day);
      if (endDateOnly.isBefore(today)) {
        return true;
      }
    }
    
    return false;
  }
  
  // 🔧 v3.0 新增：分離進行中和已結束計畫
  List<WorkoutPlanModel> get _activePlans => 
      _plans.where((p) => !_isPlanEnded(p)).toList();
  
  List<WorkoutPlanModel> get _endedPlans => 
      _plans.where((p) => _isPlanEnded(p)).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: _primaryOrange),
              ),
            )
          else if (_plans.isEmpty)
            SliverFillRemaining(child: _buildEmptyState())
          else ...[
            SliverToBoxAdapter(child: _buildSummaryCard()),
            
            // 🔧 v3.0：進行中計畫標題
            if (_activePlans.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
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
                        '進行中計畫',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_activePlans.length} 個',
                        style: TextStyle(
                          fontSize: 14,
                          color: _textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            // 🔧 v3.0：進行中計畫列表
            if (_activePlans.isNotEmpty) _buildActivePlansList(),
            
            // 🔧 v3.0：已結束計畫區塊
            if (_endedPlans.isNotEmpty) 
              SliverToBoxAdapter(child: _buildEndedPlansSection()),
            
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ],
      ),
    );
  }

  // ========== 🎨 SliverAppBar ==========
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: _primaryOrange,
      foregroundColor: Colors.white,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          '訓練計畫',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
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
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              Positioned(
                right: 24,
                bottom: 50,
                child: Icon(
                  Icons.event_note,
                  size: 40,
                  color: Colors.white.withOpacity(0.3),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () {
            HapticFeedback.lightImpact();
            _loadPlans();
          },
        ),
      ],
    );
  }

  // ========== 📊 Summary Card ==========
  Widget _buildSummaryCard() {
    // 🔧 v3.0：只計算進行中計畫
    final activeCount = _activePlans.length;
    final totalCompletions = _planProgressCache.values
        .fold(0, (sum, p) => sum + (p['completedDays'] ?? 0));
    final thisWeekTotal = _planProgressCache.values
        .fold(0, (sum, p) => sum + (p['thisWeekCount'] ?? 0));

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
        child: Row(
          children: [
            Expanded(
              child: _buildStatItem(
                icon: Icons.fitness_center,
                value: '$activeCount',
                label: '進行中',
                color: _primaryOrange,
              ),
            ),
            Container(
              width: 1,
              height: 50,
              color: Colors.grey.withOpacity(0.2),
            ),
            Expanded(
              child: _buildStatItem(
                icon: Icons.check_circle_outline,
                value: '$totalCompletions',
                label: '累計完成',
                color: _successGreen,
              ),
            ),
            Container(
              width: 1,
              height: 50,
              color: Colors.grey.withOpacity(0.2),
            ),
            Expanded(
              child: _buildStatItem(
                icon: Icons.local_fire_department,
                value: '$thisWeekTotal',
                label: '本週訓練',
                color: Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: _textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: _textSecondary,
          ),
        ),
      ],
    );
  }

  // ========== 📭 Empty State ==========
  Widget _buildEmptyState() {
    return RefreshIndicator(
      onRefresh: _loadPlans,
      color: _primaryOrange,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _lightOrange,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.event_note,
                  size: 60,
                  color: _primaryOrange.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '尚無訓練計畫',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '請聯繫你的教練獲取專屬訓練計畫',
                style: TextStyle(
                  fontSize: 14,
                  color: _textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _loadPlans,
                icon: const Icon(Icons.refresh),
                label: const Text('重新載入'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primaryOrange,
                  side: BorderSide(color: _primaryOrange),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========== 📋 Active Plans List (v3.0 修改) ==========
  Widget _buildActivePlansList() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final plan = _activePlans[index];
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
                  child: _buildPlanCard(plan, isEnded: false),
                ),
              );
            },
          );
        },
        childCount: _activePlans.length,
      ),
    );
  }
  
  // ========== 📦 Ended Plans Section (v3.0 新增) ==========
  Widget _buildEndedPlansSection() {
    final endedPlans = _endedPlans;
    final displayPlans = _isEndedExpanded ? endedPlans.take(5).toList() : <WorkoutPlanModel>[];
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: [
          // 收合標題
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                _isEndedExpanded = !_isEndedExpanded;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _endedGrey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _endedGrey.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _endedGrey.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.archive_outlined, color: _endedGrey, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '已結束的計畫',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _endedGrey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${endedPlans.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _endedGrey,
                      ),
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _isEndedExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: _endedGrey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // 展開的計畫列表
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                const SizedBox(height: 12),
                ...displayPlans.map((plan) => _buildPlanCard(plan, isEnded: true)),
                
                // 查看全部按鈕
                if (endedPlans.length > 5)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TextButton(
                      onPressed: () => _showAllEndedPlans(),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.list, size: 18, color: _endedGrey),
                          const SizedBox(width: 6),
                          Text(
                            '查看全部 ${endedPlans.length} 個已結束計畫',
                            style: TextStyle(
                              color: _endedGrey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            crossFadeState: _isEndedExpanded 
                ? CrossFadeState.showSecond 
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }
  
  // 🔧 v3.0 新增：顯示全部已結束計畫
  void _showAllEndedPlans() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // 拖動指示器
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // 標題
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _endedGrey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.archive_outlined, color: _endedGrey, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '已結束的計畫',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '共 ${_endedPlans.length} 個',
                          style: TextStyle(
                            fontSize: 13,
                            color: _textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      color: _textSecondary,
                    ),
                  ],
                ),
              ),
              
              const Divider(height: 1),
              
              // 計畫列表
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _endedPlans.length,
                  itemBuilder: (context, index) {
                    return _buildPlanCard(_endedPlans[index], isEnded: true, inBottomSheet: true);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🔧 v3.0 修改：支援已結束計畫的樣式
  Widget _buildPlanCard(WorkoutPlanModel plan, {bool isEnded = false, bool inBottomSheet = false}) {
    final progress = _planProgressCache[plan.id] ??
        {
          'totalDays': plan.days.length,
          'completedDays': 0,
          'thisWeekCount': 0,
        };

    final totalDays = progress['totalDays'] ?? plan.days.length;
    final completedDays = progress['completedDays'] ?? 0;
    final thisWeekCount = progress['thisWeekCount'] ?? 0;
    final progressValue = totalDays > 0 ? completedDays / totalDays : 0.0;
    
    // 🔧 v3.0：動態主題色
    final themeColor = isEnded ? _endedGrey : _primaryOrange;
    final darkThemeColor = isEnded ? _endedGrey.withOpacity(0.8) : _darkOrange;

    return Padding(
      padding: EdgeInsets.fromLTRB(inBottomSheet ? 0 : 16, 0, inBottomSheet ? 0 : 16, 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            // 如果在 BottomSheet 中，先關閉
            if (inBottomSheet) {
              Navigator.pop(context);
            }
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    WorkoutPlanDetailPage(plan: plan),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
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
            ).then((_) => _loadPlans());
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(20),
              // 🔧 v3.0：已結束計畫有邊框
              border: isEnded 
                  ? Border.all(color: _endedGrey.withOpacity(0.3))
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isEnded ? 0.02 : 0.04),
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
                      colors: isEnded
                          ? [_endedGrey.withOpacity(0.08), _endedGrey.withOpacity(0.03)]
                          : [_primaryOrange.withOpacity(0.08), _lightOrange.withOpacity(0.5)],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      // 圖標
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [themeColor, darkThemeColor],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: themeColor.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          isEnded ? Icons.archive : Icons.fitness_center,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),

                      // 標題和描述
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              plan.planName,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: _textPrimary,
                              ),
                            ),
                            if (plan.description != null &&
                                plan.description!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                plan.description!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),

                      // 狀態標籤
                      _buildStatusBadge(plan.status, isEnded: isEnded),
                    ],
                  ),
                ),

                // 內容區
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // 資訊行
                      Row(
                        children: [
                          _buildInfoTag(
                            icon: Icons.calendar_today,
                            text: _formatDateRange(plan),
                            isEnded: isEnded,
                          ),
                          const SizedBox(width: 12),
                          _buildInfoTag(
                            icon: Icons.repeat,
                            text: '每週 ${plan.days.map((d) => d.dayOfWeek).toSet().length} 天',
                            isEnded: isEnded,
                          ),
                          // 🔧 v3.0：已結束不顯示本週統計
                          if (thisWeekCount > 0 && !isEnded) ...[
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: _successGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.local_fire_department,
                                    size: 14,
                                    color: _successGreen,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '本週 $thisWeekCount 次',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _successGreen,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 16),

                      // 進度條
                      Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isEnded ? '總完成次數' : '累計完成',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _textSecondary,
                                ),
                              ),
                              Text(
                                '$completedDays 次',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: themeColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Stack(
                            children: [
                              // 背景
                              Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              // 進度
                              FractionallySizedBox(
                                widthFactor: progressValue.clamp(0.0, 1.0),
                                child: Container(
                                  height: 8,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [themeColor, darkThemeColor],
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                    boxShadow: isEnded ? null : [
                                      BoxShadow(
                                        color: themeColor.withOpacity(0.3),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // 查看按鈕
                      Container(
                        width: double.infinity,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: themeColor.withOpacity(0.3),
                          ),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                isEnded ? '查看記錄' : '查看詳情',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: themeColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 14,
                                color: themeColor,
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
        ),
      ),
    );
  }

  // 🔧 v3.0 修改：支援已結束狀態
  Widget _buildStatusBadge(String status, {bool isEnded = false}) {
    Color bgColor;
    Color textColor;
    String text;
    IconData icon;

    // 🔧 v3.0：如果是已結束，統一顯示
    if (isEnded) {
      bgColor = _endedGrey.withOpacity(0.1);
      textColor = _endedGrey;
      text = '已結束';
      icon = Icons.archive_outlined;
    } else {
      switch (status) {
        case 'active':
          bgColor = _successGreen.withOpacity(0.1);
          textColor = _successGreen;
          text = '進行中';
          icon = Icons.play_circle_outline;
          break;
        case 'completed':
          bgColor = Colors.blue.withOpacity(0.1);
          textColor = Colors.blue;
          text = '已完成';
          icon = Icons.check_circle_outline;
          break;
        case 'cancelled':
          bgColor = Colors.grey.withOpacity(0.1);
          textColor = Colors.grey;
          text = '已取消';
          icon = Icons.cancel_outlined;
          break;
        default:
          bgColor = _primaryOrange.withOpacity(0.1);
          textColor = _primaryOrange;
          text = status;
          icon = Icons.info_outline;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTag({required IconData icon, required String text, bool isEnded = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _textSecondary),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: _textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateRange(WorkoutPlanModel plan) {
    final start = '${plan.startDate.month}/${plan.startDate.day}';
    final end = plan.endDate != null
        ? '${plan.endDate!.month}/${plan.endDate!.day}'
        : '持續';
    return '$start - $end';
  }
}