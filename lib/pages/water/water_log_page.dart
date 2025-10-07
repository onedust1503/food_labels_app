// lib/pages/water/water_log_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/water_service.dart';

class WaterLogPage extends StatefulWidget {
  const WaterLogPage({super.key});

  @override
  State<WaterLogPage> createState() => _WaterLogPageState();
}

class _WaterLogPageState extends State<WaterLogPage> with SingleTickerProviderStateMixin {
  final WaterService _waterService = WaterService();
  late TabController _tabController;

  // 🔥 新增：獲取台灣時間的今日日期
  String get _todayTaiwan {
    DateTime tw = DateTime.now().toUtc().add(const Duration(hours: 8));
    return '${tw.year}-${tw.month.toString().padLeft(2, '0')}-${tw.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('喝水記錄'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: '今日記錄'),
            Tab(text: '歷史統計'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTodayTab(),
          _buildHistoryTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddWaterDialog,
        backgroundColor: Colors.blue,
        icon: const Icon(Icons.add),
        label: const Text('喝水'),
      ),
    );
  }

  // 今日記錄頁籤
  Widget _buildTodayTab() {
    return StreamBuilder<Map<String, dynamic>>(
      stream: _waterService.getTodayWaterStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 60, color: Colors.red),
                const SizedBox(height: 16),
                Text('載入失敗: ${snapshot.error}'),
              ],
            ),
          );
        }

        final data = snapshot.data ?? {};
        final totalWater = data['totalWater'] ?? 0;
        final targetWater = data['targetWater'] ?? 2000;
        final logs = List.from(data['logs'] ?? []);
        final percentage = targetWater > 0 ? (totalWater / targetWater).clamp(0.0, 1.0) : 0.0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // 進度圓圈
              _buildProgressCircle(totalWater, targetWater, percentage),
              
              const SizedBox(height: 24),
              
              // 快速添加按鈕
              _buildQuickAddButtons(),
              
              const SizedBox(height: 24),
              
              // 記錄列表
              _buildLogsList(logs),
            ],
          ),
        );
      },
    );
  }

  // 進度圓圈
  Widget _buildProgressCircle(int totalWater, int targetWater, double percentage) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 180,
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 180,
                  height: 180,
                  child: CircularProgressIndicator(
                    value: percentage,
                    strokeWidth: 16,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      percentage >= 1.0 ? Colors.green : Colors.blue,
                    ),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.water_drop,
                      size: 48,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$totalWater ml',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    Text(
                      '/ $targetWater ml',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(percentage * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _showTargetSettingDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit, size: 16, color: Colors.blue),
                  SizedBox(width: 4),
                  Text(
                    '調整目標',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
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

  // 快速添加按鈕
  Widget _buildQuickAddButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '快速記錄',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildQuickButton(100)),
            const SizedBox(width: 12),
            Expanded(child: _buildQuickButton(200)),
            const SizedBox(width: 12),
            Expanded(child: _buildQuickButton(300)),
            const SizedBox(width: 12),
            Expanded(child: _buildQuickButton(500)),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickButton(int amount) {
    return InkWell(
      onTap: () => _addWater(amount),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            const Icon(Icons.water_drop, color: Colors.blue, size: 24),
            const SizedBox(height: 4),
            Text(
              '${amount}ml',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 記錄列表
  Widget _buildLogsList(List logs) {
    if (logs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(Icons.water_drop_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '今日尚未記錄喝水',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '今日記錄',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...logs.asMap().entries.map((entry) {
          int index = entry.key;
          var log = entry.value;
          return _buildLogItem(log, index);
        }).toList(),
      ],
    );
  }

  Widget _buildLogItem(Map<String, dynamic> log, int index) {
    final amount = log['amount'] ?? 0;
    
    // 🔥 修改：優先使用 displayTime，否則格式化 timestamp
    String timeStr;
    if (log['displayTime'] != null && log['displayTime'].toString().isNotEmpty) {
      timeStr = log['displayTime'];
    } else if (log['timestamp'] != null) {
      final timestamp = (log['timestamp'] as dynamic).toDate();
      timeStr = DateFormat('HH:mm').format(timestamp);
    } else {
      timeStr = '--:--';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.water_drop, color: Colors.blue, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${amount}ml',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _confirmDelete(index),
            icon: const Icon(Icons.delete_outline, color: Colors.red),
          ),
        ],
      ),
    );
  }

  // 歷史統計頁籤
  Widget _buildHistoryTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _waterService.getRecentWaterLogs(days: 7),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('載入失敗: ${snapshot.error}'));
        }

        final weekData = snapshot.data ?? [];

        return FutureBuilder<Map<String, dynamic>>(
          future: _waterService.getWeeklyStats(),
          builder: (context, statsSnapshot) {
            final stats = statsSnapshot.data ?? {};

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 本週統計
                  _buildWeeklyStats(stats),
                  
                  const SizedBox(height: 24),
                  
                  // 每日記錄
                  const Text(
                    '最近 7 天',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  ...weekData.map((dayData) => _buildDayCard(dayData)).toList(),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildWeeklyStats(Map<String, dynamic> stats) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[400]!, Colors.blue[600]!],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '本週統計',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('總攝取', '${stats['totalWater'] ?? 0}ml'),
              _buildStatItem('日均', '${stats['avgDaily'] ?? 0}ml'),
              _buildStatItem('達標', '${stats['daysCompleted'] ?? 0}/7天'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildDayCard(Map<String, dynamic> dayData) {
    final date = DateTime.parse(dayData['date']);
    final totalWater = dayData['totalWater'] ?? 0;
    final targetWater = dayData['targetWater'] ?? 2000;
    final percentage = targetWater > 0 ? (totalWater / targetWater).clamp(0.0, 1.0) : 0.0;
    final isCompleted = totalWater >= targetWater;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted ? Colors.green : Colors.grey[300]!,
          width: isCompleted ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                Text(
                  DateFormat('MM/dd').format(date),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  _getWeekdayName(date.weekday),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${totalWater}ml / ${targetWater}ml',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isCompleted)
                      const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percentage,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isCompleted ? Colors.green : Colors.blue,
                    ),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getWeekdayName(int weekday) {
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    return weekdays[weekday - 1];
  }

  // 添加喝水對話框
  void _showAddWaterDialog() {
    final TextEditingController controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('記錄喝水'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '水量（毫升）',
            hintText: '例如：200',
            suffixText: 'ml',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = int.tryParse(controller.text);
              if (amount != null && amount > 0) {
                Navigator.pop(context);
                _addWater(amount);
              }
            },
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }

  // 目標設定對話框
  void _showTargetSettingDialog() {
    final TextEditingController controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('設定每日目標'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('建議每日攝取量：2000-2500ml'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '目標水量（毫升）',
                hintText: '例如：2000',
                suffixText: 'ml',
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final target = int.tryParse(controller.text);
              if (target != null && target > 0) {
                Navigator.pop(context);
                try {
                  await _waterService.updateWaterTarget(target);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('目標已更新'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('更新失敗: $e')),
                    );
                  }
                }
              }
            },
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }

  // 添加喝水
  Future<void> _addWater(int amount) async {
    try {
      await _waterService.addWaterLog(amount: amount);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已記錄 ${amount}ml'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('記錄失敗: $e')),
        );
      }
    }
  }

  // 確認刪除
  void _confirmDelete(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認刪除'),
        content: const Text('確定要刪除這筆記錄嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteLog(index);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
  }

  // 🔥 修改：刪除記錄時使用台灣時區日期
  Future<void> _deleteLog(int index) async {
    try {
      await _waterService.deleteWaterLog(date: _todayTaiwan, logIndex: index);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已刪除記錄'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('刪除失敗: $e')),
        );
      }
    }
  }
}