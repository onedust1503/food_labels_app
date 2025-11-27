// lib/pages/nutrition/ocr_scan_page.dart
// ✨ Soft UI 風格升級版 - 支援 YOLO 和 Google Cloud Vision 雙引擎
// v2.1: 現代化 UI + shimmer 動畫 + 營養素網格顯示 + 儲存到我的食物

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/ocr_service.dart';
import '../../services/food_database_service.dart';  // ✨ v2.1: 新增
import '../../theme/app_colors.dart';
import '../../widgets/nutrition/soft_card.dart';
import '../../widgets/ocr_engine_selector.dart';
import 'add_nutrition_log_page.dart';

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
  String? _usedEngine;
  int? _latencyMs;

  // ✨ 可編輯的營養素值
  final Map<String, double?> _editedNutrition = {};
  
  // ✨ 營養素定義（key, 名稱, 單位, 顏色）
  static const List<Map<String, dynamic>> _nutrientDefinitions = [
    {'key': 'calories', 'label': '熱量', 'unit': '大卡', 'color': 0xFFFF6B35},
    {'key': 'protein', 'label': '蛋白質', 'unit': 'g', 'color': 0xFFEF4444},
    {'key': 'carbs', 'label': '碳水化合物', 'unit': 'g', 'color': 0xFFF59E0B},
    {'key': 'fat', 'label': '脂肪', 'unit': 'g', 'color': 0xFF8B5CF6},
    {'key': 'sugar', 'label': '糖', 'unit': 'g', 'color': 0xFFEC4899},
    {'key': 'sodium', 'label': '鈉', 'unit': 'mg', 'color': 0xFF06B6D4},
    {'key': 'saturatedFat', 'label': '飽和脂肪', 'unit': 'g', 'color': 0xFF64748B},
    {'key': 'transFat', 'label': '反式脂肪', 'unit': 'g', 'color': 0xFF94A3B8},
    {'key': 'fiber', 'label': '膳食纖維', 'unit': 'g', 'color': 0xFF22C55E},
    {'key': 'cholesterol', 'label': '膽固醇', 'unit': 'mg', 'color': 0xFFA855F7},
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentEngine();
  }

  Future<void> _loadCurrentEngine() async {
    final engine = await OcrService.getCurrentEngine();
    setState(() => _currentEngine = engine);
  }

  /// 選擇圖片來源
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
          _latencyMs = null;
        });
        _startRecognition();
      }
    } catch (e) {
      _showErrorSnackBar('選擇圖片失敗: $e');
    }
  }

  /// 開始辨識
  Future<void> _startRecognition() async {
    if (_selectedImage == null) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    final startTime = DateTime.now();

    try {
      Map<String, dynamic> result = await _ocrService.recognizeNutritionLabel(_selectedImage!);
      
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      
      // ✨ 初始化可編輯的營養素值
      final nutrition = result['nutrition'] ?? {};
      _editedNutrition.clear();
      for (var def in _nutrientDefinitions) {
        final key = def['key'] as String;
        final value = nutrition[key];
        _editedNutrition[key] = value?.toDouble();
      }
      // 處理舊的 key 名稱相容
      if (nutrition['saturated'] != null && _editedNutrition['saturatedFat'] == null) {
        _editedNutrition['saturatedFat'] = nutrition['saturated']?.toDouble();
      }
      
      setState(() {
        _recognizedData = result;
        _isProcessing = false;
        _usedEngine = result['engine'] ?? (_currentEngine == OcrEngine.yolo ? 'yolo' : 'google');
        _latencyMs = elapsed;
      });

      if (mounted) {
        final engineName = _usedEngine == 'yolo' ? 'YOLO' : 'Google';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text('辨識完成！使用 $engineName，耗時 ${elapsed}ms'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.all(16),
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

  /// 確認並記錄
  void _goToAddLog() {
    if (_recognizedData == null) return;

    // ✨ 使用編輯後的值
    final foodData = {
      'name': '掃描食品',
      'calories': (_editedNutrition['calories'] ?? 0).toDouble(),
      'protein': (_editedNutrition['protein'] ?? 0).toDouble(),
      'fat': (_editedNutrition['fat'] ?? 0).toDouble(),
      'carbs': (_editedNutrition['carbs'] ?? 0).toDouble(),
      'servingSize': '每份',
      'isScanned': true,
      // 額外營養素
      'sugar': _editedNutrition['sugar'],
      'sodium': _editedNutrition['sodium'],
      'saturatedFat': _editedNutrition['saturatedFat'],
      'transFat': _editedNutrition['transFat'],
      'fiber': _editedNutrition['fiber'],
      'cholesterol': _editedNutrition['cholesterol'],
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddNutritionLogPage(foodData: foodData),
      ),
    );
  }

  /// 重置
  void _resetScan() {
    setState(() {
      _selectedImage = null;
      _recognizedData = null;
      _errorMessage = null;
      _usedEngine = null;
      _latencyMs = null;
    });
  }

  /// 切換引擎重試
  Future<void> _retryWithOtherEngine() async {
    final newEngine = _currentEngine == OcrEngine.yolo 
        ? OcrEngine.google 
        : OcrEngine.yolo;
    await OcrService.setEngine(newEngine);
    setState(() => _currentEngine = newEngine);
    _startRecognition();
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  /// 顯示引擎選擇 Bottom Sheet
  void _showEngineSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '選擇辨識引擎',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            _buildEngineOption(
              engine: OcrEngine.yolo,
              icon: Icons.smart_toy,
              title: 'AI 辨識 (YOLO)',
              subtitle: '自訓練深度學習模型',
              description: '專為營養標籤優化，首次需 30-50 秒啟動',
              color: const Color(0xFF8B5CF6),
            ),
            const SizedBox(height: 12),
            _buildEngineOption(
              engine: OcrEngine.google,
              icon: Icons.cloud,
              title: '雲端辨識 (Google)',
              subtitle: 'Google Cloud Vision API',
              description: '辨識速度快 (1-3秒)，準確度高',
              color: const Color(0xFF10B981),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildEngineOption({
    required OcrEngine engine,
    required IconData icon,
    required String title,
    required String subtitle,
    required String description,
    required Color color,
  }) {
    final isSelected = _currentEngine == engine;
    
    return GestureDetector(
      onTap: () async {
        await OcrService.setEngine(engine);
        setState(() => _currentEngine = engine);
        Navigator.pop(context);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? color : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (isSelected) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: color, size: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: _selectedImage == null
            ? _buildInitialView()
            : _buildResultView(),
      ),
    );
  }

  /// AppBar
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowLight,
                offset: const Offset(0, 2),
                blurRadius: 8,
              ),
            ],
          ),
          child: const Icon(
            Icons.arrow_back_ios_new,
            size: 18,
            color: AppColors.textPrimary,
          ),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        '營養標籤掃描',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
      actions: [
        // 引擎切換按鈕
        GestureDetector(
          onTap: _showEngineSelector,
          child: Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _currentEngine == OcrEngine.yolo 
                  ? const Color(0xFF8B5CF6).withOpacity(0.1)
                  : const Color(0xFF10B981).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _currentEngine == OcrEngine.yolo 
                    ? const Color(0xFF8B5CF6)
                    : const Color(0xFF10B981),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _currentEngine == OcrEngine.yolo ? Icons.smart_toy : Icons.cloud,
                  size: 16,
                  color: _currentEngine == OcrEngine.yolo 
                      ? const Color(0xFF8B5CF6)
                      : const Color(0xFF10B981),
                ),
                const SizedBox(width: 6),
                Text(
                  _currentEngine == OcrEngine.yolo ? 'YOLO' : 'Google',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _currentEngine == OcrEngine.yolo 
                        ? const Color(0xFF8B5CF6)
                        : const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 初始視圖
  Widget _buildInitialView() {
    final isYolo = _currentEngine == OcrEngine.yolo;
    final engineColor = isYolo ? const Color(0xFF8B5CF6) : const Color(0xFF10B981);
    
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          
          // 說明卡片
          SoftCard(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        engineColor.withOpacity(0.15),
                        engineColor.withOpacity(0.05),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isYolo ? Icons.smart_toy : Icons.cloud,
                    size: 56,
                    color: engineColor,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  isYolo ? '🤖 AI 辨識模式' : '☁️ 雲端辨識模式',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isYolo 
                      ? '使用自訓練 YOLO 深度學習模型'
                      : '使用 Google Cloud Vision API',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                
                // 提示標籤
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isYolo 
                        ? const Color(0xFFFFF3CD) 
                        : const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isYolo ? Icons.schedule : Icons.bolt,
                        size: 18,
                        color: isYolo 
                            ? const Color(0xFF856404) 
                            : const Color(0xFF065F46),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isYolo 
                            ? '首次使用需等待 30-50 秒啟動'
                            : '快速辨識，約 1-3 秒完成',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isYolo 
                              ? const Color(0xFF856404) 
                              : const Color(0xFF065F46),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
              .animate()
              .fadeIn(duration: 400.ms)
              .slideY(begin: 0.2, end: 0),
          
          const Spacer(),
          
          // 拍照按鈕
          _buildPrimaryButton(
            icon: Icons.camera_alt,
            label: '拍攝營養標籤',
            subtitle: '對準標籤拍照辨識',
            gradientColors: [engineColor, engineColor.withOpacity(0.7)],
            onTap: () => _pickImage(ImageSource.camera),
          )
              .animate(delay: 100.ms)
              .fadeIn(duration: 400.ms)
              .slideY(begin: 0.2, end: 0),
          
          const SizedBox(height: 16),
          
          // 相簿按鈕
          _buildSecondaryButton(
            icon: Icons.photo_library,
            label: '從相簿選擇',
            onTap: () => _pickImage(ImageSource.gallery),
          )
              .animate(delay: 200.ms)
              .fadeIn(duration: 400.ms)
              .slideY(begin: 0.2, end: 0),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required List<Color> gradientColors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: gradientColors.first.withOpacity(0.4),
              offset: const Offset(0, 8),
              blurRadius: 20,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white.withOpacity(0.6),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowDark,
              offset: const Offset(6, 6),
              blurRadius: 12,
            ),
            BoxShadow(
              color: AppColors.shadowLight,
              offset: const Offset(-6, -6),
              blurRadius: 12,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.primary, size: 24),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 結果視圖
  Widget _buildResultView() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // 圖片預覽
          _buildImagePreview()
              .animate()
              .fadeIn(duration: 400.ms)
              .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1)),
          
          const SizedBox(height: 16),
          
          // 重新選擇按鈕
          TextButton.icon(
            onPressed: _resetScan,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('重新選擇'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 狀態顯示
          if (_isProcessing)
            _buildProcessingState()
          else if (_errorMessage != null)
            _buildErrorState()
          else if (_recognizedData != null)
            _buildResultCard(),
          
          const SizedBox(height: 20),
          
          // 確認按鈕
          if (_recognizedData != null && !_isProcessing)
            _buildActionButtons()
                .animate(delay: 300.ms)
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.2, end: 0),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return GestureDetector(
      onTap: () => _showFullScreenImage(),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadowMedium,
                  offset: const Offset(0, 8),
                  blurRadius: 20,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.file(
                _selectedImage!,
                height: 280,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),
          // ✨ 放大提示圖標
          Positioned(
            right: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(
                    Icons.zoom_in,
                    color: Colors.white,
                    size: 16,
                  ),
                  SizedBox(width: 4),
                  Text(
                    '點擊放大',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ✨ 顯示全螢幕圖片查看器
  void _showFullScreenImage() {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (context, animation, secondaryAnimation) {
          return _FullScreenImageViewer(
            imageFile: _selectedImage!,
            animation: animation,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  /// 處理中狀態 - shimmer 動畫
  Widget _buildProcessingState() {
    final isYolo = _currentEngine == OcrEngine.yolo;
    
    return SoftCard(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                strokeWidth: 3,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isYolo ? '正在使用 YOLO 辨識...' : '正在使用 Google 辨識...',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isYolo ? '首次使用可能需要 30-50 秒啟動' : '預計 1-3 秒完成',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    )
        .animate(onPlay: (controller) => controller.repeat())
        .shimmer(duration: 1500.ms, color: AppColors.primary.withOpacity(0.1));
  }

  /// 錯誤狀態
  Widget _buildErrorState() {
    return SoftCard(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline,
              size: 40,
              color: AppColors.error,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '辨識失敗',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _startRecognition,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('重試'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _retryWithOtherEngine,
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: Text(
                  _currentEngine == OcrEngine.yolo ? '改用 Google' : '改用 YOLO',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: BorderSide(color: AppColors.divider),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 辨識結果卡片
  Widget _buildResultCard() {
    final confidence = _calculateConfidence(_editedNutrition);
    
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 標題列
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _usedEngine == 'yolo' 
                        ? [const Color(0xFF8B5CF6), const Color(0xFFA78BFA)]
                        : [const Color(0xFF10B981), const Color(0xFF34D399)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _usedEngine == 'yolo' ? Icons.smart_toy : Icons.cloud,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '辨識結果',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (_latencyMs != null)
                      Text(
                        '耗時 ${_latencyMs}ms',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                  ],
                ),
              ),
              // 信心度標籤
              _buildConfidenceBadge(confidence),
            ],
          ),
          
          // ✨ 可編輯提示
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFCD34D)),
            ),
            child: Row(
              children: const [
                Icon(Icons.touch_app, size: 16, color: Color(0xFFD97706)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '點擊數值可修正辨識結果',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF92400E),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // 熱量（大顯示）- 可編輯
          _buildEditableCaloriesRow(),
          
          const SizedBox(height: 20),
          
          // 三大營養素網格 - 可編輯
          Row(
            children: [
              Expanded(
                child: _buildEditableNutrientItem(
                  nutrientKey: 'protein',
                  label: '蛋白質',
                  unit: 'g',
                  color: const Color(0xFFEF4444),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildEditableNutrientItem(
                  nutrientKey: 'carbs',
                  label: '碳水化合物',
                  unit: 'g',
                  color: const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildEditableNutrientItem(
                  nutrientKey: 'fat',
                  label: '脂肪',
                  unit: 'g',
                  color: const Color(0xFF8B5CF6),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // 其他營養素 - 可編輯
          Row(
            children: [
              Expanded(
                child: _buildEditableNutrientItem(
                  nutrientKey: 'sugar',
                  label: '糖',
                  unit: 'g',
                  color: const Color(0xFFEC4899),
                  compact: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildEditableNutrientItem(
                  nutrientKey: 'sodium',
                  label: '鈉',
                  unit: 'mg',
                  color: const Color(0xFF06B6D4),
                  compact: true,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // 飽和脂肪 & 反式脂肪
          Row(
            children: [
              Expanded(
                child: _buildEditableNutrientItem(
                  nutrientKey: 'saturatedFat',
                  label: '飽和脂肪',
                  unit: 'g',
                  color: const Color(0xFF64748B),
                  compact: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildEditableNutrientItem(
                  nutrientKey: 'transFat',
                  label: '反式脂肪',
                  unit: 'g',
                  color: const Color(0xFF94A3B8),
                  compact: true,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // 膳食纖維 & 膽固醇
          Row(
            children: [
              Expanded(
                child: _buildEditableNutrientItem(
                  nutrientKey: 'fiber',
                  label: '膳食纖維',
                  unit: 'g',
                  color: const Color(0xFF22C55E),
                  compact: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildEditableNutrientItem(
                  nutrientKey: 'cholesterol',
                  label: '膽固醇',
                  unit: 'mg',
                  color: const Color(0xFFA855F7),
                  compact: true,
                ),
              ),
            ],
          ),
        ],
      ),
    )
        .animate(delay: 200.ms)
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.1, end: 0);
  }

  /// ✨ 可編輯的熱量大顯示
  Widget _buildEditableCaloriesRow() {
    final value = _editedNutrition['calories'];
    final hasValue = value != null;
    
    return GestureDetector(
      onTap: () => _showEditDialog('calories', '熱量', '大卡'),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFFF6B35).withOpacity(0.15),
              const Color(0xFFFF6B35).withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFFF6B35).withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B35).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.local_fire_department,
                color: Color(0xFFFF6B35),
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '熱量',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        hasValue ? value!.toStringAsFixed(1) : '未偵測',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: hasValue ? const Color(0xFFFF6B35) : Colors.grey,
                        ),
                      ),
                      if (hasValue) ...[
                        const SizedBox(width: 4),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 4),
                          child: Text(
                            '大卡',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFFFF6B35),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // ✨ 編輯圖標
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.edit,
                color: Color(0xFFFF6B35),
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ✨ 可編輯的營養素項目
  Widget _buildEditableNutrientItem({
    required String nutrientKey,
    required String label,
    required String unit,
    required Color color,
    bool compact = false,
  }) {
    final value = _editedNutrition[nutrientKey];
    final hasValue = value != null;
    final displayValue = hasValue ? value!.toStringAsFixed(1) : '--';
    
    return GestureDetector(
      onTap: () => _showEditDialog(nutrientKey, label, unit),
      child: Container(
        padding: EdgeInsets.all(compact ? 10 : 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: compact ? 11 : 12,
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.edit,
                  size: compact ? 12 : 14,
                  color: color.withOpacity(0.6),
                ),
              ],
            ),
            SizedBox(height: compact ? 4 : 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  displayValue,
                  style: TextStyle(
                    fontSize: compact ? 18 : 22,
                    fontWeight: FontWeight.bold,
                    color: hasValue ? color : Colors.grey,
                  ),
                ),
                if (hasValue) ...[
                  const SizedBox(width: 2),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      unit,
                      style: TextStyle(
                        fontSize: compact ? 10 : 12,
                        color: color.withOpacity(0.7),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// ✨ 顯示編輯對話框
  void _showEditDialog(String key, String label, String unit) {
    final currentValue = _editedNutrition[key];
    final controller = TextEditingController(
      text: currentValue?.toStringAsFixed(1) ?? '',
    );
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.edit,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '編輯 $label',
              style: const TextStyle(fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                hintText: '請輸入數值',
                suffixText: unit,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            // 快速數值按鈕
            if (key == 'calories') 
              _buildQuickValueButtons(controller, [50, 100, 200, 300, 500])
            else if (unit == 'mg')
              _buildQuickValueButtons(controller, [10, 50, 100, 200, 500])
            else
              _buildQuickValueButtons(controller, [1, 5, 10, 20, 50]),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _editedNutrition[key] = null;
              });
              Navigator.pop(context);
            },
            child: const Text('清除', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final newValue = double.tryParse(controller.text);
              setState(() {
                _editedNutrition[key] = newValue;
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('確認', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// ✨ 快速數值按鈕
  Widget _buildQuickValueButtons(TextEditingController controller, List<num> values) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map((value) {
        return InkWell(
          onTap: () {
            controller.text = value.toString();
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value.toString(),
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 計算信心度
  double _calculateConfidence(Map<String, dynamic> nutrition) {
    int detectedCount = 0;
    final keys = ['calories', 'protein', 'fat', 'carbs', 'sugar', 'sodium'];
    for (var key in keys) {
      if (nutrition[key] != null) detectedCount++;
    }
    return (detectedCount / keys.length * 100).clamp(0, 100);
  }

  /// 信心度標籤
  Widget _buildConfidenceBadge(double confidence) {
    Color badgeColor;
    if (confidence >= 80) {
      badgeColor = const Color(0xFF10B981);
    } else if (confidence >= 50) {
      badgeColor = const Color(0xFFF59E0B);
    } else {
      badgeColor = const Color(0xFFEF4444);
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            confidence >= 80 ? Icons.verified : Icons.info_outline,
            size: 14,
            color: badgeColor,
          ),
          const SizedBox(width: 4),
          Text(
            '${confidence.toInt()}%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: badgeColor,
            ),
          ),
        ],
      ),
    );
  }

  // ========== ✨ v2.1: 儲存到我的食物功能 ==========

  /// ✨ v2.1: 儲存到我的食物
  Future<void> _saveToMyFoods() async {
    final nameController = TextEditingController(text: '掃描食品');
    
    final foodName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.bookmark_add, color: Color(0xFF8B5CF6), size: 20),
            ),
            const SizedBox(width: 12),
            const Text('儲存到我的食物', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('輸入食物名稱，方便下次快速記錄', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '例如：統一布丁、光泉鮮乳',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.pop(context, nameController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('儲存', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (foodName == null || foodName.isEmpty) return;

    try {
      final foodService = FoodDatabaseService();
      await foodService.saveScannedFood(name: foodName, nutrition: _editedNutrition);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('「$foodName」已儲存到我的食物')),
              ],
            ),
            backgroundColor: const Color(0xFF8B5CF6),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            action: SnackBarAction(label: '繼續記錄', textColor: Colors.white, onPressed: _goToAddLog),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('儲存失敗: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// ✨ v2.1: 加入最愛
  Future<void> _addToFavorites() async {
    final nameController = TextEditingController(text: '掃描食品');
    
    final foodName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEC4899).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.favorite, color: Color(0xFFEC4899), size: 20),
            ),
            const SizedBox(width: 12),
            const Text('加入最愛', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('輸入食物名稱，方便下次快速記錄', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '例如：統一布丁、光泉鮮乳',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFEC4899), width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.pop(context, nameController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEC4899),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('加入', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (foodName == null || foodName.isEmpty) return;

    try {
      final foodService = FoodDatabaseService();
      await foodService.saveScannedFoodAndAddToFavorites(name: foodName, nutrition: _editedNutrition);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.favorite, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('已加入最愛'),
              ],
            ),
            backgroundColor: const Color(0xFFEC4899),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加入最愛失敗: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// ✨ v2.1: 操作按鈕區域（包含儲存到我的食物、加入最愛、確認並記錄）
  Widget _buildActionButtons() {
    return Column(
      children: [
        // 快速操作按鈕列
        Row(
          children: [
            // 儲存到我的食物
            Expanded(
              child: GestureDetector(
                onTap: _saveToMyFoods,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bookmark_add, color: Color(0xFF8B5CF6), size: 20),
                      SizedBox(width: 8),
                      Text('存到我的食物', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF8B5CF6))),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 加入最愛
            Expanded(
              child: GestureDetector(
                onTap: _addToFavorites,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEC4899).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFEC4899).withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.favorite, color: Color(0xFFEC4899), size: 20),
                      SizedBox(width: 8),
                      Text('加入最愛', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFEC4899))),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        // 主要確認按鈕
        GestureDetector(
          onTap: _goToAddLog,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withOpacity(0.4),
                  offset: const Offset(0, 6),
                  blurRadius: 16,
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 24),
                SizedBox(width: 12),
                Text('確認並記錄', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// ✨ 全螢幕圖片查看器
class _FullScreenImageViewer extends StatefulWidget {
  final File imageFile;
  final Animation<double> animation;

  const _FullScreenImageViewer({
    required this.imageFile,
    required this.animation,
  });

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  final TransformationController _transformationController = TransformationController();
  double _currentScale = 1.0;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    if (_currentScale != 1.0) {
      // 如果已經放大，則恢復原始大小
      _transformationController.value = Matrix4.identity();
      _currentScale = 1.0;
    } else {
      // 放大到 2 倍
      _transformationController.value = Matrix4.identity()..scale(2.0);
      _currentScale = 2.0;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 背景（點擊關閉）
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(color: Colors.transparent),
          ),
          
          // 圖片查看區域
          Center(
            child: GestureDetector(
              onDoubleTap: _handleDoubleTap,
              child: InteractiveViewer(
                transformationController: _transformationController,
                minScale: 0.5,
                maxScale: 4.0,
                onInteractionEnd: (details) {
                  _currentScale = _transformationController.value.getMaxScaleOnAxis();
                },
                child: Hero(
                  tag: 'ocr_image',
                  child: Image.file(
                    widget.imageFile,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          
          // 頂部操作欄
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 關閉按鈕
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                    
                    // 提示文字
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '雙擊放大 · 捏合縮放',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    
                    // 佔位（保持對稱）
                    const SizedBox(width: 44),
                  ],
                ),
              ),
            ),
          ),
          
          // 底部縮放比例指示器
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Center(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${(_currentScale * 100).toInt()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}