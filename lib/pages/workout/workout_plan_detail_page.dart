// lib/pages/workout/workout_plan_detail_page.dart
// ✅ v5.5 - 加入計畫更新通知橫幅
// 🔧 v5.5 新增：PlanUpdateBanner 顯示教練更新通知
// 🔧 v5.5 新增：hasUnreadUpdate 未讀標記處理
// 🔧 v5.5 新增：自動標記已讀功能
// 🔧 v5.4 教練備註區（學生端唯讀）
// 🔧 v5.4 已結束計畫灰色主題 + 執行限制

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/workout_model.dart';
import '../../models/completion_status.dart';
import '../../models/plan_progress.dart';
import '../../services/unified_workout_service.dart';
import '../../services/workout_progress_service.dart';
import '../../services/workout_completion_service.dart';
import '../../services/plan_status_service.dart';
import '../../components/completion_status_badge.dart';
import '../../utils/workout_date_helper.dart';
import 'workout_plan_execution_page.dart';

class WorkoutPlanDetailPage extends StatefulWidget {
  final WorkoutPlanModel plan;

  const WorkoutPlanDetailPage({super.key, required this.plan});

  @override
  State<WorkoutPlanDetailPage> createState() => _WorkoutPlanDetailPageState();
}

class _WorkoutPlanDetailPageState extends State<WorkoutPlanDetailPage>
    with SingleTickerProviderStateMixin {
  final UnifiedWorkoutService _workoutService = UnifiedWorkoutService();
  final WorkoutProgressService _progressService = WorkoutProgressService();
  final WorkoutCompletionService _completionService = WorkoutCompletionService();
  final PlanStatusService _planStatusService = PlanStatusService();

  // 🔥 v5.0：使用新的進度模型
  PlanProgress? _planProgress;
  bool _isLoading = true;
  late AnimationController _animController;
  
  // 🔧 v5.3：計畫狀態資訊
  PlanStatusInfo? _planStatusInfo;
  
  // 🔧 v5.4：教練備註和已結束狀態
  List<Map<String, dynamic>> _coachNotes = [];
  bool _isPlanEnded = false;
  
  // 🔧 v5.5 新增：更新通知相關
  bool _hasUnreadUpdate = false;
  int? _currentVersion;
  DateTime? _lastUpdateAt;
  String? _latestChangeSummary;
  
  // 今日資訊
  late int _todayWeekday;
  late String _todayEnglish;
  late String _todayFullName;
  late String _todayShortName;
  late DateTime _planStartDateOnly;
  late DateTime _todayDateOnly;

  // 🎨 Soft UI 配色
  static const Color _primaryOrange = Color(0xFFFF9800);
  static const Color _lightOrange = Color(0xFFFFF3E0);
  static const Color _darkOrange = Color(0xFFF57C00);
  static const Color _bgColor = Color(0xFFF8F9FA);
  static const Color _cardColor = Color(0xFFFFFFFF);
  static const Color _textPrimary = Color(0xFF2D3748);
  static const Color _textSecondary = Color(0xFF718096);
  static const Color _disabledColor = Color(0xFFCBD5E0);
  
  // 🔧 v5.4 配色
  static const Color _endedGrey = Color(0xFF9CA3AF);
  static const Color _coachGreen = Color(0xFF48BB78);
  
  // 🔧 v5.5 新增配色
  static const Color _updateWarning = Color(0xFFF59E0B);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    final now = DateTime.now();
    _todayWeekday = WorkoutDateHelper.getTodayWeekday();
    _todayEnglish = WorkoutDateHelper.getTodayEnglish();
    _todayFullName = WorkoutDateHelper.getTodayFullChinese();
    _todayShortName = WorkoutDateHelper.getShortChinese(_todayWeekday);
    _todayDateOnly = DateTime(now.year, now.month, now.day);
    
    _planStartDateOnly = DateTime(
      widget.plan.startDate.year,
      widget.plan.startDate.month,
      widget.plan.startDate.day,
    );
    
    _checkAndUpdatePlanStatus();
    _checkIfPlanEnded();
    _loadCoachNotes();
    _loadUpdateInfo(); // 🔧 v5.5 新增
    _loadProgress();
    _animController.forward();
  }
  
  // 🔧 v5.5 新增：載入更新資訊
  Future<void> _loadUpdateInfo() async {
    if (widget.plan.id == null) return;
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('workoutPlans')
          .doc(widget.plan.id)
          .get();
      
      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _hasUnreadUpdate = data['hasUnreadUpdate'] == true;
          _currentVersion = data['version'] as int?;
          _lastUpdateAt = data['lastUpdateAt'] != null 
              ? (data['lastUpdateAt'] as Timestamp).toDate() 
              : null;
        });
        
        // 從最新的調整通知獲取變更摘要
        final coachNotes = data['coachNotes'] as List?;
        if (coachNotes != null && coachNotes.isNotEmpty) {
          for (var note in coachNotes.reversed) {
            if (note is Map && note['isAdjustmentNotice'] == true) {
              setState(() {
                _latestChangeSummary = note['content']?.toString();
              });
              break;
            }
          }
        }
        
        debugPrint('📢 更新資訊: hasUnread=$_hasUnreadUpdate, version=$_currentVersion');
      }
    } catch (e) {
      debugPrint('❌ 載入更新資訊失敗: $e');
    }
  }
  
  // 🔧 v5.5 新增：標記更新為已讀
  Future<void> _markUpdateAsRead() async {
    if (widget.plan.id == null || !_hasUnreadUpdate) return;
    
    try {
      await FirebaseFirestore.instance
          .collection('workoutPlans')
          .doc(widget.plan.id)
          .update({'hasUnreadUpdate': false});
      
      setState(() {
        _hasUnreadUpdate = false;
      });
      
      debugPrint('✅ 已標記更新為已讀');
    } catch (e) {
      debugPrint('❌ 標記已讀失敗: $e');
    }
  }
  
  // 🔧 v5.3：檢查並更新計畫狀態
  Future<void> _checkAndUpdatePlanStatus() async {
    final statusInfo = _planStatusService.checkPlanStatus(widget.plan);
    
    if (statusInfo.shouldAutoUpdate) {
      await _planStatusService.checkAndUpdatePlanStatus(widget.plan);
    }
    
    if (mounted) {
      setState(() {
        _planStatusInfo = statusInfo;
      });
    }
  }
  
  // 🔧 v5.4：檢查計畫是否已結束
  void _checkIfPlanEnded() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    bool isEnded = widget.plan.status == 'completed' ||
        widget.plan.status == 'cancelled' ||
        widget.plan.status == 'expired';
    
    if (!isEnded && widget.plan.endDate != null) {
      final endDate = widget.plan.endDate!;
      final endDateOnly = DateTime(endDate.year, endDate.month, endDate.day);
      if (endDateOnly.isBefore(today)) {
        isEnded = true;
      }
    }
    
    setState(() {
      _isPlanEnded = isEnded;
    });
  }

  // 🔧 v5.4：載入教練備註
  Future<void> _loadCoachNotes() async {
    if (widget.plan.id == null) return;
    
    try {
      final notes = await _workoutService.getPlanNotes(widget.plan.id!);
      if (mounted) {
        setState(() {
          _coachNotes = notes;
        });
      }
    } catch (e) {
      debugPrint('❌ 載入教練備註失敗: $e');
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadProgress() async {
    try {
      final progress = await _progressService.getPlanProgress(widget.plan);
      
      if (mounted) {
        setState(() {
          _planProgress = progress;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ 載入進度失敗: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  WorkoutPlanDay? _getTodayRecommendedWorkout() {
    for (var day in widget.plan.days) {
      if (WorkoutDateHelper.isSameWeekday(day.dayOfWeek, _todayEnglish)) {
        return day;
      }
    }
    return null;
  }
  
  bool _isDayToday(String dayOfWeek) {
    return WorkoutDateHelper.isSameWeekday(dayOfWeek, _todayEnglish);
  }
  
  bool _isDayAfterPlanStart(String dayOfWeek) {
    final dayDate = WorkoutDateHelper.getDateForWeekdayString(dayOfWeek);
    if (dayDate == null) return false;
    final dayDateOnly = DateTime(dayDate.year, dayDate.month, dayDate.day);
    return !dayDateOnly.isBefore(_planStartDateOnly);
  }
  
  bool _isTodayCompleted() {
    if (_planProgress == null) return false;
    
    for (final day in _planProgress!.currentWeek.days) {
      if (day.isToday && day.isCompleted) {
        return true;
      }
    }
    return false;
  }
  
  bool _isTodayAfterPlanStart() {
    return !_todayDateOnly.isBefore(_planStartDateOnly);
  }

  @override
  Widget build(BuildContext context) {
    final todayWorkout = _getTodayRecommendedWorkout();
    final isTodayCompleted = _isTodayCompleted();
    final isTodayAfterPlanStart = _isTodayAfterPlanStart();
    
    final themeColor = _isPlanEnded ? _endedGrey : _primaryOrange;
    
    return Scaffold(
      backgroundColor: _bgColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(themeColor),
          SliverToBoxAdapter(
            child: Column(
              children: [
                // 🔧 v5.5 新增：更新通知橫幅（最優先顯示）
                if (_hasUnreadUpdate) _buildUpdateBanner(),
                
                // 🔧 v5.4：已結束計畫提示橫幅
                if (_isPlanEnded && !_hasUnreadUpdate) _buildEndedBanner(),
                
                // 🔥 v5.0：整體進度卡片
                _buildProgressCard(),
                const SizedBox(height: 8),
                
                // 🔧 v5.4：教練備註區
                if (_coachNotes.isNotEmpty) _buildCoachNotesSection(),
                
                // 今日推薦（已結束計畫不顯示）
                if (todayWorkout != null && !isTodayCompleted && isTodayAfterPlanStart && !_isPlanEnded)
                  _buildTodayRecommendationCard(todayWorkout),
                
                // 🔥 v5.0：週進度條
                _buildWeeklyProgressBar(),
                const SizedBox(height: 16),
                _buildSectionTitle('訓練日程'),
                const SizedBox(height: 12),
              ],
            ),
          ),
          _isLoading
              ? const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(color: _primaryOrange),
                    ),
                  ),
                )
              : _buildDaysList(),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
  
  // ============================================================
  // 🔧 v5.5 新增：更新通知橫幅
  // ============================================================
  Widget _buildUpdateBanner() {
    final dateStr = _lastUpdateAt != null
        ? DateFormat('MM/dd HH:mm').format(_lastUpdateAt!)
        : '剛剛';
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _updateWarning.withOpacity(0.15),
            _updateWarning.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _updateWarning.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _updateWarning.withOpacity(0.1),
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
              color: _updateWarning.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                // 動畫鈴鐺
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: -0.1, end: 0.1),
                  duration: const Duration(milliseconds: 300),
                  builder: (context, value, child) {
                    return Transform.rotate(
                      angle: value,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _updateWarning.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.notifications_active,
                          color: _updateWarning,
                          size: 22,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '計畫已更新',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _updateWarning.withOpacity(0.9),
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (_currentVersion != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _updateWarning,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'v$_currentVersion',
                                style: const TextStyle(
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
                        style: TextStyle(
                          color: _textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // 關閉按鈕
                IconButton(
                  icon: Icon(Icons.close, color: _textSecondary, size: 20),
                  onPressed: _markUpdateAsRead,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // 變更摘要
          if (_latestChangeSummary != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Text(
                _latestChangeSummary!.length > 150 
                    ? '${_latestChangeSummary!.substring(0, 150)}...' 
                    : _latestChangeSummary!,
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 13,
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
                    onPressed: _markUpdateAsRead,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _textSecondary,
                      side: BorderSide(color: Colors.grey.withOpacity(0.3)),
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
                      _markUpdateAsRead();
                      // 滾動到訓練日程區塊
                      _showSnackBar('請查看下方更新後的訓練計畫');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _updateWarning,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
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
  
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: _primaryOrange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  // 🔧 v5.4：已結束計畫提示橫幅
  Widget _buildEndedBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _endedGrey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _endedGrey.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _endedGrey.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.archive_outlined, color: _endedGrey, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '此計畫已結束',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _textPrimary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '您可以查看歷史記錄，但無法執行新的訓練',
                  style: TextStyle(color: _textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // 🔧 v5.4：教練備註區
  Widget _buildCoachNotesSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 標題列
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _coachGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.comment_outlined, color: _coachGreen, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  '教練備註',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _coachGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_coachNotes.length} 則',
                    style: TextStyle(
                      fontSize: 11,
                      color: _coachGreen,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // 備註列表
            ..._coachNotes.take(3).map((note) {
              final content = note['content'] as String? ?? '';
              final createdAt = note['createdAt'] as Timestamp?;
              final isAdjustmentNotice = note['isAdjustmentNotice'] == true;
              final version = note['version'] as int?;
              final timeStr = createdAt != null ? _formatNoteTime(createdAt.toDate()) : '';
              
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isAdjustmentNotice 
                      ? _updateWarning.withOpacity(0.05) 
                      : _coachGreen.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isAdjustmentNotice 
                        ? _updateWarning.withOpacity(0.2) 
                        : _coachGreen.withOpacity(0.15),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 調整通知標記
                    if (isAdjustmentNotice)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _updateWarning.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.tune, size: 10, color: _updateWarning),
                                  const SizedBox(width: 4),
                                  Text(
                                    '計畫調整',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: _updateWarning,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (version != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _updateWarning,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'v$version',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    Text(
                      content,
                      style: TextStyle(fontSize: 13, color: _textPrimary, height: 1.4),
                    ),
                    if (timeStr.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.schedule, size: 11, color: _textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            timeStr,
                            style: TextStyle(fontSize: 10, color: _textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            }),
            
            // 查看更多
            if (_coachNotes.length > 3)
              Center(
                child: TextButton(
                  onPressed: () => _showAllNotes(),
                  child: Text(
                    '查看全部 ${_coachNotes.length} 則備註',
                    style: TextStyle(color: _coachGreen, fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  String _formatNoteTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inMinutes < 1) return '剛剛';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分鐘前';
    if (diff.inHours < 24) return '${diff.inHours} 小時前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${dateTime.month}/${dateTime.day}';
  }
  
  void _showAllNotes() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _coachGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.comment_outlined, color: _coachGreen, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '教練備註 (${_coachNotes.length})', 
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _coachNotes.length,
                  itemBuilder: (context, index) {
                    final note = _coachNotes[index];
                    final content = note['content'] as String? ?? '';
                    final createdAt = note['createdAt'] as Timestamp?;
                    final isAdjustmentNotice = note['isAdjustmentNotice'] == true;
                    final version = note['version'] as int?;
                    final timeStr = createdAt != null ? _formatNoteTime(createdAt.toDate()) : '';
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isAdjustmentNotice 
                            ? _updateWarning.withOpacity(0.05)
                            : _coachGreen.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isAdjustmentNotice 
                              ? _updateWarning.withOpacity(0.2)
                              : _coachGreen.withOpacity(0.15),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isAdjustmentNotice)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: _updateWarning.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.tune, size: 12, color: _updateWarning),
                                        const SizedBox(width: 4),
                                        Text(
                                          '計畫調整',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: _updateWarning,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (version != null) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: _updateWarning,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'v$version',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          Text(
                            content, 
                            style: TextStyle(fontSize: 14, color: _textPrimary, height: 1.5),
                          ),
                          if (timeStr.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.schedule, size: 12, color: _textSecondary),
                                const SizedBox(width: 4),
                                Text(timeStr, style: TextStyle(fontSize: 11, color: _textSecondary)),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // 以下是原有的方法（保持不變）
  // ============================================================

  Widget _buildProgressCard() {
    final progress = _planProgress;
    final totalDays = widget.plan.days.length;
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.plan.description != null &&
                widget.plan.description!.isNotEmpty) ...[
              Text(
                widget.plan.description!,
                style: TextStyle(
                  fontSize: 14,
                  color: _textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
            ],

            Row(
              children: [
                _buildInfoChip(
                  icon: Icons.calendar_today,
                  label: _formatDateRange(),
                  color: _isPlanEnded ? _endedGrey : _primaryOrange,
                ),
                const SizedBox(width: 12),
                _buildInfoChip(
                  icon: Icons.repeat,
                  label: '每週 $totalDays 天',
                  color: _isPlanEnded ? _endedGrey : Colors.blue,
                ),
              ],
            ),
            
            if (_planStatusInfo != null) ...[
              const SizedBox(height: 12),
              _buildPlanStatusRow(),
            ],

            const SizedBox(height: 20),

            if (progress != null && !progress.isOngoing) ...[
              _buildOverallProgressBar(progress),
              const SizedBox(height: 20),
            ],

            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.check_circle_outline,
                    value: progress?.progressText ?? '0 次',
                    label: progress?.isOngoing == true ? '累計完成' : '整體進度',
                    color: _isPlanEnded ? _endedGrey : CompletionStatus.fromType(CompletionStatusType.onTime).color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.timeline,
                    value: '${progress?.onTimePercent ?? 0}%',
                    label: '準時率',
                    color: _isPlanEnded ? _endedGrey : Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.timer,
                    value: '${progress?.avgDuration ?? 0}',
                    label: '平均時長',
                    color: _isPlanEnded ? _endedGrey : Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallProgressBar(PlanProgress progress) {
    final rate = progress.completionRate;
    final color = _isPlanEnded ? _endedGrey : ProgressDisplayHelper.getProgressColor(rate);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '整體進度',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _textPrimary,
              ),
            ),
            Text(
              '${progress.completionPercent}%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            Container(
              height: 10,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.15),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              height: 10,
              width: MediaQuery.of(context).size.width * 0.85 * rate,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.7)],
                ),
                borderRadius: BorderRadius.circular(5),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '${progress.completedDays} / ${progress.totalTrainingDays} 次 • ${ProgressDisplayHelper.getProgressDescription(rate)}',
          style: TextStyle(
            fontSize: 11,
            color: _textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyProgressBar() {
    final weeklyProgress = _planProgress?.currentWeek;
    
    List<_WeekDayData> weekDays = [];
    final weekStart = WorkoutDateHelper.getWeekStart(DateTime.now());
    
    final trainingWeekdays = widget.plan.days
        .map((d) => WorkoutDateHelper.parseWeekday(d.dayOfWeek))
        .whereType<int>()
        .toSet();
    
    for (int i = 0; i < 7; i++) {
      final date = weekStart.add(Duration(days: i));
      final weekday = date.weekday;
      final isTrainingDay = trainingWeekdays.contains(weekday);
      final dateOnly = DateTime(date.year, date.month, date.day);
      final isToday = dateOnly.isAtSameMomentAs(_todayDateOnly);
      final isAfterPlanStart = !dateOnly.isBefore(_planStartDateOnly);
      final isPast = dateOnly.isBefore(_todayDateOnly);
      
      CompletionStatusType status = CompletionStatusType.pending;
      bool isCompleted = false;
      
      if (weeklyProgress != null && weeklyProgress.days.isNotEmpty) {
        final dayProgress = weeklyProgress.days.firstWhere(
          (d) => d.date.weekday == weekday,
          orElse: () => PlanDayProgress.fromWeekday(
            weekday: weekday,
            date: date,
            isTrainingDay: isTrainingDay,
            isAfterPlanStart: isAfterPlanStart,
            status: CompletionStatusType.pending,
          ),
        );
        status = dayProgress.status;
        isCompleted = dayProgress.isCompleted;
      } else if (isTrainingDay) {
        if (!isAfterPlanStart) {
          status = CompletionStatusType.pending;
        } else if (isToday) {
          status = CompletionStatusType.dueToday;
        } else if (isPast) {
          status = CompletionStatusType.overdue;
        } else {
          status = CompletionStatusType.pending;
        }
      }
      
      weekDays.add(_WeekDayData(
        weekday: weekday,
        date: date,
        isTrainingDay: isTrainingDay,
        isToday: isToday,
        isAfterPlanStart: isAfterPlanStart,
        status: status,
        isCompleted: isCompleted,
      ));
    }
    
    final shouldComplete = weekDays.where((d) => d.isTrainingDay && d.isAfterPlanStart).length;
    final completed = weekDays.where((d) => d.isTrainingDay && d.isCompleted).length;
    
    final themeColor = _isPlanEnded ? _endedGrey : _primaryOrange;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_view_week, size: 18, color: themeColor),
                const SizedBox(width: 8),
                Text(
                  _isPlanEnded ? '最後一週訓練' : '本週訓練',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: themeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$completed / $shouldComplete 完成',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: themeColor,
                    ),
                  ),
                ),
                const Spacer(),
                _buildCompactLegend(),
              ],
            ),
            const SizedBox(height: 16),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: weekDays.map((day) => _buildDayCircleNew(day)).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayCircleNew(_WeekDayData day) {
    final status = CompletionStatus.fromType(day.status);
    final shortName = WorkoutDateHelper.getShortChinese(day.weekday);
    
    final activeColor = _isPlanEnded ? _endedGrey : _primaryOrange;

    return Column(
      children: [
        if (day.isToday && !_isPlanEnded)
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: activeColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              '今天',
              style: TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        else
          const SizedBox(height: 18),
        
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: day.isCompleted 
                ? (_isPlanEnded ? _endedGrey : status.color)
                : day.isTrainingDay && day.isAfterPlanStart
                    ? (_isPlanEnded ? _endedGrey.withOpacity(0.1) : status.backgroundColor)
                    : Colors.grey.withOpacity(0.1),
            shape: BoxShape.circle,
            border: !day.isCompleted && day.isTrainingDay && day.isAfterPlanStart
                ? Border.all(
                    color: _isPlanEnded ? _endedGrey : status.color,
                    width: day.isToday && !_isPlanEnded ? 3 : 2,
                  )
                : !day.isCompleted && day.isTrainingDay && !day.isAfterPlanStart
                    ? Border.all(color: _disabledColor, width: 1)
                    : null,
            boxShadow: day.isToday && !day.isCompleted && day.isAfterPlanStart && !_isPlanEnded
                ? [BoxShadow(color: status.color.withOpacity(0.3), blurRadius: 8, spreadRadius: 1)]
                : day.isCompleted
                    ? [BoxShadow(color: (_isPlanEnded ? _endedGrey : status.color).withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))]
                    : null,
          ),
          child: Center(
            child: day.isCompleted
                ? Icon(status.icon, size: 18, color: Colors.white)
                : day.isTrainingDay
                    ? Icon(
                        !day.isAfterPlanStart
                            ? Icons.lock_clock
                            : day.status == CompletionStatusType.dueToday 
                                ? Icons.play_arrow 
                                : day.status == CompletionStatusType.overdue
                                    ? Icons.warning_amber
                                    : Icons.fitness_center,
                        size: 16,
                        color: day.isAfterPlanStart ? (_isPlanEnded ? _endedGrey : status.color) : _disabledColor,
                      )
                    : null,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          shortName,
          style: TextStyle(
            fontSize: 11,
            color: day.isToday && !_isPlanEnded
                ? activeColor
                : day.isTrainingDay && day.isAfterPlanStart
                    ? _textPrimary
                    : _textSecondary,
            fontWeight: (day.isToday && !_isPlanEnded) || (day.isTrainingDay && day.isAfterPlanStart) 
                ? FontWeight.w600 
                : FontWeight.normal,
          ),
        ),
        
        if (day.isCompleted && day.status == CompletionStatusType.makeup)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '補做',
              style: TextStyle(fontSize: 8, color: _isPlanEnded ? _endedGrey : status.color, fontWeight: FontWeight.w500),
            ),
          )
        else if (!day.isAfterPlanStart && day.isTrainingDay && !day.isCompleted)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '未開始',
              style: TextStyle(fontSize: 8, color: _disabledColor, fontWeight: FontWeight.w500),
            ),
          ),
      ],
    );
  }
  
  Widget _buildCompactLegend() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLegendDot(CompletionStatusType.onTime, '準時'),
        const SizedBox(width: 8),
        _buildLegendDot(CompletionStatusType.early, '提前'),
        const SizedBox(width: 8),
        _buildLegendDot(CompletionStatusType.makeup, '補做'),
      ],
    );
  }
  
  Widget _buildLegendDot(CompletionStatusType type, String label) {
    final status = CompletionStatus.fromType(type);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: _isPlanEnded ? _endedGrey : status.color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 9, color: _textSecondary)),
      ],
    );
  }
  
  Widget _buildTodayRecommendationCard(WorkoutPlanDay todayWorkout) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_primaryOrange, _darkOrange],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _primaryOrange.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.today, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '今日建議訓練',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_todayShortName - ${todayWorkout.exercises.length} 個動作',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () => _startWorkout(todayWorkout),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _primaryOrange,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_arrow, size: 18),
                  SizedBox(width: 4),
                  Text('開始', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(Color themeColor) {
    return SliverAppBar(
      expandedHeight: 160,
      floating: false,
      pinned: true,
      backgroundColor: themeColor,
      foregroundColor: Colors.white,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          widget.plan.planName,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _isPlanEnded 
                  ? [_endedGrey, _endedGrey.withOpacity(0.8)]
                  : [_primaryOrange, _darkOrange],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -30, top: -30,
                child: Container(
                  width: 150, height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              Positioned(
                left: -20, bottom: -20,
                child: Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),
              ),
              Positioned(
                right: 24, bottom: 60,
                child: Icon(
                  _isPlanEnded ? Icons.archive : Icons.fitness_center, 
                  size: 48, 
                  color: Colors.white.withOpacity(0.3),
                ),
              ),
              if (_isPlanEnded)
                Positioned(
                  left: 20, top: 80,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.archive, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text(
                          '已結束',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              // 🔧 v5.5 新增：更新標記
              if (_hasUnreadUpdate && !_isPlanEnded)
                Positioned(
                  left: 20, top: 80,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _updateWarning,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: _updateWarning.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.new_releases, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '已更新${_currentVersion != null ? ' v$_currentVersion' : ''}',
                          style: const TextStyle(
                            color: Colors.white, 
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
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
      actions: [
        if (widget.plan.status == 'active' && !_isPlanEnded)
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'complete',
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: CompletionStatus.fromType(CompletionStatusType.onTime).color),
                    const SizedBox(width: 12),
                    const Text('標記為完成'),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'complete') _markAsCompleted();
            },
          ),
      ],
    );
  }

  Widget _buildInfoChip({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPlanStatusRow() {
    final statusInfo = _planStatusInfo!;
    final daysText = _planStatusService.getDaysRemainingText(widget.plan);
    
    Color statusColor;
    IconData statusIcon;
    
    switch (statusInfo.status) {
      case PlanStatusType.active:
        statusColor = _isPlanEnded ? _endedGrey : Colors.green;
        statusIcon = Icons.play_circle_outline;
        break;
      case PlanStatusType.completed:
      case PlanStatusType.expired:
        statusColor = _endedGrey;
        statusIcon = Icons.check_circle_outline;
        break;
      case PlanStatusType.paused:
        statusColor = Colors.orange;
        statusIcon = Icons.pause_circle_outline;
        break;
      case PlanStatusType.notStarted:
        statusColor = Colors.blue;
        statusIcon = Icons.schedule;
        break;
      case PlanStatusType.cancelled:
        statusColor = Colors.red;
        statusIcon = Icons.cancel_outlined;
        break;
    }
    
    if (_isPlanEnded && statusInfo.status == PlanStatusType.active) {
      statusColor = _endedGrey;
      statusIcon = Icons.archive_outlined;
    }
    
    final expiringSoon = _planStatusService.isPlanExpiringSoon(widget.plan);
    
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(statusIcon, size: 14, color: statusColor),
              const SizedBox(width: 4),
              Text(
                _isPlanEnded ? '已結束' : statusInfo.label,
                style: TextStyle(
                  fontSize: 12,
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        
        if (!_isPlanEnded && statusInfo.status == PlanStatusType.active && widget.plan.endDate != null) ...[
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: expiringSoon ? Colors.orange.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  expiringSoon ? Icons.warning_amber_rounded : Icons.timer_outlined,
                  size: 14,
                  color: expiringSoon ? Colors.orange : _textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  daysText,
                  style: TextStyle(
                    fontSize: 12,
                    color: expiringSoon ? Colors.orange : _textSecondary,
                    fontWeight: expiringSoon ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: _textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(
            width: 4, height: 20,
            decoration: BoxDecoration(
              color: _isPlanEnded ? _endedGrey : _primaryOrange,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildDaysList() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final day = widget.plan.days[index];
          return AnimatedBuilder(
            animation: _animController,
            builder: (context, child) {
              final delay = index * 0.1;
              final animValue = Curves.easeOutBack.transform(
                ((_animController.value - delay) / (1 - delay)).clamp(0.0, 1.0),
              );
              return Transform.translate(
                offset: Offset(0, 30 * (1 - animValue)),
                child: Opacity(
                  opacity: animValue.clamp(0.0, 1.0),
                  child: _buildDayCard(day, index),
                ),
              );
            },
          );
        },
        childCount: widget.plan.days.length,
      ),
    );
  }

  Widget _buildDayCard(WorkoutPlanDay day, int index) {
    final dayWeekday = WorkoutDateHelper.parseWeekday(day.dayOfWeek) ?? 1;
    final dayDate = WorkoutDateHelper.getDateForWeekdayString(day.dayOfWeek) ?? DateTime.now();
    final dayDateOnly = DateTime(dayDate.year, dayDate.month, dayDate.day);
    
    final isToday = _isDayToday(day.dayOfWeek);
    final isAfterPlanStart = _isDayAfterPlanStart(day.dayOfWeek);
    final isPast = dayDateOnly.isBefore(_todayDateOnly);
    
    bool isCompleted = false;
    CompletionStatusType statusType = CompletionStatusType.pending;
    
    if (_planProgress != null && _planProgress!.currentWeek.days.isNotEmpty) {
      final dayProgress = _planProgress!.currentWeek.days.firstWhere(
        (d) => d.date.weekday == dayWeekday,
        orElse: () => PlanDayProgress.fromWeekday(
          weekday: dayWeekday,
          date: dayDate,
          isTrainingDay: true,
          isAfterPlanStart: isAfterPlanStart,
          status: CompletionStatusType.pending,
        ),
      );
      isCompleted = dayProgress.isCompleted;
      statusType = dayProgress.status;
    } else {
      if (!isAfterPlanStart) {
        statusType = CompletionStatusType.pending;
      } else if (isToday) {
        statusType = CompletionStatusType.dueToday;
      } else if (isPast) {
        statusType = CompletionStatusType.overdue;
      } else {
        statusType = CompletionStatusType.pending;
      }
    }
    
    final status = CompletionStatus.fromType(statusType);
    final fullName = WorkoutDateHelper.normalizeToChinese(day.dayOfWeek);
    
    final themeColor = _isPlanEnded ? _endedGrey : _primaryOrange;
    final darkThemeColor = _isPlanEnded ? _endedGrey.withOpacity(0.8) : _darkOrange;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(20),
          border: isToday && !isCompleted && isAfterPlanStart && !_isPlanEnded
              ? Border.all(color: status.color, width: 2)
              : _isPlanEnded
                  ? Border.all(color: _endedGrey.withOpacity(0.3), width: 1)
                  : null,
          boxShadow: [
            BoxShadow(
              color: isToday && !isCompleted && isAfterPlanStart && !_isPlanEnded
                  ? status.color.withOpacity(0.15)
                  : Colors.black.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isCompleted
                      ? [(_isPlanEnded ? _endedGrey : status.color).withOpacity(0.08), (_isPlanEnded ? _endedGrey : status.color).withOpacity(0.03)]
                      : [themeColor.withOpacity(0.08), _lightOrange.withOpacity(_isPlanEnded ? 0.1 : 0.5)],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isCompleted
                            ? [_isPlanEnded ? _endedGrey : status.color, (_isPlanEnded ? _endedGrey : status.color).withOpacity(0.8)]
                            : [themeColor, darkThemeColor],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: (isCompleted ? (_isPlanEnded ? _endedGrey : status.color) : themeColor).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isCompleted)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(status.icon, size: 14, color: Colors.white),
                          ),
                        Text(
                          fullName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.list_alt, size: 14, color: _textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          '${day.exercises.length} 個動作',
                          style: TextStyle(fontSize: 12, color: _textSecondary),
                        ),
                      ],
                    ),
                  ),
                  
                  if (isToday && !isCompleted && isAfterPlanStart && !_isPlanEnded) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: status.color,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '今天',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],

                  const Spacer(),

                  if (!isAfterPlanStart && !isCompleted)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _disabledColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.schedule, size: 14, color: _disabledColor),
                          const SizedBox(width: 4),
                          Text(
                            '未開始',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _disabledColor),
                          ),
                        ],
                      ),
                    )
                  else if (isCompleted)
                    CompletionStatusBadge(statusType: statusType, compact: true)
                  else if (statusType == CompletionStatusType.overdue && !_isPlanEnded)
                    CompletionStatusBadge(statusType: statusType, compact: true),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ...day.exercises.asMap().entries.map((entry) {
                    return _buildExerciseItem(entry.value, entry.key + 1);
                  }),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isPlanEnded ? null : () => _startWorkout(day),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isPlanEnded 
                            ? _endedGrey.withOpacity(0.5)
                            : isCompleted 
                                ? status.color.withOpacity(0.9)
                                : _primaryOrange,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        disabledBackgroundColor: _endedGrey.withOpacity(0.3),
                        disabledForegroundColor: Colors.white70,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isPlanEnded 
                                  ? Icons.lock_outline
                                  : isCompleted 
                                      ? Icons.replay 
                                      : Icons.play_arrow, 
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _isPlanEnded 
                                ? '計畫已結束'
                                : isCompleted 
                                    ? '再次訓練' 
                                    : (isToday && isAfterPlanStart ? '開始今日訓練' : '開始訓練'),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseItem(PlannedExercise exercise, int index) {
    final categoryInfo = _getCategoryInfo(exercise.type);
    
    final accentColor = _isPlanEnded ? _endedGrey : _primaryOrange;
    final darkAccent = _isPlanEnded ? _endedGrey.withOpacity(0.8) : _darkOrange;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [accentColor.withOpacity(0.2), _isPlanEnded ? _endedGrey.withOpacity(0.1) : _lightOrange]),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$index',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: darkAccent),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (_isPlanEnded ? _endedGrey : categoryInfo['color']).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(categoryInfo['icon'], color: _isPlanEnded ? _endedGrey : categoryInfo['color'], size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.name,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  _getExerciseDetails(exercise),
                  style: TextStyle(fontSize: 13, color: _textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getCategoryInfo(String? type) {
    switch (type) {
      case 'weight_training':
        return {'icon': Icons.fitness_center, 'color': Colors.red};
      case 'cardio':
        return {'icon': Icons.directions_run, 'color': Colors.blue};
      case 'yoga':
        return {'icon': Icons.self_improvement, 'color': Colors.purple};
      case 'stretching':
        return {'icon': Icons.accessibility_new, 'color': Colors.teal};
      default:
        return {'icon': Icons.sports_gymnastics, 'color': _primaryOrange};
    }
  }

  String _getExerciseDetails(PlannedExercise exercise) {
    List<String> details = [];
    if (exercise.sets != null && exercise.reps != null) {
      details.add('${exercise.sets} 組 × ${exercise.reps} 次');
    } else if (exercise.sets != null) {
      details.add('${exercise.sets} 組');
    }
    if (exercise.duration != null) {
      details.add('${exercise.duration} 分鐘');
    }
    return details.isEmpty ? '自訂訓練' : details.join(' • ');
  }

  String _formatDateRange() {
    final start = WorkoutDateHelper.formatDateChinese(widget.plan.startDate);
    final end = widget.plan.endDate != null
        ? WorkoutDateHelper.formatDateChinese(widget.plan.endDate!)
        : '持續進行';
    return '$start - $end';
  }

  Future<void> _startWorkout(WorkoutPlanDay day) async {
    if (widget.plan.id == null) {
      _showSnackBar('計畫 ID 不存在');
      return;
    }

    if (_isPlanEnded) {
      _showPlanBlockedDialog('此計畫已結束，無法執行新的訓練。\n\n您可以查看歷史記錄，但無法開始新訓練。');
      return;
    }

    final blockReason = _planStatusService.getExecutionBlockReason(widget.plan);
    if (blockReason != null) {
      _showPlanBlockedDialog(blockReason);
      return;
    }

    final isScheduledToday = WorkoutDateHelper.isSameWeekday(day.dayOfWeek, _todayEnglish);
    
    if (!isScheduledToday) {
      final confirmed = await _showScheduleWarningDialog(day);
      if (confirmed != true) return;
    }

    HapticFeedback.mediumImpact();

    final exercisesData = day.exercises.map((e) => {
      'name': e.name,
      'category': e.primaryMuscleGroup ?? e.type ?? '其他',
      'type': e.type ?? 'weight_training',
      'sets': e.sets ?? 3,
      'reps': e.reps ?? 12,
      'restSec': 90,
      'notes': e.notes,
    }).toList();

    final dayFullName = WorkoutDateHelper.normalizeToChinese(day.dayOfWeek);

    final result = await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            WorkoutPlanExecutionPage(
          planId: widget.plan.id!,
          planName: widget.plan.planName,
          dayOfWeek: dayFullName,
          exercises: exercisesData,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero)
                .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );

    if (mounted) {
      await Future.delayed(const Duration(milliseconds: 500));
      await _loadProgress();
    }
  }
  
  void _showPlanBlockedDialog(String reason) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red[50],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.block, color: Colors.red[400], size: 24),
            ),
            const SizedBox(width: 12),
            const Text('無法執行', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reason,
              style: TextStyle(fontSize: 15, color: _textPrimary, height: 1.6),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: _textSecondary, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '如需繼續訓練，請聯繫您的教練調整計畫',
                      style: TextStyle(fontSize: 13, color: Color(0xFF718096)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }
  
  Future<bool?> _showScheduleWarningDialog(WorkoutPlanDay day) {
    final weekday = WorkoutDateHelper.parseWeekday(day.dayOfWeek) ?? 1;
    final scheduledDay = WorkoutDateHelper.getShortChinese(weekday);
    final makeupStatus = CompletionStatus.fromType(CompletionStatusType.makeup);
    
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: makeupStatus.backgroundColor, shape: BoxShape.circle),
              child: Icon(Icons.schedule, color: makeupStatus.color, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('訓練日提醒', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 15, color: _textPrimary, height: 1.6),
                children: [
                  const TextSpan(text: '今天是 '),
                  TextSpan(text: _todayShortName, style: TextStyle(fontWeight: FontWeight.bold, color: _primaryOrange)),
                  const TextSpan(text: '\n您選擇的是 '),
                  TextSpan(text: scheduledDay, style: TextStyle(fontWeight: FontWeight.bold, color: makeupStatus.color)),
                  const TextSpan(text: ' 的訓練'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: makeupStatus.backgroundColor, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: makeupStatus.color, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '此次訓練將記錄為「$scheduledDay」的補做訓練',
                      style: TextStyle(fontSize: 13, color: _textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('取消', style: TextStyle(color: _textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [Icon(Icons.play_arrow, size: 18), SizedBox(width: 4), Text('仍要執行')],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _markAsCompleted() async {
    final successStatus = CompletionStatus.fromType(CompletionStatusType.onTime);
    
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: successStatus.backgroundColor, shape: BoxShape.circle),
                child: Icon(Icons.check_circle, color: successStatus.color),
              ),
              const SizedBox(width: 12),
              const Text('確認完成'),
            ],
          ),
          content: const Text('確定要將此訓練計畫標記為已完成嗎？\n完成後將無法再次執行此計畫。', style: TextStyle(height: 1.5)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('取消', style: TextStyle(color: _textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: successStatus.color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('確定完成'),
            ),
          ],
        ),
      );

      if (confirmed == true && widget.plan.id != null) {
        await _workoutService.markPlanAsCompleted(widget.plan.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [Icon(Icons.celebration, color: Colors.white), SizedBox(width: 8), Text('🎉 恭喜完成訓練計畫！')],
              ),
              backgroundColor: successStatus.color,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失敗：$e'), backgroundColor: Colors.red[400], behavior: SnackBarBehavior.floating),
        );
      }
    }
  }
}

class _WeekDayData {
  final int weekday;
  final DateTime date;
  final bool isTrainingDay;
  final bool isToday;
  final bool isAfterPlanStart;
  final CompletionStatusType status;
  final bool isCompleted;

  _WeekDayData({
    required this.weekday,
    required this.date,
    required this.isTrainingDay,
    required this.isToday,
    required this.isAfterPlanStart,
    required this.status,
    required this.isCompleted,
  });
}