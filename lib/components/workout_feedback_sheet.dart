// lib/components/workout_feedback_sheet.dart
// 🎯 訓練感受輸入元件 v1.1
// ✅ RPE 滑桿
// ✅ 心情選擇
// ✅ 疲勞度選擇
// ✅ 備註輸入
// ✅ 求助功能
// ✅ 支援計畫訓練 + 自由訓練

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// 🔥 修正：明確指定 import 避免衝突
import '../services/workout_share_service.dart' 
    show WorkoutFeedback, WorkoutSource, FreeWorkoutType;

/// 訓練感受輸入結果
class WorkoutFeedbackResult {
  final WorkoutFeedback feedback;
  final bool shareToCoach;
  final bool shareToChat;
  
  const WorkoutFeedbackResult({
    required this.feedback,
    this.shareToCoach = true,
    this.shareToChat = false,
  });
}

/// 訓練感受底部彈窗
class WorkoutFeedbackSheet extends StatefulWidget {
  final WorkoutSource source;
  final String workoutName;
  final String? planName;               // 計畫訓練用
  final String? freeWorkoutType;        // 自由訓練用
  final String? freeWorkoutCategory;    // 自由訓練分類
  final int durationMinutes;
  final double caloriesBurned;
  
  const WorkoutFeedbackSheet({
    super.key,
    required this.source,
    required this.workoutName,
    this.planName,
    this.freeWorkoutType,
    this.freeWorkoutCategory,
    required this.durationMinutes,
    required this.caloriesBurned,
  });
  
  /// 顯示底部彈窗（計畫訓練）
  static Future<WorkoutFeedbackResult?> showForPlan(
    BuildContext context, {
    required String workoutName,
    required String planName,
    required int durationMinutes,
    required double caloriesBurned,
  }) {
    return showModalBottomSheet<WorkoutFeedbackResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => WorkoutFeedbackSheet(
        source: WorkoutSource.plan,
        workoutName: workoutName,
        planName: planName,
        durationMinutes: durationMinutes,
        caloriesBurned: caloriesBurned,
      ),
    );
  }
  
  /// 顯示底部彈窗（自由訓練）
  static Future<WorkoutFeedbackResult?> showForFree(
    BuildContext context, {
    required String workoutName,
    required String freeWorkoutType,
    String? freeWorkoutCategory,
    required int durationMinutes,
    required double caloriesBurned,
  }) {
    return showModalBottomSheet<WorkoutFeedbackResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => WorkoutFeedbackSheet(
        source: WorkoutSource.free,
        workoutName: workoutName,
        freeWorkoutType: freeWorkoutType,
        freeWorkoutCategory: freeWorkoutCategory,
        durationMinutes: durationMinutes,
        caloriesBurned: caloriesBurned,
      ),
    );
  }
  
  @override
  State<WorkoutFeedbackSheet> createState() => _WorkoutFeedbackSheetState();
}

class _WorkoutFeedbackSheetState extends State<WorkoutFeedbackSheet> {
  // RPE 值 (1-10)
  double _rpe = 5;
  
  // 心情
  String? _mood;
  
  // 疲勞度
  String? _fatigueLevel;
  
  // 備註
  final TextEditingController _noteController = TextEditingController();
  
  // 是否需要協助
  bool _needHelp = false;
  
  // 求助訊息
  final TextEditingController _helpMessageController = TextEditingController();
  
  // 分享選項
  bool _shareToCoach = true;
  bool _shareToChat = false;
  
  // 配色
  static const Color _primaryOrange = Color(0xFFFF9800);
  static const Color _primaryBlue = Color(0xFF2196F3);
  static const Color _textPrimary = Color(0xFF2D3748);
  static const Color _textSecondary = Color(0xFF718096);
  
  // 主題色（根據訓練來源）
  Color get _themeColor => widget.source == WorkoutSource.plan ? _primaryOrange : _primaryBlue;
  
  @override
  void dispose() {
    _noteController.dispose();
    _helpMessageController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
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
          // 拖拽指示條
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
                    color: _themeColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.emoji_emotions, color: _themeColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '訓練感受',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '記錄你的訓練感受，幫助教練了解你的狀況',
                        style: TextStyle(fontSize: 12, color: _textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),
          
          // 可滾動內容
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 訓練摘要
                  _buildWorkoutSummary(),
                  
                  const SizedBox(height: 24),
                  
                  // RPE 滑桿
                  _buildRpeSlider(),
                  
                  const SizedBox(height: 24),
                  
                  // 心情選擇
                  _buildMoodSelector(),
                  
                  const SizedBox(height: 24),
                  
                  // 疲勞度選擇
                  _buildFatigueSelector(),
                  
                  const SizedBox(height: 24),
                  
                  // 備註
                  _buildNoteInput(),
                  
                  const SizedBox(height: 24),
                  
                  // 需要協助
                  _buildHelpSection(),
                  
                  const SizedBox(height: 24),
                  
                  // 分享選項
                  _buildShareOptions(),
                  
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          
          // 底部按鈕
          _buildBottomButtons(),
        ],
      ),
    );
  }
  
  Widget _buildWorkoutSummary() {
    // 根據訓練來源決定顯示內容
    String title;
    String emoji;
    
    if (widget.source == WorkoutSource.plan) {
      title = widget.planName ?? widget.workoutName;
      emoji = '🏋️';
    } else {
      emoji = FreeWorkoutType.getEmoji(widget.freeWorkoutType ?? '');
      final typeLabel = FreeWorkoutType.getLabel(widget.freeWorkoutType ?? '');
      if (widget.freeWorkoutCategory != null && widget.freeWorkoutCategory!.isNotEmpty) {
        title = '$typeLabel - ${widget.freeWorkoutCategory}';
      } else {
        title = typeLabel;
      }
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _themeColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _themeColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _themeColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.durationMinutes} 分鐘 • ${widget.caloriesBurned.toStringAsFixed(0)} 卡路里',
                  style: TextStyle(fontSize: 13, color: _textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check, color: Colors.white, size: 16),
                SizedBox(width: 4),
                Text(
                  '完成',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRpeSlider() {
    final rpeInt = _rpe.round();
    final rpeDescription = WorkoutFeedback.getRpeDescription(rpeInt);
    
    // RPE 顏色漸變
    Color getRpeColor(int rpe) {
      if (rpe <= 3) return Colors.green;
      if (rpe <= 5) return Colors.lightGreen;
      if (rpe <= 7) return Colors.orange;
      return Colors.red;
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '💪 運動強度感受 (RPE)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: getRpeColor(rpeInt).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$rpeInt - $rpeDescription',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: getRpeColor(rpeInt),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: getRpeColor(rpeInt),
            inactiveTrackColor: Colors.grey[200],
            thumbColor: getRpeColor(rpeInt),
            overlayColor: getRpeColor(rpeInt).withOpacity(0.2),
            trackHeight: 8,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
          ),
          child: Slider(
            value: _rpe,
            min: 1,
            max: 10,
            divisions: 9,
            onChanged: (value) {
              HapticFeedback.selectionClick();
              setState(() => _rpe = value);
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('1 輕鬆', style: TextStyle(fontSize: 11, color: _textSecondary)),
            Text('10 極限', style: TextStyle(fontSize: 11, color: _textSecondary)),
          ],
        ),
      ],
    );
  }
  
  Widget _buildMoodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '😊 今天心情',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: WorkoutFeedback.moods.map((mood) {
            final isSelected = _mood == mood['value'];
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _mood = mood['value']);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? _themeColor : Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? _themeColor : Colors.grey[300]!,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(mood['emoji']!, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 6),
                    Text(
                      mood['label']!,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.white : _textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
  
  Widget _buildFatigueSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '⚡ 疲勞程度',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Row(
          children: WorkoutFeedback.fatigueLevels.map((level) {
            final isSelected = _fatigueLevel == level['value'];
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _fatigueLevel = level['value']);
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? _themeColor : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? _themeColor : Colors.grey[300]!,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(level['emoji']!, style: const TextStyle(fontSize: 24)),
                      const SizedBox(height: 4),
                      Text(
                        level['label']!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.white : _textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
  
  Widget _buildNoteInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '💬 訓練備註',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _noteController,
          maxLines: 3,
          maxLength: 200,
          decoration: InputDecoration(
            hintText: '記錄今天的訓練感想、突破或問題...',
            hintStyle: TextStyle(color: _textSecondary, fontSize: 14),
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _themeColor, width: 2),
            ),
            counterStyle: TextStyle(color: _textSecondary),
          ),
        ),
      ],
    );
  }
  
  Widget _buildHelpSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '🆘 需要教練協助？',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            Switch(
              value: _needHelp,
              onChanged: (value) {
                HapticFeedback.selectionClick();
                setState(() => _needHelp = value);
              },
              activeColor: Colors.red,
            ),
          ],
        ),
        if (_needHelp) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _helpMessageController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: '告訴教練你遇到什麼問題...',
              hintStyle: TextStyle(color: _textSecondary, fontSize: 14),
              filled: true,
              fillColor: Colors.red[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
              prefixIcon: const Icon(Icons.help_outline, color: Colors.red),
            ),
          ),
        ],
      ],
    );
  }
  
  Widget _buildShareOptions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.share, color: Colors.blue[700], size: 20),
              const SizedBox(width: 8),
              Text(
                '分享選項',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildShareOption(
            icon: Icons.notifications_active,
            title: '通知教練',
            subtitle: '教練會收到訓練完成通知',
            value: _shareToCoach,
            onChanged: (value) => setState(() => _shareToCoach = value),
          ),
          const SizedBox(height: 8),
          _buildShareOption(
            icon: Icons.chat_bubble_outline,
            title: '分享到聊天室',
            subtitle: '自動發送訓練記錄卡片到教練聊天室',
            value: _shareToChat,
            onChanged: (value) => setState(() => _shareToChat = value),
          ),
        ],
      ),
    );
  }
  
  Widget _buildShareOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: _textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              Text(subtitle, style: TextStyle(fontSize: 11, color: _textSecondary)),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: _themeColor,
        ),
      ],
    );
  }
  
  Widget _buildBottomButtons() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: Colors.grey[300]!),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                '跳過',
                style: TextStyle(color: _textSecondary, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _themeColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    '完成記錄',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _submit() {
    HapticFeedback.mediumImpact();
    
    final feedback = WorkoutFeedback(
      rpe: _rpe.round(),
      mood: _mood,
      fatigueLevel: _fatigueLevel,
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      needHelp: _needHelp,
      helpMessage: _needHelp && _helpMessageController.text.trim().isNotEmpty
          ? _helpMessageController.text.trim()
          : null,
    );
    
    Navigator.pop(
      context,
      WorkoutFeedbackResult(
        feedback: feedback,
        shareToCoach: _shareToCoach,
        shareToChat: _shareToChat,
      ),
    );
  }
}