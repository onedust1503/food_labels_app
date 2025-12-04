// lib/pages/coach/trainee_workout_tab.dart
// 🎯 學員訓練日誌分頁 v2.2
// ✅ 修復：從 workoutSessions 讀取詳細動作資料
// ✅ 修復：移除 orderBy 避免索引問題
// ✅ 莫蘭迪設計風格

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';

class TraineeWorkoutTab extends StatefulWidget {
  final String traineeId;

  const TraineeWorkoutTab({
    Key? key,
    required this.traineeId,
  }) : super(key: key);

  @override
  State<TraineeWorkoutTab> createState() => _TraineeWorkoutTabState();
}

class _TraineeWorkoutTabState extends State<TraineeWorkoutTab> {
  // 切換數據來源
  bool _showCompletionsOnly = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilterToggle(),
        Expanded(
          child: _showCompletionsOnly 
              ? _buildCompletionsList() 
              : _buildAllLogsList(),
        ),
      ],
    );
  }

  // 🎨 篩選切換按鈕
  Widget _buildFilterToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.divider),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildToggleButton(
              label: '計畫訓練',
              icon: Icons.assignment_outlined,
              isSelected: _showCompletionsOnly,
              onTap: () => setState(() => _showCompletionsOnly = true),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildToggleButton(
              label: '全部紀錄',
              icon: Icons.list_alt,
              isSelected: !_showCompletionsOnly,
              onTap: () => setState(() => _showCompletionsOnly = false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppColors.coach.withOpacity(0.12) 
              : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.coach : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? AppColors.coach : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTextStyles.label.copyWith(
                color: isSelected ? AppColors.coach : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔥 計畫訓練完成列表（移除 orderBy 避免索引問題）
  Widget _buildCompletionsList() {
    return StreamBuilder<QuerySnapshot>(
      // 🔥 修復：只用 where，不用 orderBy，避免需要複合索引
      stream: FirebaseFirestore.instance
          .collection('workoutCompletions')
          .where('userId', isEqualTo: widget.traineeId)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState('尚無計畫訓練紀錄', '學員完成訓練計畫後會顯示在這裡');
        }

        // 🔥 手動排序（避免需要複合索引）
        final completions = snapshot.data!.docs.toList();
        completions.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aDate = _getDateTime(aData['createdAt'] ?? aData['completionDate']);
          final bDate = _getDateTime(bData['createdAt'] ?? bData['completionDate']);
          return bDate.compareTo(aDate); // 降序
        });

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: completions.length,
          itemBuilder: (context, index) {
            final data = completions[index].data() as Map<String, dynamic>;
            return _buildCompletionCard(data);
          },
        );
      },
    );
  }

  // 🔥 計畫訓練卡片
  Widget _buildCompletionCard(Map<String, dynamic> data) {
    final planName = data['planName']?.toString() ?? '未命名計畫';
    final dayName = data['dayName']?.toString() ?? '';
    final dayOfWeek = data['dayOfWeek']?.toString() ?? '';
    final isOnSchedule = data['isOnSchedule'] as bool? ?? false;
    final totalDuration = _toInt(data['totalDuration']);
    final totalSets = _toInt(data['totalSets']);
    final totalExercises = _toInt(data['totalExercises']);
    final exercisesCompleted = _toInt(data['exercisesCompleted']);
    final sessionId = data['sessionId']?.toString() ?? '';
    
    final exerciseCount = totalExercises > 0 ? totalExercises : exercisesCompleted;
    
    DateTime actualDate = _getDateTime(data['completionDate'] ?? data['createdAt']);

    final statusColor = isOnSchedule ? AppColors.success : AppColors.warning;
    final statusText = isOnSchedule ? '按時完成' : '補做完成';
    final statusIcon = isOnSchedule ? Icons.check_circle : Icons.schedule;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.small,
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showCompletionDetail(context, data, actualDate, sessionId),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // 日期圓圈
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: isOnSchedule 
                            ? AppColors.successGradient 
                            : AppColors.warningGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: AppShadows.small,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${actualDate.day}',
                            style: AppTextStyles.h3.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${actualDate.month}月',
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
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
                          const SizedBox(height: 4),
                          if (dayOfWeek.isNotEmpty || dayName.isNotEmpty)
                            Text(
                              dayName.isNotEmpty ? dayName : dayOfWeek,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: statusColor.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 14, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            statusText,
                            style: AppTextStyles.caption.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildStatChip(
                      Icons.fitness_center,
                      '$exerciseCount 動作',
                      AppColors.primary,
                    ),
                    if (totalSets > 0)
                      _buildStatChip(
                        Icons.repeat,
                        '$totalSets 組',
                        AppColors.accent3,
                      ),
                    _buildStatChip(
                      Icons.timer_outlined,
                      _formatDuration(totalDuration),
                      AppColors.warning,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🔥 全部訓練記錄（移除 orderBy 避免索引問題）
  Widget _buildAllLogsList() {
    return StreamBuilder<QuerySnapshot>(
      // 🔥 修復：只用 where，不用 orderBy
      stream: FirebaseFirestore.instance
          .collection('workoutLogs')
          .where('userId', isEqualTo: widget.traineeId)
          .limit(30)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState('尚無訓練紀錄', '學員開始訓練後會顯示在這裡');
        }

        // 🔥 手動排序
        final logs = snapshot.data!.docs.toList();
        logs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aDate = _getDateTime(aData['date'] ?? aData['createdAt']);
          final bDate = _getDateTime(bData['date'] ?? bData['createdAt']);
          return bDate.compareTo(aDate);
        });

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: logs.length,
          itemBuilder: (context, index) {
            final log = logs[index].data() as Map<String, dynamic>;
            final logId = logs[index].id;
            return _buildLogCard(log, logId);
          },
        );
      },
    );
  }

  // 🔥 修復：從 sessionId 讀取詳細資料
  Widget _buildLogCard(Map<String, dynamic> log, String logId) {
    DateTime date = _getDateTime(log['date'] ?? log['createdAt']);
    
    final planName = log['planName']?.toString() ?? '自由訓練';
    final duration = _toInt(log['duration'] ?? log['totalDuration']);
    final sessionId = log['sessionId']?.toString() ?? '';
    final notes = log['notes']?.toString() ?? '';
    
    // 嘗試從多個可能的欄位讀取動作數量
    int exerciseCount = 0;
    if (log['exercises'] is List) {
      exerciseCount = (log['exercises'] as List).length;
    } else if (log['exerciseCount'] != null) {
      exerciseCount = _toInt(log['exerciseCount']);
    } else if (log['totalExercises'] != null) {
      exerciseCount = _toInt(log['totalExercises']);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.small,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showLogDetailWithSession(context, log, date, sessionId),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.coach.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${date.day}',
                        style: AppTextStyles.h3.copyWith(
                          color: AppColors.coach,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${date.month}月',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.coach,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        planName,
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _buildStatChip(
                            Icons.fitness_center,
                            '$exerciseCount 動作',
                            AppColors.primary,
                          ),
                          _buildStatChip(
                            Icons.timer_outlined,
                            _formatDuration(duration),
                            AppColors.warning,
                          ),
                        ],
                      ),
                      // 顯示備註提示
                      if (notes.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          notes,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textTertiary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                Icon(
                  Icons.chevron_right,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // 🔥 顯示計畫完成詳情（從 workoutSessions 讀取動作）
  void _showCompletionDetail(
    BuildContext context,
    Map<String, dynamic> data,
    DateTime date,
    String sessionId,
  ) {
    final planName = data['planName']?.toString() ?? '未命名計畫';
    final isOnSchedule = data['isOnSchedule'] as bool? ?? false;
    final totalDuration = _toInt(data['totalDuration']);
    final totalSets = _toInt(data['totalSets']);
    final notes = data['notes']?.toString() ?? '';

    final statusColor = isOnSchedule ? AppColors.success : AppColors.warning;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 標題
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: isOnSchedule 
                                  ? AppColors.successGradient 
                                  : AppColors.warningGradient,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.fitness_center,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  planName,
                                  style: AppTextStyles.h3.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${date.year}/${date.month}/${date.day}',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              isOnSchedule ? '按時' : '補做',
                              style: AppTextStyles.label.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // 統計卡片
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: AppColors.secondaryGradient,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildDetailStat('時長', _formatDuration(totalDuration)),
                            _buildDetailDivider(),
                            _buildDetailStat('總組數', '$totalSets'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 🔥 從 workoutSessions 讀取動作列表
                      Text(
                        '訓練動作',
                        style: AppTextStyles.h4.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      if (sessionId.isNotEmpty)
                        _buildExercisesFromSession(sessionId)
                      else
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              '無動作資料',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ),
                        ),

                      // 備註
                      if (notes.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text(
                          '備註',
                          style: AppTextStyles.h4.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.warning.withOpacity(0.2),
                            ),
                          ),
                          child: Text(
                            notes,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textPrimary,
                            ),
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
      ),
    );
  }

  // 🔥 從 workoutSessions 子集合讀取動作
  Widget _buildExercisesFromSession(String sessionId) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('workoutSessions')
          .doc(sessionId)
          .collection('exercises')
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.coach),
              ),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) {
          // 嘗試從用戶子集合讀取
          return _buildExercisesFromUserSession(sessionId);
        }

        final exercises = snapshot.data!.docs;
        
        return Column(
          children: exercises.asMap().entries.map((entry) {
            final index = entry.key;
            final exerciseData = entry.value.data() as Map<String, dynamic>;
            return _buildExerciseItemFromData(index, exerciseData);
          }).toList(),
        );
      },
    );
  }

  // 🔥 備用：從 users/{userId}/workoutSessions 讀取
  Widget _buildExercisesFromUserSession(String sessionId) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.traineeId)
          .collection('workoutSessions')
          .doc(sessionId)
          .collection('exercises')
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.coach),
              ),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '無動作資料',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          );
        }

        final exercises = snapshot.data!.docs;
        
        return Column(
          children: exercises.asMap().entries.map((entry) {
            final index = entry.key;
            final exerciseData = entry.value.data() as Map<String, dynamic>;
            return _buildExerciseItemFromData(index, exerciseData);
          }).toList(),
        );
      },
    );
  }

  Widget _buildExerciseItemFromData(int index, Map<String, dynamic> exercise) {
    final name = exercise['exerciseName']?.toString() ?? 
                 exercise['name']?.toString() ?? '未命名動作';
    final completedSets = _toInt(exercise['completedSets'] ?? exercise['sets']);
    final totalSets = _toInt(exercise['totalSets'] ?? exercise['sets']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.coach.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: AppTextStyles.label.copyWith(
                  color: AppColors.coach,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (totalSets > 0 || completedSets > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                totalSets > 0 ? '$completedSets/$totalSets 組' : '$completedSets 組',
                style: AppTextStyles.label.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 🔥 顯示舊版日誌詳情（也嘗試讀取 session）
  void _showLogDetailWithSession(
    BuildContext context,
    Map<String, dynamic> log,
    DateTime date,
    String sessionId,
  ) {
    final planName = log['planName']?.toString() ?? '自由訓練';
    final duration = _toInt(log['duration'] ?? log['totalDuration']);
    final notes = log['notes']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
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
                            child: const Icon(
                              Icons.fitness_center,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  planName,
                                  style: AppTextStyles.h3.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${date.year}/${date.month}/${date.day}',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      if (duration > 0) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: AppColors.secondaryGradient,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.timer, color: Colors.white, size: 24),
                              const SizedBox(width: 12),
                              Text(
                                '訓練時長：',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                              Text(
                                _formatDuration(duration),
                                style: AppTextStyles.h3.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      
                      Text(
                        '訓練動作',
                        style: AppTextStyles.h4.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // 嘗試從 session 讀取動作
                      if (sessionId.isNotEmpty)
                        _buildExercisesFromSession(sessionId)
                      else if (log['exercises'] is List && (log['exercises'] as List).isNotEmpty)
                        _buildExerciseListFromLog(log['exercises'] as List)
                      else
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              '無動作資料',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ),
                        ),
                      
                      if (notes.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text(
                          '備註',
                          style: AppTextStyles.h4.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            notes,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textPrimary,
                            ),
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
      ),
    );
  }

  Widget _buildExerciseListFromLog(List exercises) {
    return Column(
      children: exercises.asMap().entries.map((entry) {
        final index = entry.key;
        final exercise = entry.value as Map<String, dynamic>;
        return _buildExerciseItemFromData(index, exercise);
      }).toList(),
    );
  }

  Widget _buildDetailStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: Colors.white.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.h4.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailDivider() {
    return Container(
      width: 1,
      height: 40,
      color: Colors.white.withOpacity(0.3),
    );
  }

  // 🎨 狀態 UI
  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(AppColors.coach),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 60, color: AppColors.error),
          const SizedBox(height: 16),
          Text(
            '載入失敗',
            style: AppTextStyles.h4.copyWith(color: AppColors.textSecondary),
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

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.coach.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.fitness_center,
              size: 64,
              color: AppColors.coach.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: AppTextStyles.h4.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  // 🔧 輔助方法
  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

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

  String _formatDuration(int minutes) {
    if (minutes < 60) return '$minutes 分鐘';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) return '$hours 小時';
    return '$hours 小時 $mins 分';
  }
}