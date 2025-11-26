// lib/services/ocr_service.dart
// 統一 OCR 服務 - 支援 YOLO 和 Google Cloud Vision 雙引擎

import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

/// OCR 引擎類型
enum OcrEngine {
  yolo,   // 自訓練 YOLO 模型
  google, // Google Cloud Vision
}

/// 統一 OCR 服務
class OcrService {
  // ========== 設定 ==========
  
  // YOLO (RunPod) 設定
  static const String _runpodEndpointId = '62gcl0q6545hqb';
  static const String _runpodApiKey = '';
  static const String _runpodBaseUrl = 'https://api.runpod.ai/v2';
  
  // Google Cloud Vision 設定
  // 🔥 請替換成你的 API Key
  static const String _googleApiKey = '';
  static const String _googleVisionUrl = 'https://vision.googleapis.com/v1/images:annotate';
  
  // 圖片壓縮設定
  static const int _maxImageWidth = 1024;
  static const int _maxImageHeight = 1024;
  static const int _jpegQuality = 85;

  /// 獲取當前選擇的引擎
  static Future<OcrEngine> getCurrentEngine() async {
    final prefs = await SharedPreferences.getInstance();
    final engineName = prefs.getString('ocr_engine') ?? 'google';  // 預設用 Google
    return engineName == 'yolo' ? OcrEngine.yolo : OcrEngine.google;
  }

  /// 設定引擎
  static Future<void> setEngine(OcrEngine engine) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ocr_engine', engine == OcrEngine.yolo ? 'yolo' : 'google');
  }

  /// 辨識營養標籤 - 自動使用當前選擇的引擎
  Future<Map<String, dynamic>> recognizeNutritionLabel(File imageFile) async {
    final engine = await getCurrentEngine();
    
    if (engine == OcrEngine.yolo) {
      return await _recognizeWithYolo(imageFile);
    } else {
      return await _recognizeWithGoogle(imageFile);
    }
  }

  /// 使用指定引擎辨識
  Future<Map<String, dynamic>> recognizeWithEngine(File imageFile, OcrEngine engine) async {
    if (engine == OcrEngine.yolo) {
      return await _recognizeWithYolo(imageFile);
    } else {
      return await _recognizeWithGoogle(imageFile);
    }
  }

  // ========== 圖片壓縮 ==========
  
  Future<Uint8List> _compressImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final originalImage = img.decodeImage(bytes);
    
    if (originalImage == null) {
      throw Exception('無法讀取圖片');
    }
    
    img.Image resizedImage = originalImage;
    if (originalImage.width > _maxImageWidth || originalImage.height > _maxImageHeight) {
      final double aspectRatio = originalImage.width / originalImage.height;
      
      int newWidth, newHeight;
      if (aspectRatio > 1) {
        newWidth = _maxImageWidth;
        newHeight = (_maxImageWidth / aspectRatio).round();
      } else {
        newHeight = _maxImageHeight;
        newWidth = (_maxImageHeight * aspectRatio).round();
      }
      
      resizedImage = img.copyResize(
        originalImage,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.linear,
      );
    }
    
    return Uint8List.fromList(img.encodeJpg(resizedImage, quality: _jpegQuality));
  }

  // ========== YOLO (RunPod) ==========
  
  Future<Map<String, dynamic>> _recognizeWithYolo(File imageFile) async {
    try {
      final compressedBytes = await _compressImage(imageFile);
      final base64Image = base64Encode(compressedBytes);

      // 發送請求
      final runResponse = await http.post(
        Uri.parse('$_runpodBaseUrl/$_runpodEndpointId/run'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_runpodApiKey',
        },
        body: jsonEncode({
          'input': {'image': base64Image},
        }),
      ).timeout(const Duration(seconds: 30));

      if (runResponse.statusCode != 200) {
        throw Exception('YOLO 請求失敗');
      }

      final runData = jsonDecode(runResponse.body);
      final jobId = runData['id'];

      // 輪詢結果
      return await _pollYoloResult(jobId);
      
    } catch (e) {
      throw Exception('YOLO OCR 失敗: $e');
    }
  }

  Future<Map<String, dynamic>> _pollYoloResult(String jobId) async {
    const maxAttempts = 150;
    const pollInterval = Duration(seconds: 2);

    for (int i = 0; i < maxAttempts; i++) {
      await Future.delayed(pollInterval);

      final response = await http.get(
        Uri.parse('$_runpodBaseUrl/$_runpodEndpointId/status/$jobId'),
        headers: {'Authorization': 'Bearer $_runpodApiKey'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final status = data['status'];

        if (status == 'COMPLETED') {
          return _parseYoloResponse(data['output']);
        } else if (status == 'FAILED') {
          throw Exception('YOLO 辨識失敗');
        }
      }
    }
    
    throw Exception('YOLO 辨識超時');
  }

  Map<String, dynamic> _parseYoloResponse(dynamic output) {
    Map<String, dynamic> nutritionData = _emptyNutritionData();
    
    if (output == null) return {'success': false, 'nutrition': nutritionData};
    
    List items = output['items'] ?? [];
    
    for (var item in items) {
      String label = item['label'] ?? '';
      double? value = (item['value'] as num?)?.toDouble();
      
      if (value != null) {
        value = _correctValue(label, value);
        _setNutritionValue(nutritionData, label, value);
      }
    }

    return {'success': true, 'nutrition': nutritionData, 'engine': 'yolo'};
  }

  // ========== Google Cloud Vision ==========
  
  Future<Map<String, dynamic>> _recognizeWithGoogle(File imageFile) async {
    try {
      final compressedBytes = await _compressImage(imageFile);
      final base64Image = base64Encode(compressedBytes);

      // Google Cloud Vision API 請求
      final response = await http.post(
        Uri.parse('$_googleVisionUrl?key=$_googleApiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'requests': [
            {
              'image': {'content': base64Image},
              'features': [
                {'type': 'TEXT_DETECTION', 'maxResults': 10}
              ],
              'imageContext': {
                'languageHints': ['zh-TW', 'zh-CN', 'en']
              }
            }
          ]
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('Google Vision API 請求失敗: ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      return _parseGoogleResponse(data);
      
    } catch (e) {
      throw Exception('Google OCR 失敗: $e');
    }
  }

  Map<String, dynamic> _parseGoogleResponse(Map<String, dynamic> data) {
    Map<String, dynamic> nutritionData = _emptyNutritionData();
    
    try {
      final responses = data['responses'] as List?;
      if (responses == null || responses.isEmpty) {
        return {'success': false, 'nutrition': nutritionData};
      }

      final textAnnotations = responses[0]['textAnnotations'] as List?;
      if (textAnnotations == null || textAnnotations.isEmpty) {
        return {'success': false, 'nutrition': nutritionData};
      }

      // 獲取完整文字
      final fullText = textAnnotations[0]['description'] as String? ?? '';
      
      // 解析營養標籤
      nutritionData = _parseNutritionText(fullText);
      
      return {'success': true, 'nutrition': nutritionData, 'engine': 'google', 'rawText': fullText};
      
    } catch (e) {
      print('解析 Google 回應失敗: $e');
      return {'success': false, 'nutrition': nutritionData};
    }
  }

  /// 從文字中解析營養資訊
  Map<String, dynamic> _parseNutritionText(String text) {
    Map<String, dynamic> nutrition = _emptyNutritionData();
    
    // 將文字轉為小寫並按行分割
    final lines = text.split('\n');
    
    // 營養素關鍵字對應
    final patterns = {
      'calories': [r'熱量[^\d]*(\d+\.?\d*)', r'calories[^\d]*(\d+\.?\d*)', r'(\d+\.?\d*)\s*大卡', r'(\d+\.?\d*)\s*kcal'],
      'protein': [r'蛋白質[^\d]*(\d+\.?\d*)', r'protein[^\d]*(\d+\.?\d*)'],
      'fat': [r'脂肪[^\d]*(\d+\.?\d*)', r'fat[^\d]*(\d+\.?\d*)', r'總脂肪[^\d]*(\d+\.?\d*)'],
      'saturated': [r'飽和脂肪[^\d]*(\d+\.?\d*)', r'saturated[^\d]*(\d+\.?\d*)'],
      'transFat': [r'反式脂肪[^\d]*(\d+\.?\d*)', r'trans\s*fat[^\d]*(\d+\.?\d*)'],
      'carbs': [r'碳水化合物[^\d]*(\d+\.?\d*)', r'carbohydrate[^\d]*(\d+\.?\d*)', r'總碳水[^\d]*(\d+\.?\d*)'],
      'sugar': [r'糖[^\d]*(\d+\.?\d*)', r'sugar[^\d]*(\d+\.?\d*)'],
      'sodium': [r'鈉[^\d]*(\d+\.?\d*)', r'sodium[^\d]*(\d+\.?\d*)'],
      'servingSize': [r'每份[^\d]*(\d+\.?\d*)', r'serving\s*size[^\d]*(\d+\.?\d*)'],
    };
    
    final fullText = text.toLowerCase();
    
    patterns.forEach((key, regexList) {
      for (var pattern in regexList) {
        final regex = RegExp(pattern, caseSensitive: false);
        final match = regex.firstMatch(fullText);
        if (match != null && match.groupCount >= 1) {
          final value = double.tryParse(match.group(1) ?? '');
          if (value != null && nutrition[key] == null) {
            nutrition[key] = _correctValue(key, value);
            break;
          }
        }
      }
    });
    
    return nutrition;
  }

  // ========== 工具函數 ==========
  
  Map<String, dynamic> _emptyNutritionData() {
    return {
      'servingSize': null,
      'servingsPerPackage': null,
      'calories': null,
      'protein': null,
      'fat': null,
      'saturated': null,
      'transFat': null,
      'carbs': null,
      'sugar': null,
      'sodium': null,
    };
  }

  void _setNutritionValue(Map<String, dynamic> data, String label, double? value) {
    final mapping = {
      'serving_size': 'servingSize',
      'servings_per_package': 'servingsPerPackage',
      'calories': 'calories',
      'protein': 'protein',
      'fat': 'fat',
      'saturated': 'saturated',
      'trans_fat': 'transFat',
      'carbs': 'carbs',
      'sugar': 'sugar',
      'sodium': 'sodium',
    };
    
    final key = mapping[label] ?? label;
    if (data.containsKey(key)) {
      data[key] = value;
    }
  }

  double _correctValue(String label, double value) {
    final maxValues = {
      'calories': 2000.0,
      'protein': 100.0,
      'fat': 100.0,
      'saturated': 50.0,
      'transFat': 10.0,
      'trans_fat': 10.0,
      'carbs': 200.0,
      'sugar': 100.0,
      'sodium': 5000.0,
      'servingSize': 1000.0,
      'serving_size': 1000.0,
    };
    
    double maxVal = maxValues[label] ?? 10000;
    
    if (value > maxVal) {
      String strVal = value.toInt().toString();
      if (strVal.length >= 5) {
        double opt = double.parse('${strVal.substring(0, 2)}.${strVal.substring(2)}');
        if (opt <= maxVal) return double.parse(opt.toStringAsFixed(1));
      } else if (strVal.length == 4) {
        double opt = double.parse('${strVal.substring(0, 2)}.${strVal.substring(2)}');
        if (opt <= maxVal) return double.parse(opt.toStringAsFixed(1));
      }
    }
    
    return double.parse(value.toStringAsFixed(1));
  }

  /// 檢查 API 狀態
  Future<Map<String, bool>> checkApiHealth() async {
    Map<String, bool> status = {'yolo': false, 'google': false};
    
    // 檢查 YOLO
    try {
      final response = await http.get(
        Uri.parse('$_runpodBaseUrl/$_runpodEndpointId/health'),
        headers: {'Authorization': 'Bearer $_runpodApiKey'},
      ).timeout(const Duration(seconds: 5));
      status['yolo'] = response.statusCode == 200;
    } catch (e) {
      status['yolo'] = false;
    }
    
    // 檢查 Google (簡單測試)
    try {
      status['google'] = _googleApiKey != 'YOUR_GOOGLE_CLOUD_VISION_API_KEY' && 
                         _googleApiKey.isNotEmpty;
    } catch (e) {
      status['google'] = false;
    }
    
    return status;
  }
}