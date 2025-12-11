// lib/widgets/plan_update_banner.dart
// 🎯 計畫更新提示橫幅 v1.0
// ✨ 學員端顯示計畫已更新的通知
// ✅ 明顯的更新提示
// ✅ 顯示變更摘要
// ✅ 標記為已讀功能

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

/// 計畫更新提示橫幅
class PlanUpdateBanner extends StatelessWidget {
  final String planId;
  final Map<String, dynamic> planData;
  final VoidCallback? onDismiss;
  final VoidCallback? onViewDetails;

  const PlanUpdateBanner({
    super.key,
    required this.planId,
    required this.planData,
    this.onDismiss,
    this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final hasUnreadUpdate = planData['hasUnreadUpdate'] == true;
    
    if (!hasUnreadUpdate) {
      return const SizedBox.shrink();
    }

    final lastUpdateAt = planData['lastUpdateAt'] as Timestamp?;
    final version = planData['version'] as int? ?? 1;
    final dateStr = lastUpdateAt != null
        ? DateFormat('MM/dd HH:mm').format(lastUpdateAt.toDate())
        : '剛剛';

    // 從最新的教練備註獲取變更摘要
    String? changeSummary;
    final coachNotes = planData['coachNotes'] as List?;
    if (coachNotes != null && coachNotes.isNotEmpty) {
      // 找最新的調整通知
      for (var note in coachNotes.reversed) {
        if (note is Map && note['isAdjustmentNotice'] == true) {
          changeSummary = note['content']?.toString();
          break;
        }
      }
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.warning.withOpacity(0.15),
            AppColors.warning.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.warning.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.warning.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 標題列
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                // 動畫圖標
                _AnimatedBellIcon(),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '計畫已更新',
                            style: AppTextStyles.bodyLarge.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.warning.withOpacity(0.9),
                            ),
                          ),
                          const SizedBox(width: 8),
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
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '更新於 $dateStr',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                // 關閉按鈕
                IconButton(
                  icon: Icon(Icons.close, color: AppColors.textTertiary, size: 20),
                  onPressed: () => _markAsRead(context),
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // 變更摘要
          if (changeSummary != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Text(
                changeSummary.length > 150 
                    ? '${changeSummary.substring(0, 150)}...' 
                    : changeSummary,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          // 操作按鈕
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _markAsRead(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: BorderSide(color: AppColors.divider),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('知道了'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      _markAsRead(context);
                      onViewDetails?.call();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.warning,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.visibility, size: 18),
                        SizedBox(width: 6),
                        Text('查看新計畫'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _markAsRead(BuildContext context) async {
    try {
      await FirebaseFirestore.instance
          .collection('workoutPlans')
          .doc(planId)
          .update({
        'hasUnreadUpdate': false,
      });
      onDismiss?.call();
    } catch (e) {
      debugPrint('標記已讀失敗: $e');
    }
  }
}

/// 動畫鈴鐺圖標
class _AnimatedBellIcon extends StatefulWidget {
  @override
  State<_AnimatedBellIcon> createState() => _AnimatedBellIconState();
}

class _AnimatedBellIconState extends State<_AnimatedBellIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animation = Tween<double>(begin: -0.1, end: 0.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticIn),
    );
    
    // 搖動動畫
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _controller.repeat(reverse: true);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _controller.stop();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.rotate(
          angle: _animation.value,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_active,
              color: AppColors.warning,
              size: 24,
            ),
          ),
        );
      },
    );
  }
}

/// 計畫列表中的更新標記
class PlanUpdateBadge extends StatelessWidget {
  final bool hasUpdate;

  const PlanUpdateBadge({
    super.key,
    required this.hasUpdate,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasUpdate) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.warning,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: AppColors.warning.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.new_releases, color: Colors.white, size: 12),
          const SizedBox(width: 4),
          Text(
            '已更新',
            style: AppTextStyles.caption.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

/// 教練備註卡片（學員端查看）
class CoachNoteCard extends StatelessWidget {
  final Map<String, dynamic> note;
  final bool isLatest;

  const CoachNoteCard({
    super.key,
    required this.note,
    this.isLatest = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = note['content'] as String? ?? '';
    final createdAt = note['createdAt'] as Timestamp?;
    final isAdjustmentNotice = note['isAdjustmentNotice'] == true;
    final version = note['version'] as int?;
    final dateStr = createdAt != null
        ? DateFormat('MM/dd HH:mm').format(createdAt.toDate())
        : '未知時間';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isAdjustmentNotice
              ? AppColors.warning.withOpacity(0.3)
              : AppColors.coach.withOpacity(0.2),
          width: isAdjustmentNotice ? 1.5 : 1,
        ),
        boxShadow: isLatest ? AppShadows.small : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 標題
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isAdjustmentNotice
                  ? AppColors.warning.withOpacity(0.08)
                  : AppColors.coach.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isAdjustmentNotice
                        ? AppColors.warning.withOpacity(0.15)
                        : AppColors.coach.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isAdjustmentNotice ? Icons.tune : Icons.message,
                    color: isAdjustmentNotice ? AppColors.warning : AppColors.coach,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            isAdjustmentNotice ? '計畫調整' : '教練備註',
                            style: AppTextStyles.bodySmall.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isAdjustmentNotice
                                  ? AppColors.warning
                                  : AppColors.coach,
                            ),
                          ),
                          if (version != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'v$version',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                          ],
                          if (isLatest) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.success,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'NEW',
                                style: AppTextStyles.caption.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        dateStr,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 內容
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              content,
              style: AppTextStyles.bodySmall.copyWith(
                height: 1.6,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 教練備註區塊（學員計畫詳情頁使用）
class CoachNotesSection extends StatelessWidget {
  final String planId;
  final List<Map<String, dynamic>> notes;
  final bool initiallyExpanded;

  const CoachNotesSection({
    super.key,
    required this.planId,
    required this.notes,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) {
      return const SizedBox.shrink();
    }

    // 排序：最新的在前
    final sortedNotes = List<Map<String, dynamic>>.from(notes);
    sortedNotes.sort((a, b) {
      final aTime = a['createdAt'] as Timestamp?;
      final bTime = b['createdAt'] as Timestamp?;
      if (aTime == null || bTime == null) return 0;
      return bTime.compareTo(aTime);
    });

    // 分離調整通知和一般備註
    final adjustmentNotes = sortedNotes.where((n) => n['isAdjustmentNotice'] == true).toList();
    final regularNotes = sortedNotes.where((n) => n['isAdjustmentNotice'] != true).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.small,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.coach.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.message, color: AppColors.coach, size: 20),
          ),
          title: Row(
            children: [
              Text(
                '教練備註',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.coach.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${notes.length}',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.coach,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Text(
            '包含 ${adjustmentNotes.length} 則調整通知',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
          children: [
            // 最新的調整通知優先顯示
            if (adjustmentNotes.isNotEmpty) ...[
              ...adjustmentNotes.take(2).toList().asMap().entries.map((entry) {
                return CoachNoteCard(
                  note: entry.value,
                  isLatest: entry.key == 0,
                );
              }),
            ],
            
            // 一般備註
            if (regularNotes.isNotEmpty) ...[
              if (adjustmentNotes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Divider(color: AppColors.divider),
                ),
              ...regularNotes.take(3).toList().map((note) {
                return CoachNoteCard(note: note);
              }),
            ],

            // 查看更多
            if (notes.length > 5)
              TextButton(
                onPressed: () {
                  // TODO: 導航到完整備註頁面
                },
                child: Text(
                  '查看全部 ${notes.length} 則備註',
                  style: TextStyle(color: AppColors.coach),
                ),
              ),
          ],
        ),
      ),
    );
  }
}