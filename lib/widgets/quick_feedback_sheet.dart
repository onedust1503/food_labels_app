// lib/widgets/quick_feedback_sheet.dart
// 🎯 快速回饋彈窗組件 v1.1
// ✅ 修復：不依賴 ChatDetailPage 的 initialMessage 參數
// ✅ 顯示模板分類選擇
// ✅ 短模板直接發送、長模板顯示預覽後發送
// ✅ 支援情境推薦

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/quick_feedback_service.dart';
import '../services/chat_service.dart';  // 🔥 新增
import '../theme/app_theme.dart';
import '../pages/chat_detail_page.dart';

/// 快速回饋彈窗
class QuickFeedbackSheet extends StatefulWidget {
  final String traineeId;
  final String traineeName;
  final int? daysSinceLastWorkout;
  final double? completionRate;
  final double? onTimeRate;
  final bool? achievedGoal;
  final VoidCallback? onFeedbackSent;

  const QuickFeedbackSheet({
    super.key,
    required this.traineeId,
    required this.traineeName,
    this.daysSinceLastWorkout,
    this.completionRate,
    this.onTimeRate,
    this.achievedGoal,
    this.onFeedbackSent,
  });

  /// 顯示快速回饋彈窗
  static Future<void> show(
    BuildContext context, {
    required String traineeId,
    required String traineeName,
    int? daysSinceLastWorkout,
    double? completionRate,
    double? onTimeRate,
    bool? achievedGoal,
    VoidCallback? onFeedbackSent,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QuickFeedbackSheet(
        traineeId: traineeId,
        traineeName: traineeName,
        daysSinceLastWorkout: daysSinceLastWorkout,
        completionRate: completionRate,
        onTimeRate: onTimeRate,
        achievedGoal: achievedGoal,
        onFeedbackSent: onFeedbackSent,
      ),
    );
  }

  @override
  State<QuickFeedbackSheet> createState() => _QuickFeedbackSheetState();
}

class _QuickFeedbackSheetState extends State<QuickFeedbackSheet> {
  final QuickFeedbackService _feedbackService = QuickFeedbackService();
  final ChatService _chatService = ChatService();  // 🔥 新增
  final TextEditingController _customController = TextEditingController();

  Map<FeedbackCategory, List<FeedbackTemplate>> _templatesByCategory = {};
  List<FeedbackTemplate> _recommendedTemplates = [];
  FeedbackCategory? _selectedCategory;
  bool _isLoading = true;
  bool _isSending = false;
  bool _showCustomInput = false;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  Future<void> _loadTemplates() async {
    try {
      final results = await Future.wait([
        _feedbackService.getTemplatesByCategory(),
        _feedbackService.getRecommendedTemplates(
          traineeId: widget.traineeId,
          daysSinceLastWorkout: widget.daysSinceLastWorkout,
          completionRate: widget.completionRate,
          onTimeRate: widget.onTimeRate,
          achievedGoal: widget.achievedGoal,
        ),
      ]);

      setState(() {
        _templatesByCategory = results[0] as Map<FeedbackCategory, List<FeedbackTemplate>>;
        _recommendedTemplates = results[1] as List<FeedbackTemplate>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('載入模板失敗');
    }
  }

  Future<void> _sendFeedback(FeedbackTemplate template) async {
    if (template.isQuickSend) {
      // 短模板：直接發送
      await _sendDirectly(template);
    } else {
      // 長模板：顯示確認對話框
      await _showSendConfirmDialog(template);
    }
  }

  Future<void> _sendDirectly(FeedbackTemplate template) async {
    setState(() => _isSending = true);
    HapticFeedback.mediumImpact();

    try {
      await _feedbackService.sendQuickFeedback(
        traineeId: widget.traineeId,
        templateId: template.id,
        content: template.content,
      );

      if (mounted) {
        Navigator.pop(context);
        _showSuccess('已發送：${template.content}');
        widget.onFeedbackSent?.call();
      }
    } catch (e) {
      _showError('發送失敗：$e');
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  // 🔥 v1.1：顯示確認對話框（替代跳轉到聊天室）
  Future<void> _showSendConfirmDialog(FeedbackTemplate template) async {
    final TextEditingController editController = TextEditingController(text: template.content);
    
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.coach.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.edit, color: AppColors.coach, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('編輯訊息'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '發送給 ${widget.traineeName}',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: editController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: '輸入訊息內容...',
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('取消', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.send, size: 18),
            label: const Text('發送'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.coach,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      final content = editController.text.trim();
      if (content.isNotEmpty) {
        setState(() => _isSending = true);
        HapticFeedback.mediumImpact();

        try {
          await _feedbackService.sendQuickFeedback(
            traineeId: widget.traineeId,
            templateId: template.id,
            content: content,
          );

          if (mounted) {
            Navigator.pop(context);
            _showSuccess('已發送訊息');
            widget.onFeedbackSent?.call();
          }
        } catch (e) {
          _showError('發送失敗：$e');
        } finally {
          if (mounted) {
            setState(() => _isSending = false);
          }
        }
      }
    }
    
    editController.dispose();
  }

  // 🔥 v1.1：開啟聊天室（不預填訊息，但顯示提示）
  Future<void> _openChatRoom() async {
    try {
      final chatRoomId = await _chatService.createOrGetChatRoom(widget.traineeId);

      if (mounted) {
        Navigator.pop(context);  // 關閉彈窗
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatDetailPage(
              chatId: chatRoomId,
              chatName: widget.traineeName,
              avatarUrl: '',
            ),
          ),
        );
      }
    } catch (e) {
      _showError('開啟聊天室失敗');
    }
  }

  Future<void> _sendCustomMessage() async {
    final content = _customController.text.trim();
    if (content.isEmpty) {
      _showError('請輸入訊息內容');
      return;
    }

    setState(() => _isSending = true);
    HapticFeedback.mediumImpact();

    try {
      // 直接發送自訂訊息
      await _feedbackService.sendQuickFeedback(
        traineeId: widget.traineeId,
        templateId: 'custom',
        content: content,
      );

      if (mounted) {
        Navigator.pop(context);
        _showSuccess('已發送訊息');
        widget.onFeedbackSent?.call();
      }
    } catch (e) {
      _showError('發送失敗：$e');
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          const Divider(height: 1),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            )
          else
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_recommendedTemplates.isNotEmpty) ...[
                      _buildRecommendedSection(),
                      const SizedBox(height: 20),
                    ],
                    _buildCategoryTabs(),
                    const SizedBox(height: 16),
                    _buildTemplateList(),
                    const SizedBox(height: 16),
                    _buildCustomInputSection(),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 拖動條
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.coach.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.chat_bubble, color: AppColors.coach, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '快速回饋',
                      style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '發送給 ${widget.traineeName}',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              // 🔥 v1.1：開啟完整聊天室按鈕
              TextButton.icon(
                onPressed: _openChatRoom,
                icon: Icon(Icons.open_in_new, size: 16, color: AppColors.coach),
                label: Text('開啟聊天', style: TextStyle(color: AppColors.coach)),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome, color: AppColors.warning, size: 18),
            const SizedBox(width: 6),
            Text(
              '推薦回饋',
              style: AppTextStyles.label.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.warning,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _recommendedTemplates.map((template) {
            return _buildQuickChip(template);
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildQuickChip(FeedbackTemplate template) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isSending ? null : () => _sendFeedback(template),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.coach.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.coach.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(template.categoryIcon, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  template.content.length > 15
                      ? '${template.content.substring(0, 15)}...'
                      : template.content,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.coach,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (!template.isQuickSend) ...[
                const SizedBox(width: 4),
                Icon(Icons.edit, size: 12, color: AppColors.coach),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTabs() {
    final categories = [
      null,  // 全部
      FeedbackCategory.encouragement,
      FeedbackCategory.training,
      FeedbackCategory.nutrition,
      FeedbackCategory.reminder,
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((category) {
          final isSelected = _selectedCategory == category;
          final label = category == null ? '全部' : _getCategoryName(category);
          final icon = category == null ? '📋' : _getCategoryIcon(category);

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(icon, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  Text(label),
                ],
              ),
              onSelected: (selected) {
                setState(() {
                  _selectedCategory = selected ? category : null;
                });
              },
              selectedColor: AppColors.coach.withOpacity(0.2),
              checkmarkColor: AppColors.coach,
              labelStyle: TextStyle(
                color: isSelected ? AppColors.coach : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTemplateList() {
    List<FeedbackTemplate> templates = [];

    if (_selectedCategory == null) {
      // 全部模板
      _templatesByCategory.forEach((_, list) {
        templates.addAll(list);
      });
    } else {
      templates = _templatesByCategory[_selectedCategory] ?? [];
    }

    if (templates.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            '沒有可用的模板',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textTertiary),
          ),
        ),
      );
    }

    return Column(
      children: templates.map((template) => _buildTemplateItem(template)).toList(),
    );
  }

  Widget _buildTemplateItem(FeedbackTemplate template) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isSending ? null : () => _sendFeedback(template),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _getCategoryColor(template.category).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      template.categoryIcon,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        template.content,
                        style: AppTextStyles.bodyMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getCategoryColor(template.category).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              template.categoryName,
                              style: AppTextStyles.caption.copyWith(
                                color: _getCategoryColor(template.category),
                                fontSize: 10,
                              ),
                            ),
                          ),
                          if (template.isDefault) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '預設',
                                style: AppTextStyles.caption.copyWith(
                                  color: Colors.grey,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: template.isQuickSend
                        ? AppColors.coach.withOpacity(0.1)
                        : AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    template.isQuickSend ? Icons.send : Icons.edit,
                    size: 18,
                    color: template.isQuickSend ? AppColors.coach : AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _showCustomInput = !_showCustomInput),
          child: Row(
            children: [
              Icon(
                _showCustomInput ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                color: AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 4),
              Text(
                '自訂訊息',
                style: AppTextStyles.label.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (_showCustomInput) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _customController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: '輸入自訂訊息...',
              hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textTertiary),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSending ? null : _sendCustomMessage,
              icon: _isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send, size: 18),
              label: Text(_isSending ? '發送中...' : '發送自訂訊息'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.coach,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _getCategoryName(FeedbackCategory category) {
    switch (category) {
      case FeedbackCategory.encouragement:
        return '鼓勵';
      case FeedbackCategory.training:
        return '訓練';
      case FeedbackCategory.nutrition:
        return '營養';
      case FeedbackCategory.reminder:
        return '提醒';
      case FeedbackCategory.custom:
        return '自訂';
    }
  }

  String _getCategoryIcon(FeedbackCategory category) {
    switch (category) {
      case FeedbackCategory.encouragement:
        return '😊';
      case FeedbackCategory.training:
        return '💪';
      case FeedbackCategory.nutrition:
        return '🍎';
      case FeedbackCategory.reminder:
        return '⏰';
      case FeedbackCategory.custom:
        return '✏️';
    }
  }

  Color _getCategoryColor(FeedbackCategory category) {
    switch (category) {
      case FeedbackCategory.encouragement:
        return Colors.pink;
      case FeedbackCategory.training:
        return Colors.blue;
      case FeedbackCategory.nutrition:
        return Colors.green;
      case FeedbackCategory.reminder:
        return Colors.orange;
      case FeedbackCategory.custom:
        return Colors.purple;
    }
  }
}