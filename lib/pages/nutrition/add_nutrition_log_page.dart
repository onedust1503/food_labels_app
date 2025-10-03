import 'package:flutter/material.dart';
import '../../services/nutrition_service.dart';

class AddNutritionLogPage extends StatefulWidget {
  final Map<String, dynamic> foodData;

  const AddNutritionLogPage({super.key, required this.foodData});

  @override
  State<AddNutritionLogPage> createState() => _AddNutritionLogPageState();
}

class _AddNutritionLogPageState extends State<AddNutritionLogPage> {
  double _servings = 1.0;
  String _selectedMealType = 'breakfast';
  final NutritionService _nutritionService = NutritionService();
  bool _isSaving = false;

  void _saveLog() async {
    setState(() => _isSaving = true);

    try {
      await _nutritionService.addFoodLog(
        foodData: widget.foodData,
        servings: _servings,
        mealType: _selectedMealType,
      );

      if (mounted) {
        Navigator.pop(context);
        Navigator.pop(context);
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
  Widget build(BuildContext context) {
    double totalCalories = (widget.foodData['calories'] ?? 0) * _servings;
    double totalProtein = (widget.foodData['protein'] ?? 0) * _servings;
    double totalCarbs = (widget.foodData['carbs'] ?? 0) * _servings;
    double totalFat = (widget.foodData['fat'] ?? 0) * _servings;

    return Scaffold(
      appBar: AppBar(
        title: const Text('記錄飲食'),
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
              child: const Text('儲存', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 食物資訊
            Text(
              widget.foodData['name'],
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.foodData['category']} • ${widget.foodData['servingSize']}',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),

            // 餐別選擇
            const Text('餐別', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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

            // 份量選擇
            const Text('份量', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
                '${_servings.toStringAsFixed(1)} ${widget.foodData['servingSize']}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 24),

            // 營養資訊
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildNutritionRow('熱量', '${totalCalories.toStringAsFixed(0)} 大卡'),
                  const Divider(height: 24),
                  _buildNutritionRow('蛋白質', '${totalProtein.toStringAsFixed(1)} g'),
                  _buildNutritionRow('碳水化合物', '${totalCarbs.toStringAsFixed(1)} g'),
                  _buildNutritionRow('脂肪', '${totalFat.toStringAsFixed(1)} g'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}