// lib/pages/debug/firebase_food_debug_page.dart
// 🔍 Firebase 食物資料診斷頁面

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/food_database_service.dart';

class FirebaseFoodDebugPage extends StatefulWidget {
  const FirebaseFoodDebugPage({super.key});

  @override
  State<FirebaseFoodDebugPage> createState() => _FirebaseFoodDebugPageState();
}

class _FirebaseFoodDebugPageState extends State<FirebaseFoodDebugPage> {
  final FoodDatabaseService _foodService = FoodDatabaseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<Map<String, dynamic>> _foods = [];
  bool _isLoading = true;
  String _errorMessage = '';
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _runDiagnosis();
  }

  Future<void> _runDiagnosis() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // 1️⃣ 直接從 Firestore 獲取所有食物
      QuerySnapshot snapshot = await _firestore
          .collection('foods')
          .limit(10)
          .get();

      print('🔍 診斷: Firestore 食物總數: ${snapshot.docs.length}');

      List<Map<String, dynamic>> foods = [];
      Map<String, int> categoryCount = {};
      Map<String, int> fieldPresence = {
        'name': 0,
        'category': 0,
        'calories': 0,
        'protein': 0,
        'isPublic': 0,
        'servingSize': 0,
      };

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        foods.add(data);

        // 統計分類
        String category = data['category'] ?? '未分類';
        categoryCount[category] = (categoryCount[category] ?? 0) + 1;

        // 統計欄位存在情況
        fieldPresence.forEach((key, value) {
          if (data.containsKey(key)) {
            fieldPresence[key] = fieldPresence[key]! + 1;
          }
        });

        // 列印前3筆資料
        if (foods.length <= 3) {
          print('📝 食物 ${foods.length}: ${data['name']} (${data['category']})');
          print('   - calories: ${data['calories']}');
          print('   - isPublic: ${data['isPublic']}');
          print('   - servingSize: ${data['servingSize']}');
        }
      }

      // 2️⃣ 測試 getAllFoods()
      List<Map<String, dynamic>> serviceFoods = await _foodService.getAllFoods();
      print('🔍 FoodDatabaseService.getAllFoods() 返回: ${serviceFoods.length} 筆');

      // 3️⃣ 測試搜尋功能
      List<Map<String, dynamic>> searchResult = await _foodService.searchFoods('地');
      print('🔍 搜尋「地」返回: ${searchResult.length} 筆');

      setState(() {
        _foods = foods;
        _stats = {
          'total': snapshot.docs.length,
          'serviceTotal': serviceFoods.length,
          'searchResult': searchResult.length,
          'categories': categoryCount,
          'fields': fieldPresence,
        };
        _isLoading = false;
      });

    } catch (e) {
      print('❌ 診斷失敗: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔍 Firebase 資料診斷'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _runDiagnosis,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? _buildError()
              : _buildResults(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              '診斷失敗',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 統計資訊
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '📊 資料統計',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildStatRow('Firestore 總數', '${_stats['total']}'),
                _buildStatRow('Service 總數', '${_stats['serviceTotal']}'),
                _buildStatRow('搜尋「地」結果', '${_stats['searchResult']}'),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 分類統計
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🏷️ 分類統計',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...(_stats['categories'] as Map<String, int>).entries.map((e) =>
                    _buildStatRow(e.key, '${e.value} 筆'),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 欄位存在情況
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '📝 欄位存在情況',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...(_stats['fields'] as Map<String, int>).entries.map((e) =>
                    _buildStatRow(
                      e.key,
                      '${e.value}/${_stats['total']} (${(e.value / (_stats['total'] as int) * 100).toStringAsFixed(0)}%)',
                    ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 前10筆食物資料
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '📋 前10筆食物資料',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ..._foods.map((food) => _buildFoodItem(food)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodItem(Map<String, dynamic> food) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            food['name'] ?? '未知',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text('分類: ${food['category'] ?? '未知'}'),
          Text('熱量: ${food['calories'] ?? '未知'}'),
          Text('份量: ${food['servingSize'] ?? '未知'}'),
          Text('isPublic: ${food['isPublic'] ?? '無此欄位'}'),
        ],
      ),
    );
  }
}