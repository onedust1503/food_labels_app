// lib/pages/coach/trainee_workout_tab.dart
// 🎯 學員訓練日誌分頁 v4.5 (P2)
// ✅ v4.5 P2 新增：返回時刷新頁面，紅點立即消失
// ✅ v4.4 P2 修復：發送回覆訊息時才標記協助已處理（由 ChatDetailPage 處理）
// ✅ v4.3 P2 新增：回覆時帶上訓練卡片、狀態標籤+需要協助同時顯示
// ✅ v4.2 P2 修復：快速回覆使用 ChatService.createOrGetChatRoom
// ✅ v4.1 P2 修復：移除 orderBy 避免需要索引
// ✅ v4.0 P2 新增：「需要協助」標記、feedback 顯示、快速回覆按鈕
// ✅ v3.0 整合新的 CompletionStatus 狀態系統

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../models/completion_status.dart';
import '../../services/workout_completion_service.dart';
import '../../services/chat_service.dart';  // 🔥 v4.2：聊天服務
import '../../components/completion_status_badge.dart';
import '../chat_detail_page.dart';

class TraineeWorkoutTab extends StatefulWidget {
  final String traineeId;
  final String traineeName; // 🔥 v4.0：新增學員名稱用於聊天室

  const TraineeWorkoutTab({
    Key? key,
    required this.traineeId,
    this.traineeName = '', // 可選參數
  }) : super(key: key);

  @override
  State<TraineeWorkoutTab> createState() => _TraineeWorkoutTabState();
}

class _TraineeWorkoutTabState extends State<TraineeWorkoutTab> {
  bool _showCompletionsOnly = true;
  final WorkoutCompletionService _completionService = WorkoutCompletionService();
  
  // 🔥 v4.0 P2：篩選器狀態
  String _currentFilter = 'all'; // all, needsHelp, onTime, early, makeup
  
  // 🔥 v4.0 P2：統計數據
  int _needsHelpCount = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilterToggle(),
        // 🔥 v4.0 P2：篩選器列
        _buildFilterBar(),
        Expanded(
          child: _showCompletionsOnly 
              ? _buildCompletionsList() 
              : _buildAllLogsList(),
        ),
      ],
    );
  }

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
            // 🔥 v4.0 P2：顯示需要協助數量
            if (label == '計畫訓練' && _needsHelpCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$_needsHelpCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 🔥 v4.0 P2：篩選器列
  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('all', '全部', Icons.list, null),
            const SizedBox(width: 8),
            _buildFilterChip('needsHelp', '需要協助', Icons.help_outline, Colors.red,
                count: _needsHelpCount),
            const SizedBox(width: 8),
            _buildFilterChip('onTime', '準時', Icons.check_circle, Colors.green),
            const SizedBox(width: 8),
            _buildFilterChip('early', '提前', Icons.fast_forward, Colors.blue),
            const SizedBox(width: 8),
            _buildFilterChip('makeup', '補做', Icons.update, Colors.orange),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String filter, String label, IconData icon, Color? color, {int? count}) {
    final isSelected = _currentFilter == filter;
    final chipColor = color ?? AppColors.coach;

    return GestureDetector(
      onTap: () => setState(() => _currentFilter = filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? chipColor : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? chipColor : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : chipColor,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
            if (count != null && count > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withOpacity(0.3) : chipColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : chipColor,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 🔥 v4.0 P2：計畫訓練完成列表（含 feedback）
  Widget _buildCompletionsList() {
    return StreamBuilder<QuerySnapshot>(
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

        final completions = snapshot.data!.docs.toList();
        completions.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aDate = _getDateTime(aData['actualDate'] ?? aData['createdAt'] ?? aData['completionDate']);
          final bDate = _getDateTime(bData['actualDate'] ?? bData['createdAt'] ?? bData['completionDate']);
          return bDate.compareTo(aDate);
        });

        // 🔥 v4.0 P2：為每個 completion 獲取 feedback
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _enrichCompletionsWithFeedback(completions),
          builder: (context, enrichedSnapshot) {
            if (!enrichedSnapshot.hasData) {
              return _buildLoadingState();
            }

            final enrichedCompletions = enrichedSnapshot.data!;
            
            // 🔥 更新需要協助數量
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final count = enrichedCompletions.where((c) => c['needsHelp'] == true).length;
              if (_needsHelpCount != count) {
                setState(() => _needsHelpCount = count);
              }
            });

            // 🔥 v4.0 P2：根據篩選器過濾
            final filteredCompletions = _filterCompletions(enrichedCompletions);

            if (filteredCompletions.isEmpty) {
              return _buildEmptyState(
                _currentFilter == 'needsHelp' ? '沒有需要協助的訓練' : '沒有符合條件的訓練',
                '切換篩選器查看其他訓練',
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredCompletions.length,
              itemBuilder: (context, index) {
                return _buildCompletionCardV4(filteredCompletions[index]);
              },
            );
          },
        );
      },
    );
  }

  // 🔥 v4.3 P2：為 completions 批量獲取 feedback（含已解決狀態）
  Future<List<Map<String, dynamic>>> _enrichCompletionsWithFeedback(
    List<QueryDocumentSnapshot> completions,
  ) async {
    List<Map<String, dynamic>> enriched = [];

    for (var doc in completions) {
      final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
      data['docId'] = doc.id;

      final sessionId = data['sessionId']?.toString() ?? '';
      
      if (sessionId.isNotEmpty) {
        try {
          final sessionDoc = await FirebaseFirestore.instance
              .collection('workoutSessions')
              .doc(sessionId)
              .get();

          if (sessionDoc.exists) {
            final sessionData = sessionDoc.data();
            final feedback = sessionData?['feedback'] as Map<String, dynamic>?;
            
            if (feedback != null) {
              final needHelp = feedback['needHelp'] ?? false;
              final helpResolved = feedback['helpResolved'] ?? false;
              
              // 🔥 v4.3：只有未解決的才算需要協助
              data['needsHelp'] = needHelp && !helpResolved;
              data['helpResolved'] = helpResolved;
              data['helpMessage'] = feedback['helpMessage'];
              data['rpe'] = feedback['rpe'];
              data['fatigueLevel'] = feedback['fatigueLevel'];
              data['mood'] = feedback['mood'];
              data['feedbackNote'] = feedback['note'];
            }
          }
        } catch (e) {
          // 忽略錯誤，繼續處理其他記錄
        }
      }

      enriched.add(data);
    }

    return enriched;
  }

  // 🔥 v4.0 P2：根據篩選器過濾
  List<Map<String, dynamic>> _filterCompletions(List<Map<String, dynamic>> completions) {
    if (_currentFilter == 'all') return completions;

    return completions.where((data) {
      final planDayOfWeek = data['planDayOfWeek']?.toString() ?? 
                            data['dayOfWeek']?.toString() ?? '';
      final actualDate = _getDateTime(
        data['actualDate'] ?? data['completionDate'] ?? data['createdAt']
      );

      final statusType = _completionService.calculateStatus(
        planDayOfWeek: planDayOfWeek,
        actualDate: actualDate,
        referenceDate: actualDate,
      );

      switch (_currentFilter) {
        case 'needsHelp':
          return data['needsHelp'] == true;
        case 'onTime':
          return statusType == CompletionStatusType.onTime;
        case 'early':
          return statusType == CompletionStatusType.early;
        case 'makeup':
          return statusType == CompletionStatusType.makeup;
        default:
          return true;
      }
    }).toList();
  }

  // 🔥 v4.0 P2：計畫訓練卡片（含需要協助標記）
  Widget _buildCompletionCardV4(Map<String, dynamic> data) {
    final planName = data['planName']?.toString() ?? '未命名計畫';
    final planDayOfWeek = data['planDayOfWeek']?.toString() ?? 
                          data['dayOfWeek']?.toString() ?? '';
    final actualDayOfWeek = data['actualDayOfWeek']?.toString() ?? '';
    final totalDuration = _toInt(data['totalDuration']);
    final totalSets = _toInt(data['totalSets']);
    final totalExercises = _toInt(data['totalExercises']);
    final exercisesCompleted = _toInt(data['exercisesCompleted']);
    final sessionId = data['sessionId']?.toString() ?? '';
    
    // 🔥 v4.0 P2：feedback 欄位
    final needsHelp = data['needsHelp'] == true;
    final helpMessage = data['helpMessage']?.toString() ?? '';
    
    final exerciseCount = totalExercises > 0 ? totalExercises : exercisesCompleted;
    
    DateTime actualDate = _getDateTime(
      data['actualDate'] ?? data['completionDate'] ?? data['createdAt']
    );

    final statusType = _completionService.calculateStatus(
      planDayOfWeek: planDayOfWeek,
      actualDate: actualDate,
      referenceDate: actualDate,
    );
    final status = CompletionStatus.fromType(statusType);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.small,
        // 🔥 v4.0 P2：需要協助時加紅色邊框
        border: Border.all(
          color: needsHelp 
              ? Colors.red.withOpacity(0.5) 
              : status.color.withOpacity(0.3),
          width: needsHelp ? 2 : 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showCompletionDetailV4(context, data, actualDate, sessionId, status),
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
                        color: needsHelp 
                            ? Colors.red.withOpacity(0.1)
                            : status.backgroundColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: needsHelp 
                              ? Colors.red.withOpacity(0.5)
                              : status.color.withOpacity(0.5),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${actualDate.day}',
                            style: AppTextStyles.h3.copyWith(
                              color: needsHelp ? Colors.red : status.color,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${actualDate.month}月',
                            style: AppTextStyles.caption.copyWith(
                              color: needsHelp 
                                  ? Colors.red.withOpacity(0.8)
                                  : status.color.withOpacity(0.8),
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
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  planName,
                                  style: AppTextStyles.h4.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              // 🔥 v4.0 P2：需要協助標籤
                              if (needsHelp)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.red.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.help_outline,
                                        color: Colors.red,
                                        size: 12,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '需要協助',
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          
                          // 計畫日 vs 實際完成日
                          Row(
                            children: [
                              Text(
                                '計畫：$planDayOfWeek',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              if (actualDayOfWeek.isNotEmpty && 
                                  actualDayOfWeek != planDayOfWeek) ...[
                                Text(
                                  ' → ',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                                Text(
                                  '實際：$actualDayOfWeek',
                                  style: AppTextStyles.caption.copyWith(
                                    color: status.color,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // 🔥 v4.3：狀態標籤區（需要協助 + 完成狀態都顯示）
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // 狀態標籤（準時/提前/補做）
                        CompletionStatusBadge(
                          statusType: statusType,
                          compact: true,
                        ),
                        // 🔥 需要協助標籤（顯示在下方）
                        if (needsHelp) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.support_agent,
                                  color: Colors.white,
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '待回覆',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // 統計資訊
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

                // 🔥 v4.0 P2：顯示協助訊息預覽
                if (needsHelp && helpMessage.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.red.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          color: Colors.red,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            helpMessage,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.red.shade700,
                            ),
                            maxLines: 2,
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
        ),
      ),
    );
  }

  // 全部訓練記錄（含自由訓練）
  // 🔥 v4.1：移除 orderBy 避免需要索引，改為本地排序
  Widget _buildAllLogsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('workoutSessions')
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
          return _buildEmptyState('尚無訓練紀錄', '學員開始訓練後會顯示在這裡');
        }

        // 🔥 v4.1：本地排序（按 endedAt 降序）
        final sessions = snapshot.data!.docs.toList();
        sessions.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aDate = _getDateTime(aData['endedAt'] ?? aData['createdAt']);
          final bDate = _getDateTime(bData['endedAt'] ?? bData['createdAt']);
          return bDate.compareTo(aDate);
        });

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sessions.length,
          itemBuilder: (context, index) {
            final session = sessions[index].data() as Map<String, dynamic>;
            final sessionId = sessions[index].id;
            return _buildSessionCard(session, sessionId);
          },
        );
      },
    );
  }

  // 🔥 v4.0 P2：Session 卡片（來自 workoutSessions）
  Widget _buildSessionCard(Map<String, dynamic> session, String sessionId) {
    final name = session['name']?.toString() ?? '訓練';
    final planId = session['planId']?.toString() ?? '';
    final isPlanWorkout = planId.isNotEmpty;
    final endedAt = _getDateTime(session['endedAt']);
    
    // 計算時長
    final startedAt = _getDateTime(session['startedAt']);
    int duration = session['totalDurationSeconds'] ?? 0;
    if (duration == 0) {
      duration = endedAt.difference(startedAt).inMinutes;
    } else {
      duration = (duration / 60).round();
    }

    // 計算動作數
    final exercises = session['exercises'] as List<dynamic>? ?? [];
    final exerciseCount = exercises.length;

    // 獲取 feedback
    final feedback = session['feedback'] as Map<String, dynamic>?;
    final needsHelp = feedback?['needHelp'] == true;
    final helpMessage = feedback?['helpMessage']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.small,
        border: Border.all(
          color: needsHelp 
              ? Colors.red.withOpacity(0.5)
              : isPlanWorkout 
                  ? AppColors.coach.withOpacity(0.3)
                  : Colors.purple.withOpacity(0.3),
          width: needsHelp ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showSessionDetail(context, session, sessionId),
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
                        color: needsHelp 
                            ? Colors.red.withOpacity(0.1)
                            : isPlanWorkout 
                                ? AppColors.coach.withOpacity(0.12)
                                : Colors.purple.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${endedAt.day}',
                            style: AppTextStyles.h3.copyWith(
                              color: needsHelp 
                                  ? Colors.red
                                  : isPlanWorkout ? AppColors.coach : Colors.purple,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${endedAt.month}月',
                            style: AppTextStyles.caption.copyWith(
                              color: needsHelp 
                                  ? Colors.red
                                  : isPlanWorkout ? AppColors.coach : Colors.purple,
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
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: AppTextStyles.bodyLarge.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              // 訓練類型標籤
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isPlanWorkout 
                                      ? AppColors.coach.withOpacity(0.12)
                                      : Colors.purple.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isPlanWorkout ? '計畫' : '自由',
                                  style: AppTextStyles.caption.copyWith(
                                    color: isPlanWorkout ? AppColors.coach : Colors.purple,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              // 🔥 v4.0 P2：需要協助標籤
                              if (needsHelp) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.help_outline,
                                    color: Colors.red,
                                    size: 14,
                                  ),
                                ),
                              ],
                            ],
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
                        ],
                      ),
                    ),

                    Icon(
                      Icons.chevron_right,
                      color: AppColors.textTertiary,
                    ),
                  ],
                ),
                
                // 🔥 v4.0 P2：協助訊息預覽
                if (needsHelp && helpMessage.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.chat_bubble_outline, color: Colors.red, size: 14),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            helpMessage,
                            style: TextStyle(fontSize: 12, color: Colors.red.shade700),
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

  // 🔥 v4.0 P2：顯示計畫完成詳情（含 feedback 和快速回覆）
  void _showCompletionDetailV4(
    BuildContext context,
    Map<String, dynamic> data,
    DateTime date,
    String sessionId,
    CompletionStatus status,
  ) {
    final planName = data['planName']?.toString() ?? '未命名計畫';
    final planDayOfWeek = data['planDayOfWeek']?.toString() ?? 
                          data['dayOfWeek']?.toString() ?? '';
    final actualDayOfWeek = data['actualDayOfWeek']?.toString() ?? '';
    final totalDuration = _toInt(data['totalDuration']);
    final totalSets = _toInt(data['totalSets']);
    final caloriesBurned = _toDouble(data['caloriesBurned']);
    
    // 🔥 v4.0 P2：feedback 欄位
    final needsHelp = data['needsHelp'] == true;
    final helpMessage = data['helpMessage']?.toString() ?? '';
    final rpe = data['rpe'];
    final fatigueLevel = data['fatigueLevel']?.toString();
    final mood = data['mood']?.toString();
    final feedbackNote = data['feedbackNote']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
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
                      // 標題區
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: needsHelp 
                                  ? Colors.red.withOpacity(0.1)
                                  : status.backgroundColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: needsHelp 
                                    ? Colors.red.withOpacity(0.5)
                                    : status.color.withOpacity(0.5),
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              needsHelp ? Icons.help_outline : status.icon,
                              color: needsHelp ? Colors.red : status.color,
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
                                  needsHelp ? '學員需要您的協助' : status.description,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: needsHelp ? Colors.red : status.color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!needsHelp)
                            CompletionStatusBadge(statusType: status.type),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // 🔥 v4.0 P2：需要協助區塊（醒目顯示）
                      if (needsHelp) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.3),
                              width: 2,
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
                                      color: Colors.red.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.warning_amber_rounded,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '學員需要協助',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                              if (helpMessage.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    helpMessage,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textPrimary,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // 日期資訊區
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            _buildInfoRow(
                              Icons.calendar_today,
                              '計畫日',
                              planDayOfWeek,
                            ),
                            const Divider(height: 16),
                            _buildInfoRow(
                              Icons.event_available,
                              '實際完成',
                              '${date.month}/${date.day} ${actualDayOfWeek.isNotEmpty ? actualDayOfWeek : ''}',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 統計卡片
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: needsHelp 
                                ? [Colors.red.withOpacity(0.8), Colors.red]
                                : [status.color.withOpacity(0.8), status.color],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildDetailStat('時長', _formatDuration(totalDuration)),
                            _buildDetailDivider(),
                            _buildDetailStat('總組數', '$totalSets'),
                            if (caloriesBurned > 0) ...[
                              _buildDetailDivider(),
                              _buildDetailStat('卡路里', '${caloriesBurned.round()}'),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 🔥 v4.0 P2：Feedback 資訊
                      if (rpe != null || fatigueLevel != null || mood != null || feedbackNote.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.coach.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.mood, color: AppColors.coach, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    '訓練回饋',
                                    style: AppTextStyles.h4.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              
                              if (rpe != null)
                                _buildFeedbackRow('運動自覺強度', 'RPE $rpe/10', _getRpeColor(rpe)),
                              
                              if (fatigueLevel != null)
                                _buildFeedbackRow('疲勞程度', _getFatigueLevelText(fatigueLevel), _getFatigueLevelColor(fatigueLevel)),
                              
                              if (mood != null)
                                _buildFeedbackRow('心情', _getMoodText(mood), _getMoodColor(mood)),
                              
                              if (feedbackNote.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '備註',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        feedbackNote,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: AppColors.textPrimary,
                                          height: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // 動作列表
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

                      const SizedBox(height: 24),

                      // 🔥 v4.3 P2：快速回覆按鈕（帶訓練卡片）
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _navigateToChatWithReply(data);  // 🔥 傳入訓練資料
                          },
                          icon: const Icon(Icons.reply),
                          label: Text(needsHelp ? '立即回覆' : '傳送訊息'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: needsHelp ? Colors.red : AppColors.coach,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
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

  // 🔥 v4.0 P2：顯示 Session 詳情
  void _showSessionDetail(BuildContext context, Map<String, dynamic> session, String sessionId) {
    final name = session['name']?.toString() ?? '訓練';
    final planId = session['planId']?.toString() ?? '';
    final isPlanWorkout = planId.isNotEmpty;
    final endedAt = _getDateTime(session['endedAt']);
    
    // 計算時長
    int duration = session['totalDurationSeconds'] ?? 0;
    if (duration > 0) {
      duration = (duration / 60).round();
    }

    final totalCalories = _toDouble(session['totalCalories']);
    
    // 獲取 feedback
    final feedback = session['feedback'] as Map<String, dynamic>?;
    final needsHelp = feedback?['needHelp'] == true;
    final helpMessage = feedback?['helpMessage']?.toString() ?? '';
    final rpe = feedback?['rpe'];
    final fatigueLevel = feedback?['fatigueLevel']?.toString();
    final mood = feedback?['mood']?.toString();
    final feedbackNote = feedback?['note']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                              color: needsHelp 
                                  ? Colors.red.withOpacity(0.1)
                                  : isPlanWorkout 
                                      ? AppColors.coach.withOpacity(0.12)
                                      : Colors.purple.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              needsHelp 
                                  ? Icons.help_outline
                                  : Icons.fitness_center,
                              color: needsHelp 
                                  ? Colors.red
                                  : isPlanWorkout ? AppColors.coach : Colors.purple,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '${endedAt.year}/${endedAt.month}/${endedAt.day}',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isPlanWorkout 
                                  ? AppColors.coach.withOpacity(0.12)
                                  : Colors.purple.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isPlanWorkout ? '計畫' : '自由',
                              style: TextStyle(
                                color: isPlanWorkout ? AppColors.coach : Colors.purple,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // 🔥 需要協助區塊
                      if (needsHelp) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.red.withOpacity(0.3), width: 2),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
                                  const SizedBox(width: 8),
                                  Text(
                                    '學員需要協助',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                              if (helpMessage.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(helpMessage, style: TextStyle(fontSize: 14, height: 1.5)),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // 統計
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: needsHelp 
                                ? [Colors.red.withOpacity(0.8), Colors.red]
                                : isPlanWorkout 
                                    ? [AppColors.coach.withOpacity(0.8), AppColors.coach]
                                    : [Colors.purple.withOpacity(0.8), Colors.purple],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildDetailStat('時長', _formatDuration(duration)),
                            if (totalCalories > 0) ...[
                              _buildDetailDivider(),
                              _buildDetailStat('卡路里', '${totalCalories.round()}'),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Feedback
                      if (rpe != null || fatigueLevel != null || mood != null || feedbackNote.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.coach.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.mood, color: AppColors.coach, size: 20),
                                  const SizedBox(width: 8),
                                  Text('訓練回饋', style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (rpe != null) _buildFeedbackRow('運動自覺強度', 'RPE $rpe/10', _getRpeColor(rpe)),
                              if (fatigueLevel != null) _buildFeedbackRow('疲勞程度', _getFatigueLevelText(fatigueLevel), _getFatigueLevelColor(fatigueLevel)),
                              if (mood != null) _buildFeedbackRow('心情', _getMoodText(mood), _getMoodColor(mood)),
                              if (feedbackNote.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('備註', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                      const SizedBox(height: 4),
                                      Text(feedbackNote, style: TextStyle(fontSize: 14, height: 1.5)),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // 動作列表
                      Text('訓練動作', style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      _buildExercisesFromSessionData(session['exercises'] as List<dynamic>? ?? []),

                      const SizedBox(height: 24),

                      // 🔥 v4.3 P2：快速回覆按鈕（帶訓練卡片）
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            // 構建 workoutData
                            final workoutData = {
                              'sessionId': sessionId,
                              'planName': name,
                              'needsHelp': needsHelp,
                              'helpMessage': helpMessage,
                            };
                            _navigateToChatWithReply(workoutData);
                          },
                          icon: const Icon(Icons.reply),
                          label: Text(needsHelp ? '立即回覆' : '傳送訊息'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: needsHelp ? Colors.red : AppColors.coach,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
                      ),
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

  Widget _buildExercisesFromSessionData(List<dynamic> exercises) {
    if (exercises.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('無動作資料', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textTertiary)),
        ),
      );
    }

    return Column(
      children: exercises.asMap().entries.map((entry) {
        final index = entry.key;
        final exercise = entry.value as Map<String, dynamic>;
        return _buildExerciseItemFromData(index, exercise);
      }).toList(),
    );
  }

  Widget _buildFeedbackRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: valueColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: valueColor),
            ),
          ),
        ],
      ),
    );
  }

  // 🔥 v4.3 P2：導航到聊天室並帶上訓練卡片回覆
  void _navigateToChatWithReply(Map<String, dynamic> workoutData) async {
    try {
      // 顯示載入中
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2, 
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text('正在開啟聊天室...'),
            ],
          ),
          duration: Duration(seconds: 1),
        ),
      );

      // 使用 ChatService 創建或獲取聊天室
      final chatService = ChatService();
      final chatId = await chatService.createOrGetChatRoom(widget.traineeId);
      
      if (!mounted) return;

      // 🔥 創建回覆資料
      final needsHelp = workoutData['needsHelp'] == true;
      final sessionId = workoutData['sessionId']?.toString() ?? '';
      debugPrint('🔍 創建回覆資料: needsHelp=$needsHelp, sessionId=$sessionId');
      debugPrint('🔍 workoutData keys: ${workoutData.keys.toList()}');
      
      final replyData = chatService.createReplyDataFromWorkout(
        {
          'sessionId': sessionId,
          'planName': workoutData['planName'],
          'workoutName': workoutData['planName'] ?? '訓練記錄',
          'planDayOfWeek': workoutData['planDayOfWeek'],
          'feedback': {
            'needHelp': needsHelp,
            'helpMessage': workoutData['helpMessage'],
          },
        },
        senderName: widget.traineeName.isNotEmpty ? widget.traineeName : '學員',
      );
      
      debugPrint('🔍 replyData.messageId: ${replyData.messageId}');
      
      // 導航到聊天頁面
      // 🔥 v4.5：返回時刷新頁面（讓紅點立即消失）
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatDetailPage(
            chatId: chatId,
            chatName: widget.traineeName.isNotEmpty ? widget.traineeName : '學員',
            avatarUrl: '',
            initialReplyData: replyData,  // 🔥 傳入回覆資料
            initialIsReplyingToHelp: needsHelp,  // 🔥 標記是否為協助回覆
          ),
        ),
      ).then((_) {
        // 🔥 v4.5：返回時刷新頁面
        if (mounted) {
          setState(() {});
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('無法開啟聊天室：$e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 🔥 v4.3 P2：標記協助請求已處理（保留供手動使用）
  // 注意：現在主要由 ChatDetailPage 在發送訊息時調用
  Future<void> _markHelpAsResolved(String sessionId) async {
    try {
      await FirebaseFirestore.instance
          .collection('workoutSessions')
          .doc(sessionId)
          .update({
            'feedback.helpResolved': true,
            'feedback.helpResolvedAt': FieldValue.serverTimestamp(),
          });
      debugPrint('✅ 已標記協助請求為已處理: $sessionId');
      
      // 重新載入數據
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('❌ 標記協助請求失敗: $e');
    }
  }

  // 🔥 v4.2 P2：導航到聊天室（無回覆）
  void _navigateToChat() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2, 
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text('正在開啟聊天室...'),
            ],
          ),
          duration: Duration(seconds: 1),
        ),
      );

      final chatService = ChatService();
      final chatId = await chatService.createOrGetChatRoom(widget.traineeId);
      
      if (!mounted) return;
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatDetailPage(
            chatId: chatId,
            chatName: widget.traineeName.isNotEmpty ? widget.traineeName : '學員',
            avatarUrl: '',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('無法開啟聊天室：$e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildExercisesFromSession(String sessionId) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('workoutSessions')
          .doc(sessionId)
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

        if (!snapshot.hasData || !snapshot.data!.exists) {
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

        final sessionData = snapshot.data!.data() as Map<String, dynamic>;
        final exercises = sessionData['exercises'] as List<dynamic>? ?? [];

        if (exercises.isEmpty) {
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

        return Column(
          children: exercises.asMap().entries.map((entry) {
            final index = entry.key;
            final exerciseData = entry.value as Map<String, dynamic>;
            return _buildExerciseItemFromData(index, exerciseData);
          }).toList(),
        );
      },
    );
  }

  Widget _buildExerciseItemFromData(int index, Map<String, dynamic> exercise) {
    final name = exercise['exerciseName']?.toString() ?? 
                 exercise['name']?.toString() ?? '未命名動作';
    final sets = exercise['sets'] as List<dynamic>? ?? [];
    final setCount = sets.length;

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
          if (setCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$setCount 組',
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

  // 輔助方法
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

  Color _getRpeColor(dynamic rpe) {
    final value = _toInt(rpe);
    if (value <= 3) return Colors.green;
    if (value <= 5) return Colors.blue;
    if (value <= 7) return Colors.orange;
    return Colors.red;
  }

  String _getFatigueLevelText(String level) {
    switch (level) {
      case 'low': return '輕鬆';
      case 'medium': return '適中';
      case 'high': return '疲憊';
      case 'exhausted': return '極度疲憊';
      default: return level;
    }
  }

  Color _getFatigueLevelColor(String level) {
    switch (level) {
      case 'low': return Colors.green;
      case 'medium': return Colors.orange;
      case 'high': return Colors.deepOrange;
      case 'exhausted': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _getMoodText(String mood) {
    switch (mood) {
      case 'great': return '很棒';
      case 'good': return '不錯';
      case 'okay': return '普通';
      case 'tired': return '疲倦';
      case 'bad': return '不好';
      default: return mood;
    }
  }

  Color _getMoodColor(String mood) {
    switch (mood) {
      case 'great': return Colors.green;
      case 'good': return Colors.lightGreen;
      case 'okay': return Colors.orange;
      case 'tired': return Colors.deepOrange;
      case 'bad': return Colors.red;
      default: return Colors.grey;
    }
  }
}