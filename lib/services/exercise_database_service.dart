// lib/services/exercise_database_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ExerciseDatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 初始化運動資料庫(只執行一次)
  Future<void> initializeExerciseDatabase() async {
    // 檢查是否已存在
    QuerySnapshot existing = await _firestore.collection('exercises').limit(1).get();
    if (existing.docs.isNotEmpty) {
      print('運動資料庫已存在');
      return;
    }

    print('開始初始化運動資料庫...');

    List<Map<String, dynamic>> exercises = [
      // 胸部運動
      {
        'name': '啞鈴飛鳥',
        'type': 'weight_training',
        'primaryMuscleGroup': '胸部',
        'targetMuscles': ['上胸肌', '中胸肌'],
        'difficulty': 'intermediate',
        'equipment': '啞鈴',
      },
      {
        'name': '臥推',
        'type': 'weight_training',
        'primaryMuscleGroup': '胸部',
        'targetMuscles': ['胸大肌', '三角肌前束', '肱三頭肌'],
        'difficulty': 'beginner',
        'equipment': '槓鈴',
      },

      // 背部運動
      {
        'name': '硬舉',
        'type': 'weight_training',
        'primaryMuscleGroup': '背部',
        'targetMuscles': ['下背部', '腿後肌', '臀部'],
        'difficulty': 'advanced',
        'equipment': '槓鈴',
      },
      {
        'name': '引體向上',
        'type': 'weight_training',
        'primaryMuscleGroup': '背部',
        'targetMuscles': ['背闊肌', '二頭肌'],
        'difficulty': 'intermediate',
        'equipment': '單槓',
      },
      {
        'name': '槓鈴划船',
        'type': 'weight_training',
        'primaryMuscleGroup': '背部',
        'targetMuscles': ['背闊肌', '菱形肌'],
        'difficulty': 'intermediate',
        'equipment': '槓鈴',
      },

      // 腿部運動
      {
        'name': '深蹲',
        'type': 'weight_training',
        'primaryMuscleGroup': '腿部',
        'targetMuscles': ['股四頭肌', '臀部', '腿後肌'],
        'difficulty': 'beginner',
        'equipment': '槓鈴',
      },
      {
        'name': '腿推',
        'type': 'weight_training',
        'primaryMuscleGroup': '腿部',
        'targetMuscles': ['股四頭肌', '臀部'],
        'difficulty': 'beginner',
        'equipment': '器械',
      },

      // 肩部運動
      {
        'name': '肩推',
        'type': 'weight_training',
        'primaryMuscleGroup': '肩部',
        'targetMuscles': ['三角肌', '肱三頭肌'],
        'difficulty': 'beginner',
        'equipment': '啞鈴',
      },

      // 有氧運動
      {
        'name': '跑步',
        'type': 'cardio',
        'primaryMuscleGroup': '全身',
        'targetMuscles': ['心肺功能', '腿部'],
        'difficulty': 'beginner',
        'equipment': '跑步機',
      },
    ];

    // 批次寫入
    WriteBatch batch = _firestore.batch();
    for (var exercise in exercises) {
      DocumentReference docRef = _firestore.collection('exercises').doc();
      batch.set(docRef, {
        ...exercise,
        'createdAt': FieldValue.serverTimestamp(),
        'isPublic': true,
      });
    }

    await batch.commit();
    print('運動資料庫初始化完成!共新增 ${exercises.length} 項運動');
  }

  // 搜尋運動
  Future<List<Map<String, dynamic>>> searchExercises(String query) async {
    if (query.isEmpty) return [];

    QuerySnapshot snapshot = await _firestore
        .collection('exercises')
        .where('isPublic', isEqualTo: true)
        .get();

    // 客戶端過濾(Firestore不支援 LIKE 查詢)
    List<Map<String, dynamic>> results = [];
    for (var doc in snapshot.docs) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      if (data['name'].toString().contains(query)) {
        results.add({
          ...data,
          'id': doc.id,
        });
      }
    }

    return results;
  }

  // 根據肌群篩選
  Future<List<Map<String, dynamic>>> getExercisesByMuscleGroup(String muscleGroup) async {
    QuerySnapshot snapshot = await _firestore
        .collection('exercises')
        .where('primaryMuscleGroup', isEqualTo: muscleGroup)
        .where('isPublic', isEqualTo: true)
        .get();

    return snapshot.docs.map((doc) {
      return {
        ...(doc.data() as Map<String, dynamic>),
        'id': doc.id,
      };
    }).toList();
  }
}