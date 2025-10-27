// lib/pages/coach/trainee_nutrition_tab.dart
// 學員飲食日誌分頁 - 修正型別錯誤版本

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
          .collection('nutritionLogs')
          .where('userId', isEqualTo: traineeId)
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
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
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
            
            // ✅ 處理日期欄位
            DateTime date;
            if (log['date'] is Timestamp) {
              date = (log['date'] as Timestamp).toDate();
            } else if (log['date'] is String) {
              try {
                date = DateTime.parse(log['date'] as String);
              } catch (e) {
                date = DateTime.now();
              }
            } else {
              date = DateTime.now();
            }
            
            // ✅ 修正：明確處理數值型別轉換
            final calories = _toInt(log['calories']);
            final protein = _toDouble(log['protein']);
            final carbs = _toDouble(log['carbs']);
            final fat = _toDouble(log['fat']);
            final foodName = log['foodName']?.toString() ?? '未命名食物';
            final mealType = log['mealType']?.toString() ?? '';
            
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
                          color: _getCalorieColor(calories).withOpacity(0.1),
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
                                color: _getCalorieColor(calories),
                              ),
                            ),
                            Text(
                              '${date.month}月',
                              style: TextStyle(
                                fontSize: 12,
                                color: _getCalorieColor(calories),
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
                            // 食物名稱
                            Text(
                              foodName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            // 餐別（如果有）
                            if (mealType.isNotEmpty) ...[
                              Text(
                                _getMealTypeText(mealType),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            Row(
                              children: [
                                const Icon(
                                  Icons.local_fire_department,
                                  size: 18,
                                  color: Colors.orange,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$calories kcal',
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

  // ✅ 修正：型別轉換輔助方法
  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  // 建立營養素標籤
  Widget _buildNutrientChip(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label ${value.toStringAsFixed(1)}g',
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
    if (calories < 100) {
      return Colors.green;
    } else if (calories < 300) {
      return Colors.blue;
    } else if (calories < 500) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  // 取得餐別文字
  String _getMealTypeText(String mealType) {
    switch (mealType) {
      case 'breakfast':
        return '早餐';
      case 'lunch':
        return '午餐';
      case 'dinner':
        return '晚餐';
      case 'snack':
        return '點心';
      default:
        return mealType;
    }
  }

  // 顯示飲食詳情
  void _showNutritionDetail(
    BuildContext context,
    Map<String, dynamic> log,
    DateTime date,
  ) {
    // ✅ 修正：型別轉換
    final calories = _toInt(log['calories']);
    final protein = _toDouble(log['protein']);
    final carbs = _toDouble(log['carbs']);
    final fat = _toDouble(log['fat']);
    final foodName = log['foodName']?.toString() ?? '未命名食物';
    final mealType = log['mealType']?.toString() ?? '';
    final servingSize = log['servingSize']?.toString() ?? '';
    final servings = _toInt(log['servings']);

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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  foodName,
                                  style: const TextStyle(
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
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // 餐別標籤
                      if (mealType.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _getMealTypeText(mealType),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // 營養總覽
                      _buildNutritionSummary(
                        calories,
                        protein,
                        carbs,
                        fat,
                      ),
                      const SizedBox(height: 24),

                      // 份量資訊
                      if (servingSize.isNotEmpty || servings > 0) ...[
                        const Text(
                          '份量資訊',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (servingSize.isNotEmpty)
                                Text(
                                  '份量：$servingSize',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              if (servings > 0)
                                Text(
                                  '數量：$servings 份',
                                  style: const TextStyle(fontSize: 14),
                                ),
                            ],
                          ),
                        ),
                      ],
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
    int calories,
    double protein,
    double carbs,
    double fat,
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
          _buildNutritionItem('熱量', '$calories', 'kcal'),
          _buildDivider(),
          _buildNutritionItem('蛋白質', '${protein.toStringAsFixed(1)}', 'g'),
          _buildDivider(),
          _buildNutritionItem('碳水', '${carbs.toStringAsFixed(1)}', 'g'),
          _buildDivider(),
          _buildNutritionItem('脂肪', '${fat.toStringAsFixed(1)}', 'g'),
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
}