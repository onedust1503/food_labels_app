// lib/pages/workout/coach_plans_management_page.dart
// 📊 教練端訓練計畫管理 - 完整適配你的 Firebase 資料結構
// ✅ 只顯示自己創建的計畫（coachId 過濾）
// ✅ 實時追蹤完成進度（從 workoutLogs 查詢 planId）
// ✅ 正確顯示學員名稱（從 users 讀取）
// ✅ 支援刪除、查看詳情

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class CoachPlansManagementPage extends StatefulWidget {
  const CoachPlansManagementPage({super.key});

  @override
  State<CoachPlansManagementPage> createState() => _CoachPlansManagementPageState();
}

class _CoachPlansManagementPageState extends State<CoachPlansManagementPage>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late TabController _tabController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentCoachId = _auth.currentUser?.uid;
    
    if (currentCoachId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('訓練計畫管理')),
        body: const Center(child: Text('請先登入')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          '訓練計畫管理',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          tabs: const [
            Tab(icon: Icon(Icons.schedule), text: '進行中'),
            Tab(icon: Icon(Icons.check_circle), text: '已完成'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPlansList(isActive: true, coachId: currentCoachId),
                _buildPlansList(isActive: false, coachId: currentCoachId),
              ],
            ),
    );
  }

  /// 📋 計畫列表
  Widget _buildPlansList({required bool isActive, required String coachId}) {
    return StreamBuilder<QuerySnapshot>(
      // ✅ 關鍵：只查詢該教練創建的計畫
      stream: _firestore
          .collection('workoutPlans')
          .where('coachId', isEqualTo: coachId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('發生錯誤: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(isActive);
        }

        // 🔍 過濾：根據進行中/已完成狀態
        final plans = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status'] ?? 'active';
          
          // 判斷是否已過期
          DateTime? endDate;
          try {
            if (data['endDate'] != null) {
              if (data['endDate'] is Timestamp) {
                endDate = (data['endDate'] as Timestamp).toDate();
              } else if (data['endDate'] is String) {
                endDate = DateTime.parse(data['endDate'] as String);
              }
            }
          } catch (e) {
            if (kDebugMode) debugPrint('解析結束日期失敗: $e');
          }
          
          final isExpired = endDate != null && endDate.isBefore(DateTime.now());
          
          // 根據 Tab 決定顯示哪些計畫
          if (isActive) {
            return status != 'completed' && !isExpired;
          } else {
            return status == 'completed' || isExpired;
          }
        }).toList();

        if (plans.isEmpty) {
          return _buildEmptyState(isActive);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: plans.length,
          itemBuilder: (context, index) {
            return _buildPlanCard(plans[index], isActive: isActive);
          },
        );
      },
    );
  }

  /// 🎨 空狀態顯示
  Widget _buildEmptyState(bool isActive) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isActive ? Icons.event_note : Icons.check_circle_outline,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            isActive ? '尚無進行中的計畫' : '尚無已完成的計畫',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (isActive) ...[
            const SizedBox(height: 8),
            Text(
              '點擊右上角 + 創建新計畫',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 🎴 計畫卡片
  Widget _buildPlanCard(DocumentSnapshot doc, {required bool isActive}) {
    final data = doc.data() as Map<String, dynamic>;
    final planName = data['planName'] ?? '未命名計畫';
    final traineeId = data['traineeId'] as String;
    final description = data['description'] as String?;
    
    // 🗓️ 解析日期
    DateTime startDate = DateTime.now();
    DateTime? endDate;
    
    try {
      if (data['startDate'] is Timestamp) {
        startDate = (data['startDate'] as Timestamp).toDate();
      } else if (data['startDate'] is String) {
        startDate = DateTime.parse(data['startDate'] as String);
      }
      
      if (data['endDate'] != null) {
        if (data['endDate'] is Timestamp) {
          endDate = (data['endDate'] as Timestamp).toDate();
        } else if (data['endDate'] is String) {
          endDate = DateTime.parse(data['endDate'] as String);
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('解析日期失敗: $e');
    }
    
    // 📊 計算訓練天數和動作數
    final days = (data['days'] as List<dynamic>?) ?? [];
    final totalExercises = days.fold<int>(
      0,
      (sum, day) {
        final exercises = (day as Map<String, dynamic>)['exercises'] as List? ?? [];
        return sum + exercises.length;
      },
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.green.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.15),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _viewPlanDetail(doc.id, data, traineeId),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🎯 標題列
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isActive
                            ? Colors.green.withValues(alpha: 0.15)
                            : Colors.grey.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isActive ? Icons.play_circle_outline : Icons.check_circle_outline,
                        color: isActive ? Colors.green : Colors.grey,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            planName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // ✅ 學員名稱（使用 FutureBuilder）
                          FutureBuilder<DocumentSnapshot>(
                            future: _firestore.collection('users').doc(traineeId).get(),
                            builder: (context, snapshot) {
                              String traineeName = '載入中...';
                              if (snapshot.hasData && snapshot.data!.exists) {
                                final userData = snapshot.data!.data() as Map<String, dynamic>;
                                traineeName = userData['displayName'] ?? '未命名學員';
                              } else if (snapshot.hasError || 
                                        (snapshot.connectionState == ConnectionState.done && 
                                         !snapshot.hasData)) {
                                traineeName = '未知學員';
                              }

                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.person, size: 12, color: Colors.blue),
                                    const SizedBox(width: 4),
                                    Text(
                                      traineeName,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    if (isActive)
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        onSelected: (value) {
                          if (value == 'delete') {
                            _deletePlan(doc.id, planName);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red, size: 20),
                                SizedBox(width: 8),
                                Text('刪除計畫'),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                
                // 📝 說明（如果有）
                if (description != null && description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            description,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue.shade700,
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 16),
                
                // 📊 統計資訊
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _buildStatChip(Icons.calendar_today, '${days.length} 天', Colors.blue),
                      const SizedBox(width: 12),
                      _buildStatChip(Icons.fitness_center, '$totalExercises 個動作', Colors.orange),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 📅 日期範圍
                Row(
                  children: [
                    Icon(Icons.event_available, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      '${_formatDate(startDate)} - ${endDate != null ? _formatDate(endDate) : "持續中"}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),

                // ✅ 進度條（只在進行中顯示）
                if (isActive) ...[
                  const SizedBox(height: 16),
                  // 🔥 關鍵：從 workoutLogs 查詢完成記錄
                  StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('workoutLogs')
                        .where('userId', isEqualTo: traineeId)
                        .where('planId', isEqualTo: doc.id)  // ✅ 關鍵過濾條件
                        .snapshots(),
                    builder: (context, logSnapshot) {
                      int completedSessions = 0;
                      if (logSnapshot.hasData) {
                        completedSessions = logSnapshot.data!.docs.length;
                      }

                      final totalSessions = days.length;
                      final progress = totalSessions > 0
                          ? (completedSessions / totalSessions).clamp(0.0, 1.0)
                          : 0.0;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '完成進度',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '$completedSessions / $totalSessions 次',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade600),
                              minHeight: 10,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 🏷️ 統計標籤
  Widget _buildStatChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// 👁️ 查看計畫詳情
  Future<void> _viewPlanDetail(String planId, Map<String, dynamic> data, String traineeId) async {
    await showDialog(
      context: context,
      builder: (context) => PlanDetailDialog(
        planId: planId,
        planData: data,
        traineeId: traineeId,
      ),
    );
  }

  /// 🗑️ 刪除計畫
  Future<void> _deletePlan(String planId, String planName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('確認刪除'),
          ],
        ),
        content: Text('確定要刪除「$planName」嗎？\n\n此操作無法復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestore.collection('workoutPlans').doc(planId).delete();
        _showSnackBar('已刪除計畫');
      } catch (e) {
        _showSnackBar('刪除失敗：$e', isError: true);
      }
    }
  }

  /// 📅 格式化日期
  String _formatDate(DateTime date) {
    return DateFormat('yyyy/MM/dd').format(date);
  }
}

// ===================================
// 📌 計畫詳情對話框
// ===================================

class PlanDetailDialog extends StatelessWidget {
  final String planId;
  final Map<String, dynamic> planData;
  final String traineeId;

  const PlanDetailDialog({
    super.key,
    required this.planId,
    required this.planData,
    required this.traineeId,
  });

  Color _getCategoryColor(String category) {
    switch (category) {
      case '胸部': return Colors.red;
      case '背部': return Colors.blue;
      case '腿部': return Colors.orange;
      case '肩膀': return Colors.purple;
      case '手臂': return Colors.green;
      case '腹肌': return Colors.teal;
      case '有氧': return Colors.pink;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final planName = planData['planName'] ?? '未命名計畫';
    final description = planData['description'] as String?;
    final days = (planData['days'] as List<dynamic>?) ?? [];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
          maxWidth: 500,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🎨 標題欄
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade600, Colors.green.shade400],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.event, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          planName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // 👤 學員名稱
                  FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('users').doc(traineeId).get(),
                    builder: (context, snapshot) {
                      String traineeName = '載入中...';
                      if (snapshot.hasData && snapshot.data!.exists) {
                        final userData = snapshot.data!.data() as Map<String, dynamic>;
                        traineeName = userData['displayName'] ?? '未命名學員';
                      }

                      return Row(
                        children: [
                          const Icon(Icons.person, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            traineeName,
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),

            // 📝 說明區域
            if (description != null && description.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue.shade50,
                      Colors.blue.shade100,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.info_outline, size: 20, color: Colors.blue),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '計畫說明',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            description,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              height: 1.5,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // 📋 訓練內容
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: days.length,
                itemBuilder: (context, index) {
                  final day = days[index] as Map<String, dynamic>;
                  return _buildDayCard(day);
                },
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// 📅 單日訓練卡片
  Widget _buildDayCard(Map<String, dynamic> day) {
    final dayOfWeek = day['dayOfWeek'] as String;
    final exercises = (day['exercises'] as List<dynamic>?) ?? [];

    final Map<String, String> dayNames = {
      'monday': '星期一',
      'tuesday': '星期二',
      'wednesday': '星期三',
      'thursday': '星期四',
      'friday': '星期五',
      'saturday': '星期六',
      'sunday': '星期日',
      'single': '單次訓練',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.calendar_today, color: Colors.green, size: 18),
                ),
                const SizedBox(width: 12),
                Text(
                  dayNames[dayOfWeek] ?? dayOfWeek,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.green.shade700,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${exercises.length} 個動作',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (exercises.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '尚未添加運動',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: exercises.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final exercise = exercises[index] as Map<String, dynamic>;
                final name = exercise['name'] ?? '未命名運動';
                final type = exercise['type'] ?? '';
                final sets = exercise['sets'];
                final reps = exercise['reps'];
                final categoryColor = _getCategoryColor(type);

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: categoryColor.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: categoryColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: categoryColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (sets != null && reps != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.repeat, size: 14, color: Colors.grey.shade600),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$sets 組 × $reps 次',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (type.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: categoryColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            type,
                            style: TextStyle(
                              fontSize: 11,
                              color: categoryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}