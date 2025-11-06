// lib/pages/workout/workout_plan_list_page.dart
// ✅ 更新版 - 添加進度追蹤功能，保留所有原有功能
import 'package:flutter/material.dart';
import '../../services/workout_service.dart';
import '../../services/workout_progress_service.dart'; // 🆕 添加進度服務
import '../../models/workout_model.dart';
import 'workout_plan_detail_page.dart';

class WorkoutPlanListPage extends StatefulWidget {
  const WorkoutPlanListPage({super.key});

  @override
  State<WorkoutPlanListPage> createState() => _WorkoutPlanListPageState();
}

class _WorkoutPlanListPageState extends State<WorkoutPlanListPage> {
  final WorkoutService _workoutService = WorkoutService();
  final WorkoutProgressService _progressService = WorkoutProgressService(); // 🆕 進度服務
  
  List<WorkoutPlanModel> _plans = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() => _isLoading = true);
    try {
      final plans = await _workoutService.getMyWorkoutPlans();
      setState(() {
        _plans = plans;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('載入失敗：$e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的訓練計畫'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPlans,
              child: _plans.isEmpty ? _buildEmptyState() : _buildPlansList(),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              '尚無訓練計畫',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              '請聯繫你的教練獲取訓練計畫',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlansList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _plans.length,
      itemBuilder: (context, index) {
        final plan = _plans[index];
        return _buildPlanCard(plan);
      },
    );
  }

  Widget _buildPlanCard(WorkoutPlanModel plan) {
    // 🆕 使用 FutureBuilder 來異步載入進度
    return FutureBuilder<Map<String, int>>(
      future: _loadPlanProgress(plan),
      builder: (context, snapshot) {
        // 計算進度
        final int totalDays = snapshot.data?['totalDays'] ?? plan.days.length;
        final int completedDays = snapshot.data?['completedDays'] ?? 0; // ✅ 修正：從資料庫讀取
        final double progress = totalDays > 0 ? completedDays / totalDays : 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WorkoutPlanDetailPage(plan: plan),
                ),
              ).then((_) => _loadPlans()); // 返回後重新載入
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 標題和狀態
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.fitness_center,
                          color: Colors.orange,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              plan.planName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (plan.description != null)
                              Text(
                                plan.description!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(plan.status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _getStatusText(plan.status),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _getStatusColor(plan.status),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 日期和訓練天數
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${_formatDate(plan.startDate)} - ${plan.endDate != null ? _formatDate(plan.endDate!) : "持續進行"}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.repeat, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '$totalDays 天訓練', // ✅ 顯示正確的總天數
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 進度條
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '完成進度',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '$completedDays/$totalDays 天', // ✅ 顯示實際完成天數
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.grey[200],
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.orange,
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // 🆕 載入計畫的進度信息
  Future<Map<String, int>> _loadPlanProgress(WorkoutPlanModel plan) async {
    try {
      final totalDays = _progressService.calculateTotalDays(plan);
      final completedDays = plan.id != null
          ? await _progressService.getCompletedDays(plan.id!)
          : 0;

      return {
        'totalDays': totalDays,
        'completedDays': completedDays,
      };
    } catch (e) {
      // 如果載入失敗，返回預設值
      return {
        'totalDays': plan.days.length,
        'completedDays': 0,
      };
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'active':
        return '進行中';
      case 'completed':
        return '已完成';
      case 'cancelled':
        return '已取消';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }
}