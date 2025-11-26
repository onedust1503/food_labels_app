// lib/pages/nutrition/ocr_scan_page.dart
// ✨ Soft UI 風格升級版 - 支援 YOLO 和 Google Cloud Vision 雙引擎
// v2.0: 現代化 UI + shimmer 動畫 + 營養素網格顯示

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/ocr_service.dart';
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

    final nutrition = _recognizedData!['nutrition'] ?? {};
    
    // ✨ 轉換成 foodData 格式，與其他記錄方式一致
    final foodData = {
      'name': '掃描食品',  // 預設名稱，用戶可以在下一頁編輯
      'calories': (nutrition['calories'] ?? 0).toDouble(),
      'protein': (nutrition['protein'] ?? 0).toDouble(),
      'fat': (nutrition['fat'] ?? 0).toDouble(),
      'carbs': (nutrition['carbs'] ?? 0).toDouble(),
      'servingSize': '每份',
      'isScanned': true,  // ✨ 標記為掃描記錄
      // 額外營養素
      'sugar': nutrition['sugar']?.toDouble(),
      'sodium': nutrition['sodium']?.toDouble(),
      'saturatedFat': nutrition['saturated']?.toDouble(),
      'transFat': nutrition['transFat']?.toDouble(),
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
            _buildConfirmButton()
                .animate(delay: 300.ms)
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.2, end: 0),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
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
    final nutrition = _recognizedData!['nutrition'] ?? {};
    final confidence = _calculateConfidence(nutrition);
    
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
          
          const SizedBox(height: 24),
          
          // 熱量（大顯示）
          _buildCaloriesRow(nutrition['calories']),
          
          const SizedBox(height: 20),
          
          // 三大營養素網格
          Row(
            children: [
              Expanded(
                child: _buildNutrientItem(
                  label: '蛋白質',
                  value: nutrition['protein'],
                  unit: 'g',
                  color: const Color(0xFFEF4444),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildNutrientItem(
                  label: '碳水化合物',
                  value: nutrition['carbs'],
                  unit: 'g',
                  color: const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildNutrientItem(
                  label: '脂肪',
                  value: nutrition['fat'],
                  unit: 'g',
                  color: const Color(0xFF8B5CF6),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // 其他營養素
          Row(
            children: [
              Expanded(
                child: _buildNutrientItem(
                  label: '糖',
                  value: nutrition['sugar'],
                  unit: 'g',
                  color: const Color(0xFFEC4899),
                  compact: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildNutrientItem(
                  label: '鈉',
                  value: nutrition['sodium'],
                  unit: 'mg',
                  color: const Color(0xFF06B6D4),
                  compact: true,
                ),
              ),
            ],
          ),
          
          // 飽和脂肪 & 反式脂肪
          if (nutrition['saturated'] != null || nutrition['transFat'] != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildNutrientItem(
                    label: '飽和脂肪',
                    value: nutrition['saturated'],
                    unit: 'g',
                    color: const Color(0xFF64748B),
                    compact: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildNutrientItem(
                    label: '反式脂肪',
                    value: nutrition['transFat'],
                    unit: 'g',
                    color: const Color(0xFF64748B),
                    compact: true,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    )
        .animate(delay: 200.ms)
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.1, end: 0);
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

  /// 熱量行（大顯示）
  Widget _buildCaloriesRow(dynamic calories) {
    final value = calories?.toString() ?? '未偵測';
    final hasValue = calories != null;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: hasValue 
              ? [const Color(0xFFFF6B6B).withOpacity(0.1), const Color(0xFFFFE66D).withOpacity(0.05)]
              : [Colors.grey.withOpacity(0.1), Colors.grey.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasValue 
              ? const Color(0xFFFF6B6B).withOpacity(0.2)
              : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: hasValue 
                  ? const Color(0xFFFF6B6B).withOpacity(0.2)
                  : Colors.grey.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.local_fire_department,
              color: hasValue ? const Color(0xFFFF6B6B) : Colors.grey,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Column(
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
                    hasValue ? value : '未偵測',
                    style: TextStyle(
                      fontSize: hasValue ? 32 : 20,
                      fontWeight: FontWeight.bold,
                      color: hasValue ? const Color(0xFFFF6B6B) : Colors.grey,
                    ),
                  ),
                  if (hasValue) ...[
                    const SizedBox(width: 4),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Text(
                        '大卡',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFFFF6B6B),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 營養素項目
  Widget _buildNutrientItem({
    required String label,
    required dynamic value,
    required String unit,
    required Color color,
    bool compact = false,
  }) {
    final hasValue = value != null;
    final displayValue = hasValue ? value.toString() : '-';
    
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: hasValue ? color.withOpacity(0.08) : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasValue ? color.withOpacity(0.15) : Colors.grey.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
                      fontSize: compact ? 11 : 12,
                      fontWeight: FontWeight.w500,
                      color: color.withOpacity(0.8),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// 確認按鈕
  Widget _buildConfirmButton() {
    return GestureDetector(
      onTap: _goToAddLog,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF10B981), Color(0xFF059669)],
          ),
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
            Text(
              '確認並記錄',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}