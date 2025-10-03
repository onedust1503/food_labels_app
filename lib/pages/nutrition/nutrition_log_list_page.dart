import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

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
      appBar: AppBar(
        title: const Text('今日飲食記錄'),
        backgroundColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
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
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('載入失敗: ${snapshot.error}'),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.restaurant_menu, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    '今日尚無飲食記錄',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          // 按餐別分組
          Map<String, List<QueryDocumentSnapshot>> groupedLogs = {
            'breakfast': [],
            'lunch': [],
            'dinner': [],
            'snack': [],
          };

          for (var doc in snapshot.data!.docs) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            String mealType = data['mealType'] ?? 'snack';
            groupedLogs[mealType]?.add(doc);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildMealSection('早餐', 'breakfast', groupedLogs['breakfast']!),
              _buildMealSection('午餐', 'lunch', groupedLogs['lunch']!),
              _buildMealSection('晚餐', 'dinner', groupedLogs['dinner']!),
              _buildMealSection('點心', 'snack', groupedLogs['snack']!),
            ],
          );
        },
      ),
    );
  }

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
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${totalCalories.toInt()} 大卡',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
        ...logs.map((doc) => _buildLogCard(doc)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildLogCard(QueryDocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    String foodName = data['foodName'] ?? '未知食物';
    double servings = (data['servings'] ?? 1).toDouble();
    String servingSize = data['servingSize'] ?? '';
    int calories = (data['calories'] ?? 0).toInt();
    double protein = (data['protein'] ?? 0).toDouble();
    double carbs = (data['carbs'] ?? 0).toDouble();
    double fat = (data['fat'] ?? 0).toDouble();
    
    Timestamp? timestamp = data['createdAt'] as Timestamp?;
    String timeStr = timestamp != null 
        ? DateFormat('HH:mm').format(timestamp.toDate())
        : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        foodName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (timeStr.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${servings.toStringAsFixed(1)} $servingSize',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildNutrientChip('$calories 大卡', Colors.orange),
                      const SizedBox(width: 8),
                      _buildNutrientChip('蛋白 ${protein.toStringAsFixed(1)}g', Colors.green),
                      const SizedBox(width: 8),
                      _buildNutrientChip('碳水 ${carbs.toStringAsFixed(1)}g', Colors.red),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _confirmDelete(doc),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutrientChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _confirmDelete(QueryDocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    String foodName = data['foodName'] ?? '此記錄';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認刪除'),
        content: Text('確定要刪除「$foodName」嗎？'),
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
              backgroundColor: Colors.red,
            ),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteLog(QueryDocumentSnapshot doc) async {
    try {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      String userId = _auth.currentUser!.uid;
      String today = DateTime.now().toIso8601String().split('T')[0];

      // 刪除記錄
      await doc.reference.delete();

      // 更新每日總計（減去刪除的數值）
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
          const SnackBar(
            content: Text('已刪除記錄'),
            backgroundColor: Colors.green,
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
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}