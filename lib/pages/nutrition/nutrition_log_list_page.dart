// lib/pages/nutrition/nutrition_log_list_page.dart
// Soft UI 風格的今日飲食記錄列表頁面 - 包含宵夜支援

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_colors.dart';
import '../../widgets/nutrition/soft_card.dart';

class NutritionLogListPage extends StatefulWidget {
  const NutritionLogListPage({super.key});

  @override
  State<NutritionLogListPage> createState() => _NutritionLogListPageState();
}

class _NutritionLogListPageState extends State<NutritionLogListPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    String userId = _auth.currentUser!.uid;
    String today = DateTime.now().toIso8601String().split('T')[0];

    return Scaffold(
      backgroundColor: AppColors.background,
      
      // 🎨 Soft UI 風格的 AppBar
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadowLight,
                  offset: const Offset(0, 2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              size: 18,
              color: AppColors.textPrimary,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '今日飲食記錄',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('nutritionLogs')
            .where('userId', isEqualTo: userId)
            .where('date', isEqualTo: today)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState();
          }

          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          // 🌙 按餐別分組 (包含宵夜)
          Map<String, List<QueryDocumentSnapshot>> groupedLogs = {
            'breakfast': [],
            'lunch': [],
            'dinner': [],
            'snack': [],
            'latenight': [],  // 🌙 新增宵夜
          };

          for (var doc in snapshot.data!.docs) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            String mealType = (data['mealType'] ?? 'snack').toLowerCase();
            
            // 🌙 處理可能的 late_night 格式
            if (mealType == 'late_night') {
              mealType = 'latenight';
            }
            
            if (groupedLogs.containsKey(mealType)) {
              groupedLogs[mealType]!.add(doc);
            }
          }

          // 計算總營養
          double totalCalories = 0;
          double totalProtein = 0;
          double totalCarbs = 0;
          double totalFat = 0;

          for (var doc in snapshot.data!.docs) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            totalCalories += (data['calories'] ?? 0);
            totalProtein += (data['protein'] ?? 0);
            totalCarbs += (data['carbs'] ?? 0);
            totalFat += (data['fat'] ?? 0);
          }

          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              // 📊 每日營養總覽
              _buildDailySummary(
                totalCalories,
                totalProtein,
                totalCarbs,
                totalFat,
              )
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.2, end: 0, duration: 400.ms),
              
              const SizedBox(height: 24),

              // 🍽️ 各餐別記錄
              _buildMealSection('早餐', 'breakfast', groupedLogs['breakfast']!)
                  .animate(delay: 100.ms)
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.2, end: 0, duration: 400.ms),
              
              _buildMealSection('午餐', 'lunch', groupedLogs['lunch']!)
                  .animate(delay: 150.ms)
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.2, end: 0, duration: 400.ms),
              
              _buildMealSection('晚餐', 'dinner', groupedLogs['dinner']!)
                  .animate(delay: 200.ms)
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.2, end: 0, duration: 400.ms),
              
              _buildMealSection('點心', 'snack', groupedLogs['snack']!)
                  .animate(delay: 250.ms)
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.2, end: 0, duration: 400.ms),
              
              // 🌙 宵夜區塊
              _buildMealSection('宵夜', 'latenight', groupedLogs['latenight']!)
                  .animate(delay: 300.ms)
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.2, end: 0, duration: 400.ms),

              const SizedBox(height: 100),
            ],
          );
        },
      ),
    );
  }

  /// 📊 每日營養總覽卡片
  Widget _buildDailySummary(
    double calories,
    double protein,
    double carbs,
    double fat,
  ) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.8),
                      AppColors.primaryLight,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.analytics,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '今日攝取總計',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 營養數據網格
          Row(
            children: [
              Expanded(
                child: _buildNutrientBox(
                  '熱量',
                  calories.toInt().toString(),
                  '大卡',
                  AppColors.calories,
                  Icons.local_fire_department,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildNutrientBox(
                  '蛋白質',
                  protein.toStringAsFixed(1),
                  'g',
                  AppColors.protein,
                  Icons.fitness_center,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildNutrientBox(
                  '碳水',
                  carbs.toStringAsFixed(1),
                  'g',
                  AppColors.carbs,
                  Icons.grain,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildNutrientBox(
                  '脂肪',
                  fat.toStringAsFixed(1),
                  'g',
                  AppColors.fat,
                  Icons.water_drop,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 營養數據小方塊
  Widget _buildNutrientBox(
    String label,
    String value,
    String unit,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 🍽️ 餐別區塊
  Widget _buildMealSection(
    String title,
    String mealType,
    List<QueryDocumentSnapshot> logs,
  ) {
    if (logs.isEmpty) return const SizedBox.shrink();

    // 計算該餐總熱量
    double totalCalories = logs.fold(0, (sum, doc) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      return sum + (data['calories'] ?? 0);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 餐別標題
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Text(
                AppColors.getMealEmoji(mealType),
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.getMealLightColor(mealType),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${totalCalories.toInt()} 大卡',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getMealColor(mealType),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 食物記錄列表
        ...logs.map((doc) => _buildFoodLogCard(doc, mealType)),
        
        const SizedBox(height: 16),
      ],
    );
  }

  /// 🍱 單筆食物記錄卡片
  Widget _buildFoodLogCard(QueryDocumentSnapshot doc, String mealType) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    String foodName = data['foodName'] ?? '未知食物';
    double servings = (data['servings'] ?? 1).toDouble();
    String servingSize = data['servingSize'] ?? '份';
    int calories = (data['calories'] ?? 0).toInt();
    double protein = (data['protein'] ?? 0).toDouble();
    double carbs = (data['carbs'] ?? 0).toDouble();
    double fat = (data['fat'] ?? 0).toDouble();
    
    String timeStr = _formatTime(data['createdAt']);

    return SoftCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // 左側顏色條
          Container(
            width: 4,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.getMealColor(mealType),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 16),

          // 食物資訊
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        foodName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      timeStr,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                
                // 份量和熱量
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryPale,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${servings.toStringAsFixed(1)} $servingSize',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.local_fire_department,
                      size: 14,
                      color: AppColors.calories,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$calories 大卡',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                
                // 三大營養素
                Row(
                  children: [
                    _buildMiniNutrient('P', protein, AppColors.protein),
                    const SizedBox(width: 8),
                    _buildMiniNutrient('C', carbs, AppColors.carbs),
                    const SizedBox(width: 8),
                    _buildMiniNutrient('F', fat, AppColors.fat),
                  ],
                ),
              ],
            ),
          ),

          // 刪除按鈕
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              color: AppColors.error,
              size: 20,
            ),
            onPressed: () => _confirmDelete(doc),
          ),
        ],
      ),
    );
  }

  /// 小型營養素標籤
  Widget _buildMiniNutrient(String label, double value, Color color) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(width: 2),
        Text(
          value.toStringAsFixed(1),
          style: TextStyle(
            fontSize: 10,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }

  /// 🕐 時間格式化
  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '--:--';
    
    try {
      DateTime dateTime;
      if (timestamp is Timestamp) {
        dateTime = timestamp.toDate();
      } else if (timestamp is DateTime) {
        dateTime = timestamp;
      } else {
        return '--:--';
      }
      
      return DateFormat('HH:mm').format(dateTime);
    } catch (e) {
      return '--:--';
    }
  }

  /// 🔄 載入中狀態
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadowLight,
                  offset: const Offset(0, 4),
                  blurRadius: 12,
                ),
              ],
            ),
            child: const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '載入中...',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// ⚠️ 錯誤狀態
  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: SoftCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: AppColors.error,
              ),
              const SizedBox(height: 16),
              const Text(
                '載入失敗',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 📭 空狀態
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withOpacity(0.1),
                    AppColors.primaryLight.withOpacity(0.05),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.restaurant_menu,
                size: 80,
                color: AppColors.primary.withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '今日尚無飲食記錄',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '開始記錄你的飲食\n養成健康的飲食習慣',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ❌ 確認刪除對話框
  void _confirmDelete(QueryDocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    String foodName = data['foodName'] ?? '此記錄';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('確認刪除'),
        content: Text('確定要刪除「$foodName」嗎?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteLog(doc);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
  }

  /// 🗑️ 刪除記錄
  Future<void> _deleteLog(QueryDocumentSnapshot doc) async {
    try {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      String userId = _auth.currentUser!.uid;
      String today = DateTime.now().toIso8601String().split('T')[0];

      await doc.reference.delete();

      // 更新每日總計
      DocumentReference summaryRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('dailySummary')
          .doc(today);

      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(summaryRef);

        if (snapshot.exists) {
          Map<String, dynamic> summaryData = snapshot.data() as Map<String, dynamic>;
          
          transaction.update(summaryRef, {
            'totalCalories': (summaryData['totalCalories'] ?? 0) - (data['calories'] ?? 0),
            'totalProtein': (summaryData['totalProtein'] ?? 0) - (data['protein'] ?? 0),
            'totalCarbs': (summaryData['totalCarbs'] ?? 0) - (data['carbs'] ?? 0),
            'totalFat': (summaryData['totalFat'] ?? 0) - (data['fat'] ?? 0),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text('已刪除記錄'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('刪除記錄失敗: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('刪除失敗: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }
}