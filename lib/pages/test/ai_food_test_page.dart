// lib/pages/test/ai_food_test_page.dart
// AI 食物辨識測試頁面 - v6 新增 sugar + fiber 顯示

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/ai_food_service.dart';

class AIFoodTestPage extends StatefulWidget {
  const AIFoodTestPage({super.key});

  @override
  State<AIFoodTestPage> createState() => _AIFoodTestPageState();
}

class _AIFoodTestPageState extends State<AIFoodTestPage> {
  final AIFoodService _aiService = AIFoodService();
  final ImagePicker _picker = ImagePicker();
  final ScrollController _scrollController = ScrollController();

  File? _selectedImage;
  FoodAnalysisResult? _result;
  bool _isLoading = false;
  String? _errorMessage;

  int _currentRetry = 0;
  int _maxRetries = 3;
  bool _isRetrying = false;
  int? _selectedFoodIndex;

  final Map<int, GlobalKey> _foodCardKeys = {};

  String _mealType = '午餐';
  String _userGoal = '維持';

  // ========== 柔和明亮 Soft UI 色系 ==========
  static const Color _bgColor = Color(0xFFF5F6F8);
  static const Color _cardColor = Color(0xFFFFFFFF);
  static const Color _primaryColor = Color(0xFF5B9A8B);
  static const Color _textPrimary = Color(0xFF2D3436);
  static const Color _textSecondary = Color(0xFF636E72);

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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Color _getColor(int index) => _foodColors[index % _foodColors.length];

  // ========== 圖片選擇 ==========
  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 90,
    );
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
        _result = null;
        _errorMessage = null;
        _selectedFoodIndex = null;
        _foodCardKeys.clear();
      });
    }
  }

  // ========== 分析食物 ==========
  Future<void> _analyzeFood() async {
    if (_selectedImage == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _result = null;
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
        _result = result;
        _isLoading = false;
        _isRetrying = false;
        for (int i = 0; i < result.foods.length; i++) {
          _foodCardKeys[i] = GlobalKey();
        }
      });
    } on AIFoodServiceException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
        _isRetrying = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '[UNKNOWN] $e';
        _isLoading = false;
        _isRetrying = false;
      });
    }
  }

  // ========== 互動：點擊食物 ==========
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

  // ========== Build ==========
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            _buildSettingsCard(),
            const SizedBox(height: 20),
            _buildImageCard(),
            const SizedBox(height: 20),
            _buildAnalyzeButton(),
            if (_isRetrying) ...[
              const SizedBox(height: 16),
              _buildRetryCard(),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              _buildErrorCard(),
            ],
            if (_result != null) ...[
              const SizedBox(height: 24),
              _buildFoodLegend(),
              const SizedBox(height: 20),
              _buildNutritionCard(),
              const SizedBox(height: 20),
              _buildFoodsCard(),
              const SizedBox(height: 20),
              if (_result!.mealAssessment != null) ...[
                _buildAssessmentCard(),
                const SizedBox(height: 20),
              ],
              if (_result!.recommendations.isNotEmpty) _buildRecommendationsCard(),
              const SizedBox(height: 40),
            ],
          ],
        ),
      ),
    );
  }

  // ========== AppBar ==========
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: _primaryColor,
      foregroundColor: Colors.white,
      centerTitle: true,
      title: const Text(
        'AI 食物辨識',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
      ),
      actions: [
        if (_selectedImage != null)
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => setState(() {
              _selectedImage = null;
              _result = null;
              _errorMessage = null;
              _selectedFoodIndex = null;
            }),
          ),
      ],
    );
  }

  // ========== Soft UI 卡片容器 ==========
  Widget _softCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
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

  // ========== 設定卡片 ==========
  Widget _buildSettingsCard() {
    return _softCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.tune_rounded, '分析設定'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  '餐別',
                  _mealType,
                  ['早餐', '午餐', '晚餐', '點心'],
                  (v) => setState(() => _mealType = v!),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDropdown(
                  '健身目標',
                  _userGoal,
                  ['減脂', '增肌', '維持'],
                  (v) => setState(() => _userGoal = v!),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _primaryColor, size: 18),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(
    String label,
    String value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: _textSecondary)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: _bgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: Icon(Icons.keyboard_arrow_down_rounded,
                  color: _textSecondary),
              style: const TextStyle(color: _textPrimary, fontSize: 14),
              items: items
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  // ========== 圖片卡片 ==========
  Widget _buildImageCard() {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child:
          _selectedImage == null ? _buildImagePicker() : _buildImageWithBoxes(),
    );
  }

  Widget _buildImagePicker() {
    return InkWell(
      onTap: _showSourceDialog,
      child: Container(
        height: 260,
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
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.08), blurRadius: 20)
                  ],
                ),
                child: Icon(Icons.add_photo_alternate_rounded,
                    size: 44, color: _primaryColor),
              ),
              const SizedBox(height: 20),
              Text(
                '點擊選擇食物照片',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '支援拍照或從相簿選擇',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
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
            const SizedBox(height: 24),
            _sourceOption(Icons.camera_alt_rounded, '拍照', () {
              Navigator.pop(ctx);
              _pickImage(ImageSource.camera);
            }),
            const SizedBox(height: 12),
            _sourceOption(Icons.photo_library_rounded, '從相簿選擇', () {
              Navigator.pop(ctx);
              _pickImage(ImageSource.gallery);
            }),
          ],
        ),
      ),
    );
  }

  Widget _sourceOption(IconData icon, String title, VoidCallback onTap) {
    return Material(
      color: _bgColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: _primaryColor, size: 22),
              ),
              const SizedBox(width: 14),
              Text(
                title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  // ========== 圖片 + Bounding Box ==========
  Widget _buildImageWithBoxes() {
    return Stack(
      children: [
        Image.file(_selectedImage!,
            fit: BoxFit.contain, width: double.infinity),
        if (_result != null)
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) =>
                  Stack(children: _buildBoxes(constraints.maxWidth, constraints.maxHeight)),
            ),
          ),
        Positioned(
          top: 12,
          right: 12,
          child: _floatingBtn(Icons.refresh_rounded, _showSourceDialog),
        ),
      ],
    );
  }

  Widget _floatingBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.45),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  List<Widget> _buildBoxes(double w, double h) {
    if (_result == null) return [];
    final List<Widget> boxes = [];
    final List<Rect> placedLabels = [];

    for (int i = 0; i < _result!.foods.length; i++) {
      final food = _result!.foods[i];
      if (food.boundingBox == null) continue;

      final box = food.boundingBox!;
      final color = _getColor(i);
      final isSelected = _selectedFoodIndex == i;

      final pixels = box.toPixels(w, h);
      final left = pixels[0];
      final top = pixels[1];
      final boxW = pixels[2];
      final boxH = pixels[3];

      // 框框
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
                boxShadow: isSelected
                    ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 10)]
                    : null,
              ),
            ),
          ),
        ),
      );

      // 標籤定位
      const labelW = 130.0;
      const labelH = 28.0;

      final positions = [
        Offset(left, top - labelH - 6),
        Offset(left, top + boxH + 6),
        Offset(left - labelW - 6, top),
        Offset(left + boxW + 6, top),
        Offset(left, top - labelH - 6 - 30),
        Offset(left + boxW / 2, top - labelH - 6),
        Offset(left + boxW - labelW, top + boxH + 6),
      ];

      Offset bestPos = positions[0];

      for (final pos in positions) {
        final candidateRect = Rect.fromLTWH(
          pos.dx.clamp(4.0, w - labelW - 4),
          pos.dy.clamp(4.0, h - labelH - 4),
          labelW,
          labelH,
        );

        bool overlaps = false;
        for (final placed in placedLabels) {
          if (candidateRect.overlaps(placed)) {
            overlaps = true;
            break;
          }
        }

        if (!overlaps) {
          bestPos = Offset(candidateRect.left, candidateRect.top);
          placedLabels.add(candidateRect);
          break;
        }

        if (pos == positions.last) {
          final offset = i * 32.0;
          bestPos = Offset(
            (positions[0].dx + offset).clamp(4.0, w - labelW - 4),
            (positions[0].dy - offset).clamp(4.0, h - labelH - 4),
          );
          placedLabels
              .add(Rect.fromLTWH(bestPos.dx, bestPos.dy, labelW, labelH));
        }
      }

      // 標籤
      boxes.add(
        Positioned(
          left: bestPos.dx,
          top: bestPos.dy,
          child: GestureDetector(
            onTap: () => _onFoodTap(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: color,
                  width: isSelected ? 0 : 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? color.withOpacity(0.4)
                        : Colors.black.withOpacity(0.12),
                    blurRadius: isSelected ? 8 : 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : color,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          color: isSelected ? color : Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    food.name.length > 6
                        ? '${food.name.substring(0, 6)}...'
                        : food.name,
                    style: TextStyle(
                      color: isSelected ? Colors.white : _textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withOpacity(0.25)
                          : color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${food.calories.toInt()}',
                      style: TextStyle(
                        color: isSelected ? Colors.white : color,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
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

  // ========== 圖例區域 ==========
  Widget _buildFoodLegend() {
    if (_result == null || _result!.foods.isEmpty) return const SizedBox.shrink();

    return _softCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.touch_app_rounded, color: _primaryColor, size: 18),
              const SizedBox(width: 8),
              const Text(
                '點擊食物可高亮顯示',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(_result!.foods.length, (i) {
              final food = _result!.foods[i];
              final color = _getColor(i);
              final isSelected = _selectedFoodIndex == i;

              return GestureDetector(
                onTap: () => _onFoodTap(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? color : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? color : color.withOpacity(0.5),
                      width: 1.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: color.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : color,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: isSelected ? color : Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        food.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : _textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withOpacity(0.25)
                              : color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${food.calories.toInt()}kcal',
                          style: TextStyle(
                            fontSize: 10,
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

  // ========== 分析按鈕 ==========
  Widget _buildAnalyzeButton() {
    final enabled = _selectedImage != null && !_isLoading;
    return GestureDetector(
      onTap: enabled ? _analyzeFood : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: enabled
                ? [const Color(0xFF5B9A8B), const Color(0xFF4E8A7C)]
                : [Colors.grey.shade300, Colors.grey.shade400],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: const Color(0xFF5B9A8B).withOpacity(0.35),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: _isLoading
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _isRetrying ? '重試中...' : '分析中...',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              : const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_rounded,
                        color: Colors.white, size: 22),
                    SizedBox(width: 10),
                    Text(
                      '開始 AI 分析',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // ========== 重試提示 ==========
  Widget _buildRetryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFE4A0)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(Color(0xFFE8A000)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI 服務忙碌中',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFB87A00),
                  ),
                ),
                Text(
                  '正在重試 ($_currentRetry/$_maxRetries)...',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFB87A00),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ========== 錯誤訊息 ==========
  Widget _buildErrorCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFDC2626),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  '分析失敗',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFDC2626),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy_rounded,
                      size: 18, color: Color(0xFFDC2626)),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _errorMessage ?? ''));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('已複製'),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: SelectableText(
              _errorMessage!,
              style: const TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: Color(0xFF991B1B),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _analyzeFood,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('重試'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========== 🆕 v6: 營養總計卡片（新增糖和纖維）==========
  Widget _buildNutritionCard() {
    final total = _result!.total;
    return _softCard(
      child: Column(
        children: [
          Row(
            children: [
              _sectionHeader(Icons.local_fire_department_rounded, '營養總計'),
              const Spacer(),
              _confidenceBadge(_result!.overallConfidence),
            ],
          ),
          const SizedBox(height: 20),
          // 第一排：熱量、蛋白質、碳水、脂肪
          Row(
            children: [
              Expanded(
                child: _nutrientBox(
                    '熱量', '${total.calories.toInt()}', 'kcal', 
                    const Color(0xFFE57373)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _nutrientBox(
                    '蛋白質', total.protein.toStringAsFixed(1), 'g',
                    const Color(0xFF64B5F6)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _nutrientBox(
                    '碳水', total.carbs.toStringAsFixed(1), 'g',
                    const Color(0xFFFFB74D)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _nutrientBox(
                    '脂肪', total.fat.toStringAsFixed(1), 'g',
                    const Color(0xFF81C784)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 🆕 第二排：糖、纖維
          Row(
            children: [
              Expanded(
                child: _nutrientBox(
                    '糖', total.sugar.toStringAsFixed(1), 'g',
                    const Color(0xFFEC4899)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _nutrientBox(
                    '膳食纖維', total.fiber.toStringAsFixed(1), 'g',
                    const Color(0xFF22C55E)),
              ),
              const SizedBox(width: 10),
              // 空白佔位
              const Expanded(child: SizedBox()),
              const SizedBox(width: 10),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _nutrientBox(String label, String value, String unit, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: _textSecondary)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(unit, style: TextStyle(fontSize: 10, color: _textSecondary)),
        ],
      ),
    );
  }

  Widget _confidenceBadge(String confidence) {
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // ========== 🆕 v6: 食物列表卡片（新增糖和纖維）==========
  Widget _buildFoodsCard() {
    return _softCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
              Icons.restaurant_rounded, '辨識食物 (${_result!.foods.length}項)'),
          const SizedBox(height: 16),
          ...List.generate(
              _result!.foods.length, (i) => _foodItem(_result!.foods[i], i)),
        ],
      ),
    );
  }

  Widget _foodItem(FoodItem food, int index) {
    final color = _getColor(index);
    final isSelected = _selectedFoodIndex == index;

    return GestureDetector(
      key: _foodCardKeys[index],
      onTap: () => _onFoodTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.06) : _bgColor,
          borderRadius: BorderRadius.circular(14),
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
                  width: 26,
                  height: 26,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        food.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        food.portion,
                        style: TextStyle(fontSize: 12, color: _textSecondary),
                      ),
                    ],
                  ),
                ),
                _confidenceBadge(food.confidence),
              ],
            ),
            const SizedBox(height: 12),
            // 🆕 v6: 新增糖和纖維標籤
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _nutrientTag(
                    '${food.calories.toInt()} kcal', const Color(0xFFE57373)),
                _nutrientTag(
                    '蛋白 ${food.protein.toStringAsFixed(1)}g', 
                    const Color(0xFF64B5F6)),
                _nutrientTag(
                    '碳水 ${food.carbs.toStringAsFixed(1)}g',
                    const Color(0xFFFFB74D)),
                _nutrientTag(
                    '脂肪 ${food.fat.toStringAsFixed(1)}g',
                    const Color(0xFF81C784)),
                // 🆕 糖和纖維
                _nutrientTag(
                    '糖 ${food.sugar.toStringAsFixed(1)}g',
                    const Color(0xFFEC4899)),
                _nutrientTag(
                    '纖維 ${food.fiber.toStringAsFixed(1)}g',
                    const Color(0xFF22C55E)),
              ],
            ),
            if (food.notes != null && food.notes!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 14, color: _textSecondary),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        food.notes!,
                        style: TextStyle(
                          fontSize: 11,
                          color: _textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
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

  Widget _nutrientTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  // ========== 餐點評估卡片 ==========
  Widget _buildAssessmentCard() {
    final assessment = _result!.mealAssessment!;
    final scoreColor = assessment.balanceScore >= 8
        ? const Color(0xFF22C55E)
        : assessment.balanceScore >= 5
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444);

    return _softCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _sectionHeader(Icons.star_rounded, '餐點評估'),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: scoreColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${assessment.balanceScore}/10',
                  style: TextStyle(
                    color: scoreColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (assessment.strengths.isNotEmpty)
            _assessmentSection(
              '優點',
              Icons.check_circle_rounded,
              const Color(0xFF22C55E),
              assessment.strengths,
            ),
          if (assessment.improvements.isNotEmpty) ...[
            const SizedBox(height: 14),
            _assessmentSection(
              '可改進',
              Icons.lightbulb_rounded,
              const Color(0xFFF59E0B),
              assessment.improvements,
            ),
          ],
        ],
      ),
    );
  }

  Widget _assessmentSection(
      String title, IconData icon, Color color, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: color,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(left: 24, bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 7),
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _textSecondary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ========== AI 建議卡片 ==========
  Widget _buildRecommendationsCard() {
    final colors = [
      const Color(0xFFF59E0B),
      const Color(0xFF3B82F6),
      const Color(0xFFA855F7),
    ];
    final icons = [
      Icons.flash_on_rounded,
      Icons.restaurant_menu_rounded,
      Icons.lightbulb_rounded,
    ];

    return _softCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.tips_and_updates_rounded, 'AI 建議'),
          const SizedBox(height: 16),
          ...List.generate(_result!.recommendations.length, (i) {
            final rec = _result!.recommendations[i];
            final color = colors[i % colors.length];
            final icon = icons[i % icons.length];

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withOpacity(0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: color, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        '建議',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    rec.advice,
                    style: const TextStyle(
                      height: 1.6,
                      color: _textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  if (rec.reason.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      rec.reason,
                      style: TextStyle(
                        fontSize: 12,
                        color: _textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}