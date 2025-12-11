// lib/pages/coach/weekly_report_page.dart
// 🎯 教練週報頁面 v1.0
// ✅ 顯示本週學員總覽
// ✅ 成就展示
// ✅ 學員進度摘要

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/positive_notification_service.dart';
import '../../theme/app_theme.dart';

class WeeklyReportPage extends StatefulWidget {
  const WeeklyReportPage({super.key});

  @override
  State<WeeklyReportPage> createState() => _WeeklyReportPageState();
}

class _WeeklyReportPageState extends State<WeeklyReportPage> {
  final PositiveNotificationService _notificationService = PositiveNotificationService();
  
  WeeklyReport? _report;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    
    try {
      final report = await _notificationService.generateWeeklyReport();
      setState(() {
        _report = report;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('載入週報失敗');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_report != null)
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildOverviewSection(),
                  const SizedBox(height: 24),
                  if (_report!.achievements.isNotEmpty) ...[
                    _buildAchievementsSection(),
                    const SizedBox(height: 24),
                  ],
                  _buildStudentListSection(),
                  const SizedBox(height: 100),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    final report = _report;
    
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.secondaryGradient,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.summarize, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '週報總結',
                        style: AppTextStyles.h3.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (report != null)
                    Text(
                      report.title,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  const SizedBox(height: 8),
                  if (report != null)
                    Text(
                      report.summary,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: _loadReport,
          tooltip: '重新載入',
        ),
        IconButton(
          icon: const Icon(Icons.share, color: Colors.white),
          onPressed: _shareReport,
          tooltip: '分享週報',
        ),
      ],
    );
  }

  Widget _buildOverviewSection() {
    final report = _report!;
    
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
              Icon(Icons.insights, color: AppColors.coach, size: 22),
              const SizedBox(width: 8),
              Text(
                '本週概覽',
                style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.people,
                  label: '總學員',
                  value: '${report.totalStudents}',
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.trending_up,
                  label: '活躍學員',
                  value: '${report.activeStudents}',
                  color: AppColors.coach,
                  subtitle: '${(report.activeRate * 100).toStringAsFixed(0)}%',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.check_circle,
                  label: '達成目標',
                  value: '${report.goalAchievers}',
                  color: AppColors.success,
                  subtitle: '${(report.goalRate * 100).toStringAsFixed(0)}%',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.warning_amber,
                  label: '需關注',
                  value: '${report.needsAttentionCount}',
                  color: report.needsAttentionCount > 0 ? AppColors.warning : AppColors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const Spacer(),
              if (subtitle != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    subtitle,
                    style: AppTextStyles.caption.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: AppTextStyles.h2.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsSection() {
    final achievements = _report!.achievements;
    
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.emoji_events, color: Colors.amber, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                '本週成就',
                style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${achievements.length} 項',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.amber[800],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...achievements.take(5).map((achievement) => _buildAchievementItem(achievement)),
          if (achievements.length > 5)
            TextButton(
              onPressed: () {
                // TODO: 顯示更多成就
              },
              child: Text('查看全部 ${achievements.length} 項成就'),
            ),
        ],
      ),
    );
  }

  Widget _buildAchievementItem(Achievement achievement) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Text(
            achievement.emoji,
            style: const TextStyle(fontSize: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.traineeName,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  achievement.description,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              // TODO: 發送恭喜訊息
            },
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.coach.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.celebration, color: AppColors.coach, size: 18),
            ),
            tooltip: '發送恭喜',
          ),
        ],
      ),
    );
  }

  Widget _buildStudentListSection() {
    final summaries = _report!.studentSummaries;
    
    // 分類學員
    final achievers = summaries.where((s) => s.achievedGoal).toList();
    final needsAttention = summaries.where((s) => s.concerns.isNotEmpty).toList();
    final others = summaries.where((s) => !s.achievedGoal && s.concerns.isEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 達成目標的學員
        if (achievers.isNotEmpty) ...[
          _buildStudentSection(
            title: '🎯 達成目標',
            students: achievers,
            color: AppColors.success,
          ),
          const SizedBox(height: 16),
        ],
        
        // 需要關注的學員
        if (needsAttention.isNotEmpty) ...[
          _buildStudentSection(
            title: '⚠️ 需要關注',
            students: needsAttention,
            color: AppColors.warning,
          ),
          const SizedBox(height: 16),
        ],
        
        // 其他學員
        if (others.isNotEmpty) ...[
          _buildStudentSection(
            title: '📊 其他學員',
            students: others,
            color: AppColors.textSecondary,
          ),
        ],
      ],
    );
  }

  Widget _buildStudentSection({
    required String title,
    required List<StudentWeeklySummary> students,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.small,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${students.length} 位',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...students.map((student) => _buildStudentSummaryCard(student)),
        ],
      ),
    );
  }

  Widget _buildStudentSummaryCard(StudentWeeklySummary student) {
    final progressColor = student.achievedGoal 
        ? AppColors.success 
        : student.completionRate >= 0.5 
            ? AppColors.warning 
            : AppColors.error;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 頭像
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: student.achievedGoal
                      ? const LinearGradient(colors: [Color(0xFF34D399), Color(0xFF10B981)])
                      : AppColors.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    student.traineeName.isNotEmpty
                        ? student.traineeName[0].toUpperCase()
                        : 'S',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 名稱和狀態
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          student.traineeName,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (student.achievedGoal) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.check_circle, color: AppColors.success, size: 16),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${student.completedWorkouts}/${student.targetWorkouts} 次訓練',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // 完成率
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${(student.completionRate * 100).toStringAsFixed(0)}%',
                    style: AppTextStyles.h4.copyWith(
                      color: progressColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '完成率',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // 進度條
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: student.completionRate.clamp(0.0, 1.0),
              backgroundColor: progressColor.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              minHeight: 6,
            ),
          ),
          // 亮點或關注點
          if (student.highlights.isNotEmpty || student.concerns.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ...student.highlights.map((h) => _buildTag(h, AppColors.success)),
                ...student.concerns.map((c) => _buildTag(c, AppColors.warning)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: AppTextStyles.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _shareReport() {
    // TODO: 實現分享功能
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('分享功能開發中...'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}