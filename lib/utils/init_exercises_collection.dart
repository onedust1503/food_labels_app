// lib/utils/init_exercises_collection.dart
// 🔥 初始化系統動作庫 - 只需執行一次
// 可以在 App 啟動時檢查並初始化，或手動執行

import 'package:cloud_firestore/cloud_firestore.dart';

class ExercisesInitializer {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 檢查並初始化動作庫
  static Future<void> initializeIfNeeded() async {
    try {
      final snapshot = await _firestore.collection('exercises').limit(1).get();
      
      if (snapshot.docs.isEmpty) {
        print('🔥 動作庫為空，開始初始化...');
        await _initializeExercises();
        print('✅ 動作庫初始化完成！');
      } else {
        print('✅ 動作庫已存在，共 ${snapshot.docs.length}+ 筆');
      }
    } catch (e) {
      print('❌ 初始化動作庫失敗: $e');
    }
  }

  /// 初始化所有動作
  static Future<void> _initializeExercises() async {
    final batch = _firestore.batch();
    
    for (var exercise in _defaultExercises) {
      final docRef = _firestore.collection('exercises').doc();
      batch.set(docRef, {
        ...exercise,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    
    await batch.commit();
  }

  /// 預設動作列表
  static final List<Map<String, dynamic>> _defaultExercises = [
    // ========== 胸部 ==========
    {'name': '槓鈴臥推', 'category': '胸部', 'equipment': '槓鈴'},
    {'name': '啞鈴臥推', 'category': '胸部', 'equipment': '啞鈴'},
    {'name': '上斜槓鈴臥推', 'category': '胸部', 'equipment': '槓鈴'},
    {'name': '上斜啞鈴臥推', 'category': '胸部', 'equipment': '啞鈴'},
    {'name': '下斜臥推', 'category': '胸部', 'equipment': '槓鈴'},
    {'name': '啞鈴飛鳥', 'category': '胸部', 'equipment': '啞鈴'},
    {'name': '上斜啞鈴飛鳥', 'category': '胸部', 'equipment': '啞鈴'},
    {'name': '蝴蝶機夾胸', 'category': '胸部', 'equipment': '機械'},
    {'name': '龍門架夾胸', 'category': '胸部', 'equipment': '纜繩'},
    {'name': '胸推機', 'category': '胸部', 'equipment': '機械'},
    {'name': '伏地挺身', 'category': '胸部', 'equipment': '徒手'},
    {'name': '雙槓撐體', 'category': '胸部', 'equipment': '徒手'},
    
    // ========== 背部 ==========
    {'name': '引體向上', 'category': '背部', 'equipment': '徒手'},
    {'name': '滑輪下拉', 'category': '背部', 'equipment': '機械'},
    {'name': '寬握下拉', 'category': '背部', 'equipment': '機械'},
    {'name': '窄握下拉', 'category': '背部', 'equipment': '機械'},
    {'name': '槓鈴划船', 'category': '背部', 'equipment': '槓鈴'},
    {'name': '啞鈴划船', 'category': '背部', 'equipment': '啞鈴'},
    {'name': '單臂啞鈴划船', 'category': '背部', 'equipment': '啞鈴'},
    {'name': '坐姿划船', 'category': '背部', 'equipment': '機械'},
    {'name': 'T槓划船', 'category': '背部', 'equipment': '槓鈴'},
    {'name': '硬舉', 'category': '背部', 'equipment': '槓鈴'},
    {'name': '羅馬尼亞硬舉', 'category': '背部', 'equipment': '槓鈴'},
    {'name': '直臂下壓', 'category': '背部', 'equipment': '纜繩'},
    {'name': '背部伸展', 'category': '背部', 'equipment': '徒手'},
    
    // ========== 肩部 ==========
    {'name': '槓鈴肩推', 'category': '肩部', 'equipment': '槓鈴'},
    {'name': '啞鈴肩推', 'category': '肩部', 'equipment': '啞鈴'},
    {'name': '阿諾肩推', 'category': '肩部', 'equipment': '啞鈴'},
    {'name': '啞鈴側平舉', 'category': '肩部', 'equipment': '啞鈴'},
    {'name': '纜繩側平舉', 'category': '肩部', 'equipment': '纜繩'},
    {'name': '啞鈴前平舉', 'category': '肩部', 'equipment': '啞鈴'},
    {'name': '槓鈴前平舉', 'category': '肩部', 'equipment': '槓鈴'},
    {'name': '俯身啞鈴飛鳥', 'category': '肩部', 'equipment': '啞鈴'},
    {'name': '反向蝴蝶機', 'category': '肩部', 'equipment': '機械'},
    {'name': '面拉', 'category': '肩部', 'equipment': '纜繩'},
    {'name': '槓鈴聳肩', 'category': '肩部', 'equipment': '槓鈴'},
    {'name': '啞鈴聳肩', 'category': '肩部', 'equipment': '啞鈴'},
    
    // ========== 手臂 ==========
    {'name': '槓鈴彎舉', 'category': '手臂', 'equipment': '槓鈴'},
    {'name': '啞鈴彎舉', 'category': '手臂', 'equipment': '啞鈴'},
    {'name': '錘式彎舉', 'category': '手臂', 'equipment': '啞鈴'},
    {'name': '斜板彎舉', 'category': '手臂', 'equipment': '啞鈴'},
    {'name': '集中彎舉', 'category': '手臂', 'equipment': '啞鈴'},
    {'name': '纜繩彎舉', 'category': '手臂', 'equipment': '纜繩'},
    {'name': '窄握臥推', 'category': '手臂', 'equipment': '槓鈴'},
    {'name': '三頭肌下壓', 'category': '手臂', 'equipment': '纜繩'},
    {'name': '繩索下壓', 'category': '手臂', 'equipment': '纜繩'},
    {'name': '過頭三頭伸展', 'category': '手臂', 'equipment': '啞鈴'},
    {'name': '仰臥三頭伸展', 'category': '手臂', 'equipment': '槓鈴'},
    {'name': '啞鈴三頭後伸', 'category': '手臂', 'equipment': '啞鈴'},
    {'name': '腕彎舉', 'category': '手臂', 'equipment': '槓鈴'},
    
    // ========== 腿部 ==========
    {'name': '槓鈴深蹲', 'category': '腿部', 'equipment': '槓鈴'},
    {'name': '前蹲', 'category': '腿部', 'equipment': '槓鈴'},
    {'name': '高腳杯深蹲', 'category': '腿部', 'equipment': '啞鈴'},
    {'name': '腿推', 'category': '腿部', 'equipment': '機械'},
    {'name': '哈克深蹲', 'category': '腿部', 'equipment': '機械'},
    {'name': '弓步蹲', 'category': '腿部', 'equipment': '啞鈴'},
    {'name': '保加利亞分腿蹲', 'category': '腿部', 'equipment': '啞鈴'},
    {'name': '腿伸展', 'category': '腿部', 'equipment': '機械'},
    {'name': '腿彎舉', 'category': '腿部', 'equipment': '機械'},
    {'name': '站姿腿彎舉', 'category': '腿部', 'equipment': '機械'},
    {'name': '直腿硬舉', 'category': '腿部', 'equipment': '槓鈴'},
    {'name': '站姿提踵', 'category': '腿部', 'equipment': '機械'},
    {'name': '坐姿提踵', 'category': '腿部', 'equipment': '機械'},
    {'name': '腿內收', 'category': '腿部', 'equipment': '機械'},
    {'name': '腿外展', 'category': '腿部', 'equipment': '機械'},
    {'name': '臀推', 'category': '腿部', 'equipment': '槓鈴'},
    
    // ========== 核心 ==========
    {'name': '仰臥起坐', 'category': '核心', 'equipment': '徒手'},
    {'name': '捲腹', 'category': '核心', 'equipment': '徒手'},
    {'name': '反向捲腹', 'category': '核心', 'equipment': '徒手'},
    {'name': '平板支撐', 'category': '核心', 'equipment': '徒手'},
    {'name': '側平板', 'category': '核心', 'equipment': '徒手'},
    {'name': '懸吊抬腿', 'category': '核心', 'equipment': '徒手'},
    {'name': '羅馬椅抬腿', 'category': '核心', 'equipment': '機械'},
    {'name': '纜繩捲腹', 'category': '核心', 'equipment': '纜繩'},
    {'name': '俄羅斯轉體', 'category': '核心', 'equipment': '徒手'},
    {'name': '死蟲式', 'category': '核心', 'equipment': '徒手'},
    {'name': '登山者', 'category': '核心', 'equipment': '徒手'},
    {'name': '腹肌滾輪', 'category': '核心', 'equipment': '器材'},
    
    // ========== 有氧 ==========
    {'name': '跑步機', 'category': '有氧', 'equipment': '機械'},
    {'name': '橢圓機', 'category': '有氧', 'equipment': '機械'},
    {'name': '飛輪', 'category': '有氧', 'equipment': '機械'},
    {'name': '划船機', 'category': '有氧', 'equipment': '機械'},
    {'name': '登階機', 'category': '有氧', 'equipment': '機械'},
    {'name': '跳繩', 'category': '有氧', 'equipment': '器材'},
    {'name': '開合跳', 'category': '有氧', 'equipment': '徒手'},
    {'name': '波比跳', 'category': '有氧', 'equipment': '徒手'},
    {'name': '高抬腿', 'category': '有氧', 'equipment': '徒手'},
    {'name': '戰繩', 'category': '有氧', 'equipment': '器材'},
    
    // ========== 其他 ==========
    {'name': '農夫走路', 'category': '其他', 'equipment': '啞鈴'},
    {'name': '壺鈴擺盪', 'category': '其他', 'equipment': '壺鈴'},
    {'name': '土耳其起立', 'category': '其他', 'equipment': '壺鈴'},
    {'name': '抓舉', 'category': '其他', 'equipment': '槓鈴'},
    {'name': '挺舉', 'category': '其他', 'equipment': '槓鈴'},
    {'name': '上搏', 'category': '其他', 'equipment': '槓鈴'},
  ];
}