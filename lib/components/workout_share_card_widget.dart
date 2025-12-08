// lib/components/workout_share_card_widget.dart
// 🎴 訓練分享卡片元件 v2.0
// ✅ LINE 官方帳號風格互動卡片
// ✅ 可點擊操作按鈕
// ✅ 豐富視覺層次
// ✅ 需要協助醒目提示

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/workout_share_service.dart' show FreeWorkoutType, WorkoutFeedback;

/// 訓練分享卡片（LINE 官方帳號風格）
class WorkoutShareCardWidget extends StatelessWidget {
  final Map<String, dynamic> workoutData;
  final bool isMe;
  final VoidCallback? onTap;
  final VoidCallback? onReply;
  final VoidCallback? onMarkHandled;
  
  const WorkoutShareCardWidget({
    super.key,
    required this.workoutData,
    required this.isMe,
    this.onTap,
    this.onReply,
    this.onMarkHandled,
  });
  
  // 配色
  static const Color _primaryOrange = Color(0xFFFF9800);
  static const Color _primaryBlue = Color(0xFF2196F3);
  static const Color _textPrimary = Color(0xFF2D3748);
  static const Color _textSecondary = Color(0xFF718096);
  
  @override
  Widget build(BuildContext context) {
    final isPlanWorkout = workoutData['source'] == 'plan';
    final themeColor = isPlanWorkout ? _primaryOrange : _primaryBlue;
    final needsHelp = workoutData['feedback']?['needHelp'] == true;
    
    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 頂部漸層標題區
          _buildHeader(themeColor, isPlanWorkout, needsHelp),
          
          // 數據區
          _buildStatsGrid(themeColor),
          
          // 訓練亮點（如果有）
          if (workoutData['highlights'] != null)
            _buildHighlights(themeColor),
          
          // 訓練感受（如果有）
          if (workoutData['feedback'] != null)
            _buildFeedbackSection(themeColor),
          
          // 需要協助醒目區塊
          if (needsHelp)
            _buildHelpAlert(),
          
          // 底部操作按鈕區
          _buildActionButtons(context, themeColor, needsHelp),
          
          // 時間戳記
          _buildTimestamp(),
        ],
      ),
    );
  }
  
  // ========== 頂部標題區（漸層背景）==========
  Widget _buildHeader(Color themeColor, bool isPlanWorkout, bool needsHelp) {
    final planName = workoutData['planName'] as String?;
    final workoutName = workoutData['workoutName'] as String? ?? '訓練記錄';
    final planDayOfWeek = workoutData['planDayOfWeek'] as String?;
    final statusLabel = workoutData['statusLabel'] as String? ?? '';
    final freeWorkoutType = workoutData['freeWorkoutType'] as String?;
    final freeWorkoutCategory = workoutData['freeWorkoutCategory'] as String?;
    
    // 決定顯示標題
    String title;
    String? subtitle;
    IconData headerIcon;
    
    if (isPlanWorkout) {
      title = planName ?? workoutName;
      subtitle = planDayOfWeek;
      headerIcon = Icons.fitness_center;
    } else {
      headerIcon = _getWorkoutTypeIcon(freeWorkoutType ?? '');
      final typeLabel = FreeWorkoutType.getLabel(freeWorkoutType ?? '');
      if (freeWorkoutCategory != null && freeWorkoutCategory.isNotEmpty) {
        title = '$typeLabel - $freeWorkoutCategory';
      } else {
        title = typeLabel;
      }
      subtitle = workoutName.isNotEmpty && workoutName != typeLabel ? workoutName : null;
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            themeColor,
            themeColor.withOpacity(0.8),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 頂部標籤列
          Row(
            children: [
              // 訓練類型標籤
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPlanWorkout ? Icons.assignment : Icons.self_improvement,
                      size: 12,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isPlanWorkout ? '計畫訓練' : '自主訓練',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // 狀態標籤
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 12,
                      color: themeColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: themeColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 標題區
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(headerIcon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.85),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          // 需要協助緊急標記
          if (needsHelp) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.priority_high, size: 14, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    '學生需要協助',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  // ========== 數據網格區 ==========
  Widget _buildStatsGrid(Color themeColor) {
    final duration = workoutData['durationMinutes'] as int? ?? 0;
    final calories = (workoutData['caloriesBurned'] as num?)?.toDouble() ?? 0;
    final exercises = workoutData['exerciseCount'] as int? ?? 0;
    final sets = workoutData['totalSets'] as int? ?? 0;
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildStatCard(Icons.timer_outlined, '$duration', '分鐘', themeColor),
          const SizedBox(width: 8),
          _buildStatCard(Icons.local_fire_department_outlined, '${calories.toStringAsFixed(0)}', '卡路里', themeColor),
          const SizedBox(width: 8),
          _buildStatCard(Icons.fitness_center, '$exercises', '動作', themeColor),
          const SizedBox(width: 8),
          _buildStatCard(Icons.repeat, '$sets', '組', themeColor),
        ],
      ),
    );
  }
  
  Widget _buildStatCard(IconData icon, String value, String label, Color themeColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: themeColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: themeColor),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: themeColor,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: themeColor.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // ========== 訓練亮點區 ==========
  Widget _buildHighlights(Color themeColor) {
    final highlights = workoutData['highlights'] as Map<String, dynamic>?;
    if (highlights == null) return const SizedBox.shrink();
    
    final maxWeight = highlights['maxWeight'];
    final maxWeightExercise = highlights['maxWeightExercise'] as String?;
    final totalVolume = highlights['totalVolume'] as num?;
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events, size: 16, color: Colors.amber[700]),
              const SizedBox(width: 6),
              Text(
                '訓練亮點',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (maxWeight != null)
            _buildHighlightItem(
              Icons.fitness_center,
              '最大重量',
              '$maxWeight kg${maxWeightExercise != null ? '（$maxWeightExercise）' : ''}',
            ),
          if (totalVolume != null)
            _buildHighlightItem(
              Icons.analytics_outlined,
              '總訓練量',
              '${(totalVolume / 1000).toStringAsFixed(1)} 噸',
            ),
        ],
      ),
    );
  }
  
  Widget _buildHighlightItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.amber[700]),
          const SizedBox(width: 8),
          Text(
            '$label：',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // ========== 訓練感受區 ==========
  Widget _buildFeedbackSection(Color themeColor) {
    final feedback = workoutData['feedback'] as Map<String, dynamic>?;
    if (feedback == null) return const SizedBox.shrink();
    
    final rpe = feedback['rpe'] as int?;
    final mood = feedback['mood'] as String?;
    final fatigueLevel = feedback['fatigueLevel'] as String?;
    final note = feedback['note'] as String?;
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sentiment_satisfied_alt, size: 16, color: Colors.blue[700]),
              const SizedBox(width: 6),
              Text(
                '訓練感受',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 感受標籤列
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (rpe != null)
                _buildFeedbackChip(
                  Icons.speed,
                  'RPE $rpe',
                  Colors.orange,
                ),
              if (mood != null)
                _buildFeedbackChip(
                  _getMoodIcon(mood),
                  _getMoodLabel(mood),
                  Colors.blue,
                ),
              if (fatigueLevel != null)
                _buildFeedbackChip(
                  _getFatigueIcon(fatigueLevel),
                  _getFatigueLabel(fatigueLevel),
                  Colors.purple,
                ),
            ],
          ),
          // 備註
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '「$note」',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildFeedbackChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
  
  // ========== 需要協助醒目區塊 ==========
  Widget _buildHelpAlert() {
    final helpMessage = workoutData['feedback']?['helpMessage'] as String?;
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red[50]!, Colors.red[100]!],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.support_agent,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  '需要教練協助',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ),
          if (helpMessage != null && helpMessage.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.format_quote, size: 16, color: Colors.red[300]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      helpMessage,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[800],
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  // ========== 底部操作按鈕區（LINE 風格）==========
  Widget _buildActionButtons(BuildContext context, Color themeColor, bool needsHelp) {
    // 只有教練端（非自己發送的）才顯示操作按鈕
    if (isMe) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Row(
        children: [
          // 查看詳情按鈕
          Expanded(
            child: _buildActionButton(
              icon: Icons.visibility_outlined,
              label: '查看詳情',
              color: themeColor,
              outlined: true,
              onTap: () {
                HapticFeedback.lightImpact();
                onTap?.call();
              },
            ),
          ),
          const SizedBox(width: 8),
          // 快速回覆按鈕（需要協助時醒目顯示）
          Expanded(
            child: _buildActionButton(
              icon: Icons.reply,
              label: needsHelp ? '回覆協助' : '回覆',
              color: needsHelp ? Colors.red : themeColor,
              outlined: !needsHelp,
              onTap: () {
                HapticFeedback.lightImpact();
                onReply?.call();
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool outlined,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: outlined ? Colors.transparent : color,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: color,
              width: outlined ? 1.5 : 0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: outlined ? color : Colors.white,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: outlined ? color : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // ========== 時間戳記 ==========
  Widget _buildTimestamp() {
    final completedAt = workoutData['completedAt'];
    DateTime? time;
    
    if (completedAt is Timestamp) {
      time = completedAt.toDate();
    } else if (completedAt is DateTime) {
      time = completedAt;
    }
    
    if (time == null) return const SizedBox.shrink();
    
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Icon(Icons.access_time, size: 12, color: Colors.grey[400]),
          const SizedBox(width: 4),
          Text(
            '完成於 $hour:$minute',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }
  
  // ========== 工具方法 ==========
  IconData _getMoodIcon(String mood) {
    switch (mood) {
      case 'great': return Icons.sentiment_very_satisfied;
      case 'good': return Icons.sentiment_satisfied;
      case 'okay': return Icons.sentiment_neutral;
      case 'tired': return Icons.sentiment_dissatisfied;
      case 'bad': return Icons.sentiment_very_dissatisfied;
      default: return Icons.sentiment_neutral;
    }
  }
  
  String _getMoodLabel(String mood) {
    switch (mood) {
      case 'great': return '超棒';
      case 'good': return '不錯';
      case 'okay': return '一般';
      case 'tired': return '疲憊';
      case 'bad': return '不好';
      default: return '';
    }
  }
  
  IconData _getFatigueIcon(String fatigue) {
    switch (fatigue) {
      case 'low': return Icons.battery_full;
      case 'medium': return Icons.battery_std;
      case 'high': return Icons.battery_3_bar;
      case 'exhausted': return Icons.battery_1_bar;
      default: return Icons.battery_std;
    }
  }
  
  String _getFatigueLabel(String fatigue) {
    switch (fatigue) {
      case 'low': return '精力充沛';
      case 'medium': return '正常';
      case 'high': return '有點累';
      case 'exhausted': return '很疲憊';
      default: return '';
    }
  }
  
  IconData _getWorkoutTypeIcon(String type) {
    switch (type) {
      case 'weight_training': return Icons.fitness_center;
      case 'cardio': return Icons.directions_run;
      case 'yoga': return Icons.self_improvement;
      case 'hiit': return Icons.flash_on;
      case 'stretching': return Icons.accessibility_new;
      case 'sports': return Icons.sports_soccer;
      case 'other': return Icons.sports;
      default: return Icons.fitness_center;
    }
  }
}

/// 回覆引用卡片（顯示被回覆的訓練記錄）
class WorkoutReplyQuote extends StatelessWidget {
  final Map<String, dynamic> workoutData;
  final VoidCallback? onCancel;
  
  const WorkoutReplyQuote({
    super.key,
    required this.workoutData,
    this.onCancel,
  });
  
  @override
  Widget build(BuildContext context) {
    final isPlanWorkout = workoutData['source'] == 'plan';
    final themeColor = isPlanWorkout ? const Color(0xFFFF9800) : const Color(0xFF2196F3);
    final workoutName = workoutData['workoutName'] as String? ?? '訓練記錄';
    final planName = workoutData['planName'] as String?;
    final needsHelp = workoutData['feedback']?['needHelp'] == true;
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: needsHelp ? Colors.red[50] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: needsHelp ? Colors.red : themeColor,
            width: 4,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.reply,
            size: 16,
            color: needsHelp ? Colors.red : themeColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '回覆訓練記錄',
                  style: TextStyle(
                    fontSize: 11,
                    color: needsHelp ? Colors.red : themeColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isPlanWorkout ? (planName ?? workoutName) : workoutName,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (needsHelp)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(Icons.support_agent, size: 12, color: Colors.red[700]),
                        const SizedBox(width: 4),
                        Text(
                          '需要協助',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.red[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (onCancel != null)
            IconButton(
              icon: Icon(Icons.close, size: 18, color: Colors.grey[500]),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: onCancel,
            ),
        ],
      ),
    );
  }
}

/// 帶引用的訊息氣泡（顯示回覆的是哪條訓練記錄）
class ReplyMessageBubble extends StatelessWidget {
  final String message;
  final Map<String, dynamic>? replyToWorkout;
  final bool isMe;
  final DateTime timestamp;
  
  const ReplyMessageBubble({
    super.key,
    required this.message,
    this.replyToWorkout,
    required this.isMe,
    required this.timestamp,
  });
  
  @override
  Widget build(BuildContext context) {
    final isPlanWorkout = replyToWorkout?['source'] == 'plan';
    final themeColor = isPlanWorkout ? const Color(0xFFFF9800) : const Color(0xFF2196F3);
    final workoutName = replyToWorkout?['workoutName'] as String? ?? '訓練記錄';
    final planName = replyToWorkout?['planName'] as String?;
    final needsHelp = replyToWorkout?['feedback']?['needHelp'] == true;
    
    return Container(
      margin: EdgeInsets.only(
        left: isMe ? 60 : 0,
        right: isMe ? 0 : 60,
      ),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // 引用區塊
          if (replyToWorkout != null)
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: needsHelp ? Colors.red[50] : Colors.grey[100],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                border: Border(
                  left: BorderSide(
                    color: needsHelp ? Colors.red : themeColor,
                    width: 3,
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.fitness_center,
                    size: 14,
                    color: needsHelp ? Colors.red : themeColor,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      isPlanWorkout ? (planName ?? workoutName) : workoutName,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          // 訊息內容
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isMe ? const Color(0xFF6C63FF) : const Color(0xFFF5F3FF),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(replyToWorkout != null ? 4 : 20),
                topRight: Radius.circular(replyToWorkout != null ? 4 : 20),
                bottomLeft: Radius.circular(isMe ? 20 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 20),
              ),
            ),
            child: Text(
              message,
              style: TextStyle(
                color: isMe ? Colors.white : const Color(0xFF2D2D2D),
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}