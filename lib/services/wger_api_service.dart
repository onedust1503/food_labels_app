// lib/services/wger_api_service.dart
// 🔧 WGER API 服務 - 修正版：優先使用離線資料庫

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class Exercise {
  final int id;
  final String name;
  final String nameZhTw;
  final String category;
  final String? description;
  final List<String> muscles;
  final String? equipment;

  Exercise({
    required this.id,
    required this.name,
    required this.nameZhTw,
    required this.category,
    this.description,
    required this.muscles,
    this.equipment,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'],
      name: json['name'] ?? '',
      nameZhTw: json['nameZhTw'] ?? json['name'] ?? '',
      category: json['category']?.toString() ?? '',
      description: json['description'],
      muscles: (json['muscles'] as List?)?.map((e) => e.toString()).toList() ?? [],
      equipment: json['equipment']?.toString(),
    );
  }
  
  @override
  String toString() {
    return 'Exercise(id: $id, name: $name, nameZhTw: $nameZhTw, category: $category)';
  }
}

class WgerApiService {
  static const String baseUrl = 'https://wger.de/api/v2';
  static const int timeoutSeconds = 5; // 🔧 縮短超時時間
  
  // 🔧 新增：控制是否使用離線模式
  static const bool _forceOfflineMode = true; // 設為 true 強制使用離線資料

  // 英文到繁體中文的運動分類翻譯
  static const Map<String, String> _categoryTranslations = {
    'Abs': '腹肌',
    'Arms': '手臂',
    'Back': '背部',
    'Calves': '小腿',
    'Chest': '胸部',
    'Legs': '腿部',
    'Shoulders': '肩膀',
    'Cardio': '有氧',
    '8': '手臂',
    '9': '腿部',
    '10': '腹肌',
    '11': '胸部',
    '12': '背部',
    '13': '肩膀',
    '14': '小腿',
    '15': '有氧',
  };

  // 英文到繁體中文的肌肉群翻譯
  static const Map<String, String> _muscleTranslations = {
    'Biceps': '二頭肌',
    'Triceps': '三頭肌',
    'Shoulders': '肩膀',
    'Chest': '胸部',
    'Back': '背部',
    'Abs': '腹肌',
    'Quads': '股四頭肌',
    'Hamstrings': '腿後肌',
    'Glutes': '臀部',
    'Calves': '小腿',
    'Forearms': '前臂',
    'Lats': '背闊肌',
    'Lower Back': '下背部',
    '1': '二頭肌',
    '2': '前三角肌',
    '3': '胸部',
    '4': '背闊肌',
    '5': '三頭肌',
    '6': '腹肌',
    '7': '臀部',
    '8': '股四頭肌',
    '9': '腿後肌',
    '10': '小腿',
    '11': '前臂',
    '12': '斜方肌',
    '13': '下背部',
  };

  /// 獲取所有運動（帶分頁）
  Future<List<Exercise>> getExercises({int page = 1, int limit = 50}) async {
    // 🔧 如果強制離線模式，直接返回離線數據
    if (_forceOfflineMode) {
      if (kDebugMode) {
        debugPrint('📦 使用離線資料庫（強制離線模式）');
      }
      await Future.delayed(const Duration(milliseconds: 500)); // 模擬載入
      return _getOfflineExercises();
    }

    try {
      if (kDebugMode) {
        debugPrint('🌐 嘗試從 WGER API 載入運動...');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/exercise/?language=2&limit=$limit&offset=${(page - 1) * limit}'),
        headers: {'Accept': 'application/json'},
      ).timeout(Duration(seconds: timeoutSeconds));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final results = data['results'] as List;
        
        if (kDebugMode) {
          debugPrint('✅ API 返回 ${results.length} 個運動');
        }
        
        if (results.isEmpty) {
          if (kDebugMode) {
            debugPrint('⚠️ API 返回空列表，使用離線資料');
          }
          return _getOfflineExercises();
        }
        
        final exercises = results.map((json) {
          return _parseExercise(json);
        }).where((exercise) {
          return exercise.nameZhTw.isNotEmpty;
        }).toList();
        
        if (exercises.isEmpty) {
          if (kDebugMode) {
            debugPrint('⚠️ 解析後無有效運動，使用離線資料');
          }
          return _getOfflineExercises();
        }
        
        return exercises;
      } else {
        if (kDebugMode) {
          debugPrint('⚠️ API 返回錯誤: ${response.statusCode}');
        }
        return _getOfflineExercises();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ API 載入失敗: $e');
        debugPrint('📦 使用離線資料庫');
      }
      return _getOfflineExercises();
    }
  }

  /// 搜尋運動
  Future<List<Exercise>> searchExercises(String query) async {
    if (_forceOfflineMode) {
      return _searchOfflineExercises(query);
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/exercise/search/?term=$query&language=2'),
        headers: {'Accept': 'application/json'},
      ).timeout(Duration(seconds: timeoutSeconds));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final suggestions = data['suggestions'] as List;
        
        return suggestions.map((json) {
          return _parseExercise(json['data']);
        }).where((exercise) => exercise.nameZhTw.isNotEmpty).toList();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 搜尋失敗: $e');
      }
    }
    return _searchOfflineExercises(query);
  }

  /// 根據分類獲取運動
  Future<List<Exercise>> getExercisesByCategory(String category) async {
    if (_forceOfflineMode) {
      return _getOfflineExercisesByCategory(category);
    }

    try {
      final categoryId = _getCategoryId(category);
      final response = await http.get(
        Uri.parse('$baseUrl/exercise/?language=2&category=$categoryId&limit=100'),
        headers: {'Accept': 'application/json'},
      ).timeout(Duration(seconds: timeoutSeconds));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final results = data['results'] as List;
        
        return results.map((json) => _parseExercise(json))
            .where((exercise) => exercise.nameZhTw.isNotEmpty)
            .toList();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 分類載入失敗: $e');
      }
    }
    return _getOfflineExercisesByCategory(category);
  }

  /// 解析運動資料
  Exercise _parseExercise(Map<String, dynamic> json) {
    String name = (json['name'] ?? '').toString().trim();
    String category = (json['category'] ?? '').toString().trim();
    
    String nameZhTw = _translateExerciseName(name);
    String categoryZhTw = _translateCategory(category);
    
    List<String> muscles = [];
    if (json['muscles'] != null && json['muscles'] is List) {
      muscles = (json['muscles'] as List)
          .map((e) => _translateMuscle(e.toString()))
          .toList();
    }
    
    return Exercise(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: name,
      nameZhTw: nameZhTw,
      category: categoryZhTw,
      description: json['description']?.toString(),
      muscles: muscles,
      equipment: json['equipment']?.toString(),
    );
  }

  /// 翻譯運動名稱
  String _translateExerciseName(String name) {
    if (name.isEmpty) return '';
    
    // 常見運動翻譯表
    const translations = {
      'Bench Press': '臥推', 'Push-ups': '伏地挺身', 'Dumbbell Fly': '啞鈴飛鳥',
      'Pull-ups': '引體向上', 'Deadlift': '硬舉', 'Barbell Row': '槓鈴划船',
      'Squat': '深蹲', 'Leg Press': '腿推', 'Lunges': '弓箭步',
      'Shoulder Press': '肩推', 'Lateral Raise': '側平舉',
      'Bicep Curl': '二頭彎舉', 'Tricep Extension': '三頭伸展',
      'Crunches': '捲腹', 'Plank': '棒式',
      'Running': '跑步', 'Cycling': '騎自行車', 'Swimming': '游泳',
    };
    
    return translations[name] ?? name;
  }

  String _translateCategory(String category) {
    if (category.isEmpty) return '其他';
    return _categoryTranslations[category] ?? category;
  }

  String _translateMuscle(String muscle) {
    if (muscle.isEmpty) return '';
    return _muscleTranslations[muscle] ?? muscle;
  }

  int _getCategoryId(String category) {
    const ids = {
      '腹肌': 10, '手臂': 8, '背部': 12, '小腿': 14,
      '胸部': 11, '腿部': 9, '肩膀': 13, '有氧': 15,
    };
    return ids[category] ?? 10;
  }

  /// 🔧 擴充的離線運動資料庫（50個運動）
  List<Exercise> _getOfflineExercises() {
    return [
      // 胸部 (8個)
      Exercise(id: 1, name: 'Bench Press', nameZhTw: '臥推', category: '胸部', muscles: ['胸部', '三頭肌'], description: '平躺臥推'),
      Exercise(id: 2, name: 'Push-ups', nameZhTw: '伏地挺身', category: '胸部', muscles: ['胸部', '三頭肌'], description: '徒手胸部訓練'),
      Exercise(id: 3, name: 'Incline Bench Press', nameZhTw: '上斜臥推', category: '胸部', muscles: ['胸部'], description: '上斜臥推'),
      Exercise(id: 4, name: 'Decline Bench Press', nameZhTw: '下斜臥推', category: '胸部', muscles: ['胸部'], description: '下斜臥推'),
      Exercise(id: 5, name: 'Dumbbell Fly', nameZhTw: '啞鈴飛鳥', category: '胸部', muscles: ['胸部'], description: '啞鈴飛鳥'),
      Exercise(id: 6, name: 'Cable Crossover', nameZhTw: '繩索飛鳥', category: '胸部', muscles: ['胸部'], description: '繩索飛鳥'),
      Exercise(id: 7, name: 'Chest Dips', nameZhTw: '胸部撐體', category: '胸部', muscles: ['胸部', '三頭肌'], description: '雙槓撐體'),
      Exercise(id: 8, name: 'Chest Press Machine', nameZhTw: '胸推機', category: '胸部', muscles: ['胸部'], description: '器械胸推'),
      
      // 背部 (8個)
      Exercise(id: 9, name: 'Pull-ups', nameZhTw: '引體向上', category: '背部', muscles: ['背闊肌', '二頭肌'], description: '徒手背部訓練'),
      Exercise(id: 10, name: 'Deadlift', nameZhTw: '硬舉', category: '背部', muscles: ['下背部', '腿後肌'], description: '全身性複合動作'),
      Exercise(id: 11, name: 'Barbell Row', nameZhTw: '槓鈴划船', category: '背部', muscles: ['背闊肌'], description: '槓鈴划船'),
      Exercise(id: 12, name: 'Lat Pulldown', nameZhTw: '滑輪下拉', category: '背部', muscles: ['背闊肌'], description: '滑輪下拉'),
      Exercise(id: 13, name: 'Dumbbell Row', nameZhTw: '啞鈴划船', category: '背部', muscles: ['背闊肌'], description: '單臂划船'),
      Exercise(id: 14, name: 'T-Bar Row', nameZhTw: 'T槓划船', category: '背部', muscles: ['背闊肌'], description: 'T槓划船'),
      Exercise(id: 15, name: 'Cable Row', nameZhTw: '坐姿划船', category: '背部', muscles: ['背闊肌'], description: '坐姿划船'),
      Exercise(id: 16, name: 'Face Pull', nameZhTw: '面拉', category: '背部', muscles: ['後三角肌'], description: '面拉'),
      
      // 腿部 (10個)
      Exercise(id: 17, name: 'Squat', nameZhTw: '深蹲', category: '腿部', muscles: ['股四頭肌', '臀部'], description: '深蹲'),
      Exercise(id: 18, name: 'Front Squat', nameZhTw: '前蹲', category: '腿部', muscles: ['股四頭肌'], description: '前蹲'),
      Exercise(id: 19, name: 'Leg Press', nameZhTw: '腿推', category: '腿部', muscles: ['股四頭肌'], description: '腿推機'),
      Exercise(id: 20, name: 'Lunges', nameZhTw: '弓箭步', category: '腿部', muscles: ['股四頭肌', '臀部'], description: '弓箭步'),
      Exercise(id: 21, name: 'Leg Extension', nameZhTw: '腿伸展', category: '腿部', muscles: ['股四頭肌'], description: '腿伸展'),
      Exercise(id: 22, name: 'Leg Curl', nameZhTw: '腿彎舉', category: '腿部', muscles: ['腿後肌'], description: '腿彎舉'),
      Exercise(id: 23, name: 'Bulgarian Split Squat', nameZhTw: '保加利亞分腿蹲', category: '腿部', muscles: ['股四頭肌'], description: '單腿蹲'),
      Exercise(id: 24, name: 'Romanian Deadlift', nameZhTw: '羅馬尼亞硬舉', category: '腿部', muscles: ['腿後肌'], description: '直腿硬舉'),
      Exercise(id: 25, name: 'Calf Raise', nameZhTw: '提踵', category: '腿部', muscles: ['小腿'], description: '小腿訓練'),
      Exercise(id: 26, name: 'Leg Adduction', nameZhTw: '腿內收', category: '腿部', muscles: ['內收肌'], description: '內收機'),
      
      // 肩膀 (6個)
      Exercise(id: 27, name: 'Shoulder Press', nameZhTw: '肩推', category: '肩膀', muscles: ['肩膀'], description: '肩推'),
      Exercise(id: 28, name: 'Lateral Raise', nameZhTw: '側平舉', category: '肩膀', muscles: ['肩膀'], description: '側平舉'),
      Exercise(id: 29, name: 'Front Raise', nameZhTw: '前平舉', category: '肩膀', muscles: ['前三角肌'], description: '前平舉'),
      Exercise(id: 30, name: 'Rear Delt Fly', nameZhTw: '後三角飛鳥', category: '肩膀', muscles: ['後三角肌'], description: '後三角'),
      Exercise(id: 31, name: 'Upright Row', nameZhTw: '直立划船', category: '肩膀', muscles: ['肩膀'], description: '直立划船'),
      Exercise(id: 32, name: 'Arnold Press', nameZhTw: '阿諾推舉', category: '肩膀', muscles: ['肩膀'], description: '阿諾推舉'),
      
      // 手臂 (8個)
      Exercise(id: 33, name: 'Bicep Curl', nameZhTw: '二頭彎舉', category: '手臂', muscles: ['二頭肌'], description: '二頭彎舉'),
      Exercise(id: 34, name: 'Hammer Curl', nameZhTw: '錘式彎舉', category: '手臂', muscles: ['二頭肌'], description: '錘式彎舉'),
      Exercise(id: 35, name: 'Preacher Curl', nameZhTw: '牧師椅彎舉', category: '手臂', muscles: ['二頭肌'], description: '牧師椅'),
      Exercise(id: 36, name: 'Cable Curl', nameZhTw: '繩索彎舉', category: '手臂', muscles: ['二頭肌'], description: '繩索彎舉'),
      Exercise(id: 37, name: 'Tricep Extension', nameZhTw: '三頭伸展', category: '手臂', muscles: ['三頭肌'], description: '三頭伸展'),
      Exercise(id: 38, name: 'Tricep Dips', nameZhTw: '三頭撐體', category: '手臂', muscles: ['三頭肌'], description: '撐體'),
      Exercise(id: 39, name: 'Skull Crusher', nameZhTw: '仰臥三頭伸展', category: '手臂', muscles: ['三頭肌'], description: '碎顱者'),
      Exercise(id: 40, name: 'Close Grip Bench', nameZhTw: '窄握臥推', category: '手臂', muscles: ['三頭肌'], description: '窄握臥推'),
      
      // 腹肌 (6個)
      Exercise(id: 41, name: 'Crunches', nameZhTw: '捲腹', category: '腹肌', muscles: ['腹肌'], description: '捲腹'),
      Exercise(id: 42, name: 'Plank', nameZhTw: '棒式', category: '腹肌', muscles: ['核心'], description: '棒式'),
      Exercise(id: 43, name: 'Leg Raises', nameZhTw: '抬腿', category: '腹肌', muscles: ['下腹'], description: '抬腿'),
      Exercise(id: 44, name: 'Russian Twist', nameZhTw: '俄羅斯轉體', category: '腹肌', muscles: ['腹斜肌'], description: '轉體'),
      Exercise(id: 45, name: 'Mountain Climbers', nameZhTw: '登山者', category: '腹肌', muscles: ['核心'], description: '登山者'),
      Exercise(id: 46, name: 'Bicycle Crunches', nameZhTw: '單車捲腹', category: '腹肌', muscles: ['腹肌'], description: '單車捲腹'),
      
      // 有氧 (4個)
      Exercise(id: 47, name: 'Running', nameZhTw: '跑步', category: '有氧', muscles: [], description: '跑步'),
      Exercise(id: 48, name: 'Cycling', nameZhTw: '騎自行車', category: '有氧', muscles: [], description: '騎車'),
      Exercise(id: 49, name: 'Swimming', nameZhTw: '游泳', category: '有氧', muscles: [], description: '游泳'),
      Exercise(id: 50, name: 'Jump Rope', nameZhTw: '跳繩', category: '有氧', muscles: [], description: '跳繩'),
    ];
  }

  List<Exercise> _searchOfflineExercises(String query) {
    final allExercises = _getOfflineExercises();
    query = query.toLowerCase();
    
    return allExercises.where((exercise) {
      return exercise.name.toLowerCase().contains(query) ||
             exercise.nameZhTw.contains(query) ||
             exercise.category.contains(query);
    }).toList();
  }

  List<Exercise> _getOfflineExercisesByCategory(String category) {
    final allExercises = _getOfflineExercises();
    return allExercises.where((exercise) => exercise.category == category).toList();
  }

  List<String> getCategories() {
    return ['全部', '胸部', '背部', '腿部', '肩膀', '手臂', '腹肌', '有氧'];
  }
}