// lib/pages/workout/workout_history_page.dart
// 🔥 訓練歷史頁 - 顯示統一的訓練記錄
// ✅ 修正版：使用正確的參數傳遞給詳細頁面

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/unified_workout_service.dart';
import 'workout_session_detail_page.dart';

class WorkoutHistoryPage extends StatefulWidget {
  const WorkoutHistoryPage({super.key});

  @override
  State<WorkoutHistoryPage> createState() => _WorkoutHistoryPageState();
}

class _WorkoutHistoryPageState extends State<WorkoutHistoryPage> {
  final UnifiedWorkoutService _service = UnifiedWorkoutService();
  
  List<Map<String, dynamic>> _workouts = [];
  bool _isLoading = true;
  int _selectedDays = 30;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    
    try {
      // 使用 UnifiedWorkoutService 的方法
      final workouts = await _service.getWorkoutHistory(days: _selectedDays);
      
      if (mounted) {
        setState(() {
          _workouts = workouts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('載入失敗：$e', Colors.red);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
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
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text(
          '訓練歷史',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          PopupMenuButton<int>(
            icon: const Icon(Icons.calendar_today),
            onSelected: (days) {
              setState(() => _selectedDays = days);
              _loadHistory();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 7, child: Text('最近 7 天')),
              const PopupMenuItem(value: 30, child: Text('最近 30 天')),
              const PopupMenuItem(value: 90, child: Text('最近 90 天')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF6C63FF),
              ),
            )
          : _workouts.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadHistory,
                  color: const Color(0xFF6C63FF),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _workouts.length,
                    itemBuilder: (context, index) {
                      final workout = _workouts[index];
                      return _buildWorkoutCard(workout);
                    },
                  ),
                ),
    );
  }

  Widget _buildWorkoutCard(Map<String, dynamic> workout) {
    // 解析資料
    final name = workout['name'] ?? '訓練記錄';
    final duration = workout['duration'] ?? 0;
    final calories = (workout['caloriesBurned'] ?? 0.0).toDouble();
    final exercises = workout['exercises'] as List<dynamic>? ?? [];
    final hasplanId = workout['planId'] != null;
    
    // 解析日期
    final dateStr = workout['date'] ?? '';
    
    // 解析時間戳記
    final timestamp = workout['completedAt'] ?? workout['createdAt'];
    DateTime? dateTime;
    if (timestamp != null) {
      try {
        if (timestamp is Timestamp) {
          dateTime = timestamp.toDate();
        }
      } catch (e) {
        // 時間解析失敗,使用日期字串
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // ✅ 修正：直接傳遞 workout (workoutSession) 物件
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WorkoutSessionDetailPage(
                  workoutSession: workout,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 標題列
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: hasplanId 
                              ? [const Color(0xFF2196F3), const Color(0xFF1976D2)]
                              : [const Color(0xFF6C63FF), const Color(0xFF2DC4EA)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        hasplanId ? Icons.event_note : Icons.fitness_center,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
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
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (hasplanId)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.blue.withOpacity(0.3),
                                    ),
                                  ),
                                  child: const Text(
                                    '計畫',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 12,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                dateTime != null
                                    ? _formatDateTime(dateTime)
                                    : _formatDate(dateStr),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: Colors.grey,
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // 統計數據
                Row(
                  children: [
                    _buildStatChip(
                      Icons.timer,
                      '$duration 分鐘',
                      const Color(0xFF6C63FF),
                    ),
                    const SizedBox(width: 8),
                    _buildStatChip(
                      Icons.local_fire_department,
                      '${calories.toInt()} 卡',
                      Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    if (exercises.isNotEmpty)
                      _buildStatChip(
                        Icons.list,
                        '${exercises.length} 動作',
                        const Color(0xFF22C55E),
                      ),
                  ],
                ),
                
                // 動作摘要
                if (exercises.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F7FB),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '包含動作',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: exercises.take(4).map((ex) {
                            final exMap = ex as Map<String, dynamic>;
                            final exName = exMap['name'] ?? '未知';
                            final sets = exMap['sets'] as List<dynamic>? ?? [];
                            
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFF6C63FF).withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                '$exName ${sets.length}組',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        if (exercises.length > 4)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '+${exercises.length - 4} 個動作',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '還沒有訓練記錄',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '開始你的第一次訓練吧！',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final targetDate = DateTime(date.year, date.month, date.day);

      if (targetDate == today) {
        return '今天';
      } else if (targetDate == yesterday) {
        return '昨天';
      } else {
        return DateFormat('MM/dd (E)', 'zh_TW').format(date);
      }
    } catch (e) {
      return dateStr;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final targetDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    String prefix;
    if (targetDate == today) {
      prefix = '今天';
    } else if (targetDate == yesterday) {
      prefix = '昨天';
    } else {
      prefix = DateFormat('MM/dd', 'zh_TW').format(dateTime);
    }

    return '$prefix ${DateFormat('HH:mm').format(dateTime)}';
  }
}