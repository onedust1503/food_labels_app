// lib/pages/coach/trainee_nutrition_tab.dart
// 學員飲食日誌分頁

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TraineeNutritionTab extends StatelessWidget {
  final String traineeId;

  const TraineeNutritionTab({
    Key? key,
    required this.traineeId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(traineeId)
          .collection('nutrition_logs')
          .orderBy('date', descending: true)
          .limit(30)
          .snapshots(),
      builder: (context, snapshot) {
        // 載入中
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            ),
          );
        }

        // 錯誤處理
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 60,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  '載入失敗',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        // 沒有資料
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.restaurant_menu,
                  size: 80,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  '尚無飲食紀錄',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '學員開始記錄後會顯示在這裡',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          );
        }

        final logs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: logs.length,
          itemBuilder: (context, index) {
            final log = logs[index].data() as Map<String, dynamic>;
            final logId = logs[index].id;
            final date = (log['date'] as Timestamp?)?.toDate() ?? DateTime.now();
            final totalCalories = log['totalCalories'] ?? 0;
            final protein = log['protein'] ?? 0;
            final carbs = log['carbs'] ?? 0;
            final fat = log['fat'] ?? 0;
            final foods = log['foods'] as List<dynamic>? ?? [];

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _showNutritionDetail(context, log, date),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // 左側：日期圓圈
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: _getCalorieColor(totalCalories).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${date.day}',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: _getCalorieColor(totalCalories),
                              ),
                            ),
                            Text(
                              '${date.month}月',
                              style: TextStyle(
                                fontSize: 12,
                                color: _getCalorieColor(totalCalories),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),

                      // 中間：營養資訊
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.local_fire_department,
                                  size: 18,
                                  color: Colors.orange,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$totalCalories kcal',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _buildNutrientChip('蛋白質', protein, Colors.red),
                                const SizedBox(width: 8),
                                _buildNutrientChip('碳水', carbs, Colors.blue),
                                const SizedBox(width: 8),
                                _buildNutrientChip('脂肪', fat, Colors.orange),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${foods.length} 項食物',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 右側：箭頭
                      Icon(
                        Icons.chevron_right,
                        color: Colors.grey[400],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 建立營養素標籤
  Widget _buildNutrientChip(String label, dynamic value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label ${value}g',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  // 根據熱量取得顏色
  Color _getCalorieColor(int calories) {
    if (calories < 1500) {
      return Colors.orange; // 熱量過低
    } else if (calories > 2500) {
      return Colors.red; // 熱量過高
    } else {
      return Colors.green; // 正常範圍
    }
  }

  // 顯示飲食詳情
  void _showNutritionDetail(
    BuildContext context,
    Map<String, dynamic> log,
    DateTime date,
  ) {
    final totalCalories = log['totalCalories'] ?? 0;
    final protein = log['protein'] ?? 0;
    final carbs = log['carbs'] ?? 0;
    final fat = log['fat'] ?? 0;
    final foods = log['foods'] as List<dynamic>? ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // 頂部拖拉指示器
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // 內容
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 標題
                      Row(
                        children: [
                          const Icon(
                            Icons.restaurant,
                            color: Colors.green,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '飲食詳情',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${date.year}/${date.month}/${date.day}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // 營養總覽
                      _buildNutritionSummary(
                        totalCalories,
                        protein,
                        carbs,
                        fat,
                      ),
                      const SizedBox(height: 24),

                      // 食物列表
                      const Text(
                        '食物清單',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildFoodList(foods),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 營養總覽卡片
  Widget _buildNutritionSummary(
    int totalCalories,
    dynamic protein,
    dynamic carbs,
    dynamic fat,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[400]!, Colors.green[600]!],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNutritionItem('熱量', '$totalCalories', 'kcal'),
          _buildDivider(),
          _buildNutritionItem('蛋白質', '$protein', 'g'),
          _buildDivider(),
          _buildNutritionItem('碳水', '$carbs', 'g'),
          _buildDivider(),
          _buildNutritionItem('脂肪', '$fat', 'g'),
        ],
      ),
    );
  }

  Widget _buildNutritionItem(String label, String value, String unit) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          unit,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 40,
      color: Colors.white30,
    );
  }

  // 食物列表
  Widget _buildFoodList(List<dynamic> foods) {
    if (foods.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '無食物資料',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return Column(
      children: foods.map((food) {
        final foodMap = food as Map<String, dynamic>;
        final name = foodMap['name'] ?? '未命名食物';
        final calories = foodMap['calories'] ?? 0;
        final amount = foodMap['amount'] ?? 1;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.restaurant,
                  color: Colors.orange,
                  size: 20,
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
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$calories kcal',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${amount}份',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}