// lib/widgets/plan_adjustment_sheet.dart
// 🎯 快速調整計畫功能 v1.1
// ✨ 教練端快速調整學員訓練計畫
// ✅ 調整類型選擇
// ✅ 選擇訓練日
// ✅ 自動建議生成
// ✅ 確認調整並通知學員
// ✅ v1.1: 修正實際調整邏輯，返回更新後的數據

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../theme/app_theme.dart';

/// 調整類型枚舉
enum AdjustmentType {
  increaseVolume,   // 增加訓練量
  decreaseVolume,   // 減少訓練量
  modifyExercise,   // 調整動作
  adjustSchedule,   // 調整時間
}

extension AdjustmentTypeExtension on AdjustmentType {
  String get label {
    switch (this) {
      case AdjustmentType.increaseVolume:
        return '增加訓練量';
      case AdjustmentType.decreaseVolume:
        return '減少訓練量';
      case AdjustmentType.modifyExercise:
        return '調整動作';
      case AdjustmentType.adjustSchedule:
        return '調整時間';
    }
  }

  IconData get icon {
    switch (this) {
      case AdjustmentType.increaseVolume:
        return Icons.trending_up;
      case AdjustmentType.decreaseVolume:
        return Icons.trending_down;
      case AdjustmentType.modifyExercise:
        return Icons.swap_horiz;
      case AdjustmentType.adjustSchedule:
        return Icons.schedule;
    }
  }

  Color get color {
    switch (this) {
      case AdjustmentType.increaseVolume:
        return AppColors.success;
      case AdjustmentType.decreaseVolume:
        return AppColors.warning;
      case AdjustmentType.modifyExercise:
        return AppColors.info;
      case AdjustmentType.adjustSchedule:
        return AppColors.primary;
    }
  }
}

/// 調整結果
class AdjustmentResult {
  final bool success;
  final Map<String, dynamic>? updatedPlanData;
  final String? message;

  AdjustmentResult({
    required this.success,
    this.updatedPlanData,
    this.message,
  });
}

/// 快速調整底部彈窗
class PlanAdjustmentSheet extends StatefulWidget {
  final String planId;
  final Map<String, dynamic> planData;
  final String traineeId;
  final String traineeName;
  final Map<String, dynamic>? weeklyStats;

  const PlanAdjustmentSheet({
    super.key,
    required this.planId,
    required this.planData,
    required this.traineeId,
    required this.traineeName,
    this.weeklyStats,
  });

  /// 顯示調整彈窗
  static Future<AdjustmentResult?> show({
    required BuildContext context,
    required String planId,
    required Map<String, dynamic> planData,
    required String traineeId,
    required String traineeName,
    Map<String, dynamic>? weeklyStats,
  }) {
    return showModalBottomSheet<AdjustmentResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PlanAdjustmentSheet(
        planId: planId,
        planData: planData,
        traineeId: traineeId,
        traineeName: traineeName,
        weeklyStats: weeklyStats,
      ),
    );
  }

  @override
  State<PlanAdjustmentSheet> createState() => _PlanAdjustmentSheetState();
}

class _PlanAdjustmentSheetState extends State<PlanAdjustmentSheet> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _reasonController = TextEditingController();

  // 選擇狀態
  AdjustmentType? _selectedType;
  Set<String> _selectedDays = {};
  bool _isSubmitting = false;

  // 訓練日列表
  late List<Map<String, dynamic>> _daysList;

  @override
  void initState() {
    super.initState();
    _parseDaysList();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _parseDaysList() {
    final daysData = widget.planData['days'];
    _daysList = [];

    if (daysData is List) {
      _daysList = daysData.map((d) => Map<String, dynamic>.from(d as Map)).toList();
    } else if (daysData is Map) {
      _daysList = (daysData as Map<String, dynamic>)
          .values
          .map((d) => Map<String, dynamic>.from(d as Map))
          .toList();
    }
  }

  /// 生成自動建議
  String _generateSuggestion() {
    if (_selectedType == null) {
      return '請先選擇調整類型';
    }

    final stats = widget.weeklyStats;
    final completionRate = stats?['completionRate'] ?? 0.0;
    final onTimeRate = stats?['onTimeRate'] ?? 0.0;

    switch (_selectedType!) {
      case AdjustmentType.increaseVolume:
        if (completionRate >= 0.8 && onTimeRate >= 0.7) {
          return '學員近期表現優秀（完成率 ${(completionRate * 100).toInt()}%），建議適度增加組數或重量。';
        } else if (completionRate >= 0.5) {
          return '學員完成率中等，建議小幅增加訓練量，觀察適應情況。';
        } else {
          return '學員目前完成率較低，建議先確認是否適合增加訓練量。';
        }

      case AdjustmentType.decreaseVolume:
        if (completionRate < 0.5) {
          return '學員近期完成率偏低（${(completionRate * 100).toInt()}%），減少訓練量可幫助恢復信心。';
        } else if (onTimeRate < 0.5) {
          return '學員按時率較低，可能訓練量過大，建議適度減少。';
        } else {
          return '可根據學員反饋適度調整，避免過度疲勞。';
        }

      case AdjustmentType.modifyExercise:
        return '根據學員狀況或設備情況，替換為相似效果的動作。';

      case AdjustmentType.adjustSchedule:
        if (_selectedDays.isEmpty) {
          return '選擇要調整的訓練日後，將顯示建議。';
        }
        return '可根據學員時間安排，調整訓練日或順序。';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖動指示器
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
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
                    gradient: AppColors.secondaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.tune,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '調整訓練計畫',
                        style: AppTextStyles.h4.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.traineeName,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context, null),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // 內容區
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. 調整類型
                  _buildSectionTitle('調整類型', Icons.category),
                  const SizedBox(height: 12),
                  _buildAdjustmentTypeSelector(),
                  const SizedBox(height: 24),

                  // 2. 選擇訓練日
                  _buildSectionTitle('選擇訓練日', Icons.calendar_today),
                  const SizedBox(height: 12),
                  _buildDaySelector(),
                  const SizedBox(height: 24),

                  // 3. 調整建議（自動生成）
                  _buildSectionTitle('調整建議', Icons.lightbulb_outline, 
                    subtitle: '自動生成'),
                  const SizedBox(height: 12),
                  _buildSuggestionCard(),
                  const SizedBox(height: 24),

                  // 4. 給學員的說明
                  _buildSectionTitle('給學員的說明', Icons.edit_note),
                  const SizedBox(height: 12),
                  _buildReasonInput(),
                  const SizedBox(height: 32),

                  // 5. 操作按鈕
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, {String? subtitle}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.coach),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppTextStyles.label.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              subtitle,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.warning,
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// 調整類型選擇器
  Widget _buildAdjustmentTypeSelector() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: AdjustmentType.values.map((type) {
        final isSelected = _selectedType == type;
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedType = type;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? type.color.withOpacity(0.15)
                  : AppColors.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? type.color : AppColors.divider,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected ? AppShadows.small : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  type.icon,
                  size: 18,
                  color: isSelected ? type.color : AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  type.label,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isSelected ? type.color : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 訓練日選擇器
  Widget _buildDaySelector() {
    if (_daysList.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.textTertiary, size: 20),
            const SizedBox(width: 10),
            Text(
              '此計畫尚無訓練日配置',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _daysList.asMap().entries.map((entry) {
        final day = entry.value;
        final dayOfWeek = day['dayOfWeek']?.toString() ?? '未設定';
        final exercises = day['exercises'] as List?;

        // 獲取第一個動作的類別作為標籤
        String? category;
        if (exercises != null && exercises.isNotEmpty) {
          final firstExercise = exercises[0] as Map<String, dynamic>;
          category = firstExercise['type']?.toString();
        }

        final isSelected = _selectedDays.contains(dayOfWeek);

        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedDays.remove(dayOfWeek);
              } else {
                _selectedDays.add(dayOfWeek);
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
              mainAxisSize: MainAxisSize.min,
              children: [
                // 勾選框
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.coach : Colors.transparent,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: isSelected ? AppColors.coach : AppColors.textTertiary,
                      width: 1.5,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dayOfWeek,
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? AppColors.coach
                            : AppColors.textPrimary,
                      ),
                    ),
                    if (category != null)
                      Text(
                        category,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 建議卡片
  Widget _buildSuggestionCard() {
    final suggestion = _generateSuggestion();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.warning.withOpacity(0.08),
            AppColors.warning.withOpacity(0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.warning.withOpacity(0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.auto_awesome,
              color: AppColors.warning,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              suggestion,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 說明輸入框
  Widget _buildReasonInput() {
    return TextField(
      controller: _reasonController,
      maxLines: 3,
      decoration: InputDecoration(
        hintText: '輸入調整原因或對學員的說明...',
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textTertiary,
        ),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.coach, width: 2),
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }

  /// 操作按鈕
  Widget _buildActionButtons() {
    final isValid = _selectedType != null && _selectedDays.isNotEmpty;

    return Row(
      children: [
        // 取消按鈕
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context, null),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(color: AppColors.divider),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              '取消',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // 確認按鈕
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: isValid && !_isSubmitting ? _submitAdjustment : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: AppColors.coach,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.divider,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: isValid ? 2 : 0,
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '確認調整並通知',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  /// 提交調整
  Future<void> _submitAdjustment() async {
    if (_selectedType == null || _selectedDays.isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      // 1. 執行實際調整
      final updatedDays = await _applyAdjustment();
      
      if (updatedDays == null) {
        throw Exception('調整失敗');
      }

      // 2. 記錄調整歷史
      final adjustmentRecord = {
        'type': _selectedType!.name,
        'typeLabel': _selectedType!.label,
        'selectedDays': _selectedDays.toList(),
        'suggestion': _generateSuggestion(),
        'reason': _reasonController.text.trim(),
        'coachId': FirebaseAuth.instance.currentUser?.uid,
        'createdAt': Timestamp.now(),
      };

      await _firestore
          .collection('workoutPlans')
          .doc(widget.planId)
          .update({
        'adjustmentHistory': FieldValue.arrayUnion([adjustmentRecord]),
        'lastAdjustedAt': FieldValue.serverTimestamp(),
      });

      // 3. 發送通知給學員（作為備註）
      final noteContent = '''
📋 計畫調整通知

調整類型：${_selectedType!.label}
調整範圍：${_selectedDays.join('、')}
${_reasonController.text.isNotEmpty ? '\n教練說明：${_reasonController.text}' : ''}

${_generateSuggestion()}
'''.trim();

      await _firestore
          .collection('workoutPlans')
          .doc(widget.planId)
          .update({
        'coachNotes': FieldValue.arrayUnion([
          {
            'content': noteContent,
            'createdAt': Timestamp.now(),
            'coachId': FirebaseAuth.instance.currentUser?.uid,
            'isAdjustmentNotice': true,
          }
        ]),
      });

      // 4. 重新讀取完整的計畫數據
      final updatedDoc = await _firestore
          .collection('workoutPlans')
          .doc(widget.planId)
          .get();
      
      final updatedPlanData = updatedDoc.data() as Map<String, dynamic>?;

      if (mounted) {
        Navigator.pop(
          context, 
          AdjustmentResult(
            success: true,
            updatedPlanData: updatedPlanData,
            message: '計畫已調整，已通知學員',
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('調整失敗: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('調整失敗：$e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  /// 實際執行調整（根據類型）- 返回更新後的 days
  Future<List<Map<String, dynamic>>?> _applyAdjustment() async {
    final planRef = _firestore.collection('workoutPlans').doc(widget.planId);
    final planDoc = await planRef.get();
    
    if (!planDoc.exists) return null;
    
    final data = planDoc.data() as Map<String, dynamic>;
    final daysData = data['days'];
    
    List<Map<String, dynamic>> daysList = [];
    if (daysData is List) {
      daysList = daysData.map((d) => Map<String, dynamic>.from(d as Map)).toList();
    } else if (daysData is Map) {
      daysList = (daysData as Map<String, dynamic>)
          .values
          .map((d) => Map<String, dynamic>.from(d as Map))
          .toList();
    }

    // 根據調整類型修改計畫
    switch (_selectedType!) {
      case AdjustmentType.increaseVolume:
        // 增加選中訓練日的組數
        for (var day in daysList) {
          final dayOfWeek = day['dayOfWeek']?.toString() ?? '';
          if (_selectedDays.contains(dayOfWeek)) {
            final exercises = day['exercises'] as List?;
            if (exercises != null) {
              final updatedExercises = <Map<String, dynamic>>[];
              for (var i = 0; i < exercises.length; i++) {
                final exercise = Map<String, dynamic>.from(exercises[i] as Map);
                final currentSets = exercise['sets'] as int? ?? 3;
                exercise['sets'] = currentSets + 1; // 增加 1 組
                updatedExercises.add(exercise);
              }
              day['exercises'] = updatedExercises;
            }
          }
        }
        break;

      case AdjustmentType.decreaseVolume:
        // 減少選中訓練日的組數
        for (var day in daysList) {
          final dayOfWeek = day['dayOfWeek']?.toString() ?? '';
          if (_selectedDays.contains(dayOfWeek)) {
            final exercises = day['exercises'] as List?;
            if (exercises != null) {
              final updatedExercises = <Map<String, dynamic>>[];
              for (var i = 0; i < exercises.length; i++) {
                final exercise = Map<String, dynamic>.from(exercises[i] as Map);
                final currentSets = exercise['sets'] as int? ?? 3;
                if (currentSets > 1) {
                  exercise['sets'] = currentSets - 1; // 減少 1 組
                }
                updatedExercises.add(exercise);
              }
              day['exercises'] = updatedExercises;
            }
          }
        }
        break;

      case AdjustmentType.modifyExercise:
        // 動作調整需要更複雜的 UI，這裡只記錄調整意圖
        break;

      case AdjustmentType.adjustSchedule:
        // 時間調整需要更複雜的 UI
        break;
    }

    // 更新計畫
    await planRef.update({
      'days': daysList,
    });

    if (kDebugMode) {
      debugPrint('✅ 計畫已更新，days: ${daysList.length} 個訓練日');
      for (var day in daysList) {
        final dayOfWeek = day['dayOfWeek'];
        final exercises = day['exercises'] as List?;
        if (exercises != null && exercises.isNotEmpty) {
          final firstEx = exercises[0] as Map<String, dynamic>;
          debugPrint('  - $dayOfWeek: ${firstEx['name']} = ${firstEx['sets']} 組');
        }
      }
    }

    return daysList;
  }
}