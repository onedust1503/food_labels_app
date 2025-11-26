// lib/pages/nutrition/manual_nutrition_input_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/nutrition_service.dart';

class ManualNutritionInputPage extends StatefulWidget {
  final Map<String, dynamic>? initialData; // OCR 辨識結果預填

  const ManualNutritionInputPage({
    super.key,
    this.initialData,
  });

  @override
  State<ManualNutritionInputPage> createState() => _ManualNutritionInputPageState();
}

class _ManualNutritionInputPageState extends State<ManualNutritionInputPage> {
  final _formKey = GlobalKey<FormState>();
  final NutritionService _nutritionService = NutritionService();

  // 表單控制器
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _servingSizeController = TextEditingController();
  final TextEditingController _caloriesController = TextEditingController();
  final TextEditingController _proteinController = TextEditingController();
  final TextEditingController _fatController = TextEditingController();
  final TextEditingController _carbsController = TextEditingController();
  final TextEditingController _sodiumController = TextEditingController();

  String _selectedMealType = 'breakfast';
  double _servings = 1.0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  /// 載入 OCR 辨識的初始資料
  void _loadInitialData() {
    if (widget.initialData != null) {
      final data = widget.initialData!;
      
      // 預填數值（如果 OCR 有辨識到）
      if (data['calories'] != null) {
        _caloriesController.text = data['calories'].toString();
      }
      if (data['protein'] != null) {
        _proteinController.text = data['protein'].toString();
      }
      if (data['fat'] != null) {
        _fatController.text = data['fat'].toString();
      }
      if (data['carbs'] != null) {
        _carbsController.text = data['carbs'].toString();
      }
      if (data['sodium'] != null) {
        _sodiumController.text = data['sodium'].toString();
      }
      if (data['servingSize'] != null) {
        _servingSizeController.text = data['servingSize'].toString();
      }
    }
  }

  /// 儲存飲食記錄
  Future<void> _saveLog() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // 建立食物資料
      Map<String, dynamic> foodData = {
        'name': _nameController.text.trim(),
        'servingSize': _servingSizeController.text.trim(),
        'calories': double.tryParse(_caloriesController.text) ?? 0,
        'protein': double.tryParse(_proteinController.text) ?? 0,
        'fat': double.tryParse(_fatController.text) ?? 0,
        'carbs': double.tryParse(_carbsController.text) ?? 0,
        'sodium': double.tryParse(_sodiumController.text) ?? 0,
        'category': '手動輸入',
        'id': 'manual_${DateTime.now().millisecondsSinceEpoch}',
      };

      // 儲存記錄
      await _nutritionService.addFoodLog(
        foodData: foodData,
        servings: _servings,
        mealType: _selectedMealType,
      );

      if (mounted) {
        // 返回兩層（關閉輸入頁和掃描頁）
        Navigator.pop(context);
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('記錄成功！'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('記錄失敗: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _servingSizeController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _fatController.dispose();
    _carbsController.dispose();
    _sodiumController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('確認營養資訊'),
        backgroundColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveLog,
              child: const Text(
                '儲存',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 提示訊息
              if (widget.initialData != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          '已自動填入辨識結果，請確認數值是否正確',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // 食物名稱
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '食物名稱 *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.restaurant),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '請輸入食物名稱';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 份量大小
              TextFormField(
                controller: _servingSizeController,
                decoration: const InputDecoration(
                  labelText: '份量大小（例如：100g, 1碗）',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.straighten),
                ),
              ),
              const SizedBox(height: 24),

              // 餐別選擇
              const Text(
                '餐別 *',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('早餐'),
                    selected: _selectedMealType == 'breakfast',
                    onSelected: (_) => setState(() => _selectedMealType = 'breakfast'),
                    selectedColor: const Color(0xFF3B82F6),
                    labelStyle: TextStyle(
                      color: _selectedMealType == 'breakfast' ? Colors.white : Colors.black,
                    ),
                  ),
                  ChoiceChip(
                    label: const Text('午餐'),
                    selected: _selectedMealType == 'lunch',
                    onSelected: (_) => setState(() => _selectedMealType = 'lunch'),
                    selectedColor: const Color(0xFF3B82F6),
                    labelStyle: TextStyle(
                      color: _selectedMealType == 'lunch' ? Colors.white : Colors.black,
                    ),
                  ),
                  ChoiceChip(
                    label: const Text('晚餐'),
                    selected: _selectedMealType == 'dinner',
                    onSelected: (_) => setState(() => _selectedMealType = 'dinner'),
                    selectedColor: const Color(0xFF3B82F6),
                    labelStyle: TextStyle(
                      color: _selectedMealType == 'dinner' ? Colors.white : Colors.black,
                    ),
                  ),
                  ChoiceChip(
                    label: const Text('點心'),
                    selected: _selectedMealType == 'snack',
                    onSelected: (_) => setState(() => _selectedMealType = 'snack'),
                    selectedColor: const Color(0xFF3B82F6),
                    labelStyle: TextStyle(
                      color: _selectedMealType == 'snack' ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 營養數值
              const Text(
                '營養資訊（每份）*',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),

              _buildNumberField(
                controller: _caloriesController,
                label: '熱量（大卡）',
                icon: Icons.local_fire_department,
              ),
              const SizedBox(height: 12),
              _buildNumberField(
                controller: _proteinController,
                label: '蛋白質（g）',
                icon: Icons.egg,
              ),
              const SizedBox(height: 12),
              _buildNumberField(
                controller: _fatController,
                label: '脂肪（g）',
                icon: Icons.water_drop,
              ),
              const SizedBox(height: 12),
              _buildNumberField(
                controller: _carbsController,
                label: '碳水化合物（g）',
                icon: Icons.grain,
              ),
              const SizedBox(height: 12),
              _buildNumberField(
                controller: _sodiumController,
                label: '鈉（mg）',
                icon: Icons.science,
                required: false,
              ),
              const SizedBox(height: 24),

              // 份數選擇
              const Text(
                '份數',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      if (_servings > 0.5) setState(() => _servings -= 0.5);
                    },
                    icon: const Icon(Icons.remove_circle_outline, color: Color(0xFF3B82F6)),
                  ),
                  Expanded(
                    child: Slider(
                      value: _servings,
                      min: 0.5,
                      max: 5.0,
                      divisions: 9,
                      label: _servings.toStringAsFixed(1),
                      activeColor: const Color(0xFF3B82F6),
                      onChanged: (value) => setState(() => _servings = value),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      if (_servings < 5.0) setState(() => _servings += 0.5);
                    },
                    icon: const Icon(Icons.add_circle_outline, color: Color(0xFF3B82F6)),
                  ),
                ],
              ),
              Center(
                child: Text(
                  '${_servings.toStringAsFixed(1)} 份',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool required = true,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
      ],
      validator: required
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return '請輸入數值';
              }
              if (double.tryParse(value) == null) {
                return '請輸入有效數字';
              }
              return null;
            }
          : null,
    );
  }
}
