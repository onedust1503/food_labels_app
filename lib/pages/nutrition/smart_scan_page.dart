// lib/pages/nutrition/smart_scan_page.dart
// ✨ 智慧掃描頁面 v4.2 - 修正 AI 確認流程
// 基於 v4.1 修改，修正 _confirmAiResult() 方法
// 響應式設計 + OCR 可編輯 + AI 辨識

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/ocr_service.dart';
import '../../services/ai_food_service.dart';
import '../../services/food_database_service.dart';
import '../../theme/app_colors.dart';
import 'add_nutrition_log_page.dart';
import 'ai_food_confirm_page.dart';

/// 掃描模式
enum ScanMode { aiFood, ocrLabel }

/// 響應式尺寸類別
enum ScreenSize { small, medium, large }

class SmartScanPage extends StatefulWidget {
  const SmartScanPage({super.key});

  @override
  State<SmartScanPage> createState() => _SmartScanPageState();
}

class _SmartScanPageState extends State<SmartScanPage>
    with SingleTickerProviderStateMixin {
  // ========== 控制器 ==========
  late TabController _tabController;
  final ImagePicker _picker = ImagePicker();
  final ScrollController _aiScrollController = ScrollController();
  final ScrollController _ocrScrollController = ScrollController();

  // ========== 共用狀態 ==========
  ScanMode _currentMode = ScanMode.aiFood;
  File? _selectedImage;
  bool _isProcessing = false;
  String? _errorMessage;

  // ========== OCR 相關狀態 ==========
  final OcrService _ocrService = OcrService();
  OcrEngine _currentEngine = OcrEngine.google;
  Map<String, dynamic>? _ocrResult;
  final Map<String, double?> _editedNutrition = {};
  String? _usedEngine;
  int? _latencyMs;

  // ========== AI 相關狀態 ==========
  final AIFoodService _aiService = AIFoodService();
  FoodAnalysisResult? _aiResult;
  int? _selectedFoodIndex;
  final Map<int, GlobalKey> _foodCardKeys = {};
  String _mealType = '午餐';
  String _userGoal = '維持';
  int _currentRetry = 0;
  int _maxRetries = 3;
  bool _isRetrying = false;

  // ========== Soft UI 色系 ==========
  static const Color _bgColor = Color(0xFFF5F6F8);
  static const Color _cardColor = Color(0xFFFFFFFF);
  static const Color _primaryColor = Color(0xFF5B9A8B);
  static const Color _textPrimary = Color(0xFF2D3436);
  static const Color _textSecondary = Color(0xFF636E72);

  // AI 食物顏色
  static const List<Color> _foodColors = [
    Color(0xFF5B9A8B),
    Color(0xFF5B8FB9),
    Color(0xFFE8A87C),
    Color(0xFFD88B9A),
    Color(0xFF9B8DC9),
    Color(0xFF5BB5B0),
    Color(0xFFE8907C),
    Color(0xFF8B85C9),
  ];

  // OCR 營養素定義
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
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadCurrentEngine();
    _autoSelectMealType();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _aiScrollController.dispose();
    _ocrScrollController.dispose();
    super.dispose();
  }

  // ========== 響應式尺寸計算（完整保留 v3.0） ==========
  ScreenSize _getScreenSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 360) return ScreenSize.small;
    if (width < 400) return ScreenSize.medium;
    return ScreenSize.large;
  }

  double _getResponsiveValue(BuildContext context, {
    required double small,
    required double medium,
    required double large,
  }) {
    switch (_getScreenSize(context)) {
      case ScreenSize.small:
        return small;
      case ScreenSize.medium:
        return medium;
      case ScreenSize.large:
        return large;
    }
  }

  EdgeInsets _getResponsivePadding(BuildContext context) {
    final size = _getScreenSize(context);
    switch (size) {
      case ScreenSize.small:
        return const EdgeInsets.all(12);
      case ScreenSize.medium:
        return const EdgeInsets.all(16);
      case ScreenSize.large:
        return const EdgeInsets.all(20);
    }
  }

  EdgeInsets _getCardPadding(BuildContext context) {
    final size = _getScreenSize(context);
    switch (size) {
      case ScreenSize.small:
        return const EdgeInsets.all(14);
      case ScreenSize.medium:
        return const EdgeInsets.all(18);
      case ScreenSize.large:
        return const EdgeInsets.all(20);
    }
  }

  double _getTitleFontSize(BuildContext context) =>
      _getResponsiveValue(context, small: 15, medium: 17, large: 18);

  double _getSubtitleFontSize(BuildContext context) =>
      _getResponsiveValue(context, small: 12, medium: 13, large: 14);

  double _getBodyFontSize(BuildContext context) =>
      _getResponsiveValue(context, small: 11, medium: 12, large: 13);

  double _getLargeFontSize(BuildContext context) =>
      _getResponsiveValue(context, small: 26, medium: 30, large: 32);

  double _getImageHeight(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    if (height < 700) return 200;
    if (height < 800) return 240;
    return 280;
  }

  double _getIconSize(BuildContext context, {bool large = false}) {
    if (large) {
      return _getResponsiveValue(context, small: 40, medium: 48, large: 56);
    }
    return _getResponsiveValue(context, small: 18, medium: 20, large: 22);
  }

  double _getBorderRadius(BuildContext context, {bool large = false}) {
    if (large) {
      return _getResponsiveValue(context, small: 16, medium: 20, large: 24);
    }
    return _getResponsiveValue(context, small: 10, medium: 12, large: 14);
  }

  double _getSpacing(BuildContext context, {bool large = false}) {
    if (large) {
      return _getResponsiveValue(context, small: 14, medium: 18, large: 20);
    }
    return _getResponsiveValue(context, small: 8, medium: 10, large: 12);
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        _currentMode = _tabController.index == 0 ? ScanMode.aiFood : ScanMode.ocrLabel;
        _clearResults();
      });
    }
  }

  void _clearResults() {
    _ocrResult = null;
    _aiResult = null;
    _errorMessage = null;
    _selectedFoodIndex = null;
    _editedNutrition.clear();
    _foodCardKeys.clear();
    _usedEngine = null;
    _latencyMs = null;
  }

  Future<void> _loadCurrentEngine() async {
    final engine = await OcrService.getCurrentEngine();
    setState(() => _currentEngine = engine);
  }

  void _autoSelectMealType() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 10) {
      _mealType = '早餐';
    } else if (hour >= 10 && hour < 14) {
      _mealType = '午餐';
    } else if (hour >= 14 && hour < 17) {
      _mealType = '點心';
    } else if (hour >= 17 && hour < 21) {
      _mealType = '晚餐';
    } else {
      _mealType = '宵夜';
    }
  }

  Color _getColor(int index) => _foodColors[index % _foodColors.length];

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ========== 圖片選擇 ==========
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 90,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _clearResults();
        });
        _startRecognition();
      }
    } catch (e) {
      _showSnackBar('選擇圖片失敗: $e', isError: true);
    }
  }

  // ========== 開始辨識 ==========
  Future<void> _startRecognition() async {
    if (_selectedImage == null) return;

    if (_currentMode == ScanMode.ocrLabel) {
      await _startOcrRecognition();
    } else {
      await _startAiRecognition();
    }
  }

  // ========== OCR 辨識 ==========
  Future<void> _startOcrRecognition() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    final startTime = DateTime.now();

    try {
      Map<String, dynamic> result =
          await _ocrService.recognizeNutritionLabel(_selectedImage!);

      final elapsed = DateTime.now().difference(startTime).inMilliseconds;

      final nutrition = result['nutrition'] ?? {};
      _editedNutrition.clear();
      for (var def in _nutrientDefinitions) {
        final key = def['key'] as String;
        final value = nutrition[key];
        _editedNutrition[key] = value?.toDouble();
      }
      if (nutrition['saturated'] != null && _editedNutrition['saturatedFat'] == null) {
        _editedNutrition['saturatedFat'] = nutrition['saturated']?.toDouble();
      }

      setState(() {
        _ocrResult = result;
        _isProcessing = false;
        _usedEngine = result['engine'] ?? (_currentEngine == OcrEngine.yolo ? 'yolo' : 'google');
        _latencyMs = elapsed;
      });

      final engineName = _usedEngine == 'yolo' ? 'YOLO' : 'Google';
      _showSnackBar('辨識完成！使用 $engineName，耗時 ${elapsed}ms');
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isProcessing = false;
      });
    }
  }

  // ========== AI 辨識 ==========
  Future<void> _startAiRecognition() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _aiResult = null;
      _currentRetry = 0;
      _isRetrying = false;
      _selectedFoodIndex = null;
    });

    try {
      final result = await _aiService.analyzeFood(
        _selectedImage!,
        mealType: _mealType,
        userGoal: _userGoal,
        onRetry: (attempt, maxAttempts) {
          setState(() {
            _currentRetry = attempt;
            _maxRetries = maxAttempts;
            _isRetrying = true;
          });
        },
      );

      setState(() {
        _aiResult = result;
        _isProcessing = false;
        _isRetrying = false;
        for (int i = 0; i < result.foods.length; i++) {
          _foodCardKeys[i] = GlobalKey();
        }
      });

      _showSnackBar('AI 辨識完成！共 ${result.foods.length} 項食物');
    } on AIFoodServiceException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isProcessing = false;
        _isRetrying = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '[UNKNOWN] $e';
        _isProcessing = false;
        _isRetrying = false;
      });
    }
  }

  // ========== Build（改用 NestedScrollView + SliverAppBar） ==========
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildSliverAppBar(context, innerBoxIsScrolled),
        ],
        body: TabBarView(
          controller: _tabController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildAiModeContent(context),
            _buildOcrModeContent(context),
          ],
        ),
      ),
    );
  }

  // ========== SliverAppBar（新增：可收合） ==========
  Widget _buildSliverAppBar(BuildContext context, bool innerBoxIsScrolled) {
    final topPadding = MediaQuery.of(context).padding.top;
    final titleSize = _getTitleFontSize(context);
    final fontSize = _getSubtitleFontSize(context);
    final iconSize = _getResponsiveValue(context, small: 16, medium: 17, large: 18);

    return SliverAppBar(
      expandedHeight: _getResponsiveValue(context, small: 95, medium: 105, large: 115) + topPadding,
      collapsedHeight: kToolbarHeight,
      pinned: true,
      floating: false,
      snap: false,
      elevation: innerBoxIsScrolled ? 2 : 0,
      backgroundColor: _primaryColor,
      foregroundColor: Colors.white,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new, size: _getIconSize(context) - 2),
        onPressed: () => Navigator.pop(context),
      ),
      title: innerBoxIsScrolled
          ? Text('智慧掃描', style: TextStyle(fontWeight: FontWeight.w600, fontSize: titleSize))
          : null,
      actions: [
        // OCR 模式顯示引擎選擇
        if (_currentMode == ScanMode.ocrLabel)
          GestureDetector(
            onTap: _showEngineSelector,
            child: Container(
              margin: EdgeInsets.only(right: _getSpacing(context)),
              padding: EdgeInsets.symmetric(
                horizontal: _getSpacing(context),
                vertical: _getSpacing(context) / 2,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(_getBorderRadius(context)),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _currentEngine == OcrEngine.yolo ? Icons.smart_toy : Icons.cloud,
                    size: _getResponsiveValue(context, small: 14, medium: 15, large: 16),
                    color: Colors.white,
                  ),
                  SizedBox(width: _getSpacing(context) / 2),
                  Text(
                    _currentEngine == OcrEngine.yolo ? 'YOLO' : 'Google',
                    style: TextStyle(
                      fontSize: _getBodyFontSize(context),
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        // 重置按鈕
        if (_selectedImage != null)
          IconButton(
            icon: Icon(Icons.refresh_rounded, size: _getIconSize(context)),
            onPressed: () {
              setState(() {
                _selectedImage = null;
                _clearResults();
              });
            },
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF5B9A8B), Color(0xFF4E8A7C)],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // 標題區域（會被收起）
                Padding(
                  padding: EdgeInsets.only(top: _getResponsiveValue(context, small: 6, medium: 8, large: 10)),
                  child: Text(
                    '智慧掃描',
                    style: TextStyle(
                      fontSize: _getResponsiveValue(context, small: 17, medium: 19, large: 21),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
      // TabBar 固定在底部
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(_getResponsiveValue(context, small: 44, medium: 48, large: 52)),
        child: Container(
          margin: EdgeInsets.fromLTRB(
            _getSpacing(context, large: true),
            0,
            _getSpacing(context, large: true),
            _getResponsiveValue(context, small: 10, medium: 12, large: 14),
          ),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(_getBorderRadius(context)),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(_getBorderRadius(context) - 2),
            ),
            indicatorPadding: EdgeInsets.all(_getResponsiveValue(context, small: 3, medium: 4, large: 4)),
            labelColor: _primaryColor,
            unselectedLabelColor: Colors.white,
            labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: fontSize),
            dividerColor: Colors.transparent,
            tabs: [
              Tab(
                height: _getResponsiveValue(context, small: 36, medium: 40, large: 44),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_awesome, size: iconSize),
                    SizedBox(width: _getSpacing(context) / 2),
                    Text('食物辨識', style: TextStyle(fontSize: fontSize)),
                  ],
                ),
              ),
              Tab(
                height: _getResponsiveValue(context, small: 36, medium: 40, large: 44),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.qr_code_scanner, size: iconSize),
                    SizedBox(width: _getSpacing(context) / 2),
                    Text('標籤掃描', style: TextStyle(fontSize: fontSize)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========== 響應式 Soft UI 卡片（完整保留 v3.0） ==========
  Widget _softCard(BuildContext context, {required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? _getCardPadding(context),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(_getBorderRadius(context, large: true)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
          const BoxShadow(
            color: Colors.white,
            blurRadius: 10,
            offset: Offset(-5, -5),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionHeader(BuildContext context, IconData icon, String title) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(_getSpacing(context)),
          decoration: BoxDecoration(
            color: _primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(_getBorderRadius(context)),
          ),
          child: Icon(icon, color: _primaryColor, size: _getIconSize(context) - 2),
        ),
        SizedBox(width: _getSpacing(context)),
        Text(
          title,
          style: TextStyle(
            fontSize: _getTitleFontSize(context) - 2,
            fontWeight: FontWeight.w600,
            color: _textPrimary,
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // ██  AI 模式內容（完整保留 v3.0）
  // ══════════════════════════════════════════════════════════════════

  Widget _buildAiModeContent(BuildContext context) {
    final padding = _getResponsivePadding(context);
    final spacing = _getSpacing(context, large: true);

    return SingleChildScrollView(
      controller: _aiScrollController,
      physics: const BouncingScrollPhysics(),
      padding: padding,
      child: Column(
        children: [
          _buildAiSettingsCard(context),
          SizedBox(height: spacing),
          _buildImageCard(context),
          SizedBox(height: spacing),

          if (_selectedImage != null && _aiResult == null && !_isProcessing)
            _buildAiAnalyzeButton(context),

          if (_isProcessing && _currentMode == ScanMode.aiFood)
            _buildAiProcessingState(context),

          if (_isRetrying) ...[
            SizedBox(height: _getSpacing(context)),
            _buildRetryCard(context),
          ],

          if (_errorMessage != null && _currentMode == ScanMode.aiFood) ...[
            SizedBox(height: _getSpacing(context)),
            _buildErrorCard(context),
          ],

          if (_aiResult != null) ...[
            SizedBox(height: spacing),
            _buildFoodLegend(context),
            SizedBox(height: spacing),
            _buildNutritionCard(context),
            SizedBox(height: spacing),
            _buildFoodsCard(context),
            SizedBox(height: spacing),
            if (_aiResult!.mealAssessment != null) ...[
              _buildAssessmentCard(context),
              SizedBox(height: spacing),
            ],
            if (_aiResult!.recommendations.isNotEmpty)
              _buildRecommendationsCard(context),
            SizedBox(height: spacing),
            _buildAiConfirmButton(context),
            const SizedBox(height: 40),
          ],
        ],
      ),
    );
  }

  // AI 設定卡片
  Widget _buildAiSettingsCard(BuildContext context) {
    return _softCard(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(context, Icons.tune_rounded, '分析設定'),
          SizedBox(height: _getSpacing(context, large: true)),
          Row(
            children: [
              Expanded(child: _buildDropdown(context, '餐別', _mealType, ['早餐', '午餐', '晚餐', '點心', '宵夜'], (v) => setState(() => _mealType = v!))),
              SizedBox(width: _getSpacing(context, large: true)),
              Expanded(child: _buildDropdown(context, '健身目標', _userGoal, ['減脂', '增肌', '維持'], (v) => setState(() => _userGoal = v!))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(BuildContext context, String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    final fontSize = _getBodyFontSize(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: fontSize, color: _textSecondary)),
        SizedBox(height: _getSpacing(context) / 2),
        Container(
          padding: EdgeInsets.symmetric(horizontal: _getSpacing(context)),
          decoration: BoxDecoration(
            color: _bgColor,
            borderRadius: BorderRadius.circular(_getBorderRadius(context)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: Icon(Icons.keyboard_arrow_down_rounded, color: _textSecondary, size: _getIconSize(context)),
              style: TextStyle(color: _textPrimary, fontSize: _getSubtitleFontSize(context)),
              items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  // AI 分析按鈕
  Widget _buildAiAnalyzeButton(BuildContext context) {
    return GestureDetector(
      onTap: _startAiRecognition,
      child: Container(
        height: _getResponsiveValue(context, small: 48, medium: 52, large: 56),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF5B9A8B), Color(0xFF4E8A7C)]),
          borderRadius: BorderRadius.circular(_getBorderRadius(context, large: true)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF5B9A8B).withOpacity(0.35),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_rounded, color: Colors.white, size: _getIconSize(context)),
              SizedBox(width: _getSpacing(context)),
              Text(
                '開始 AI 分析',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: _getTitleFontSize(context) - 2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // AI 處理中
  Widget _buildAiProcessingState(BuildContext context) {
    return _softCard(
      context,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(_getSpacing(context, large: true)),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: SizedBox(
              width: _getResponsiveValue(context, small: 28, medium: 30, large: 32),
              height: _getResponsiveValue(context, small: 28, medium: 30, large: 32),
              child: const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                strokeWidth: 3,
              ),
            ),
          ),
          SizedBox(height: _getSpacing(context, large: true)),
          Text(
            _isRetrying ? '重試中...' : 'AI 分析中...',
            style: TextStyle(
              fontSize: _getTitleFontSize(context) - 2,
              fontWeight: FontWeight.w600,
              color: _textPrimary,
            ),
          ),
          SizedBox(height: _getSpacing(context)),
          Text(
            '正在辨識食物並估算營養',
            style: TextStyle(fontSize: _getSubtitleFontSize(context), color: _textSecondary),
          ),
        ],
      ),
    ).animate(onPlay: (c) => c.repeat()).shimmer(
          duration: 1500.ms,
          color: _primaryColor.withOpacity(0.1),
        );
  }

  // 重試卡片
  Widget _buildRetryCard(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(_getSpacing(context, large: true)),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E6),
        borderRadius: BorderRadius.circular(_getBorderRadius(context, large: true)),
        border: Border.all(color: const Color(0xFFFFE4A0)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _getIconSize(context),
            height: _getIconSize(context),
            child: const CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(Color(0xFFE8A000)),
            ),
          ),
          SizedBox(width: _getSpacing(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI 服務忙碌中',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFB87A00),
                    fontSize: _getSubtitleFontSize(context),
                  ),
                ),
                Text(
                  '正在重試 ($_currentRetry/$_maxRetries)...',
                  style: TextStyle(fontSize: _getBodyFontSize(context), color: const Color(0xFFB87A00)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 錯誤卡片
  Widget _buildErrorCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(_getBorderRadius(context, large: true)),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(_getSpacing(context, large: true)),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(_getSpacing(context)),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(_getBorderRadius(context)),
                  ),
                  child: Icon(
                    Icons.error_outline_rounded,
                    color: const Color(0xFFDC2626),
                    size: _getIconSize(context) - 2,
                  ),
                ),
                SizedBox(width: _getSpacing(context)),
                Text(
                  '辨識失敗',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFDC2626),
                    fontSize: _getSubtitleFontSize(context),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.copy_rounded, size: _getIconSize(context) - 2, color: const Color(0xFFDC2626)),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _errorMessage ?? ''));
                    _showSnackBar('已複製錯誤訊息');
                  },
                ),
              ],
            ),
          ),
          Container(
            margin: EdgeInsets.fromLTRB(
              _getSpacing(context, large: true),
              0,
              _getSpacing(context, large: true),
              _getSpacing(context, large: true),
            ),
            padding: EdgeInsets.all(_getSpacing(context)),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(_getBorderRadius(context)),
            ),
            child: SelectableText(
              _errorMessage!,
              style: TextStyle(
                fontSize: _getBodyFontSize(context) - 1,
                fontFamily: 'monospace',
                color: const Color(0xFF991B1B),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              _getSpacing(context, large: true),
              0,
              _getSpacing(context, large: true),
              _getSpacing(context, large: true),
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _startRecognition,
                icon: Icon(Icons.refresh_rounded, size: _getIconSize(context) - 4),
                label: Text('重試', style: TextStyle(fontSize: _getSubtitleFontSize(context))),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: _getSpacing(context)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_getBorderRadius(context))),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 食物圖例
  Widget _buildFoodLegend(BuildContext context) {
    if (_aiResult == null || _aiResult!.foods.isEmpty) return const SizedBox.shrink();

    final fontSize = _getBodyFontSize(context);

    return _softCard(
      context,
      padding: EdgeInsets.all(_getSpacing(context, large: true)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.touch_app_rounded, color: _primaryColor, size: _getIconSize(context) - 2),
              SizedBox(width: _getSpacing(context)),
              Text(
                '點擊食物可高亮顯示',
                style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w500, color: _textSecondary),
              ),
            ],
          ),
          SizedBox(height: _getSpacing(context)),
          Wrap(
            spacing: _getSpacing(context),
            runSpacing: _getSpacing(context),
            children: List.generate(_aiResult!.foods.length, (i) {
              final food = _aiResult!.foods[i];
              final color = _getColor(i);
              final isSelected = _selectedFoodIndex == i;

              return GestureDetector(
                onTap: () => _onFoodTap(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(
                    horizontal: _getSpacing(context),
                    vertical: _getSpacing(context) / 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? color : Colors.white,
                    borderRadius: BorderRadius.circular(_getBorderRadius(context, large: true)),
                    border: Border.all(
                      color: isSelected ? color : color.withOpacity(0.5),
                      width: 1.5,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: _getResponsiveValue(context, small: 18, medium: 20, large: 22),
                        height: _getResponsiveValue(context, small: 18, medium: 20, large: 22),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : color,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: isSelected ? color : Colors.white,
                              fontSize: _getBodyFontSize(context) - 1,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: _getSpacing(context) / 1.5),
                      Text(
                        food.name,
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : _textPrimary,
                        ),
                      ),
                      SizedBox(width: _getSpacing(context) / 2),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: _getSpacing(context) / 1.5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white.withOpacity(0.25) : color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(_getBorderRadius(context)),
                        ),
                        child: Text(
                          '${food.calories.toInt()}kcal',
                          style: TextStyle(
                            fontSize: _getBodyFontSize(context) - 2,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  void _onFoodTap(int index) {
    setState(() {
      _selectedFoodIndex = _selectedFoodIndex == index ? null : index;
    });

    final key = _foodCardKeys[index];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        alignment: 0.3,
      );
    }
  }

  // 營養總計卡片
  Widget _buildNutritionCard(BuildContext context) {
    final total = _aiResult!.total;
    final screenSize = _getScreenSize(context);
    
    // 小螢幕用 2x3 網格，大螢幕用 4+2 排列
    if (screenSize == ScreenSize.small) {
      return _softCard(
        context,
        child: Column(
          children: [
            Row(
              children: [
                _sectionHeader(context, Icons.local_fire_department_rounded, '營養總計'),
                const Spacer(),
                _confidenceBadge(context, _aiResult!.overallConfidence),
              ],
            ),
            SizedBox(height: _getSpacing(context, large: true)),
            // 2x3 網格
            Row(
              children: [
                Expanded(child: _nutrientBox(context, '熱量', '${total.calories.toInt()}', 'kcal', const Color(0xFFE57373))),
                SizedBox(width: _getSpacing(context)),
                Expanded(child: _nutrientBox(context, '蛋白質', total.protein.toStringAsFixed(1), 'g', const Color(0xFF64B5F6))),
              ],
            ),
            SizedBox(height: _getSpacing(context)),
            Row(
              children: [
                Expanded(child: _nutrientBox(context, '碳水', total.carbs.toStringAsFixed(1), 'g', const Color(0xFFFFB74D))),
                SizedBox(width: _getSpacing(context)),
                Expanded(child: _nutrientBox(context, '脂肪', total.fat.toStringAsFixed(1), 'g', const Color(0xFF81C784))),
              ],
            ),
            SizedBox(height: _getSpacing(context)),
            Row(
              children: [
                Expanded(child: _nutrientBox(context, '糖', total.sugar.toStringAsFixed(1), 'g', const Color(0xFFEC4899))),
                SizedBox(width: _getSpacing(context)),
                Expanded(child: _nutrientBox(context, '膳食纖維', total.fiber.toStringAsFixed(1), 'g', const Color(0xFF22C55E))),
              ],
            ),
          ],
        ),
      );
    }

    // 中大螢幕用 4+2 排列
    return _softCard(
      context,
      child: Column(
        children: [
          Row(
            children: [
              _sectionHeader(context, Icons.local_fire_department_rounded, '營養總計'),
              const Spacer(),
              _confidenceBadge(context, _aiResult!.overallConfidence),
            ],
          ),
          SizedBox(height: _getSpacing(context, large: true)),
          Row(
            children: [
              Expanded(child: _nutrientBox(context, '熱量', '${total.calories.toInt()}', 'kcal', const Color(0xFFE57373))),
              SizedBox(width: _getSpacing(context)),
              Expanded(child: _nutrientBox(context, '蛋白質', total.protein.toStringAsFixed(1), 'g', const Color(0xFF64B5F6))),
              SizedBox(width: _getSpacing(context)),
              Expanded(child: _nutrientBox(context, '碳水', total.carbs.toStringAsFixed(1), 'g', const Color(0xFFFFB74D))),
              SizedBox(width: _getSpacing(context)),
              Expanded(child: _nutrientBox(context, '脂肪', total.fat.toStringAsFixed(1), 'g', const Color(0xFF81C784))),
            ],
          ),
          SizedBox(height: _getSpacing(context)),
          Row(
            children: [
              Expanded(child: _nutrientBox(context, '糖', total.sugar.toStringAsFixed(1), 'g', const Color(0xFFEC4899))),
              SizedBox(width: _getSpacing(context)),
              Expanded(child: _nutrientBox(context, '膳食纖維', total.fiber.toStringAsFixed(1), 'g', const Color(0xFF22C55E))),
              SizedBox(width: _getSpacing(context)),
              const Expanded(child: SizedBox()),
              SizedBox(width: _getSpacing(context)),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _nutrientBox(BuildContext context, String label, String value, String unit, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: _getSpacing(context)),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(_getBorderRadius(context)),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: _getBodyFontSize(context) - 1, color: _textSecondary)),
          SizedBox(height: _getSpacing(context) / 3),
          Text(
            value,
            style: TextStyle(
              fontSize: _getResponsiveValue(context, small: 16, medium: 18, large: 20),
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(unit, style: TextStyle(fontSize: _getBodyFontSize(context) - 2, color: _textSecondary)),
        ],
      ),
    );
  }

  Widget _confidenceBadge(BuildContext context, String confidence) {
    Color color;
    String text;
    IconData icon;
    switch (confidence) {
      case 'high':
        color = const Color(0xFF22C55E);
        text = '高準確度';
        icon = Icons.verified_rounded;
        break;
      case 'low':
        color = const Color(0xFFF59E0B);
        text = '低準確度';
        icon = Icons.warning_rounded;
        break;
      default:
        color = const Color(0xFF3B82F6);
        text = '中準確度';
        icon = Icons.check_circle_outline_rounded;
    }
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _getSpacing(context),
        vertical: _getSpacing(context) / 2,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(_getBorderRadius(context, large: true)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: _getBodyFontSize(context), color: color),
          SizedBox(width: _getSpacing(context) / 3),
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w500, fontSize: _getBodyFontSize(context) - 1)),
        ],
      ),
    );
  }

  // 食物列表卡片
  Widget _buildFoodsCard(BuildContext context) {
    return _softCard(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(context, Icons.restaurant_rounded, '辨識食物 (${_aiResult!.foods.length}項)'),
          SizedBox(height: _getSpacing(context, large: true)),
          ...List.generate(_aiResult!.foods.length, (i) => _foodItem(context, _aiResult!.foods[i], i)),
        ],
      ),
    );
  }

  Widget _foodItem(BuildContext context, FoodItem food, int index) {
    final color = _getColor(index);
    final isSelected = _selectedFoodIndex == index;

    return GestureDetector(
      key: _foodCardKeys[index],
      onTap: () => _onFoodTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: EdgeInsets.only(bottom: _getSpacing(context)),
        padding: EdgeInsets.all(_getSpacing(context)),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.06) : _bgColor,
          borderRadius: BorderRadius.circular(_getBorderRadius(context)),
          border: Border.all(
            color: isSelected ? color.withOpacity(0.4) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: _getResponsiveValue(context, small: 22, medium: 24, large: 26),
                  height: _getResponsiveValue(context, small: 22, medium: 24, large: 26),
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(color: Colors.white, fontSize: _getBodyFontSize(context), fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                SizedBox(width: _getSpacing(context)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(food.name, style: TextStyle(fontSize: _getSubtitleFontSize(context) + 1, fontWeight: FontWeight.w600)),
                      Text(food.portion, style: TextStyle(fontSize: _getBodyFontSize(context), color: _textSecondary)),
                    ],
                  ),
                ),
                _confidenceBadge(context, food.confidence),
              ],
            ),
            SizedBox(height: _getSpacing(context)),
            Wrap(
              spacing: _getSpacing(context) / 1.5,
              runSpacing: _getSpacing(context) / 1.5,
              children: [
                _nutrientTag(context, '${food.calories.toInt()} kcal', const Color(0xFFE57373)),
                _nutrientTag(context, '蛋白 ${food.protein.toStringAsFixed(1)}g', const Color(0xFF64B5F6)),
                _nutrientTag(context, '碳水 ${food.carbs.toStringAsFixed(1)}g', const Color(0xFFFFB74D)),
                _nutrientTag(context, '脂肪 ${food.fat.toStringAsFixed(1)}g', const Color(0xFF81C784)),
                _nutrientTag(context, '糖 ${food.sugar.toStringAsFixed(1)}g', const Color(0xFFEC4899)),
                _nutrientTag(context, '纖維 ${food.fiber.toStringAsFixed(1)}g', const Color(0xFF22C55E)),
              ],
            ),
            if (food.notes != null && food.notes!.isNotEmpty) ...[
              SizedBox(height: _getSpacing(context)),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: _getSpacing(context),
                  vertical: _getSpacing(context) / 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(_getBorderRadius(context)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline_rounded, size: _getBodyFontSize(context), color: _textSecondary),
                    SizedBox(width: _getSpacing(context) / 2),
                    Flexible(
                      child: Text(
                        food.notes!,
                        style: TextStyle(fontSize: _getBodyFontSize(context) - 1, color: _textSecondary, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _nutrientTag(BuildContext context, String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _getSpacing(context),
        vertical: _getSpacing(context) / 2.5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(_getBorderRadius(context)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: _getBodyFontSize(context) - 1, fontWeight: FontWeight.w500, color: color),
      ),
    );
  }

  // 餐點評估卡片
  Widget _buildAssessmentCard(BuildContext context) {
    final assessment = _aiResult!.mealAssessment!;
    final scoreColor = assessment.balanceScore >= 8
        ? const Color(0xFF22C55E)
        : assessment.balanceScore >= 5
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444);

    return _softCard(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _sectionHeader(context, Icons.star_rounded, '餐點評估'),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: _getSpacing(context),
                  vertical: _getSpacing(context) / 2,
                ),
                decoration: BoxDecoration(
                  color: scoreColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(_getBorderRadius(context, large: true)),
                ),
                child: Text(
                  '${assessment.balanceScore}/10',
                  style: TextStyle(color: scoreColor, fontWeight: FontWeight.bold, fontSize: _getSubtitleFontSize(context) + 1),
                ),
              ),
            ],
          ),
          SizedBox(height: _getSpacing(context, large: true)),
          if (assessment.strengths.isNotEmpty)
            _assessmentSection(context, '優點', Icons.check_circle_rounded, const Color(0xFF22C55E), assessment.strengths),
          if (assessment.improvements.isNotEmpty) ...[
            SizedBox(height: _getSpacing(context)),
            _assessmentSection(context, '可改進', Icons.lightbulb_rounded, const Color(0xFFF59E0B), assessment.improvements),
          ],
        ],
      ),
    );
  }

  Widget _assessmentSection(BuildContext context, String title, IconData icon, Color color, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: _getIconSize(context) - 4),
            SizedBox(width: _getSpacing(context)),
            Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: color, fontSize: _getSubtitleFontSize(context))),
          ],
        ),
        SizedBox(height: _getSpacing(context)),
        ...items.map(
          (item) => Padding(
            padding: EdgeInsets.only(left: _getSpacing(context, large: true), bottom: _getSpacing(context) / 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: EdgeInsets.only(top: _getSpacing(context) / 1.5),
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(color: _textSecondary, shape: BoxShape.circle),
                ),
                SizedBox(width: _getSpacing(context)),
                Expanded(
                  child: Text(item, style: TextStyle(color: _textSecondary, fontSize: _getSubtitleFontSize(context), height: 1.5)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // AI 建議卡片
  Widget _buildRecommendationsCard(BuildContext context) {
    final colors = [const Color(0xFFF59E0B), const Color(0xFF3B82F6), const Color(0xFFA855F7)];
    final icons = [Icons.flash_on_rounded, Icons.restaurant_menu_rounded, Icons.lightbulb_rounded];

    return _softCard(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(context, Icons.tips_and_updates_rounded, 'AI 建議'),
          SizedBox(height: _getSpacing(context, large: true)),
          ...List.generate(_aiResult!.recommendations.length, (i) {
            final rec = _aiResult!.recommendations[i];
            final color = colors[i % colors.length];
            final icon = icons[i % icons.length];

            return Container(
              margin: EdgeInsets.only(bottom: _getSpacing(context)),
              padding: EdgeInsets.all(_getSpacing(context)),
              decoration: BoxDecoration(
                color: color.withOpacity(0.05),
                borderRadius: BorderRadius.circular(_getBorderRadius(context)),
                border: Border.all(color: color.withOpacity(0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: color, size: _getIconSize(context) - 4),
                      SizedBox(width: _getSpacing(context)),
                      Text('建議', style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: _getBodyFontSize(context))),
                    ],
                  ),
                  SizedBox(height: _getSpacing(context)),
                  Text(rec.advice, style: TextStyle(height: 1.6, color: _textPrimary, fontSize: _getSubtitleFontSize(context))),
                  if (rec.reason.isNotEmpty) ...[
                    SizedBox(height: _getSpacing(context)),
                    Text(rec.reason, style: TextStyle(fontSize: _getBodyFontSize(context), color: _textSecondary, height: 1.5)),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // AI 確認按鈕
  Widget _buildAiConfirmButton(BuildContext context) {
    return GestureDetector(
      onTap: _confirmAiResult,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: _getSpacing(context, large: true)),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
          borderRadius: BorderRadius.circular(_getBorderRadius(context, large: true)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withOpacity(0.4),
              offset: const Offset(0, 6),
              blurRadius: 16,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: _getIconSize(context)),
            SizedBox(width: _getSpacing(context)),
            Text(
              '確認並記錄',
              style: TextStyle(fontSize: _getTitleFontSize(context) - 1, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ v4.2 修正：自動生成餐點名稱，不再使用 suggestedMealName 屬性
  void _confirmAiResult() {
    if (_aiResult == null) return;
    
    // 自動生成餐點名稱
    String? suggestedName;
    if (_aiResult!.foods.isNotEmpty) {
      if (_aiResult!.foods.length == 1) {
        suggestedName = _aiResult!.foods.first.name;
      } else {
        final names = _aiResult!.foods.map((f) => f.name).toList();
        if (names.length <= 3) {
          suggestedName = names.join('、');
        } else {
          suggestedName = '${names.first}等 ${names.length} 項';
        }
      }
    }
    
    // 導航到確認頁面
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AiFoodConfirmPage(
          aiResult: _aiResult!,
          suggestedMealName: suggestedName,
        ),
      ),
    ).then((success) {
      // 如果記錄成功，返回上一頁
      if (success == true && mounted) {
        Navigator.pop(context);
      }
    });
  }

  // ══════════════════════════════════════════════════════════════════
  // ██  OCR 模式內容（完整保留 v3.0 所有功能）
  // ══════════════════════════════════════════════════════════════════

  Widget _buildOcrModeContent(BuildContext context) {
    final padding = _getResponsivePadding(context);
    final spacing = _getSpacing(context, large: true);

    return SingleChildScrollView(
      controller: _ocrScrollController,
      physics: const BouncingScrollPhysics(),
      padding: padding,
      child: Column(
        children: [
          if (_selectedImage == null) _buildOcrIntroCard(context),

          if (_selectedImage != null) ...[
            _buildImageCard(context),
            SizedBox(height: spacing),
          ],

          if (_isProcessing && _currentMode == ScanMode.ocrLabel) _buildOcrProcessingState(context),

          if (_errorMessage != null && _currentMode == ScanMode.ocrLabel) ...[
            SizedBox(height: _getSpacing(context)),
            _buildOcrErrorState(context),
          ],

          if (_ocrResult != null) ...[
            SizedBox(height: spacing),
            _buildOcrResultCard(context),
            SizedBox(height: spacing),
            _buildOcrActionButtons(context),
            const SizedBox(height: 40),
          ],
        ],
      ),
    );
  }

  // OCR 介紹卡片（完整保留 v3.0）
  Widget _buildOcrIntroCard(BuildContext context) {
    final isYolo = _currentEngine == OcrEngine.yolo;
    final engineColor = isYolo ? const Color(0xFF8B5CF6) : const Color(0xFF10B981);
    final spacing = _getSpacing(context, large: true);

    return Column(
      children: [
        _softCard(
          context,
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(_getSpacing(context, large: true)),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [engineColor.withOpacity(0.15), engineColor.withOpacity(0.05)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(isYolo ? Icons.smart_toy : Icons.cloud, size: _getIconSize(context, large: true), color: engineColor),
              ),
              SizedBox(height: spacing),
              Text(
                '📋 營養標籤掃描',
                style: TextStyle(fontSize: _getTitleFontSize(context) + 2, fontWeight: FontWeight.bold, color: _textPrimary),
              ),
              SizedBox(height: _getSpacing(context)),
              Text(
                '拍攝包裝食品標籤，自動辨識營養成分',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: _getSubtitleFontSize(context), color: _textSecondary),
              ),
              SizedBox(height: _getSpacing(context, large: true)),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: _getSpacing(context, large: true),
                  vertical: _getSpacing(context),
                ),
                decoration: BoxDecoration(
                  color: isYolo ? const Color(0xFFFFF3CD) : const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(_getBorderRadius(context)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isYolo ? Icons.schedule : Icons.bolt,
                      size: _getIconSize(context) - 2,
                      color: isYolo ? const Color(0xFF856404) : const Color(0xFF065F46),
                    ),
                    SizedBox(width: _getSpacing(context)),
                    Flexible(
                      child: Text(
                        isYolo ? '首次使用需等待 30-50 秒啟動' : '快速辨識，約 1-3 秒完成',
                        style: TextStyle(
                          fontSize: _getSubtitleFontSize(context),
                          fontWeight: FontWeight.w500,
                          color: isYolo ? const Color(0xFF856404) : const Color(0xFF065F46),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),
        SizedBox(height: spacing),

        _buildPrimaryButton(
          context,
          icon: Icons.camera_alt,
          label: '拍攝營養標籤',
          subtitle: '對準標籤拍照辨識',
          gradientColors: [engineColor, engineColor.withOpacity(0.7)],
          onTap: () => _pickImage(ImageSource.camera),
        ).animate(delay: 100.ms).fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),

        SizedBox(height: _getSpacing(context, large: true)),

        _buildSecondaryButton(
          context,
          icon: Icons.photo_library,
          label: '從相簿選擇',
          onTap: () => _pickImage(ImageSource.gallery),
        ).animate(delay: 200.ms).fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),
      ],
    );
  }

  Widget _buildPrimaryButton(BuildContext context, {
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
        padding: EdgeInsets.all(_getSpacing(context, large: true)),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradientColors),
          borderRadius: BorderRadius.circular(_getBorderRadius(context, large: true)),
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
              padding: EdgeInsets.all(_getSpacing(context, large: true)),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(_getBorderRadius(context, large: true)),
              ),
              child: Icon(icon, color: Colors.white, size: _getIconSize(context) + 8),
            ),
            SizedBox(width: _getSpacing(context, large: true)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: _getTitleFontSize(context), fontWeight: FontWeight.bold, color: Colors.white)),
                  SizedBox(height: _getSpacing(context) / 3),
                  Text(subtitle, style: TextStyle(fontSize: _getSubtitleFontSize(context), color: Colors.white.withOpacity(0.8))),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.white.withOpacity(0.6), size: _getIconSize(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryButton(BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          vertical: _getSpacing(context, large: true),
          horizontal: _getSpacing(context, large: true),
        ),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(_getBorderRadius(context, large: true)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.08), offset: const Offset(6, 6), blurRadius: 12),
            const BoxShadow(color: Colors.white, offset: Offset(-6, -6), blurRadius: 12),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: _primaryColor, size: _getIconSize(context)),
            SizedBox(width: _getSpacing(context)),
            Text(label, style: TextStyle(fontSize: _getTitleFontSize(context) - 2, fontWeight: FontWeight.w600, color: _textPrimary)),
          ],
        ),
      ),
    );
  }

  // OCR 處理中（完整保留 v3.0）
  Widget _buildOcrProcessingState(BuildContext context) {
    final isYolo = _currentEngine == OcrEngine.yolo;

    return _softCard(
      context,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(_getSpacing(context, large: true)),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: SizedBox(
              width: _getResponsiveValue(context, small: 28, medium: 30, large: 32),
              height: _getResponsiveValue(context, small: 28, medium: 30, large: 32),
              child: const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                strokeWidth: 3,
              ),
            ),
          ),
          SizedBox(height: _getSpacing(context, large: true)),
          Text(
            isYolo ? '正在使用 YOLO 辨識...' : '正在使用 Google 辨識...',
            style: TextStyle(fontSize: _getTitleFontSize(context) - 2, fontWeight: FontWeight.w600, color: _textPrimary),
          ),
          SizedBox(height: _getSpacing(context)),
          Text(
            isYolo ? '首次使用可能需要 30-50 秒啟動' : '預計 1-3 秒完成',
            style: TextStyle(fontSize: _getSubtitleFontSize(context), color: _textSecondary),
          ),
        ],
      ),
    ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1500.ms, color: _primaryColor.withOpacity(0.1));
  }

  // OCR 錯誤（完整保留 v3.0）
  Widget _buildOcrErrorState(BuildContext context) {
    return _softCard(
      context,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(_getSpacing(context, large: true)),
            decoration: BoxDecoration(
              color: const Color(0xFFDC2626).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.error_outline, size: _getIconSize(context, large: true) - 16, color: const Color(0xFFDC2626)),
          ),
          SizedBox(height: _getSpacing(context, large: true)),
          Text('辨識失敗', style: TextStyle(fontSize: _getTitleFontSize(context), fontWeight: FontWeight.bold, color: _textPrimary)),
          SizedBox(height: _getSpacing(context)),
          Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(fontSize: _getSubtitleFontSize(context), color: _textSecondary)),
          SizedBox(height: _getSpacing(context, large: true)),
          Wrap(
            spacing: _getSpacing(context),
            runSpacing: _getSpacing(context),
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _startOcrRecognition,
                icon: Icon(Icons.refresh, size: _getIconSize(context) - 4),
                label: Text('重試', style: TextStyle(fontSize: _getSubtitleFontSize(context))),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primaryColor,
                  side: const BorderSide(color: _primaryColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_getBorderRadius(context))),
                  padding: EdgeInsets.symmetric(horizontal: _getSpacing(context, large: true), vertical: _getSpacing(context)),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final newEngine = _currentEngine == OcrEngine.yolo ? OcrEngine.google : OcrEngine.yolo;
                  await OcrService.setEngine(newEngine);
                  setState(() => _currentEngine = newEngine);
                  _startOcrRecognition();
                },
                icon: Icon(Icons.swap_horiz, size: _getIconSize(context) - 4),
                label: Text(
                  _currentEngine == OcrEngine.yolo ? '改用 Google' : '改用 YOLO',
                  style: TextStyle(fontSize: _getSubtitleFontSize(context)),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _textSecondary,
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_getBorderRadius(context))),
                  padding: EdgeInsets.symmetric(horizontal: _getSpacing(context, large: true), vertical: _getSpacing(context)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // OCR 結果卡片（完整保留 v3.0 所有可編輯功能）
  Widget _buildOcrResultCard(BuildContext context) {
    final confidence = _calculateOcrConfidence();
    final screenSize = _getScreenSize(context);

    return _softCard(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 標題列
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(_getSpacing(context)),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _usedEngine == 'yolo'
                        ? [const Color(0xFF8B5CF6), const Color(0xFFA78BFA)]
                        : [const Color(0xFF10B981), const Color(0xFF34D399)],
                  ),
                  borderRadius: BorderRadius.circular(_getBorderRadius(context)),
                ),
                child: Icon(
                  _usedEngine == 'yolo' ? Icons.smart_toy : Icons.cloud,
                  color: Colors.white,
                  size: _getIconSize(context) - 2,
                ),
              ),
              SizedBox(width: _getSpacing(context)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('辨識結果', style: TextStyle(fontSize: _getTitleFontSize(context), fontWeight: FontWeight.bold, color: _textPrimary)),
                    if (_latencyMs != null)
                      Text('耗時 ${_latencyMs}ms', style: TextStyle(fontSize: _getBodyFontSize(context), color: Colors.grey.shade500)),
                  ],
                ),
              ),
              _buildOcrConfidenceBadge(context, confidence),
            ],
          ),

          // 可編輯提示
          Container(
            margin: EdgeInsets.only(top: _getSpacing(context)),
            padding: EdgeInsets.symmetric(horizontal: _getSpacing(context), vertical: _getSpacing(context) / 1.5),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(_getBorderRadius(context)),
              border: Border.all(color: const Color(0xFFFCD34D)),
            ),
            child: Row(
              children: [
                Icon(Icons.touch_app, size: _getIconSize(context) - 4, color: const Color(0xFFD97706)),
                SizedBox(width: _getSpacing(context)),
                Expanded(
                  child: Text(
                    '點擊數值可修正辨識結果',
                    style: TextStyle(fontSize: _getBodyFontSize(context), color: const Color(0xFF92400E), fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: _getSpacing(context, large: true)),

          // 熱量（大顯示）
          _buildEditableCaloriesRow(context),

          SizedBox(height: _getSpacing(context, large: true)),

          // 根據螢幕大小調整佈局
          if (screenSize == ScreenSize.small) ...[
            // 小螢幕：2列佈局
            Row(
              children: [
                Expanded(child: _buildEditableNutrientItem(context, 'protein', '蛋白質', 'g', const Color(0xFFEF4444))),
                SizedBox(width: _getSpacing(context)),
                Expanded(child: _buildEditableNutrientItem(context, 'carbs', '碳水', 'g', const Color(0xFFF59E0B))),
              ],
            ),
            SizedBox(height: _getSpacing(context)),
            Row(
              children: [
                Expanded(child: _buildEditableNutrientItem(context, 'fat', '脂肪', 'g', const Color(0xFF8B5CF6))),
                SizedBox(width: _getSpacing(context)),
                Expanded(child: _buildEditableNutrientItem(context, 'sugar', '糖', 'g', const Color(0xFFEC4899))),
              ],
            ),
            SizedBox(height: _getSpacing(context)),
            Row(
              children: [
                Expanded(child: _buildEditableNutrientItem(context, 'sodium', '鈉', 'mg', const Color(0xFF06B6D4))),
                SizedBox(width: _getSpacing(context)),
                Expanded(child: _buildEditableNutrientItem(context, 'fiber', '膳食纖維', 'g', const Color(0xFF22C55E))),
              ],
            ),
            SizedBox(height: _getSpacing(context)),
            Row(
              children: [
                Expanded(child: _buildEditableNutrientItem(context, 'saturatedFat', '飽和脂肪', 'g', const Color(0xFF64748B))),
                SizedBox(width: _getSpacing(context)),
                Expanded(child: _buildEditableNutrientItem(context, 'transFat', '反式脂肪', 'g', const Color(0xFF94A3B8))),
              ],
            ),
            SizedBox(height: _getSpacing(context)),
            Row(
              children: [
                Expanded(child: _buildEditableNutrientItem(context, 'cholesterol', '膽固醇', 'mg', const Color(0xFFA855F7))),
                SizedBox(width: _getSpacing(context)),
                const Expanded(child: SizedBox()),
              ],
            ),
          ] else ...[
            // 中大螢幕：3列佈局
            Row(
              children: [
                Expanded(child: _buildEditableNutrientItem(context, 'protein', '蛋白質', 'g', const Color(0xFFEF4444))),
                SizedBox(width: _getSpacing(context)),
                Expanded(child: _buildEditableNutrientItem(context, 'carbs', '碳水化合物', 'g', const Color(0xFFF59E0B))),
                SizedBox(width: _getSpacing(context)),
                Expanded(child: _buildEditableNutrientItem(context, 'fat', '脂肪', 'g', const Color(0xFF8B5CF6))),
              ],
            ),
            SizedBox(height: _getSpacing(context)),
            Row(
              children: [
                Expanded(child: _buildEditableNutrientItem(context, 'sugar', '糖', 'g', const Color(0xFFEC4899), compact: true)),
                SizedBox(width: _getSpacing(context)),
                Expanded(child: _buildEditableNutrientItem(context, 'sodium', '鈉', 'mg', const Color(0xFF06B6D4), compact: true)),
              ],
            ),
            SizedBox(height: _getSpacing(context)),
            Row(
              children: [
                Expanded(child: _buildEditableNutrientItem(context, 'saturatedFat', '飽和脂肪', 'g', const Color(0xFF64748B), compact: true)),
                SizedBox(width: _getSpacing(context)),
                Expanded(child: _buildEditableNutrientItem(context, 'transFat', '反式脂肪', 'g', const Color(0xFF94A3B8), compact: true)),
              ],
            ),
            SizedBox(height: _getSpacing(context)),
            Row(
              children: [
                Expanded(child: _buildEditableNutrientItem(context, 'fiber', '膳食纖維', 'g', const Color(0xFF22C55E), compact: true)),
                SizedBox(width: _getSpacing(context)),
                Expanded(child: _buildEditableNutrientItem(context, 'cholesterol', '膽固醇', 'mg', const Color(0xFFA855F7), compact: true)),
              ],
            ),
          ],
        ],
      ),
    ).animate(delay: 200.ms).fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  // 可編輯的熱量大顯示（完整保留 v3.0）
  Widget _buildEditableCaloriesRow(BuildContext context) {
    final value = _editedNutrition['calories'];
    final hasValue = value != null;

    return GestureDetector(
      onTap: () => _showEditDialog(context, 'calories', '熱量', '大卡'),
      child: Container(
        padding: EdgeInsets.all(_getSpacing(context, large: true)),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFFFF6B35).withOpacity(0.15), const Color(0xFFFF6B35).withOpacity(0.05)],
          ),
          borderRadius: BorderRadius.circular(_getBorderRadius(context, large: true)),
          border: Border.all(color: const Color(0xFFFF6B35).withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(_getSpacing(context)),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B35).withOpacity(0.2),
                borderRadius: BorderRadius.circular(_getBorderRadius(context)),
              ),
              child: Icon(Icons.local_fire_department, color: const Color(0xFFFF6B35), size: _getIconSize(context) + 4),
            ),
            SizedBox(width: _getSpacing(context, large: true)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('熱量', style: TextStyle(fontSize: _getSubtitleFontSize(context), color: _textSecondary)),
                  SizedBox(height: _getSpacing(context) / 3),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        hasValue ? value!.toStringAsFixed(1) : '未偵測',
                        style: TextStyle(
                          fontSize: _getLargeFontSize(context),
                          fontWeight: FontWeight.bold,
                          color: hasValue ? const Color(0xFFFF6B35) : Colors.grey,
                        ),
                      ),
                      if (hasValue) ...[
                        SizedBox(width: _getSpacing(context) / 2),
                        Padding(
                          padding: EdgeInsets.only(bottom: _getSpacing(context) / 2),
                          child: Text(
                            '大卡',
                            style: TextStyle(fontSize: _getTitleFontSize(context) - 2, color: const Color(0xFFFF6B35)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.all(_getSpacing(context)),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(_getBorderRadius(context)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
              ),
              child: Icon(Icons.edit, color: const Color(0xFFFF6B35), size: _getIconSize(context) - 2),
            ),
          ],
        ),
      ),
    );
  }

  // 可編輯的營養素項目（完整保留 v3.0）
  Widget _buildEditableNutrientItem(BuildContext context, String key, String label, String unit, Color color, {bool compact = false}) {
    final value = _editedNutrition[key];
    final hasValue = value != null;
    final displayValue = hasValue ? value!.toStringAsFixed(1) : '--';

    return GestureDetector(
      onTap: () => _showEditDialog(context, key, label, unit),
      child: Container(
        padding: EdgeInsets.all(compact ? _getSpacing(context) : _getSpacing(context)),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(_getBorderRadius(context)),
          border: Border.all(color: color.withOpacity(0.2)),
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
                    style: TextStyle(fontSize: _getBodyFontSize(context) - (compact ? 1 : 0), color: _textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.edit, size: _getBodyFontSize(context), color: color.withOpacity(0.6)),
              ],
            ),
            SizedBox(height: _getSpacing(context) / 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  displayValue,
                  style: TextStyle(
                    fontSize: _getResponsiveValue(context, small: 16, medium: 18, large: compact ? 18 : 22),
                    fontWeight: FontWeight.bold,
                    color: hasValue ? color : Colors.grey,
                  ),
                ),
                if (hasValue) ...[
                  const SizedBox(width: 2),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(unit, style: TextStyle(fontSize: _getBodyFontSize(context) - 1, color: color.withOpacity(0.7))),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 編輯對話框（完整保留 v3.0）
  void _showEditDialog(BuildContext context, String key, String label, String unit) {
    final currentValue = _editedNutrition[key];
    final controller = TextEditingController(text: currentValue?.toStringAsFixed(1) ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_getBorderRadius(context, large: true))),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(_getSpacing(context)),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(_getBorderRadius(context)),
              ),
              child: Icon(Icons.edit, color: _primaryColor, size: _getIconSize(context)),
            ),
            SizedBox(width: _getSpacing(context)),
            Text('編輯 $label', style: TextStyle(fontSize: _getTitleFontSize(context))),
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(_getBorderRadius(context))),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(_getBorderRadius(context)),
                  borderSide: const BorderSide(color: _primaryColor, width: 2),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: _getSpacing(context, large: true), vertical: _getSpacing(context)),
              ),
              style: TextStyle(fontSize: _getTitleFontSize(context) + 2, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: _getSpacing(context)),
            if (key == 'calories')
              _buildQuickValueButtons(context, controller, [50, 100, 200, 300, 500])
            else if (unit == 'mg')
              _buildQuickValueButtons(context, controller, [10, 50, 100, 200, 500])
            else
              _buildQuickValueButtons(context, controller, [1, 5, 10, 20, 50]),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _editedNutrition[key] = null);
              Navigator.pop(ctx);
            },
            child: Text('清除', style: TextStyle(color: Colors.grey, fontSize: _getSubtitleFontSize(context))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(fontSize: _getSubtitleFontSize(context))),
          ),
          ElevatedButton(
            onPressed: () {
              final newValue = double.tryParse(controller.text);
              setState(() => _editedNutrition[key] = newValue);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_getBorderRadius(context))),
            ),
            child: Text('確認', style: TextStyle(color: Colors.white, fontSize: _getSubtitleFontSize(context))),
          ),
        ],
      ),
    );
  }

  // 快速數值按鈕（完整保留 v3.0）
  Widget _buildQuickValueButtons(BuildContext context, TextEditingController controller, List<num> values) {
    return Wrap(
      spacing: _getSpacing(context),
      runSpacing: _getSpacing(context),
      children: values.map((value) {
        return InkWell(
          onTap: () => controller.text = value.toString(),
          borderRadius: BorderRadius.circular(_getBorderRadius(context)),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: _getSpacing(context), vertical: _getSpacing(context) / 2),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(_getBorderRadius(context)),
            ),
            child: Text(
              value.toString(),
              style: TextStyle(color: _primaryColor, fontWeight: FontWeight.w500, fontSize: _getSubtitleFontSize(context)),
            ),
          ),
        );
      }).toList(),
    );
  }

  double _calculateOcrConfidence() {
    int detectedCount = 0;
    final keys = ['calories', 'protein', 'fat', 'carbs', 'sugar', 'sodium'];
    for (var key in keys) {
      if (_editedNutrition[key] != null) detectedCount++;
    }
    return (detectedCount / keys.length * 100).clamp(0, 100);
  }

  Widget _buildOcrConfidenceBadge(BuildContext context, double confidence) {
    Color badgeColor;
    if (confidence >= 80) {
      badgeColor = const Color(0xFF10B981);
    } else if (confidence >= 50) {
      badgeColor = const Color(0xFFF59E0B);
    } else {
      badgeColor = const Color(0xFFEF4444);
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: _getSpacing(context), vertical: _getSpacing(context) / 2),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(_getBorderRadius(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(confidence >= 80 ? Icons.verified : Icons.info_outline, size: _getBodyFontSize(context), color: badgeColor),
          SizedBox(width: _getSpacing(context) / 3),
          Text('${confidence.toInt()}%', style: TextStyle(fontSize: _getBodyFontSize(context), fontWeight: FontWeight.bold, color: badgeColor)),
        ],
      ),
    );
  }

  // OCR 操作按鈕（完整保留 v3.0）
  Widget _buildOcrActionButtons(BuildContext context) {
    final screenSize = _getScreenSize(context);
    
    // 小螢幕垂直排列，大螢幕水平排列
    if (screenSize == ScreenSize.small) {
      return Column(
        children: [
          _buildOcrQuickActionButton(
            context,
            icon: Icons.bookmark_add,
            label: '存到我的食物',
            color: const Color(0xFF8B5CF6),
            onTap: _saveToMyFoods,
          ),
          SizedBox(height: _getSpacing(context)),
          _buildOcrQuickActionButton(
            context,
            icon: Icons.favorite,
            label: '加入最愛',
            color: const Color(0xFFEC4899),
            onTap: _addToFavorites,
          ),
          SizedBox(height: _getSpacing(context)),
          _buildOcrConfirmButton(context),
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildOcrQuickActionButton(
                context,
                icon: Icons.bookmark_add,
                label: '存到我的食物',
                color: const Color(0xFF8B5CF6),
                onTap: _saveToMyFoods,
              ),
            ),
            SizedBox(width: _getSpacing(context)),
            Expanded(
              child: _buildOcrQuickActionButton(
                context,
                icon: Icons.favorite,
                label: '加入最愛',
                color: const Color(0xFFEC4899),
                onTap: _addToFavorites,
              ),
            ),
          ],
        ),
        SizedBox(height: _getSpacing(context)),
        _buildOcrConfirmButton(context),
      ],
    );
  }

  Widget _buildOcrQuickActionButton(BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: _getSpacing(context)),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(_getBorderRadius(context, large: true)),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: _getIconSize(context)),
            SizedBox(width: _getSpacing(context)),
            Text(label, style: TextStyle(fontSize: _getSubtitleFontSize(context), fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildOcrConfirmButton(BuildContext context) {
    return GestureDetector(
      onTap: _goToAddLog,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: _getSpacing(context, large: true)),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
          borderRadius: BorderRadius.circular(_getBorderRadius(context, large: true)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withOpacity(0.4),
              offset: const Offset(0, 6),
              blurRadius: 16,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: _getIconSize(context)),
            SizedBox(width: _getSpacing(context)),
            Text(
              '確認並記錄',
              style: TextStyle(fontSize: _getTitleFontSize(context) - 1, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  void _goToAddLog() {
    if (_ocrResult == null) return;

    final foodData = {
      'name': '掃描食品',
      'calories': (_editedNutrition['calories'] ?? 0).toDouble(),
      'protein': (_editedNutrition['protein'] ?? 0).toDouble(),
      'fat': (_editedNutrition['fat'] ?? 0).toDouble(),
      'carbs': (_editedNutrition['carbs'] ?? 0).toDouble(),
      'servingSize': '每份',
      'isScanned': true,
      'sugar': _editedNutrition['sugar'],
      'sodium': _editedNutrition['sodium'],
      'saturatedFat': _editedNutrition['saturatedFat'],
      'transFat': _editedNutrition['transFat'],
      'fiber': _editedNutrition['fiber'],
      'cholesterol': _editedNutrition['cholesterol'],
    };

    Navigator.push(context, MaterialPageRoute(builder: (_) => AddNutritionLogPage(foodData: foodData)));
  }

  // 儲存到我的食物（完整保留 v3.0）
  Future<void> _saveToMyFoods() async {
    final nameController = TextEditingController(text: '掃描食品');

    final foodName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_getBorderRadius(context, large: true))),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(_getSpacing(context)),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(_getBorderRadius(context)),
              ),
              child: Icon(Icons.bookmark_add, color: const Color(0xFF8B5CF6), size: _getIconSize(context)),
            ),
            SizedBox(width: _getSpacing(context)),
            Text('儲存到我的食物', style: TextStyle(fontSize: _getTitleFontSize(context))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('輸入食物名稱，方便下次快速記錄', style: TextStyle(fontSize: _getSubtitleFontSize(context), color: Colors.grey)),
            SizedBox(height: _getSpacing(context, large: true)),
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '例如：統一布丁、光泉鮮乳',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(_getBorderRadius(context))),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(_getBorderRadius(context)),
                  borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 2),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: _getSpacing(context, large: true), vertical: _getSpacing(context)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('取消', style: TextStyle(fontSize: _getSubtitleFontSize(context)))),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.pop(ctx, nameController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_getBorderRadius(context))),
            ),
            child: Text('儲存', style: TextStyle(color: Colors.white, fontSize: _getSubtitleFontSize(context))),
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

  // 加入最愛（完整保留 v3.0）
  Future<void> _addToFavorites() async {
    final nameController = TextEditingController(text: '掃描食品');

    final foodName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_getBorderRadius(context, large: true))),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(_getSpacing(context)),
              decoration: BoxDecoration(
                color: const Color(0xFFEC4899).withOpacity(0.1),
                borderRadius: BorderRadius.circular(_getBorderRadius(context)),
              ),
              child: Icon(Icons.favorite, color: const Color(0xFFEC4899), size: _getIconSize(context)),
            ),
            SizedBox(width: _getSpacing(context)),
            Text('加入最愛', style: TextStyle(fontSize: _getTitleFontSize(context))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('輸入食物名稱，方便下次快速記錄', style: TextStyle(fontSize: _getSubtitleFontSize(context), color: Colors.grey)),
            SizedBox(height: _getSpacing(context, large: true)),
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '例如：統一布丁、光泉鮮乳',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(_getBorderRadius(context))),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(_getBorderRadius(context)),
                  borderSide: const BorderSide(color: Color(0xFFEC4899), width: 2),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: _getSpacing(context, large: true), vertical: _getSpacing(context)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('取消', style: TextStyle(fontSize: _getSubtitleFontSize(context)))),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.pop(ctx, nameController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEC4899),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_getBorderRadius(context))),
            ),
            child: Text('加入', style: TextStyle(color: Colors.white, fontSize: _getSubtitleFontSize(context))),
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
            content: const Row(
              children: [
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

  // 引擎選擇（完整保留 v3.0）
  void _showEngineSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.all(_getSpacing(context, large: true)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(_getBorderRadius(context, large: true) + 4)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: _getSpacing(context, large: true)),
            Text(
              '選擇辨識引擎',
              style: TextStyle(fontSize: _getTitleFontSize(context) + 2, fontWeight: FontWeight.bold, color: _textPrimary),
            ),
            SizedBox(height: _getSpacing(context, large: true)),
            _buildEngineOption(
              context,
              engine: OcrEngine.yolo,
              icon: Icons.smart_toy,
              title: 'AI 辨識 (YOLO)',
              subtitle: '自訓練深度學習模型',
              description: '專為營養標籤優化，首次需 30-50 秒啟動',
              color: const Color(0xFF8B5CF6),
            ),
            SizedBox(height: _getSpacing(context)),
            _buildEngineOption(
              context,
              engine: OcrEngine.google,
              icon: Icons.cloud,
              title: '雲端辨識 (Google)',
              subtitle: 'Google Cloud Vision API',
              description: '辨識速度快 (1-3秒)，準確度高',
              color: const Color(0xFF10B981),
            ),
            SizedBox(height: _getSpacing(context, large: true)),
          ],
        ),
      ),
    );
  }

  Widget _buildEngineOption(BuildContext context, {
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
        if (_selectedImage != null && _ocrResult != null) {
          _startOcrRecognition();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(_getSpacing(context, large: true)),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : _bgColor,
          borderRadius: BorderRadius.circular(_getBorderRadius(context, large: true)),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(_getSpacing(context)),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(_getBorderRadius(context)),
              ),
              child: Icon(icon, color: color, size: _getIconSize(context)),
            ),
            SizedBox(width: _getSpacing(context, large: true)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: _getTitleFontSize(context) - 2,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? color : _textPrimary,
                    ),
                  ),
                  SizedBox(height: _getSpacing(context) / 4),
                  Text(subtitle, style: TextStyle(fontSize: _getSubtitleFontSize(context), color: _textSecondary)),
                  if (isSelected) ...[
                    SizedBox(height: _getSpacing(context) / 2),
                    Text(description, style: TextStyle(fontSize: _getBodyFontSize(context), color: Colors.grey.shade500)),
                  ],
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: color, size: _getIconSize(context)),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // ██  共用圖片卡片（完整保留 v3.0）
  // ══════════════════════════════════════════════════════════════════

  Widget _buildImageCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(_getBorderRadius(context, large: true)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: _selectedImage == null ? _buildImagePicker(context) : _buildImageWithOverlay(context),
    );
  }

  Widget _buildImagePicker(BuildContext context) {
    final height = _getImageHeight(context);

    return InkWell(
      onTap: _showSourceDialog,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_bgColor, Colors.grey.shade200],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(_getSpacing(context, large: true)),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20)],
                ),
                child: Icon(Icons.add_photo_alternate_rounded, size: _getIconSize(context, large: true) - 10, color: _primaryColor),
              ),
              SizedBox(height: _getSpacing(context, large: true)),
              Text(
                _currentMode == ScanMode.aiFood ? '點擊選擇食物照片' : '點擊選擇營養標籤',
                style: TextStyle(color: _textSecondary, fontSize: _getTitleFontSize(context) - 2, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: _getSpacing(context) / 2),
              Text('支援拍照或從相簿選擇', style: TextStyle(color: Colors.grey.shade400, fontSize: _getSubtitleFontSize(context))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageWithOverlay(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: _showFullScreenImage,
          child: Image.file(_selectedImage!, fit: BoxFit.contain, width: double.infinity),
        ),

        if (_currentMode == ScanMode.aiFood && _aiResult != null)
          Positioned.fill(
            child: LayoutBuilder(
              builder: (ctx, constraints) =>
                  Stack(children: _buildBoundingBoxes(context, constraints.maxWidth, constraints.maxHeight)),
            ),
          ),

        Positioned(
          top: _getSpacing(context),
          right: _getSpacing(context),
          child: GestureDetector(
            onTap: _showSourceDialog,
            child: Container(
              padding: EdgeInsets.all(_getSpacing(context)),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.45),
                borderRadius: BorderRadius.circular(_getBorderRadius(context)),
              ),
              child: Icon(Icons.refresh_rounded, color: Colors.white, size: _getIconSize(context)),
            ),
          ),
        ),

        Positioned(
          right: _getSpacing(context),
          bottom: _getSpacing(context),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: _getSpacing(context), vertical: _getSpacing(context) / 2),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(_getBorderRadius(context, large: true)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.zoom_in, color: Colors.white, size: _getIconSize(context) - 4),
                SizedBox(width: _getSpacing(context) / 2),
                Text('點擊放大', style: TextStyle(color: Colors.white, fontSize: _getBodyFontSize(context), fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),

        Positioned(
          top: _getSpacing(context),
          left: _getSpacing(context),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: _getSpacing(context), vertical: _getSpacing(context) / 2),
            decoration: BoxDecoration(
              color: _currentMode == ScanMode.aiFood ? _primaryColor : const Color(0xFF8B5CF6),
              borderRadius: BorderRadius.circular(_getBorderRadius(context, large: true)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _currentMode == ScanMode.aiFood ? Icons.auto_awesome : Icons.qr_code_scanner,
                  color: Colors.white,
                  size: _getBodyFontSize(context),
                ),
                SizedBox(width: _getSpacing(context) / 2),
                Text(
                  _currentMode == ScanMode.aiFood ? 'AI 辨識' : '標籤掃描',
                  style: TextStyle(color: Colors.white, fontSize: _getBodyFontSize(context) - 1, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // AI Bounding Boxes（完整保留 v3.0）
  List<Widget> _buildBoundingBoxes(BuildContext context, double w, double h) {
    if (_aiResult == null) return [];
    final List<Widget> boxes = [];

    for (int i = 0; i < _aiResult!.foods.length; i++) {
      final food = _aiResult!.foods[i];
      if (food.boundingBox == null) continue;

      final box = food.boundingBox!;
      final color = _getColor(i);
      final isSelected = _selectedFoodIndex == i;

      final pixels = box.toPixels(w, h);
      final left = pixels[0];
      final top = pixels[1];
      final boxW = pixels[2];
      final boxH = pixels[3];

      boxes.add(
        Positioned(
          left: left,
          top: top,
          width: boxW,
          height: boxH,
          child: IgnorePointer(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected ? color : color.withOpacity(0.8),
                  width: isSelected ? 3 : 2,
                ),
                color: isSelected ? color.withOpacity(0.18) : Colors.transparent,
              ),
            ),
          ),
        ),
      );

      boxes.add(
        Positioned(
          left: left,
          top: (top - 28).clamp(4.0, h - 28),
          child: GestureDetector(
            onTap: () => _onFoodTap(i),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: _getSpacing(context) / 1.5, vertical: _getSpacing(context) / 3),
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: color, width: 1.5),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : color,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          color: isSelected ? color : Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    food.name.length > 5 ? '${food.name.substring(0, 5)}...' : food.name,
                    style: TextStyle(
                      color: isSelected ? Colors.white : _textPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return boxes;
  }

  void _showSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(_getBorderRadius(context, large: true))),
        ),
        padding: EdgeInsets.fromLTRB(
          _getSpacing(context, large: true),
          _getSpacing(context, large: true),
          _getSpacing(context, large: true),
          _getSpacing(context, large: true) + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: _getSpacing(context, large: true)),
            _sourceOption(context, Icons.camera_alt_rounded, '拍照', () {
              Navigator.pop(ctx);
              _pickImage(ImageSource.camera);
            }),
            SizedBox(height: _getSpacing(context)),
            _sourceOption(context, Icons.photo_library_rounded, '從相簿選擇', () {
              Navigator.pop(ctx);
              _pickImage(ImageSource.gallery);
            }),
          ],
        ),
      ),
    );
  }

  Widget _sourceOption(BuildContext context, IconData icon, String title, VoidCallback onTap) {
    return Material(
      color: _bgColor,
      borderRadius: BorderRadius.circular(_getBorderRadius(context)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_getBorderRadius(context)),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: _getSpacing(context, large: true), vertical: _getSpacing(context)),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(_getSpacing(context)),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(_getBorderRadius(context)),
                ),
                child: Icon(icon, color: _primaryColor, size: _getIconSize(context)),
              ),
              SizedBox(width: _getSpacing(context)),
              Text(title, style: TextStyle(fontSize: _getTitleFontSize(context) - 2, fontWeight: FontWeight.w500)),
              const Spacer(),
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: _getIconSize(context)),
            ],
          ),
        ),
      ),
    );
  }

  void _showFullScreenImage() {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (ctx, animation, secondaryAnimation) {
          return _FullScreenImageViewer(imageFile: _selectedImage!, animation: animation);
        },
        transitionsBuilder: (ctx, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// ██  全螢幕圖片查看器（完整保留 v3.0）
// ══════════════════════════════════════════════════════════════════

class _FullScreenImageViewer extends StatefulWidget {
  final File imageFile;
  final Animation<double> animation;

  const _FullScreenImageViewer({required this.imageFile, required this.animation});

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
      _transformationController.value = Matrix4.identity();
      _currentScale = 1.0;
    } else {
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
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(color: Colors.transparent),
          ),
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
                child: Image.file(widget.imageFile, fit: BoxFit.contain),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 24),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '雙擊放大 · 捏合縮放',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(width: 44),
                  ],
                ),
              ),
            ),
          ),
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
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
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