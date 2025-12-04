// lib/pages/workout/workout_plan_list_page.dart
// ✅ v2.0 - Soft UI 風格
// 🔥 統一使用 UnifiedWorkoutService
// 🔥 使用 WorkoutProgressService 獲取進度
// 🔥 優化進度顯示（本週完成次數）
// 🔥 現代化 UI/UX 設計

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/unified_workout_service.dart'; // ✅ 統一使用
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
  final UnifiedWorkoutService _workoutService = UnifiedWorkoutService(); // ✅ 統一使用
  final WorkoutProgressService _progressService = WorkoutProgressService();

  List<WorkoutPlanModel> _plans = [];
  Map<String, Map<String, int>> _planProgressCache = {};
  bool _isLoading = true;
  late AnimationController _animController;

  // 🎨 Soft UI 配色
  static const Color _primaryOrange = Color(0xFFFF9800);
  static const Color _lightOrange = Color(0xFFFFF3E0);
  static const Color _darkOrange = Color(0xFFF57C00);
  static const Color _bgColor = Color(0xFFF8F9FA);
  static const Color _cardColor = Color(0xFFFFFFFF);
  static const Color _textPrimary = Color(0xFF2D3748);
  static const Color _textSecondary = Color(0xFF718096);
  static const Color _successGreen = Color(0xFF48BB78);

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

  Future<void> _loadPlans() async {
    setState(() => _isLoading = true);
    try {
      final plans = await _workoutService.getMyWorkoutPlans();

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
                      '我的計畫',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_plans.length} 個',
                      style: TextStyle(
                        fontSize: 14,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildPlansList(),
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
    final activePlans = _plans.where((p) => p.status == 'active').length;
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
                value: '$activePlans',
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

  // ========== 📋 Plans List ==========
  Widget _buildPlansList() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final plan = _plans[index];
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
                  child: _buildPlanCard(plan),
                ),
              );
            },
          );
        },
        childCount: _plans.length,
      ),
    );
  }

  Widget _buildPlanCard(WorkoutPlanModel plan) {
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
    final isActive = plan.status == 'active';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
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
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
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
                      colors: isActive
                          ? [
                              _primaryOrange.withOpacity(0.08),
                              _lightOrange.withOpacity(0.5),
                            ]
                          : [
                              Colors.grey.withOpacity(0.05),
                              Colors.grey.withOpacity(0.02),
                            ],
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
                          gradient: isActive
                              ? LinearGradient(
                                  colors: [_primaryOrange, _darkOrange],
                                )
                              : null,
                          color: isActive ? null : Colors.grey[400],
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: isActive
                              ? [
                                  BoxShadow(
                                    color: _primaryOrange.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: const Icon(
                          Icons.fitness_center,
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
                      _buildStatusBadge(plan.status),
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
                          ),
                          const SizedBox(width: 12),
                          _buildInfoTag(
                            icon: Icons.repeat,
                            text: '每週 $totalDays 天',
                          ),
                          if (thisWeekCount > 0) ...[
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
                                '累計完成',
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
                                  color: _primaryOrange,
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
                                      colors: [_primaryOrange, _darkOrange],
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _primaryOrange.withOpacity(0.3),
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

                      // 查看詳情按鈕
                      Container(
                        width: double.infinity,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _primaryOrange.withOpacity(0.3),
                          ),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '查看詳情',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _primaryOrange,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 14,
                                color: _primaryOrange,
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

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    String text;
    IconData icon;

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

  Widget _buildInfoTag({required IconData icon, required String text}) {
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