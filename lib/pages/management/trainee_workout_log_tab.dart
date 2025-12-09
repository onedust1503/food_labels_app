// lib/pages/management/trainee_workout_log_tab.dart
// 🔥 教練端：學員訓練日誌分頁 v2.1
// ✅ v2.1 修正：解決 WorkoutCompletionRecord 名稱衝突
// ✅ v2.0 新增：「需要協助」標記、feedback 顯示、快速回覆按鈕
// ✅ 莫蘭迪配色 Soft UI 風格

import 'package:flutter/material.dart';
// 🔥 v4.1：使用新的 TraineeWorkoutLog 類避免衝突
import '../../services/workout_completion_service.dart';
import '../../models/completion_status.dart' show CompletionStatusType, CompletionStatus;
import '../chat_detail_page.dart';

class TraineeWorkoutLogTab extends StatefulWidget {
  final String traineeId;
  final String traineeName;

  const TraineeWorkoutLogTab({
    super.key,
    required this.traineeId,
    required this.traineeName,
  });

  @override
  State<TraineeWorkoutLogTab> createState() => _TraineeWorkoutLogTabState();
}

class _TraineeWorkoutLogTabState extends State<TraineeWorkoutLogTab>
    with SingleTickerProviderStateMixin {
  final WorkoutCompletionService _completionService = WorkoutCompletionService();

  // 🔥 莫蘭迪配色
  static const Color _primaryColor = Color(0xFF7D9A78); // 莫蘭迪綠
  static const Color _backgroundColor = Color(0xFFF5F5F0);
  static const Color _cardColor = Colors.white;
  static const Color _textPrimary = Color(0xFF2D3A2D);
  static const Color _textSecondary = Color(0xFF6B7B6B);

  // 🔥 狀態顏色
  static const Color _onTimeColor = Color(0xFF4CAF50); // 綠色 - 準時
  static const Color _earlyColor = Color(0xFF2196F3); // 藍色 - 提前
  static const Color _makeupColor = Color(0xFFFFC107); // 黃色 - 補做
  static const Color _needsHelpColor = Color(0xFFE53935); // 紅色 - 需要協助

  late TabController _tabController;

  // 🔥 v4.1：使用 TraineeWorkoutLog 而非 WorkoutCompletionRecord
  List<TraineeWorkoutLog> _allLogs = [];
  List<TraineeWorkoutLog> _filteredLogs = [];
  Map<String, dynamic> _statistics = {};

  bool _isLoading = true;
  String _currentFilter = 'all'; // all, onTime, early, makeup, needsHelp

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final logs = await _completionService.getTraineeWorkoutLogs(
        traineeId: widget.traineeId,
        limit: 100,
      );

      final stats = await _completionService.getTraineeStatistics(
        traineeId: widget.traineeId,
        days: 30,
      );

      setState(() {
        _allLogs = logs;
        _filteredLogs = logs;
        _statistics = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('載入失敗：$e', Colors.red);
    }
  }

  void _applyFilter(String filter) {
    setState(() {
      _currentFilter = filter;

      switch (filter) {
        case 'onTime':
          _filteredLogs = _allLogs
              .where((log) => log.statusType == CompletionStatusType.onTime)
              .toList();
          break;
        case 'early':
          _filteredLogs = _allLogs
              .where((log) => log.statusType == CompletionStatusType.early)
              .toList();
          break;
        case 'makeup':
          _filteredLogs = _allLogs
              .where((log) => log.statusType == CompletionStatusType.makeup)
              .toList();
          break;
        case 'needsHelp':
          _filteredLogs = _allLogs.where((log) => log.needsHelp).toList();
          break;
        case 'free':
          _filteredLogs = _allLogs.where((log) => !log.isPlanWorkout).toList();
          break;
        default:
          _filteredLogs = _allLogs;
      }
    });
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _primaryColor),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: _primaryColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔥 統計卡片
            _buildStatsHeader(),
            const SizedBox(height: 16),

            // 🔥 篩選器
            _buildFilterBar(),
            const SizedBox(height: 16),

            // 🔥 訓練列表
            _buildWorkoutList(),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 🔥 統計卡片
  // ============================================================

  Widget _buildStatsHeader() {
    final totalCompleted = _statistics['totalCompleted'] ?? 0;
    final planCount = _statistics['planCount'] ?? 0;
    final freeCount = _statistics['freeCount'] ?? 0;
    final onTimeRate = _statistics['onTimeRate'] ?? 0;
    final totalDuration = _statistics['totalDuration'] ?? 0;
    final needsHelpCount = _statistics['needsHelpCount'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 標題行
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.fitness_center,
                  color: _primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '近 30 天訓練統計',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
              ),
              const Spacer(),
              // 🔥 需要協助徽章
              if (needsHelpCount > 0)
                GestureDetector(
                  onTap: () => _applyFilter('needsHelp'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _needsHelpColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _needsHelpColor.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.help_outline,
                          color: _needsHelpColor,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$needsHelpCount 則待回覆',
                          style: TextStyle(
                            color: _needsHelpColor,
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
          const SizedBox(height: 20),

          // 統計數據
          Row(
            children: [
              _buildStatItem(
                icon: Icons.check_circle_outline,
                label: '總完成',
                value: '$totalCompleted',
                color: _primaryColor,
              ),
              _buildStatItem(
                icon: Icons.calendar_today,
                label: '計畫訓練',
                value: '$planCount',
                color: _onTimeColor,
              ),
              _buildStatItem(
                icon: Icons.sports_gymnastics,
                label: '自由訓練',
                value: '$freeCount',
                color: Colors.purple,
              ),
              _buildStatItem(
                icon: Icons.timer_outlined,
                label: '總時長',
                value: '${(totalDuration / 60).round()}h',
                color: Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 狀態分佈
          _buildStatusDistribution(),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: _textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDistribution() {
    final onTime = _statistics['onTimeCount'] ?? 0;
    final early = _statistics['earlyCount'] ?? 0;
    final makeup = _statistics['makeupCount'] ?? 0;
    final total = _statistics['totalCompleted'] ?? 1;

    return Row(
      children: [
        _buildStatusChip('準時', onTime, total, _onTimeColor),
        const SizedBox(width: 8),
        _buildStatusChip('提前', early, total, _earlyColor),
        const SizedBox(width: 8),
        _buildStatusChip('補做', makeup, total, _makeupColor),
      ],
    );
  }

  Widget _buildStatusChip(String label, int count, int total, Color color) {
    final percentage = total > 0 ? (count / total * 100).round() : 0;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              '$label ($percentage%)',
              style: TextStyle(
                fontSize: 11,
                color: color.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 🔥 篩選器
  // ============================================================

  Widget _buildFilterBar() {
    final needsHelpCount = _allLogs.where((log) => log.needsHelp).length;
    final freeCount = _allLogs.where((log) => !log.isPlanWorkout).length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('all', '全部', Icons.list, null),
          const SizedBox(width: 8),
          _buildFilterChip('needsHelp', '需要協助', Icons.help_outline, _needsHelpColor,
              count: needsHelpCount),
          const SizedBox(width: 8),
          _buildFilterChip('free', '自由訓練', Icons.sports_gymnastics, Colors.purple,
              count: freeCount),
          const SizedBox(width: 8),
          _buildFilterChip('onTime', '準時', Icons.check_circle, _onTimeColor),
          const SizedBox(width: 8),
          _buildFilterChip('early', '提前', Icons.fast_forward, _earlyColor),
          const SizedBox(width: 8),
          _buildFilterChip('makeup', '補做', Icons.update, _makeupColor),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String filter,
    String label,
    IconData icon,
    Color? color, {
    int? count,
  }) {
    final isSelected = _currentFilter == filter;
    final chipColor = color ?? _primaryColor;

    return GestureDetector(
      onTap: () => _applyFilter(filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? chipColor : _cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? chipColor : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: chipColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : chipColor,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : _textPrimary,
              ),
            ),
            if (count != null && count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withOpacity(0.3) : chipColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
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

  // ============================================================
  // 🔥 訓練列表
  // ============================================================

  Widget _buildWorkoutList() {
    if (_filteredLogs.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '訓練記錄 (${_filteredLogs.length})',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: _textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ..._filteredLogs.map((log) => _buildWorkoutCard(log)),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _currentFilter == 'needsHelp'
                ? Icons.thumb_up_outlined
                : Icons.fitness_center,
            size: 60,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            _currentFilter == 'needsHelp' ? '沒有需要協助的訓練' : '暫無訓練記錄',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutCard(TraineeWorkoutLog log) {
    final statusInfo = log.status;
    final hasNeedsHelp = log.needsHelp;

    return GestureDetector(
      onTap: () => _showWorkoutDetails(log),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          // 🔥 需要協助時加紅色邊框
          border: hasNeedsHelp
              ? Border.all(color: _needsHelpColor.withOpacity(0.5), width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: hasNeedsHelp
                  ? _needsHelpColor.withOpacity(0.1)
                  : Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 日期圓圈
              _buildDateCircle(log),
              const SizedBox(width: 16),

              // 訓練資訊
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 訓練名稱 + 需要協助標籤
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            log.planName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // 🔥 需要協助標籤
                        if (hasNeedsHelp)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _needsHelpColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.help_outline,
                                  color: _needsHelpColor,
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '需要協助',
                                  style: TextStyle(
                                    color: _needsHelpColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // 計畫日 + 狀態 + 訓練類型
                    Row(
                      children: [
                        // 🔥 v4.2：訓練類型標籤（計畫/自由）
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: log.isPlanWorkout 
                                ? _primaryColor.withOpacity(0.1)
                                : Colors.purple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            log.workoutTypeLabel,
                            style: TextStyle(
                              fontSize: 10,
                              color: log.isPlanWorkout ? _primaryColor : Colors.purple,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (log.planDayOfWeek.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            log.planDayOfWeek,
                            style: TextStyle(
                              fontSize: 13,
                              color: _textSecondary,
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: statusInfo.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            statusInfo.label,
                            style: TextStyle(
                              fontSize: 11,
                              color: statusInfo.color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // 統計資訊
                    Row(
                      children: [
                        _buildInfoChip(
                          Icons.timer_outlined,
                          '${log.duration} 分鐘',
                        ),
                        const SizedBox(width: 12),
                        _buildInfoChip(
                          Icons.local_fire_department,
                          '${log.calories.round()} 卡',
                        ),
                        const SizedBox(width: 12),
                        _buildInfoChip(
                          Icons.fitness_center,
                          '${log.exerciseCount} 動作',
                        ),
                      ],
                    ),

                    // 🔥 顯示協助訊息預覽
                    if (hasNeedsHelp && log.helpMessage != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _needsHelpColor.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              color: _needsHelpColor,
                              size: 14,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                log.helpMessage!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _needsHelpColor.withOpacity(0.8),
                                ),
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

              // 箭頭
              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateCircle(TraineeWorkoutLog log) {
    final date = log.actualDate;
    if (date == null) {
      return Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.schedule,
          color: Colors.grey.shade400,
        ),
      );
    }

    final statusInfo = log.status;

    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: statusInfo.color.withOpacity(0.1),
        shape: BoxShape.circle,
        border: Border.all(
          color: statusInfo.color.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${date.day}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: statusInfo.color,
            ),
          ),
          Text(
            '${date.month}月',
            style: TextStyle(
              fontSize: 10,
              color: statusInfo.color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: _textSecondary),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: _textSecondary,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // 🔥 詳情底部彈窗
  // ============================================================

  void _showWorkoutDetails(TraineeWorkoutLog log) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _WorkoutDetailsSheet(
        log: log,
        traineeName: widget.traineeName,
        traineeId: widget.traineeId,
        onReplyTap: () {
          Navigator.pop(context);
          _navigateToChat();
        },
      ),
    );
  }

  // 🔥 v2.1 修正：導航到聊天室
  // ⚠️ 根據你的 ChatService 和 ChatDetailPage 實現調整此方法
  void _navigateToChat() async {
    try {
      // 方案 1：如果 ChatService 有 getOrCreateChat 方法
      // final chatId = await _chatService.getOrCreateChat(widget.traineeId);
      
      // 方案 2：如果 ChatService 有 createOneOnOneChat 方法
      // final chatId = await _chatService.createOneOnOneChat(widget.traineeId);
      
      // 方案 3：直接使用 traineeId 作為 chatId（如果你的系統這樣設計）
      final chatId = widget.traineeId;
      
      if (!mounted) return;
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatDetailPage(
            chatId: chatId,
            chatName: widget.traineeName,
            avatarUrl: '', // 🔥 使用空字串（String 類型）
          ),
        ),
      );
    } catch (e) {
      _showSnackBar('無法開啟聊天室：$e', Colors.red);
    }
  }
}

// ============================================================
// 🔥 詳情底部彈窗組件
// ============================================================

class _WorkoutDetailsSheet extends StatelessWidget {
  final TraineeWorkoutLog log;
  final String traineeName;
  final String traineeId;
  final VoidCallback onReplyTap;

  // 莫蘭迪配色
  static const Color _primaryColor = Color(0xFF7D9A78);
  static const Color _textPrimary = Color(0xFF2D3A2D);
  static const Color _textSecondary = Color(0xFF6B7B6B);
  static const Color _needsHelpColor = Color(0xFFE53935);

  const _WorkoutDetailsSheet({
    required this.log,
    required this.traineeName,
    required this.traineeId,
    required this.onReplyTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusInfo = log.status;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // 拖曳條
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // 內容
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // 標題
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: statusInfo.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.fitness_center,
                            color: statusInfo.color,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                log.planName,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: _textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusInfo.color.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      statusInfo.label,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: statusInfo.color,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    log.planDayOfWeek,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: _textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // 🔥 需要協助區塊（醒目顯示）
                    if (log.needsHelp) ...[
                      _buildNeedsHelpCard(),
                      const SizedBox(height: 20),
                    ],

                    // 訓練統計
                    _buildStatsCard(),
                    const SizedBox(height: 20),

                    // 🔥 Feedback 資訊
                    if (log.hasFeedback) ...[
                      _buildFeedbackCard(),
                      const SizedBox(height: 20),
                    ],

                    // 日期資訊
                    _buildDateCard(),
                    const SizedBox(height: 24),

                    // 🔥 快速回覆按鈕
                    _buildReplyButton(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 🔥 需要協助卡片（紅色醒目）
  Widget _buildNeedsHelpCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _needsHelpColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _needsHelpColor.withOpacity(0.3),
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
                  color: _needsHelpColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: _needsHelpColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '學員需要協助',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _needsHelpColor,
                ),
              ),
            ],
          ),
          if (log.helpMessage != null && log.helpMessage!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                log.helpMessage!,
                style: TextStyle(
                  fontSize: 14,
                  color: _textPrimary,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 訓練統計卡片
  Widget _buildStatsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '訓練統計',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatTile(
                Icons.timer_outlined,
                '${log.duration}',
                '分鐘',
                Colors.blue,
              ),
              _buildStatTile(
                Icons.local_fire_department,
                '${log.calories.round()}',
                '卡路里',
                Colors.orange,
              ),
              _buildStatTile(
                Icons.fitness_center,
                '${log.exerciseCount}',
                '動作',
                _primaryColor,
              ),
              _buildStatTile(
                Icons.repeat,
                '${log.setCount}',
                '組數',
                Colors.purple,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: _textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// 🔥 Feedback 卡片
  Widget _buildFeedbackCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.mood,
                color: _primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                '訓練回饋',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // RPE
          if (log.rpe != null)
            _buildFeedbackRow(
              '運動自覺強度',
              'RPE ${log.rpe}/10',
              _getRpeColor(log.rpe!),
            ),

          // 疲勞程度
          if (log.fatigueLevel != null)
            _buildFeedbackRow(
              '疲勞程度',
              log.fatigueLevelText,
              _getFatigueLevelColor(log.fatigueLevel!),
            ),

          // 心情
          if (log.mood != null)
            _buildFeedbackRow(
              '心情',
              log.moodText,
              _getMoodColor(log.mood!),
            ),

          // 備註
          if (log.note != null && log.note!.isNotEmpty) ...[
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
                      color: _textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    log.note!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: _textPrimary,
                      height: 1.5,
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

  Widget _buildFeedbackRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: _textSecondary,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: valueColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 日期資訊卡片
  Widget _buildDateCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildDateRow('計畫日', log.planDayOfWeek),
          if (log.actualDate != null)
            _buildDateRow(
              '完成日',
              _formatDate(log.actualDate!),
            ),
        ],
      ),
    );
  }

  Widget _buildDateRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: _textSecondary,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  /// 🔥 快速回覆按鈕
  Widget _buildReplyButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onReplyTap,
        icon: const Icon(Icons.chat_bubble_outline),
        label: Text(log.needsHelp ? '立即回覆' : '傳送訊息'),
        style: ElevatedButton.styleFrom(
          backgroundColor: log.needsHelp ? _needsHelpColor : _primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  // ============================================================
  // 輔助方法
  // ============================================================

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Color _getRpeColor(int rpe) {
    if (rpe <= 3) return Colors.green;
    if (rpe <= 5) return Colors.blue;
    if (rpe <= 7) return Colors.orange;
    return Colors.red;
  }

  Color _getFatigueLevelColor(String level) {
    switch (level) {
      case 'low':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'high':
        return Colors.deepOrange;
      case 'exhausted':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getMoodColor(String mood) {
    switch (mood) {
      case 'great':
        return Colors.green;
      case 'good':
        return Colors.lightGreen;
      case 'okay':
        return Colors.orange;
      case 'tired':
        return Colors.deepOrange;
      case 'bad':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}