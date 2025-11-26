// lib/pages/nutrition/ocr_scan_page.dart
// 更新版 - 支援 YOLO 和 Google Cloud Vision 雙引擎

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/ocr_service.dart';
import '../../widgets/ocr_engine_selector.dart';
import 'manual_nutrition_input_page.dart';

class OcrScanPage extends StatefulWidget {
  const OcrScanPage({super.key});

  @override
  State<OcrScanPage> createState() => _OcrScanPageState();
}

class _OcrScanPageState extends State<OcrScanPage> {
  final OcrService _ocrService = OcrService();
  final ImagePicker _picker = ImagePicker();
  
  File? _selectedImage;
  bool _isProcessing = false;
  Map<String, dynamic>? _recognizedData;
  String? _errorMessage;
  OcrEngine _currentEngine = OcrEngine.google;
  String? _usedEngine;  // 記錄實際使用的引擎

  @override
  void initState() {
    super.initState();
    _loadCurrentEngine();
  }

  Future<void> _loadCurrentEngine() async {
    final engine = await OcrService.getCurrentEngine();
    setState(() => _currentEngine = engine);
  }

  /// 選擇圖片來源（相機或相簿）
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _recognizedData = null;
          _errorMessage = null;
          _usedEngine = null;
        });
        
        // 自動開始辨識
        _startRecognition();
      }
    } catch (e) {
      _showError('選擇圖片失敗: $e');
    }
  }

  /// 開始辨識營養標籤
  Future<void> _startRecognition() async {
    if (_selectedImage == null) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    // 記錄開始時間
    final startTime = DateTime.now();

    try {
      Map<String, dynamic> result = await _ocrService.recognizeNutritionLabel(_selectedImage!);
      
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      
      setState(() {
        _recognizedData = result;
        _isProcessing = false;
        _usedEngine = result['engine'] ?? (_currentEngine == OcrEngine.yolo ? 'YOLO' : 'Google');
      });

      // 顯示辨識完成提示
      if (mounted) {
        final engineName = _usedEngine == 'yolo' ? 'YOLO' : 'Google';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('辨識完成！使用 $engineName，耗時 ${elapsed} ms'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isProcessing = false;
      });
    }
  }

  /// 前往手動輸入頁面，預填辨識結果
  void _goToManualInput() {
    if (_recognizedData == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ManualNutritionInputPage(
          initialData: _recognizedData!['nutrition'],
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  /// 顯示引擎選擇對話框
  void _showEngineDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '選擇 OCR 引擎',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            OcrEngineSelector(
              onEngineChanged: (engine) {
                setState(() => _currentEngine = engine);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('掃描營養標籤'),
        backgroundColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
        actions: [
          // 引擎切換按鈕
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: OcrEngineQuickSelector(
              onEngineChanged: (engine) {
                setState(() => _currentEngine = engine);
              },
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 選擇圖片按鈕
            if (_selectedImage == null) ...[
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _currentEngine == OcrEngine.yolo 
                      ? Colors.purple[50] 
                      : Colors.green[50],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(
                      _currentEngine == OcrEngine.yolo 
                          ? Icons.smart_toy 
                          : Icons.cloud,
                      size: 80,
                      color: _currentEngine == OcrEngine.yolo 
                          ? Colors.purple[300] 
                          : Colors.green[300],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _currentEngine == OcrEngine.yolo 
                          ? '🤖 AI 辨識模式' 
                          : '☁️ 雲端辨識模式',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _currentEngine == OcrEngine.yolo 
                          ? '使用自訓練 YOLO 深度學習模型' 
                          : '使用 Google Cloud Vision API',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currentEngine == OcrEngine.yolo 
                          ? '首次使用需等待 30-50 秒啟動' 
                          : '快速辨識，約 1-3 秒完成',
                      style: TextStyle(
                        fontSize: 12,
                        color: _currentEngine == OcrEngine.yolo 
                            ? Colors.orange[700] 
                            : Colors.green[700],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('拍照'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('從相簿選擇'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF3B82F6),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // 顯示選擇的圖片
            if (_selectedImage != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _selectedImage!,
                  height: 300,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 16),
              
              // 重新選擇按鈕
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedImage = null;
                    _recognizedData = null;
                    _errorMessage = null;
                    _usedEngine = null;
                  });
                },
                icon: const Icon(Icons.refresh),
                label: const Text('重新選擇'),
              ),
            ],

            // 辨識中狀態
            if (_isProcessing) ...[
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                _currentEngine == OcrEngine.yolo 
                    ? '正在使用 YOLO 辨識中...' 
                    : '正在使用 Google 辨識中...',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Text(
                _currentEngine == OcrEngine.yolo 
                    ? '首次使用可能需要 30-50 秒啟動' 
                    : '預計 1-3 秒完成',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],

            // 錯誤訊息
            if (_errorMessage != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '辨識失敗',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _errorMessage!,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _startRecognition,
                    icon: const Icon(Icons.refresh),
                    label: const Text('重試'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      // 切換引擎重試
                      final newEngine = _currentEngine == OcrEngine.yolo 
                          ? OcrEngine.google 
                          : OcrEngine.yolo;
                      await OcrService.setEngine(newEngine);
                      setState(() => _currentEngine = newEngine);
                      _startRecognition();
                    },
                    icon: const Icon(Icons.swap_horiz),
                    label: Text(
                      _currentEngine == OcrEngine.yolo 
                          ? '改用 Google' 
                          : '改用 YOLO',
                    ),
                  ),
                ],
              ),
            ],

            // 辨識結果
            if (_recognizedData != null && !_isProcessing) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green[700]),
                        const SizedBox(width: 8),
                        const Text(
                          '辨識完成',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        // 顯示使用的引擎
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _usedEngine == 'yolo' 
                                ? Colors.purple[100] 
                                : Colors.blue[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _usedEngine == 'yolo' ? '🤖 YOLO' : '☁️ Google',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _usedEngine == 'yolo' 
                                  ? Colors.purple[700] 
                                  : Colors.blue[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildNutritionField('每份熱量', _recognizedData!['nutrition']['calories'], '大卡'),
                    _buildNutritionField('蛋白質', _recognizedData!['nutrition']['protein'], 'g'),
                    _buildNutritionField('脂肪', _recognizedData!['nutrition']['fat'], 'g'),
                    _buildNutritionField('碳水化合物', _recognizedData!['nutrition']['carbs'], 'g'),
                    _buildNutritionField('糖', _recognizedData!['nutrition']['sugar'], 'g'),
                    _buildNutritionField('鈉', _recognizedData!['nutrition']['sodium'], 'mg'),
                    _buildNutritionField('飽和脂肪', _recognizedData!['nutrition']['saturated'], 'g'),
                    _buildNutritionField('反式脂肪', _recognizedData!['nutrition']['transFat'], 'g'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _goToManualInput,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '確認並記錄',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionField(String label, dynamic value, String unit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
          Text(
            value != null ? '$value $unit' : '未偵測',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: value != null ? Colors.black : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}