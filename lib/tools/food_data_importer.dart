import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Firebase 食物資料批次導入工具
/// 
/// 使用方式:
/// 1. 將此檔案放在專案的 lib/tools/ 目錄下
/// 2. 將 standardized_foods.json 放在 assets/ 目錄
/// 3. 在 pubspec.yaml 中加入 assets 設定
/// 4. 在 main.dart 中暫時呼叫 importFoodData() 函數
/// 5. 執行 app 一次即可完成導入
class FoodDataImporter {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 批次導入食物資料
  Future<void> importFoodData() async {
    print('🚀 開始導入食物資料...');
    
    try {
      // 從 assets 讀取 JSON 檔案
      print('📖 正在讀取 assets/standardized_foods.json...');
      final jsonString = await rootBundle.loadString('assets/standardized_foods.json');
      final List<dynamic> foodsData = json.decode(jsonString);
      
      print('📊 共 ${foodsData.length} 筆資料待導入');

      // 檢查是否已有資料
      final existingDocs = await _firestore
          .collection('foods')
          .where('createdBy', isEqualTo: 'system')
          .get();
      
      if (existingDocs.docs.isNotEmpty) {
        print('⚠️  發現 ${existingDocs.docs.length} 筆系統食物資料');
        print('   是否要清除舊資料? (建議先備份)');
        // 這裡可以加入確認邏輯
      }

      // 批次寫入 (每次最多 500 筆)
      int batchSize = 500;
      int totalBatches = (foodsData.length / batchSize).ceil();
      int successCount = 0;
      int failCount = 0;

      for (int i = 0; i < totalBatches; i++) {
        int start = i * batchSize;
        int end = (start + batchSize < foodsData.length) 
            ? start + batchSize 
            : foodsData.length;
        
        List<dynamic> batch = foodsData.sublist(start, end);
        
        print('\n📦 處理批次 ${i + 1}/$totalBatches (${batch.length} 筆)');
        
        WriteBatch writeBatch = _firestore.batch();
        
        for (var foodData in batch) {
          try {
            // 建立新文件參考
            DocumentReference docRef = _firestore.collection('foods').doc();
            
            // 準備資料
            Map<String, dynamic> data = {
              'name': foodData['name'],
              'category': foodData['category'],
              'servingSize': foodData['servingSize'],
              'servingSizeGram': foodData['servingSizeGram'],
              'calories': foodData['calories'],
              'protein': foodData['protein'],
              'carbs': foodData['carbs'],
              'fat': foodData['fat'],
              'fiber': foodData['fiber'] ?? 0.0,
              'isPublic': true,
              'createdBy': 'system',
              'mealTags': foodData['mealTags'] ?? [],
              'source': foodData['source'] ?? '',
              'createdAt': FieldValue.serverTimestamp(),
            };
            
            writeBatch.set(docRef, data);
            successCount++;
            
          } catch (e) {
            print('  ❌ 處理失敗: ${foodData['name']} - $e');
            failCount++;
          }
        }
        
        // 提交批次
        try {
          await writeBatch.commit();
          print('  ✅ 批次 ${i + 1} 提交成功');
        } catch (e) {
          print('  ❌ 批次 ${i + 1} 提交失敗: $e');
          failCount += batch.length;
          successCount -= batch.length;
        }
        
        // 避免過快請求
        if (i < totalBatches - 1) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      print('\n' + '=' * 60);
      print('🎉 導入完成!');
      print('=' * 60);
      print('✅ 成功: $successCount 筆');
      if (failCount > 0) {
        print('❌ 失敗: $failCount 筆');
      }
      print('=' * 60);

      // 驗證導入結果
      await _verifyImport();

    } catch (e) {
      print('❌ 導入過程發生錯誤: $e');
      print('   請確認:');
      print('   1. standardized_foods.json 在 assets/ 目錄');
      print('   2. pubspec.yaml 中有設定 assets');
      print('   3. 執行過 flutter pub get');
    }
  }

  /// 驗證導入結果
  Future<void> _verifyImport() async {
    print('\n🔍 驗證導入結果...');
    
    try {
      // 統計各類別食物數量
      QuerySnapshot allFoods = await _firestore
          .collection('foods')
          .where('createdBy', isEqualTo: 'system')
          .get();
      
      print('📊 總計: ${allFoods.docs.length} 筆系統食物');
      
      // 按類別統計
      Map<String, int> categoryCount = {};
      for (var doc in allFoods.docs) {
        String category = doc.get('category') ?? '未分類';
        categoryCount[category] = (categoryCount[category] ?? 0) + 1;
      }
      
      print('\n📋 分類明細:');
      categoryCount.forEach((category, count) {
        print('  $category: $count 筆');
      });
      
      // 隨機檢查幾筆資料
      if (allFoods.docs.isNotEmpty) {
        print('\n🔎 隨機檢查資料:');
        var randomDocs = allFoods.docs.take(3);
        for (var doc in randomDocs) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          print('  ✓ ${data['name']} - ${data['calories']} kcal');
        }
      }
      
    } catch (e) {
      print('❌ 驗證失敗: $e');
    }
  }

  /// 清除所有系統食物資料 (謹慎使用!)
  Future<void> clearSystemFoods() async {
    print('🗑️  開始清除系統食物資料...');
    
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('foods')
          .where('createdBy', isEqualTo: 'system')
          .get();
      
      if (snapshot.docs.isEmpty) {
        print('   沒有需要清除的資料');
        return;
      }
      
      print('   找到 ${snapshot.docs.length} 筆資料');
      
      // 批次刪除
      int deleted = 0;
      WriteBatch batch = _firestore.batch();
      
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
        deleted++;
        
        // 每 500 筆提交一次
        if (deleted % 500 == 0) {
          await batch.commit();
          batch = _firestore.batch();
          print('   已刪除 $deleted 筆...');
        }
      }
      
      // 提交剩餘的
      if (deleted % 500 != 0) {
        await batch.commit();
      }
      
      print('✅ 清除完成,共刪除 $deleted 筆資料');
      
    } catch (e) {
      print('❌ 清除失敗: $e');
    }
  }
}