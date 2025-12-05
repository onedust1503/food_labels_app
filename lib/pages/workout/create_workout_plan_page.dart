// lib/pages/workout/create_workout_plan_page.dart
// 🎯 教練端創建訓練計畫 v2.0
// ✨ 明亮版莫蘭迪風格
// ✅ 整合 WGER API + 多學員選擇 + 週期重複設定
// ✅ 優化動作選擇 UX

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/workout_model.dart';
import '../../services/workout_service.dart';
import '../../services/user_service.dart';
import '../../services/wger_api_service.dart';
import '../../theme/app_theme.dart';

class CreateWorkoutPlanPage extends StatefulWidget {
  const CreateWorkoutPlanPage({super.key});

  @override
  State<CreateWorkoutPlanPage> createState() => _CreateWorkoutPlanPageState();
}

class _CreateWorkoutPlanPageState extends State<CreateWorkoutPlanPage>
    with SingleTickerProviderStateMixin {
  final WorkoutService _workoutService = WorkoutService();
  final UserService _userService = UserService();
  final WgerApiService _wgerService = WgerApiService();

  final _formKey = GlobalKey<FormState>();
  final _planNameController = TextEditingController();
  final _descriptionController = TextEditingController();

  // 選中的學員
  List<String> _selectedTraineeIds = [];
  List<DocumentSnapshot> _students = [];

  // 日期設定
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;

  // 重複設定
  bool _isSingleSession = false;
  List<String> _selectedWeekDays = [];

  // 每日訓練內容
  Map<String, List<PlanExercise>> _weekDaysExercises = {};

  bool _isLoading = false;
  bool _isLoadingStudents = true;

  // 🔥 動畫控制
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final Map<String, String> _dayNames = {
    'monday': '星期一',
    'tuesday': '星期二',
    'wednesday': '星期三',
    'thursday': '星期四',
    'friday': '星期五',
    'saturday': '星期六',
    'sunday': '星期日',
  };

  final List<String> _dayOrder = [
    'monday', 'tuesday', 'wednesday', 'thursday', 
    'friday', 'saturday', 'sunday',
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: AppAnimations.normal,
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _loadStudents();
    _animationController.forward();
  }

  @override
  void dispose() {
    _planNameController.dispose();
    _descriptionController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    try {
      final students = await _userService.getCoachStudents(
        _userService.currentUserId!,
      );
      if (mounted) {
        setState(() {
          _students = students;
          _isLoadingStudents = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingStudents = false);
        _showSnackBar('載入學員失敗：$e', isError: true);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AppColors.error : AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          '創建訓練計畫',
          style: AppTextStyles.h3.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.secondaryGradient,
          ),
        ),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoadingStudents
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.coach),
              ),
            )
          : FadeTransition(
              opacity: _fadeAnimation,
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 提示訊息
                      _buildInfoBanner(),
                      const SizedBox(height: 20),
                      // 計畫資訊
                      _buildPlanInfo(),
                      const SizedBox(height: 20),
                      // 日期設定
                      _buildDateSettings(),
                      const SizedBox(height: 20),
                      // 重複設定
                      _buildRepeatSettings(),
                      const SizedBox(height: 20),
                      // 訓練內容
                      if (!_isSingleSession && _selectedWeekDays.isNotEmpty)
                        _buildTrainingContent(),
                      if (_isSingleSession) 
                        _buildSingleSessionContent(),
                      const SizedBox(height: 28),
                      // 提交按鈕
                      _buildSubmitButton(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  // 🎨 提示橫幅
  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.info.withOpacity(0.1),
            AppColors.info.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.info.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.lightbulb_outline, 
              color: AppColors.info, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              '創建計畫後，您可以選擇要分配給哪些學員',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.info,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🎨 計畫資訊卡片
  Widget _buildPlanInfo() {
    return _buildCard(
      icon: Icons.edit_note,
      title: '計畫資訊',
      child: Column(
        children: [
          TextFormField(
            controller: _planNameController,
            decoration: _buildInputDecoration(
              label: '計畫名稱 *',
              hint: '例：胸與三頭訓練',
              icon: Icons.title,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '請輸入計畫名稱';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            decoration: _buildInputDecoration(
              label: '計畫說明（選填）',
              hint: '說明訓練目標和重點',
              icon: Icons.description,
            ),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  // 🎨 日期設定卡片
  Widget _buildDateSettings() {
    return _buildCard(
      icon: Icons.calendar_today,
      title: '計畫時間',
      child: Column(
        children: [
          _buildDateTile(
            icon: Icons.event,
            iconColor: AppColors.coach,
            title: '開始日期',
            value: _formatDate(_startDate),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _startDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: ColorScheme.light(
                        primary: AppColors.coach,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                setState(() => _startDate = picked);
              }
            },
          ),
          Divider(color: AppColors.divider, height: 24),
          _buildDateTile(
            icon: Icons.event_available,
            iconColor: AppColors.warning,
            title: '結束日期（選填）',
            value: _endDate != null ? _formatDate(_endDate!) : '持續進行',
            valueColor: _endDate != null ? null : AppColors.textTertiary,
            trailing: _endDate != null
                ? IconButton(
                    icon: Icon(Icons.clear, 
                      size: 20, color: AppColors.textTertiary),
                    onPressed: () => setState(() => _endDate = null),
                  )
                : null,
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _endDate ?? _startDate.add(const Duration(days: 30)),
                firstDate: _startDate,
                lastDate: DateTime.now().add(const Duration(days: 365)),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: ColorScheme.light(
                        primary: AppColors.warning,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                setState(() => _endDate = picked);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDateTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    Color? valueColor,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                      color: valueColor,
                    ),
                  ),
                ],
              ),
            ),
            trailing ?? Icon(Icons.chevron_right, 
              color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  // 🎨 重複設定卡片
  Widget _buildRepeatSettings() {
    return _buildCard(
      icon: Icons.repeat,
      title: '重複設定',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 單次訓練開關
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              title: Text(
                '單次訓練',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                '僅執行一次，不重複',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              value: _isSingleSession,
              activeColor: AppColors.coach,
              onChanged: (value) {
                setState(() {
                  _isSingleSession = value;
                  if (value) {
                    _selectedWeekDays.clear();
                    _weekDaysExercises.clear();
                  }
                });
              },
            ),
          ),
          
          if (!_isSingleSession) ...[
            const SizedBox(height: 20),
            Text(
              '選擇訓練日（可多選）',
              style: AppTextStyles.label.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _dayOrder.map((day) {
                final isSelected = _selectedWeekDays.contains(day);
                return _buildDayChip(day, isSelected);
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDayChip(String day, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedWeekDays.remove(day);
            _weekDaysExercises.remove(day);
          } else {
            _selectedWeekDays.add(day);
            if (!_weekDaysExercises.containsKey(day)) {
              _weekDaysExercises[day] = [];
            }
          }
        });
      },
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.secondaryGradient : null,
          color: isSelected ? null : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? AppColors.coach 
                : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? AppShadows.small : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(Icons.check, 
                  color: Colors.white, size: 16),
              ),
            Text(
              _dayNames[day]!,
              style: AppTextStyles.label.copyWith(
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🎨 訓練內容（週期訓練）
  Widget _buildTrainingContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _selectedWeekDays.map((day) {
        return _buildDayExercisesCard(day);
      }).toList(),
    );
  }

  Widget _buildDayExercisesCard(String day) {
    final exercises = _weekDaysExercises[day] ?? [];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.medium,
      ),
      child: Column(
        children: [
          // 標題
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppColors.secondaryGradient,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.calendar_today, 
                    color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Text(
                  _dayNames[day]!,
                  style: AppTextStyles.h4.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${exercises.length} 個動作',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // 動作列表
          if (exercises.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.fitness_center,
                    size: 48, color: AppColors.textTertiary),
                  const SizedBox(height: 12),
                  Text(
                    '尚未添加運動',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: exercises.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                return _buildExerciseCard(exercises[index], day, index);
              },
            ),
          
          // 新增按鈕
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _addExerciseToDay(day),
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('新增運動'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.coach,
                  side: BorderSide(color: AppColors.coach, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🎨 訓練內容（單次訓練）
  Widget _buildSingleSessionContent() {
    final exercises = _weekDaysExercises['single'] ?? [];
    
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.medium,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppColors.warningGradient,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.fitness_center, 
                    color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Text(
                  '訓練動作',
                  style: AppTextStyles.h4.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${exercises.length} 個動作',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          if (exercises.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.fitness_center,
                    size: 48, color: AppColors.textTertiary),
                  const SizedBox(height: 12),
                  Text(
                    '尚未添加運動',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: exercises.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                return _buildExerciseCard(exercises[index], 'single', index);
              },
            ),
          
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _addExerciseToDay('single'),
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('新增運動'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.warning,
                  side: BorderSide(color: AppColors.warning, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🎨 運動卡片
  Widget _buildExerciseCard(PlanExercise exercise, String day, int index) {
    final categoryColor = _getCategoryColor(exercise.category);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: categoryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: categoryColor.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          // 序號
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: categoryColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: AppTextStyles.label.copyWith(
                  color: categoryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // 運動資訊
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        exercise.name,
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: categoryColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        exercise.category,
                        style: AppTextStyles.caption.copyWith(
                          color: categoryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (exercise.sets != null && exercise.reps != null) ...[
                      Icon(Icons.repeat, 
                        size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        '${exercise.sets} 組 × ${exercise.reps} 次',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    if (exercise.weight != null) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.line_weight, 
                        size: 14, color: categoryColor),
                      const SizedBox(width: 4),
                      Text(
                        '${exercise.weight} kg',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: categoryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // 刪除按鈕
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close, 
                color: AppColors.error, size: 16),
            ),
            onPressed: () {
              setState(() {
                _weekDaysExercises[day]?.removeAt(index);
              });
              _showSnackBar('已移除 ${exercise.name}');
            },
          ),
        ],
      ),
    );
  }

  // 🎨 提交按鈕
  Widget _buildSubmitButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.secondaryGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppShadows.emphasized,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : _createPlanAndSelectStudents,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isLoading)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                else
                  const Icon(Icons.check_circle, 
                    color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Text(
                  _isLoading ? '創建中...' : '下一步：選擇學員',
                  style: AppTextStyles.h4.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🔧 共用卡片組件
  Widget _buildCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.medium,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.coach.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.coach, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: AppTextStyles.h4.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.coach),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.coach, width: 2),
      ),
      filled: true,
      fillColor: AppColors.background,
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case '胸部': return const Color(0xFFE57373);
      case '背部': return const Color(0xFF64B5F6);
      case '腿部': return const Color(0xFFFFB74D);
      case '肩膀': return const Color(0xFFBA68C8);
      case '手臂': return AppColors.coach;
      case '腹肌': return const Color(0xFF4DB6AC);
      case '有氧': return const Color(0xFFF06292);
      default: return AppColors.textSecondary;
    }
  }

  // 🔧 添加運動到指定日期
  Future<void> _addExerciseToDay(String day) async {
    final result = await showDialog<Exercise>(
      context: context,
      builder: (context) => ExercisePickerDialog(wgerService: _wgerService),
    );

    if (result != null) {
      final exerciseDetail = await showDialog<PlanExercise>(
        context: context,
        builder: (context) => ExerciseDetailDialog(exercise: result),
      );

      if (exerciseDetail != null) {
        setState(() {
          if (!_weekDaysExercises.containsKey(day)) {
            _weekDaysExercises[day] = [];
          }
          _weekDaysExercises[day]!.add(exerciseDetail);
        });
        _showSnackBar('已添加 ${exerciseDetail.name}');
      }
    }
  }

  // 🔧 創建計畫並選擇學員
  Future<void> _createPlanAndSelectStudents() async {
    if (!_formKey.currentState!.validate()) return;

    bool hasExercises = false;
    if (_isSingleSession) {
      hasExercises = _weekDaysExercises['single']?.isNotEmpty ?? false;
    } else {
      hasExercises = _weekDaysExercises.values.any((list) => list.isNotEmpty);
    }

    if (!hasExercises) {
      _showSnackBar('請至少添加一個運動', isError: true);
      return;
    }

    final selectedStudents = await showDialog<List<String>>(
      context: context,
      builder: (context) => StudentSelectorDialog(
        students: _students,
        preSelectedIds: _selectedTraineeIds,
      ),
    );

    if (selectedStudents == null || selectedStudents.isEmpty) {
      _showSnackBar('請至少選擇一位學員', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
      _selectedTraineeIds = selectedStudents;
    });

    try {
      for (String traineeId in _selectedTraineeIds) {
        List<WorkoutPlanDay> days = [];

        if (_isSingleSession) {
          days.add(WorkoutPlanDay(
            dayOfWeek: 'single',
            exercises: _weekDaysExercises['single']!
                .map((e) => PlannedExercise(
                      name: e.name,
                      type: e.category,
                      sets: e.sets,
                      reps: e.reps,
                      notes: e.description,
                    ))
                .toList(),
          ));
        } else {
          for (String day in _selectedWeekDays) {
            if (_weekDaysExercises[day]?.isNotEmpty ?? false) {
              days.add(WorkoutPlanDay(
                dayOfWeek: day,
                exercises: _weekDaysExercises[day]!
                    .map((e) => PlannedExercise(
                          name: e.name,
                          type: e.category,
                          sets: e.sets,
                          reps: e.reps,
                          notes: e.description,
                        ))
                    .toList(),
              ));
            }
          }
        }

        await _workoutService.createWorkoutPlan(
          traineeId: traineeId,
          planName: _planNameController.text,
          description: _descriptionController.text.isNotEmpty
              ? _descriptionController.text
              : null,
          startDate: _startDate,
          endDate: _endDate,
          days: days,
        );
      }

      if (mounted) {
        _showSnackBar('成功為 ${_selectedTraineeIds.length} 位學員創建訓練計畫！');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('創建訓練計畫失敗: $e');
      }
      _showSnackBar('創建失敗：$e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }
}

// ===================================
// 📌 運動選擇對話框（升級版）
// ===================================

class ExercisePickerDialog extends StatefulWidget {
  final WgerApiService wgerService;

  const ExercisePickerDialog({super.key, required this.wgerService});

  @override
  State<ExercisePickerDialog> createState() => _ExercisePickerDialogState();
}

class _ExercisePickerDialogState extends State<ExercisePickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<Exercise> _allExercises = [];
  List<Exercise> _filteredExercises = [];
  bool _isLoading = true;
  String _selectedCategory = '全部';

  final List<String> _categories = [
    '全部', '胸部', '背部', '腿部', '肩膀', '手臂', '腹肌', '有氧',
  ];

  @override
  void initState() {
    super.initState();
    _loadExercises();
    _searchController.addListener(_filterExercises);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadExercises() async {
    try {
      final exercises = await widget.wgerService.getExercises(limit: 100);
      if (mounted) {
        setState(() {
          _allExercises = exercises;
          _filteredExercises = exercises;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterExercises() {
    final query = _searchController.text.toLowerCase().trim();

    setState(() {
      _filteredExercises = _allExercises.where((exercise) {
        final matchesSearch = query.isEmpty ||
            exercise.nameZhTw.toLowerCase().contains(query) ||
            exercise.name.toLowerCase().contains(query);

        final matchesCategory =
            _selectedCategory == '全部' || exercise.category == _selectedCategory;

        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case '胸部': return const Color(0xFFE57373);
      case '背部': return const Color(0xFF64B5F6);
      case '腿部': return const Color(0xFFFFB74D);
      case '肩膀': return const Color(0xFFBA68C8);
      case '手臂': return AppColors.coach;
      case '腹肌': return const Color(0xFF4DB6AC);
      case '有氧': return const Color(0xFFF06292);
      default: return AppColors.coach;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 標題
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.coach.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.fitness_center, 
                    color: AppColors.coach, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  '選擇運動',
                  style: AppTextStyles.h3.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 搜尋欄
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜尋運動名稱...',
                prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, 
                          size: 20, color: AppColors.textSecondary),
                        onPressed: () {
                          _searchController.clear();
                          _filterExercises();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.divider),
                ),
                filled: true,
                fillColor: AppColors.background,
              ),
            ),
            const SizedBox(height: 12),

            // 分類篩選
            SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = category == _selectedCategory;
                  final categoryColor = category == '全部' 
                      ? AppColors.coach 
                      : _getCategoryColor(category);

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCategory = category;
                          _filterExercises();
                        });
                      },
                      child: AnimatedContainer(
                        duration: AppAnimations.fast,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: isSelected 
                              ? LinearGradient(
                                  colors: [categoryColor, categoryColor.withOpacity(0.8)],
                                )
                              : null,
                          color: isSelected ? null : categoryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: categoryColor.withOpacity(isSelected ? 1 : 0.3),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Text(
                          category,
                          style: AppTextStyles.label.copyWith(
                            color: isSelected ? Colors.white : categoryColor,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // 運動列表
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.coach),
                      ),
                    )
                  : _filteredExercises.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off, 
                                size: 48, color: AppColors.textTertiary),
                              const SizedBox(height: 12),
                              Text(
                                '找不到符合的運動',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredExercises.length,
                          itemBuilder: (context, index) {
                            final exercise = _filteredExercises[index];
                            final categoryColor = _getCategoryColor(exercise.category);
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: categoryColor.withOpacity(0.2),
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(12),
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: categoryColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.fitness_center,
                                    color: categoryColor,
                                    size: 24,
                                  ),
                                ),
                                title: Text(
                                  exercise.nameZhTw,
                                  style: AppTextStyles.bodyLarge.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Container(
                                  margin: const EdgeInsets.only(top: 6),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: categoryColor.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          exercise.category,
                                          style: AppTextStyles.caption.copyWith(
                                            color: categoryColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                trailing: Icon(
                                  Icons.add_circle,
                                  color: categoryColor,
                                  size: 28,
                                ),
                                onTap: () => Navigator.pop(context, exercise),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================================
// 📌 運動詳情設定對話框
// ===================================

class ExerciseDetailDialog extends StatefulWidget {
  final Exercise exercise;

  const ExerciseDetailDialog({super.key, required this.exercise});

  @override
  State<ExerciseDetailDialog> createState() => _ExerciseDetailDialogState();
}

class _ExerciseDetailDialogState extends State<ExerciseDetailDialog> {
  final _setsController = TextEditingController();
  final _repsController = TextEditingController();
  final _weightController = TextEditingController();

  @override
  void dispose() {
    _setsController.dispose();
    _repsController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case '胸部': return const Color(0xFFE57373);
      case '背部': return const Color(0xFF64B5F6);
      case '腿部': return const Color(0xFFFFB74D);
      case '肩膀': return const Color(0xFFBA68C8);
      case '手臂': return AppColors.coach;
      case '腹肌': return const Color(0xFF4DB6AC);
      case '有氧': return const Color(0xFFF06292);
      default: return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryColor = _getCategoryColor(widget.exercise.category);
    
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: categoryColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.fitness_center, 
              color: categoryColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.exercise.nameZhTw,
                  style: AppTextStyles.h4.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: categoryColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.exercise.category,
                    style: AppTextStyles.caption.copyWith(
                      color: categoryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.exercise.description != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, 
                      size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.exercise.description!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            
            Text(
              '訓練參數',
              style: AppTextStyles.label.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            
            // 組數
            TextField(
              controller: _setsController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '組數 *',
                hintText: '例：3',
                prefixIcon: Icon(Icons.repeat, color: categoryColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                filled: true,
                fillColor: AppColors.background,
              ),
            ),
            const SizedBox(height: 14),
            
            // 次數
            TextField(
              controller: _repsController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '次數 *',
                hintText: '例：12',
                prefixIcon: Icon(Icons.format_list_numbered, color: categoryColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                filled: true,
                fillColor: AppColors.background,
              ),
            ),
            const SizedBox(height: 14),
            
            // 重量
            TextField(
              controller: _weightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: '重量 (kg) - 選填',
                hintText: '例：20',
                prefixIcon: Icon(Icons.line_weight, color: categoryColor),
                suffixText: 'kg',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                filled: true,
                fillColor: AppColors.background,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.lightbulb_outline, 
                  size: 14, color: AppColors.textTertiary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '重量可以不填，讓學員自行調整',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
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
          child: Text(
            '取消',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            final sets = int.tryParse(_setsController.text);
            final reps = int.tryParse(_repsController.text);
            final weight = _weightController.text.isEmpty 
                ? null 
                : double.tryParse(_weightController.text);

            if (sets == null || reps == null || sets <= 0 || reps <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('請輸入有效的組數和次數'),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
              return;
            }

            Navigator.pop(
              context,
              PlanExercise(
                name: widget.exercise.nameZhTw,
                category: widget.exercise.category,
                sets: sets,
                reps: reps,
                weight: weight,
                description: widget.exercise.description,
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: categoryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Text('確定', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

// ===================================
// 📌 學員選擇對話框
// ===================================

class StudentSelectorDialog extends StatefulWidget {
  final List<DocumentSnapshot> students;
  final List<String> preSelectedIds;

  const StudentSelectorDialog({
    super.key,
    required this.students,
    this.preSelectedIds = const [],
  });

  @override
  State<StudentSelectorDialog> createState() => _StudentSelectorDialogState();
}

class _StudentSelectorDialogState extends State<StudentSelectorDialog> {
  late List<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = List.from(widget.preSelectedIds);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.people, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 12),
          Text(
            '選擇學員',
            style: AppTextStyles.h4.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: widget.students.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_off, 
                      size: 48, color: AppColors.textTertiary),
                    const SizedBox(height: 12),
                    Text(
                      '尚無配對學員',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: widget.students.length,
                itemBuilder: (context, index) {
                  final student = widget.students[index];
                  final data = student.data() as Map<String, dynamic>;
                  final name = data['displayName'] ?? '未命名學員';
                  final isSelected = _selectedIds.contains(student.id);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? AppColors.coach.withOpacity(0.08)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected 
                            ? AppColors.coach.withOpacity(0.3)
                            : AppColors.divider,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: CheckboxListTile(
                      title: Text(
                        name,
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        data['email'] ?? '',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      value: isSelected,
                      activeColor: AppColors.coach,
                      checkboxShape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedIds.add(student.id);
                          } else {
                            _selectedIds.remove(student.id);
                          }
                        });
                      },
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            '取消',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: _selectedIds.isEmpty
              ? null
              : () => Navigator.pop(context, _selectedIds),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.coach,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.divider,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            '確定（${_selectedIds.length}）',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

// ===================================
// 📌 運動模型
// ===================================

class PlanExercise {
  final String name;
  final String category;
  final int? sets;
  final int? reps;
  final double? weight;
  final String? description;

  PlanExercise({
    required this.name,
    required this.category,
    this.sets,
    this.reps,
    this.weight,
    this.description,
  });
}