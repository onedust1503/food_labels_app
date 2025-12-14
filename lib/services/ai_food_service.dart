// lib/services/ai_food_service.dart
// AI 食物辨識服務 - v5 新增 sugar + fiber 營養素支援

import 'dart:convert';
import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

// ============================================
// 📦 資料模型
// ============================================

/// Bounding Box 座標（0-1000 相對座標）
class BoundingBox {
  final int xMin;
  final int yMin;
  final int xMax;
  final int yMax;

  BoundingBox({
    required this.xMin,
    required this.yMin,
    required this.xMax,
    required this.yMax,
  });

  factory BoundingBox.fromJson(Map<String, dynamic> json) {
    return BoundingBox(
      xMin: (json['x_min'] as num?)?.toInt() ?? 0,
      yMin: (json['y_min'] as num?)?.toInt() ?? 0,
      xMax: (json['x_max'] as num?)?.toInt() ?? 0,
      yMax: (json['y_max'] as num?)?.toInt() ?? 0,
    );
  }

  /// 轉換為實際像素座標 [left, top, width, height]
  List<double> toPixels(double imageWidth, double imageHeight) {
    final left = (xMin / 1000) * imageWidth;
    final top = (yMin / 1000) * imageHeight;
    final right = (xMax / 1000) * imageWidth;
    final bottom = (yMax / 1000) * imageHeight;
    return [left, top, right - left, bottom - top];
  }

  Map<String, dynamic> toJson() => {
    'x_min': xMin,
    'y_min': yMin,
    'x_max': xMax,
    'y_max': yMax,
  };
}

/// 食物項目 - v5 新增 sugar, fiber
class FoodItem {
  final String name;
  final String portion;
  final int? portionGrams;
  final String confidence;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double sugar;   // 🆕 v5: 糖
  final double fiber;   // 🆕 v5: 膳食纖維
  final String? notes;
  final BoundingBox? boundingBox;

  FoodItem({
    required this.name,
    required this.portion,
    this.portionGrams,
    required this.confidence,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.sugar = 0,   // 🆕
    this.fiber = 0,   // 🆕
    this.notes,
    this.boundingBox,
  });

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    return FoodItem(
      name: json['name'] ?? '未知食物',
      portion: json['portion'] ?? '1份',
      portionGrams: json['portion_grams'] as int?,
      confidence: json['confidence'] ?? 'medium',
      calories: (json['calories'] as num?)?.toDouble() ?? 0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0,
      carbs: (json['carbs'] as num?)?.toDouble() ?? 0,
      fat: (json['fat'] as num?)?.toDouble() ?? 0,
      sugar: (json['sugar'] as num?)?.toDouble() ?? 0,   // 🆕
      fiber: (json['fiber'] as num?)?.toDouble() ?? 0,   // 🆕
      notes: json['notes'] as String?,
      boundingBox: json['bounding_box'] != null
          ? BoundingBox.fromJson(json['bounding_box'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'portion': portion,
    'portion_grams': portionGrams,
    'confidence': confidence,
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'sugar': sugar,   // 🆕
    'fiber': fiber,   // 🆕
    'notes': notes,
    'bounding_box': boundingBox?.toJson(),
  };
}

/// 營養總計 - v5 新增 sugar, fiber
class NutritionTotal {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double sugar;   // 🆕 v5
  final double fiber;   // 🆕 v5

  NutritionTotal({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.sugar = 0,   // 🆕
    this.fiber = 0,   // 🆕
  });

  factory NutritionTotal.fromJson(Map<String, dynamic> json) {
    return NutritionTotal(
      calories: (json['calories'] as num?)?.toDouble() ?? 0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0,
      carbs: (json['carbs'] as num?)?.toDouble() ?? 0,
      fat: (json['fat'] as num?)?.toDouble() ?? 0,
      sugar: (json['sugar'] as num?)?.toDouble() ?? 0,   // 🆕
      fiber: (json['fiber'] as num?)?.toDouble() ?? 0,   // 🆕
    );
  }
}

/// AI 建議
class Recommendation {
  final String type;
  final String advice;
  final String reason;

  Recommendation({
    required this.type,
    required this.advice,
    required this.reason,
  });

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    return Recommendation(
      type: json['type'] ?? 'general',
      advice: json['advice'] ?? '',
      reason: json['reason'] ?? '',
    );
  }
}

/// 餐點評估
class MealAssessment {
  final int balanceScore;
  final List<String> strengths;
  final List<String> improvements;

  MealAssessment({
    required this.balanceScore,
    required this.strengths,
    required this.improvements,
  });

  factory MealAssessment.fromJson(Map<String, dynamic> json) {
    return MealAssessment(
      balanceScore: (json['balance_score'] as num?)?.toInt() ?? 5,
      strengths: (json['strengths'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
      improvements: (json['improvements'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
    );
  }
}

/// 完整分析結果
class FoodAnalysisResult {
  final List<FoodItem> foods;
  final NutritionTotal total;
  final List<Recommendation> recommendations;
  final String overallConfidence;
  final MealAssessment? mealAssessment;

  FoodAnalysisResult({
    required this.foods,
    required this.total,
    required this.recommendations,
    required this.overallConfidence,
    this.mealAssessment,
  });

  factory FoodAnalysisResult.fromJson(Map<String, dynamic> json) {
    return FoodAnalysisResult(
      foods: (json['foods'] as List<dynamic>?)
          ?.map((e) => FoodItem.fromJson(e))
          .toList() ?? [],
      total: NutritionTotal.fromJson(json['total'] ?? {}),
      recommendations: (json['recommendations'] as List<dynamic>?)
          ?.map((e) => Recommendation.fromJson(e))
          .toList() ?? [],
      overallConfidence: json['overall_confidence'] ?? 'medium',
      mealAssessment: json['meal_assessment'] != null
          ? MealAssessment.fromJson(json['meal_assessment'])
          : null,
    );
  }
}

/// 自訂例外
class AIFoodServiceException implements Exception {
  final String message;
  final String? code;
  final bool isRetryable;

  AIFoodServiceException(this.message, {this.code, this.isRetryable = false});

  @override
  String toString() => message;
}

// ============================================
// 🍽️ AI 食物辨識服務
// ============================================

class AIFoodService {
  static final AIFoodService _instance = AIFoodService._internal();
  factory AIFoodService() => _instance;
  AIFoodService._internal();

  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'asia-east1',
  );

  // 重試配置（Flutter 端的重試，Cloud Function 已經有自己的重試）
  static const int _maxRetries = 2;
  static const Duration _retryDelay = Duration(seconds: 3);

  /// 分析食物圖片（帶自動重試）
  Future<FoodAnalysisResult> analyzeFood(
    File imageFile, {
    String? mealType,
    String? userGoal,
    int? targetCalories,
    Function(int attempt, int maxAttempts)? onRetry,
  }) async {
    // 壓縮圖片
    final base64Image = await _compressAndEncodeImage(imageFile);

    if (kDebugMode) {
      print('🍽️ [AI] 開始分析食物...');
      print('🍽️ [AI] 圖片已轉為 Base64，大小: ${base64Image.length} bytes');
    }

    // 帶重試的 API 呼叫
    return _callWithRetry(
      base64Image: base64Image,
      mealType: mealType,
      userGoal: userGoal,
      targetCalories: targetCalories,
      onRetry: onRetry,
    );
  }

  /// 帶重試機制的 API 呼叫
  Future<FoodAnalysisResult> _callWithRetry({
    required String base64Image,
    String? mealType,
    String? userGoal,
    int? targetCalories,
    Function(int attempt, int maxAttempts)? onRetry,
  }) async {
    int attempt = 0;
    Exception? lastException;

    while (attempt < _maxRetries) {
      attempt++;

      try {
        if (kDebugMode) {
          print('🍽️ [AI] Flutter 端嘗試第 $attempt/$_maxRetries 次...');
        }

        return await _callAnalyzeFood(
          base64Image: base64Image,
          mealType: mealType,
          userGoal: userGoal,
          targetCalories: targetCalories,
        );
      } on AIFoodServiceException catch (e) {
        lastException = e;

        // 檢查是否可重試
        if (e.isRetryable && attempt < _maxRetries) {
          if (kDebugMode) {
            print('🍽️ [AI] 錯誤可重試，等待 ${_retryDelay.inSeconds} 秒...');
          }

          // 通知 UI 正在重試
          onRetry?.call(attempt, _maxRetries);

          // 等待後重試
          await Future.delayed(_retryDelay * attempt);
          continue;
        }

        // 不可重試或已達最大次數
        rethrow;
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());

        if (attempt < _maxRetries) {
          if (kDebugMode) {
            print('🍽️ [AI] 未知錯誤，嘗試重試: $e');
          }
          onRetry?.call(attempt, _maxRetries);
          await Future.delayed(_retryDelay * attempt);
          continue;
        }

        throw AIFoodServiceException(
          '[UNKNOWN] 分析失敗: $e',
          isRetryable: false,
        );
      }
    }

    // 不應該到這裡
    throw lastException ?? AIFoodServiceException('[ERROR] 分析失敗');
  }

  /// 實際呼叫 Cloud Function
  Future<FoodAnalysisResult> _callAnalyzeFood({
    required String base64Image,
    String? mealType,
    String? userGoal,
    int? targetCalories,
  }) async {
    try {
      final callable = _functions.httpsCallable(
        'analyzeFood',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 120),
        ),
      );

      if (kDebugMode) {
        print('🍽️ [AI] 呼叫 Cloud Function: analyzeFood');
      }

      final result = await callable.call({
        'imageBase64': base64Image,
        'mealType': mealType,
        'userGoal': userGoal,
        'targetCalories': targetCalories,
      });

      // 安全的類型轉換
      final rawData = result.data;
      final data = _convertToStringDynamic(rawData);

      if (kDebugMode) {
        print('🍽️ [AI] Cloud Function 回應: success=${data['success']}, '
            'modelUsed=${data['modelUsed']}');
      }

      if (data['success'] == true && data['result'] != null) {
        if (kDebugMode) {
          print('🍽️ [AI] 分析成功！使用模型: ${data['modelUsed']}');
        }
        // 對 result 也做類型轉換
        final resultData = _convertToStringDynamic(data['result']);
        return FoodAnalysisResult.fromJson(resultData);
      } else {
        throw AIFoodServiceException(
          data['error']?.toString() ?? '[ERROR] 分析失敗，未知原因',
          isRetryable: false,
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        print('🍽️ [AI] Firebase Functions 錯誤:');
        print('  code: ${e.code}');
        print('  message: ${e.message}');
        print('  details: ${e.details}');
      }

      // 判斷是否為可重試錯誤
      final isRetryable = _isRetryableError(e.code, e.message);

      // 直接使用 Cloud Function 傳回的詳細訊息
      final errorMessage = _getErrorMessage(e.code, e.message);

      throw AIFoodServiceException(
        errorMessage,
        code: e.code,
        isRetryable: isRetryable,
      );
    }
  }

  /// 判斷錯誤是否可重試
  bool _isRetryableError(String code, String? message) {
    // 503 錯誤（服務過載）
    if (message?.contains('503') == true) return true;
    if (message?.contains('overloaded') == true) return true;

    // 其他暫時性錯誤
    if (code == 'unavailable') return true;
    if (code == 'resource-exhausted') return true;
    if (code == 'deadline-exceeded') return true;

    return false;
  }

  /// 壓縮並編碼圖片
  Future<String> _compressAndEncodeImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();

    // 解碼圖片
    img.Image? image = img.decodeImage(bytes);
    if (image == null) {
      throw AIFoodServiceException('[IMAGE] 無法讀取圖片');
    }

    // 壓縮：限制最大寬度為 1024
    if (image.width > 1024) {
      image = img.copyResize(image, width: 1024);
    }

    // 轉為 JPEG（品質 85%）
    final compressedBytes = img.encodeJpg(image, quality: 85);

    return base64Encode(compressedBytes);
  }

  /// 遞迴轉換 Map 類型（解決 Firebase 回傳類型問題）
  Map<String, dynamic> _convertToStringDynamic(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return data.map((key, value) {
        if (value is Map) {
          return MapEntry(key.toString(), _convertToStringDynamic(value));
        } else if (value is List) {
          return MapEntry(key.toString(), _convertList(value));
        }
        return MapEntry(key.toString(), value);
      });
    }
    return {};
  }

  /// 轉換 List 中的 Map
  List<dynamic> _convertList(List<dynamic> list) {
    return list.map((item) {
      if (item is Map) {
        return _convertToStringDynamic(item);
      } else if (item is List) {
        return _convertList(item);
      }
      return item;
    }).toList();
  }

  /// 錯誤訊息轉換（優先使用 Cloud Function 傳回的詳細訊息）
  String _getErrorMessage(String code, [String? message]) {
    // 如果 message 包含錯誤代碼標記（來自 Cloud Function），直接使用
    if (message != null && message.startsWith('[')) {
      return message;
    }

    // 如果 message 有內容且不是通用訊息，組合顯示
    if (message != null && 
        message.isNotEmpty && 
        !message.contains('INTERNAL') &&
        message.length > 10) {
      return '[$code] $message';
    }

    // 否則使用預設訊息
    switch (code) {
      case 'unauthenticated':
        return '[AUTH] 請先登入';
      case 'invalid-argument':
        return '[INVALID] 圖片格式不正確，請重新選擇';
      case 'unavailable':
        return '[UNAVAILABLE] AI 服務暫時無法使用';
      case 'resource-exhausted':
        return '[RATE_LIMIT] 請求過於頻繁，請稍後再試';
      case 'deadline-exceeded':
        return '[TIMEOUT] 分析超時（超過 120 秒），請重試';
      case 'internal':
        return '[INTERNAL] 內部錯誤: ${message ?? "未知"}';
      default:
        return '[$code] ${message ?? "發生錯誤，請稍後再試"}';
    }
  }
}