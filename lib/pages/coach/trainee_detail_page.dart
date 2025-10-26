// lib/pages/coach/trainee_detail_page.dart
// 學員詳細資料主頁面 - 包含 4 個分頁

import 'package:flutter/material.dart';
import 'trainee_basic_info_tab.dart';
import 'trainee_nutrition_tab.dart';
import 'trainee_workout_tab.dart';

class TraineeDetailPage extends StatefulWidget {
  final String traineeId;
  final String traineeName;

  const TraineeDetailPage({
    Key? key,
    required this.traineeId,
    required this.traineeName,
  }) : super(key: key);

  @override
  State<TraineeDetailPage> createState() => _TraineeDetailPageState();
}

class _TraineeDetailPageState extends State<TraineeDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(widget.traineeName),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.green,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.green,
          tabs: const [
            Tab(
              icon: Icon(Icons.person),
              text: '基本資料',
            ),
            Tab(
              icon: Icon(Icons.restaurant),
              text: '飲食日誌',
            ),
            Tab(
              icon: Icon(Icons.fitness_center),
              text: '訓練日誌',
            ),
            Tab(
              icon: Icon(Icons.trending_up),
              text: '進度圖表',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 基本資料分頁
          TraineeBasicInfoTab(traineeId: widget.traineeId),
          
          // 飲食日誌分頁
          TraineeNutritionTab(traineeId: widget.traineeId),
          
          // 訓練日誌分頁
          TraineeWorkoutTab(traineeId: widget.traineeId),
          
          // 進度圖表分頁（稍後實作）
          _buildProgressTabPlaceholder(),
        ],
      ),
    );
  }

  // 進度圖表佔位符（稍後會用 Syncfusion Charts 實作）
  Widget _buildProgressTabPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.show_chart,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            '進度圖表功能',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '即將推出',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}