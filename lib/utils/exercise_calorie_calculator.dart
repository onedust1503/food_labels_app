// lib/utils/exercise_calorie_calculator.dart
// 🔥 基於 Compendium of Physical Activities (2024) 的精確卡路里計算
// 參考來源: https://pacompendium.com/

/// 運動卡路里計算器
class ExerciseCalorieCalculator {
  /// 預設體重 (kg) - 可由用戶設定覆蓋
  static const double defaultBodyWeight = 65.0;

  // ============================================================
  // MET 值對照表 (基於 2011/2024 Compendium of Physical Activities)
  // ============================================================

  /// 重量訓練基礎 MET 值
  static const Map<String, double> _weightTrainingMets = {
    // 強度分類
    'light': 3.5,      // 輕度重訓
    'moderate': 5.0,   // 中等強度
    'vigorous': 6.0,   // 高強度/健力
    'circuit': 8.0,    // 循環訓練
  };

  /// 依肌群分類的 MET 值 (考慮肌群大小和複合程度)
  static const Map<String, double> _muscleGroupMets = {
    // 大肌群複合動作 (較高 MET)
    '腿部': 6.5,
    '背部': 6.0,
    '胸部': 5.5,
    
    // 中等肌群
    '肩部': 5.0,
    '核心': 4.5,
    
    // 小肌群孤立動作 (較低 MET)
    '手臂': 4.0,
    '二頭肌': 4.0,
    '三頭肌': 4.0,
    '前臂': 3.5,
    
    // 有氧運動
    '有氧': 7.0,
    '全身': 6.0,
  };

  /// 依動作類型的 MET 調整係數
  static const Map<String, double> _exerciseTypeMets = {
    // 複合動作 - 高 MET
    '深蹲': 7.0,
    'squat': 7.0,
    '硬舉': 7.5,
    'deadlift': 7.5,
    '臥推': 5.5,
    'bench press': 5.5,
    '划船': 6.0,
    'row': 6.0,
    '肩推': 5.5,
    'shoulder press': 5.5,
    '引體向上': 6.5,
    'pull up': 6.5,
    '下拉': 5.5,
    'lat pulldown': 5.5,
    
    // 孤立動作 - 中等 MET
    '彎舉': 4.0,
    'curl': 4.0,
    '三頭伸展': 4.0,
    'tricep': 4.0,
    '飛鳥': 4.5,
    'fly': 4.5,
    '側平舉': 4.0,
    'lateral raise': 4.0,
    '腿彎舉': 5.0,
    'leg curl': 5.0,
    '腿伸展': 5.0,
    'leg extension': 5.0,
    '小腿': 4.0,
    'calf': 4.0,
    
    // 核心訓練
    '捲腹': 4.0,
    'crunch': 4.0,
    '平板支撐': 4.0,
    'plank': 4.0,
    
    // 徒手訓練
    '伏地挺身': 5.5,
    'push up': 5.5,
    '撐體': 5.0,
    'dip': 5.0,
    
    // 有氧
    '跑步': 9.0,
    'running': 9.0,
    '跳繩': 12.3,
    'jump rope': 12.3,
    '踩腳踏車': 7.0,
    'cycling': 7.0,
  };

  // ============================================================
  // 主要計算方法
  // ============================================================

  /// 🔥 計算單組訓練的卡路里消耗
  /// 
  /// [exerciseName] - 動作名稱
  /// [category] - 肌群分類 (如：胸部、背部、腿部)
  /// [reps] - 次數
  /// [weight] - 重量 (kg)
  /// [durationSeconds] - 該組持續時間 (秒)
  /// [bodyWeight] - 用戶體重 (kg)，可選
  static double calculateSetCalories({
    required String exerciseName,
    String? category,
    required int reps,
    double? weight,
    required int durationSeconds,
    double? bodyWeight,
  }) {
    final userWeight = bodyWeight ?? defaultBodyWeight;
    
    // 1. 獲取基礎 MET 值
    double met = _getMetForExercise(exerciseName, category);
    
    // 2. 根據重量調整 MET (重量越重，強度越高)
    if (weight != null && weight > 0) {
      met = _adjustMetForWeight(met, weight, userWeight);
    }
    
    // 3. 計算卡路里
    // 公式: (MET × 3.5 × 體重kg) / 200 × 時間(分鐘)
    double minutes = durationSeconds / 60.0;
    double calories = (met * 3.5 * userWeight) / 200 * minutes;
    
    // 4. 確保最小值
    return calories < 1.0 ? 1.0 : calories;
  }

  /// 🔥 計算整個動作（多組）的卡路里消耗
  static double calculateExerciseCalories({
    required String exerciseName,
    String? category,
    required List<Map<String, dynamic>> sets,
    double? bodyWeight,
  }) {
    double totalCalories = 0;
    
    for (var set in sets) {
      final status = set['status'] as String?;
      
      // 只計算已完成的組
      if (status == 'completed' || status == 'resting') {
        final reps = (set['actualReps'] ?? set['reps'] ?? 12) as int;
        final weight = (set['weight'] as num?)?.toDouble() ?? 0.0;
        final duration = (set['actualDurationSec'] ?? set['durationSec'] ?? 30) as int;
        
        totalCalories += calculateSetCalories(
          exerciseName: exerciseName,
          category: category,
          reps: reps,
          weight: weight,
          durationSeconds: duration,
          bodyWeight: bodyWeight,
        );
      }
    }
    
    return totalCalories;
  }

  /// 🔥 計算整個訓練課程的卡路里消耗
  static double calculateSessionCalories({
    required List<Map<String, dynamic>> exercises,
    double? bodyWeight,
  }) {
    double totalCalories = 0;
    
    for (var exercise in exercises) {
      final name = (exercise['name'] ?? exercise['exerciseName'] ?? '') as String;
      final category = exercise['category'] as String?;
      final sets = exercise['sets'] as List<dynamic>? ?? [];
      
      totalCalories += calculateExerciseCalories(
        exerciseName: name,
        category: category,
        sets: sets.cast<Map<String, dynamic>>(),
        bodyWeight: bodyWeight,
      );
    }
    
    return totalCalories;
  }

  /// 🔥 簡易計算（用於快速估算）
  /// 基於總訓練時間和平均強度
  static double calculateSimple({
    required int totalDurationMinutes,
    required int completedSets,
    double averageWeight = 20.0,
    double? bodyWeight,
    String intensity = 'moderate', // light, moderate, vigorous
  }) {
    final userWeight = bodyWeight ?? defaultBodyWeight;
    final met = _weightTrainingMets[intensity] ?? 5.0;
    
    // 基礎卡路里 (基於時間)
    double baseCalories = (met * 3.5 * userWeight) / 200 * totalDurationMinutes;
    
    // 根據完成組數和重量調整
    double weightFactor = 1.0;
    if (averageWeight >= 50) {
      weightFactor = 1.3;
    } else if (averageWeight >= 30) {
      weightFactor = 1.2;
    } else if (averageWeight >= 15) {
      weightFactor = 1.1;
    }
    
    return baseCalories * weightFactor;
  }

  // ============================================================
  // 輔助方法
  // ============================================================

  /// 根據動作名稱獲取 MET 值
  static double _getMetForExercise(String exerciseName, String? category) {
    final nameLower = exerciseName.toLowerCase();
    
    // 1. 先檢查特定動作
    for (var entry in _exerciseTypeMets.entries) {
      if (nameLower.contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    
    // 2. 檢查肌群分類
    if (category != null) {
      for (var entry in _muscleGroupMets.entries) {
        if (category.contains(entry.key)) {
          return entry.value;
        }
      }
    }
    
    // 3. 預設值
    return 5.0;
  }

  /// 根據使用重量調整 MET 值
  static double _adjustMetForWeight(double baseMet, double weight, double bodyWeight) {
    // 計算相對重量比例
    double relativeWeight = weight / bodyWeight;
    
    // 調整係數
    double adjustment = 1.0;
    if (relativeWeight >= 0.8) {
      // 重量 >= 80% 體重：高強度
      adjustment = 1.3;
    } else if (relativeWeight >= 0.5) {
      // 重量 >= 50% 體重：中高強度
      adjustment = 1.2;
    } else if (relativeWeight >= 0.3) {
      // 重量 >= 30% 體重：中等強度
      adjustment = 1.1;
    }
    // < 30% 體重：基礎強度，不調整
    
    return baseMet * adjustment;
  }

  /// 獲取動作的估計 MET 值（供顯示用）
  static double getEstimatedMet(String exerciseName, String? category) {
    return _getMetForExercise(exerciseName, category);
  }

  /// 獲取強度描述
  static String getIntensityDescription(double met) {
    if (met >= 8.0) return '高強度';
    if (met >= 6.0) return '中高強度';
    if (met >= 4.0) return '中等強度';
    return '輕度';
  }
}

// ============================================================
// 使用範例
// ============================================================
/*
void main() {
  // 範例 1: 計算單組卡路里
  double setCalories = ExerciseCalorieCalculator.calculateSetCalories(
    exerciseName: '臥推',
    category: '胸部',
    reps: 10,
    weight: 60,
    durationSeconds: 45,
    bodyWeight: 70,
  );
  print('單組卡路里: ${setCalories.toStringAsFixed(1)}');

  // 範例 2: 計算整個訓練的卡路里
  double sessionCalories = ExerciseCalorieCalculator.calculateSessionCalories(
    exercises: [
      {
        'name': '臥推',
        'category': '胸部',
        'sets': [
          {'reps': 10, 'weight': 60, 'durationSec': 45, 'status': 'completed'},
          {'reps': 8, 'weight': 65, 'durationSec': 50, 'status': 'completed'},
        ],
      },
      {
        'name': '深蹲',
        'category': '腿部',
        'sets': [
          {'reps': 12, 'weight': 80, 'durationSec': 60, 'status': 'completed'},
        ],
      },
    ],
    bodyWeight: 70,
  );
  print('總卡路里: ${sessionCalories.toStringAsFixed(1)}');
}
*/