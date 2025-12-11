// lib/pages/coach/feedback_templates_page.dart
// 🎯 快速回饋模板管理頁面 v1.0
// ✅ 查看所有模板（預設 + 自訂）
// ✅ 新增、編輯、刪除自訂模板
// ✅ 分類管理

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/quick_feedback_service.dart';
import '../../theme/app_theme.dart';

class FeedbackTemplatesPage extends StatefulWidget {
  const FeedbackTemplatesPage({super.key});

  @override
  State<FeedbackTemplatesPage> createState() => _FeedbackTemplatesPageState();
}

class _FeedbackTemplatesPageState extends State<FeedbackTemplatesPage>
    with SingleTickerProviderStateMixin {
  final QuickFeedbackService _feedbackService = QuickFeedbackService();
  late TabController _tabController;

  Map<FeedbackCategory, List<FeedbackTemplate>> _templatesByCategory = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadTemplates();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTemplates() async {
    setState(() => _isLoading = true);
    
    try {
      final templates = await _feedbackService.getTemplatesByCategory();
      setState(() {
        _templatesByCategory = templates;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('載入模板失敗');
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

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('快速回饋模板'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.secondaryGradient,
          ),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: '😊 鼓勵'),
            Tab(text: '💪 訓練'),
            Tab(text: '🍎 營養'),
            Tab(text: '⏰ 提醒'),
            Tab(text: '✏️ 自訂'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCategoryList(FeedbackCategory.encouragement),
                _buildCategoryList(FeedbackCategory.training),
                _buildCategoryList(FeedbackCategory.nutrition),
                _buildCategoryList(FeedbackCategory.reminder),
                _buildCategoryList(FeedbackCategory.custom),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTemplateDialog,
        backgroundColor: AppColors.coach,
        icon: const Icon(Icons.add),
        label: const Text('新增模板'),
      ),
    );
  }

  Widget _buildCategoryList(FeedbackCategory category) {
    final templates = _templatesByCategory[category] ?? [];
    
    if (templates.isEmpty) {
      return _buildEmptyState(category);
    }

    // 分離預設和自訂模板
    final defaultTemplates = templates.where((t) => t.isDefault).toList();
    final customTemplates = templates.where((t) => !t.isDefault).toList();

    return RefreshIndicator(
      onRefresh: _loadTemplates,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (customTemplates.isNotEmpty) ...[
            _buildSectionHeader('我的模板', customTemplates.length),
            const SizedBox(height: 12),
            ...customTemplates.map((t) => _buildTemplateCard(t, canEdit: true)),
            const SizedBox(height: 24),
          ],
          if (defaultTemplates.isNotEmpty) ...[
            _buildSectionHeader('預設模板', defaultTemplates.length),
            const SizedBox(height: 12),
            ...defaultTemplates.map((t) => _buildTemplateCard(t, canEdit: false)),
          ],
          const SizedBox(height: 80),  // FAB 空間
        ],
      ),
    );
  }

  Widget _buildEmptyState(FeedbackCategory category) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.coach.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Text(
              _getCategoryIcon(category),
              style: const TextStyle(fontSize: 48),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '尚無${_getCategoryName(category)}類模板',
            style: AppTextStyles.h4.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            '點擊右下角按鈕新增',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Row(
      children: [
        Text(
          title,
          style: AppTextStyles.label.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
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
            '$count',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.coach,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTemplateCard(FeedbackTemplate template, {required bool canEdit}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.small,
        border: canEdit
            ? Border.all(color: AppColors.coach.withOpacity(0.2))
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canEdit ? () => _showEditTemplateDialog(template) : null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // 圖標
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _getCategoryColor(template.category).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      template.categoryIcon,
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // 內容
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        template.content,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          // 類型標籤
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: template.isQuickSend
                                  ? AppColors.success.withOpacity(0.1)
                                  : AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  template.isQuickSend ? Icons.flash_on : Icons.edit,
                                  size: 12,
                                  color: template.isQuickSend
                                      ? AppColors.success
                                      : AppColors.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  template.isQuickSend ? '快速發送' : '編輯後發送',
                                  style: AppTextStyles.caption.copyWith(
                                    color: template.isQuickSend
                                        ? AppColors.success
                                        : AppColors.primary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // 預設標籤
                          if (template.isDefault) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '預設',
                                style: AppTextStyles.caption.copyWith(
                                  color: Colors.grey,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                          // 使用次數
                          if (template.usageCount > 0) ...[
                            const Spacer(),
                            Text(
                              '已使用 ${template.usageCount} 次',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textTertiary,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // 操作按鈕
                if (canEdit) ...[
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showEditTemplateDialog(template);
                      } else if (value == 'delete') {
                        _confirmDeleteTemplate(template);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('編輯'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 18, color: AppColors.error),
                            const SizedBox(width: 8),
                            Text('刪除', style: TextStyle(color: AppColors.error)),
                          ],
                        ),
                      ),
                    ],
                    icon: Icon(Icons.more_vert, color: AppColors.textTertiary),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddTemplateDialog() {
    _showTemplateDialog(
      title: '新增模板',
      initialContent: '',
      initialCategory: FeedbackCategory.values[_tabController.index],
      initialType: TemplateType.quick,
      onSave: (content, category, type) async {
        try {
          await _feedbackService.addCustomTemplate(
            content: content,
            category: category,
            type: type,
          );
          _showSuccess('模板已新增');
          _loadTemplates();
        } catch (e) {
          _showError('新增失敗：$e');
        }
      },
    );
  }

  void _showEditTemplateDialog(FeedbackTemplate template) {
    _showTemplateDialog(
      title: '編輯模板',
      initialContent: template.content,
      initialCategory: template.category,
      initialType: template.type,
      onSave: (content, category, type) async {
        try {
          await _feedbackService.updateTemplate(
            template.copyWith(
              content: content,
              category: category,
              type: type,
              updatedAt: DateTime.now(),
            ),
          );
          _showSuccess('模板已更新');
          _loadTemplates();
        } catch (e) {
          _showError('更新失敗：$e');
        }
      },
    );
  }

  void _showTemplateDialog({
    required String title,
    required String initialContent,
    required FeedbackCategory initialCategory,
    required TemplateType initialType,
    required Future<void> Function(String content, FeedbackCategory category, TemplateType type) onSave,
  }) {
    final contentController = TextEditingController(text: initialContent);
    FeedbackCategory selectedCategory = initialCategory;
    TemplateType selectedType = initialType;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.coach.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  title.contains('新增') ? Icons.add : Icons.edit,
                  color: AppColors.coach,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(title),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 內容輸入
                Text('模板內容', style: AppTextStyles.label),
                const SizedBox(height: 8),
                TextField(
                  controller: contentController,
                  maxLines: 3,
                  maxLength: 100,
                  decoration: InputDecoration(
                    hintText: '輸入回饋內容...',
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
                const SizedBox(height: 16),

                // 分類選擇
                Text('分類', style: AppTextStyles.label),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: FeedbackCategory.values.map((category) {
                    final isSelected = selectedCategory == category;
                    return ChoiceChip(
                      selected: isSelected,
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_getCategoryIcon(category)),
                          const SizedBox(width: 4),
                          Text(_getCategoryName(category)),
                        ],
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setDialogState(() => selectedCategory = category);
                        }
                      },
                      selectedColor: _getCategoryColor(category).withOpacity(0.2),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? _getCategoryColor(category)
                            : AppColors.textSecondary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // 發送方式
                Text('發送方式', style: AppTextStyles.label),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildTypeOption(
                        icon: Icons.flash_on,
                        label: '快速發送',
                        description: '直接發送',
                        isSelected: selectedType == TemplateType.quick,
                        onTap: () => setDialogState(() => selectedType = TemplateType.quick),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTypeOption(
                        icon: Icons.edit,
                        label: '編輯後發送',
                        description: '可修改內容',
                        isSelected: selectedType == TemplateType.long,
                        onTap: () => setDialogState(() => selectedType = TemplateType.long),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('取消', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                final content = contentController.text.trim();
                if (content.isEmpty) {
                  _showError('請輸入模板內容');
                  return;
                }
                Navigator.pop(context);
                await onSave(content, selectedCategory, selectedType);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.coach,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('儲存'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeOption({
    required IconData icon,
    required String label,
    required String description,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.coach.withOpacity(0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.coach : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.coach : AppColors.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: isSelected ? AppColors.coach : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            Text(
              description,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textTertiary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteTemplate(FeedbackTemplate template) {
    HapticFeedback.mediumImpact();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.delete, color: AppColors.error, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('刪除模板'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('確定要刪除這個模板嗎？'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                template.content,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _feedbackService.deleteTemplate(template.id);
                _showSuccess('模板已刪除');
                _loadTemplates();
              } catch (e) {
                _showError('刪除失敗：$e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('刪除'),
          ),
        ],
      ),
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