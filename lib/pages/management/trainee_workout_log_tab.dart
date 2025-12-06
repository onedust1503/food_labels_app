// lib/pages/management/trainee_workout_log_tab.dart
// 🔥 教練端 - 學員訓練日誌分頁 v2.0
// 顯示學員的訓練記錄，包含清楚的完成狀態標示

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/completion_status.dart';
import '../../services/workout_completion_service.dart';
import '../../components/completion_status_badge.dart';

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
  late TabController _tabController;
  final WorkoutCompletionService _completionService = WorkoutCompletionService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  bool _isLoading = true;
  List<WorkoutCompletionRecord> _planWorkouts = [];
  List<Map<String, dynamic>> _allWorkouts = [];
  Map<String, dynamic> _statistics = {};
  
  // 篩選選項
  String _selectedFilter = 'all'; // all, onTime, makeup, early

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
      // 載入計畫訓練記錄
      final planWorkouts = await _completionService.getTraineeWorkoutLogs(
        traineeId: widget.traineeId,
        limit: 100,
      );
      
      // 載入所有訓練記錄（包含自由訓練）
      final allWorkoutsSnapshot = await _firestore
          .collection('workoutLogs')
          .where('userId', isEqualTo: widget.traineeId)
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();
      
      final allWorkouts = allWorkoutsSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      
      // 載入統計數據
      final stats = await _completionService.getTraineeStatistics(
        traineeId: widget.traineeId,
        days: 30,
      );
      
      setState(() {
        _planWorkouts = planWorkouts;
        _allWorkouts = allWorkouts;
        _statistics = stats;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ 載入數據失敗: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 統計卡片
        _buildStatsHeader(),
        
        // 分頁標籤
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            indicatorPadding: const EdgeInsets.all(4),
            labelColor: const Color(0xFF3B82F6),
            unselectedLabelColor: Colors.grey[600],
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            tabs: const [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_today, size: 16),
                    SizedBox(width: 6),
                    Text('計畫訓練'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.list_alt, size: 16),
                    SizedBox(width: 6),
                    Text('全部紀錄'),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // 內容區域
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPlanWorkoutsTab(),
                    _buildAllWorkoutsTab(),
                  ],
                ),
        ),
      ],
    );
  }

  /// 🔥 統計頭部卡片
  Widget _buildStatsHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${widget.traineeName} 的訓練概況',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '近 ${_statistics['period'] ?? '30 天'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // 統計數據
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  '總完成',
                  '${_statistics['totalCompleted'] ?? 0}',
                  Icons.check_circle_outline,
                ),
              ),
              _buildVerticalDivider(),
              Expanded(
                child: _buildStatItem(
                  '準時率',
                  '${_statistics['onTimeRate'] ?? 0}%',
                  Icons.access_time,
                ),
              ),
              _buildVerticalDivider(),
              Expanded(
                child: _buildStatItem(
                  '總時長',
                  '${_statistics['totalDuration'] ?? 0}分',
                  Icons.timer_outlined,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // 狀態分佈
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatusChip(
                '準時', 
                _statistics['onTimeCount'] ?? 0,
                const Color(0xFF10B981),
              ),
              _buildStatusChip(
                '提前', 
                _statistics['earlyCount'] ?? 0,
                const Color(0xFF3B82F6),
              ),
              _buildStatusChip(
                '補做', 
                _statistics['makeupCount'] ?? 0,
                const Color(0xFFF59E0B),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.8), size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.white.withOpacity(0.3),
    );
  }

  Widget _buildStatusChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$label $count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// 🔥 計畫訓練分頁
  Widget _buildPlanWorkoutsTab() {
    if (_planWorkouts.isEmpty) {
      return _buildEmptyState(
        icon: Icons.calendar_today,
        title: '尚無計畫訓練記錄',
        subtitle: '學員還沒有完成任何計畫訓練',
      );
    }

    // 篩選功能
    final filteredWorkouts = _filterWorkouts(_planWorkouts);

    return Column(
      children: [
        // 篩選器
        _buildFilterBar(),
        
        // 狀態圖例
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: StatusLegend(compact: true),
        ),
        
        // 列表
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredWorkouts.length,
              itemBuilder: (context, index) {
                final record = filteredWorkouts[index];
                return WorkoutLogCard(
                  record: record,
                  onTap: () => _showWorkoutDetails(record),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  /// 🔥 篩選器
  Widget _buildFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildFilterChip('all', '全部', null),
          const SizedBox(width: 8),
          _buildFilterChip('onTime', '準時', CompletionStatusType.onTime),
          const SizedBox(width: 8),
          _buildFilterChip('early', '提前', CompletionStatusType.early),
          const SizedBox(width: 8),
          _buildFilterChip('makeup', '補做', CompletionStatusType.makeup),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, CompletionStatusType? type) {
    final isSelected = _selectedFilter == value;
    final status = type != null ? CompletionStatus.fromType(type) : null;
    
    return GestureDetector(
      onTap: () {
        setState(() => _selectedFilter = value);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? (status?.color ?? const Color(0xFF3B82F6))
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected 
                ? (status?.color ?? const Color(0xFF3B82F6))
                : Colors.grey[300]!,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (status != null) ...[
              Icon(
                status.icon,
                size: 14,
                color: isSelected ? Colors.white : status.color,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isSelected 
                    ? Colors.white 
                    : (status?.color ?? Colors.grey[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<WorkoutCompletionRecord> _filterWorkouts(List<WorkoutCompletionRecord> workouts) {
    if (_selectedFilter == 'all') return workouts;
    
    return workouts.where((w) {
      switch (_selectedFilter) {
        case 'onTime':
          return w.statusType == CompletionStatusType.onTime;
        case 'early':
          return w.statusType == CompletionStatusType.early;
        case 'makeup':
          return w.statusType == CompletionStatusType.makeup;
        default:
          return true;
      }
    }).toList();
  }

  /// 🔥 全部紀錄分頁
  Widget _buildAllWorkoutsTab() {
    if (_allWorkouts.isEmpty) {
      return _buildEmptyState(
        icon: Icons.fitness_center,
        title: '尚無訓練紀錄',
        subtitle: '學員還沒有任何訓練記錄',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _allWorkouts.length,
        itemBuilder: (context, index) {
          final workout = _allWorkouts[index];
          return _buildWorkoutCard(workout);
        },
      ),
    );
  }

  /// 🔥 通用訓練卡片（用於全部紀錄分頁）
  Widget _buildWorkoutCard(Map<String, dynamic> workout) {
    final name = workout['name'] ?? '訓練';
    final duration = workout['duration'] ?? 0;
    final calories = (workout['caloriesBurned'] ?? 0).toDouble();
    final date = workout['date'] ?? '';
    final planId = workout['planId'];
    final isPlanWorkout = planId != null;
    
    // 解析日期
    DateTime? parsedDate;
    try {
      if (date is String && date.isNotEmpty) {
        parsedDate = DateTime.parse(date);
      }
    } catch (e) {
      // ignore
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPlanWorkout 
              ? const Color(0xFF3B82F6).withOpacity(0.3)
              : Colors.grey[200]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 日期
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isPlanWorkout 
                  ? const Color(0xFFDBEAFE)
                  : Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  parsedDate?.day.toString() ?? '--',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isPlanWorkout 
                        ? const Color(0xFF3B82F6)
                        : Colors.orange,
                  ),
                ),
                Text(
                  '${parsedDate?.month ?? '--'}月',
                  style: TextStyle(
                    fontSize: 11,
                    color: isPlanWorkout 
                        ? const Color(0xFF3B82F6).withOpacity(0.8)
                        : Colors.orange.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 12),
          
          // 訓練資訊
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 15,
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
                            ? const Color(0xFFDBEAFE)
                            : Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isPlanWorkout ? '計畫' : '自由',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isPlanWorkout 
                              ? const Color(0xFF3B82F6)
                              : Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                // 統計
                Row(
                  children: [
                    _buildMiniStat(Icons.timer_outlined, '$duration 分鐘'),
                    const SizedBox(width: 16),
                    _buildMiniStat(
                      Icons.local_fire_department_outlined, 
                      '${calories.round()} 卡',
                    ),
                    if (workout['totalExercises'] != null) ...[
                      const SizedBox(width: 16),
                      _buildMiniStat(
                        Icons.fitness_center, 
                        '${workout['totalExercises']} 動作',
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[500]),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  /// 🔥 空狀態
  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  /// 🔥 顯示訓練詳情
  void _showWorkoutDetails(WorkoutCompletionRecord record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _WorkoutDetailsSheet(record: record),
    );
  }
}

/// 🔥 訓練詳情底部彈窗
class _WorkoutDetailsSheet extends StatelessWidget {
  final WorkoutCompletionRecord record;
  
  const _WorkoutDetailsSheet({required this.record});

  @override
  Widget build(BuildContext context) {
    final status = record.status;
    
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖曳指示條
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 標題和狀態
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              record.planName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              status.description,
                              style: TextStyle(
                                fontSize: 14,
                                color: status.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                      CompletionStatusBadge(statusType: record.statusType),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // 日期資訊
                  _buildInfoSection(
                    icon: Icons.calendar_today,
                    title: '日期資訊',
                    children: [
                      _buildInfoRow('計畫日', record.planDayOfWeek),
                      if (record.actualDate != null) ...[
                        _buildInfoRow(
                          '實際完成', 
                          '${record.actualDate!.month}/${record.actualDate!.day} ${record.actualDayOfWeek ?? ''}',
                        ),
                      ],
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // 訓練統計
                  _buildInfoSection(
                    icon: Icons.bar_chart,
                    title: '訓練統計',
                    children: [
                      _buildInfoRow('訓練時長', '${record.duration} 分鐘'),
                      _buildInfoRow('動作數量', '${record.exerciseCount} 個'),
                      _buildInfoRow('完成組數', '${record.setCount} 組'),
                      _buildInfoRow('消耗熱量', '${record.calories.round()} 卡'),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // 關閉按鈕
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: status.color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('關閉'),
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

  Widget _buildInfoSection({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}