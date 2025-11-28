// lib/pages/profile/trainee_edit_page.dart
// 學生專用的個人資料編輯頁面
// 🔥 修正：使用 UserGoalsService 同步更新目標到所有位置

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/user_goals_service.dart'; // 🔥 新增

class TraineeEditPage extends StatefulWidget {
  const TraineeEditPage({Key? key}) : super(key: key);

  @override
  State<TraineeEditPage> createState() => _TraineeEditPageState();
}

class _TraineeEditPageState extends State<TraineeEditPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserGoalsService _goalsService = UserGoalsService(); // 🔥 新增
  
  // 表單控制器
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _targetWeightController = TextEditingController();
  final TextEditingController _dailyCaloriesController = TextEditingController();
  final TextEditingController _proteinController = TextEditingController(); // 🔥 新增
  final TextEditingController _carbsController = TextEditingController();   // 🔥 新增
  final TextEditingController _fatController = TextEditingController();     // 🔥 新增
  final TextEditingController _waterTargetController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  // 表單數據
  String _gender = 'male';
  DateTime? _birthDate;
  String _goal = '減重';
  String _activityLevel = 'light'; // 🔥 新增活動量
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _targetWeightController.dispose();
    _dailyCaloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _waterTargetController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('未登入');

      final doc = await _firestore.collection('users').doc(user.uid).get();
      
      if (doc.exists) {
        final data = doc.data()!;
        
        setState(() {
          _nameController.text = data['displayName'] ?? '';
          _gender = data['gender'] ?? 'male';
          _activityLevel = data['activityLevel'] ?? 'light';
          
          if (data['birthDate'] != null) {
            _birthDate = (data['birthDate'] as Timestamp).toDate();
          }
          
          _heightController.text = data['height']?.toString() ?? '';
          _weightController.text = data['weight']?.toString() ?? '';
          _targetWeightController.text = data['targetWeight']?.toString() ?? '';
          _dailyCaloriesController.text = data['dailyCalories']?.toString() ?? '';
          _proteinController.text = data['targetProtein']?.toString() ?? '';
          _carbsController.text = data['targetCarbs']?.toString() ?? '';
          _fatController.text = data['targetFat']?.toString() ?? '';
          _waterTargetController.text = data['waterTargetDefault']?.toString() ?? '2000';
          _goal = data['goal'] ?? '減重';
          _phoneController.text = data['phone'] ?? '';
        });
      }
    } catch (e) {
      _showError('載入資料失敗：$e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 🔥 新增：根據身體數據計算建議目標
  void _calculateRecommendedGoals() {
    final height = double.tryParse(_heightController.text);
    final weight = double.tryParse(_weightController.text);
    final age = _birthDate != null 
        ? DateTime.now().year - _birthDate!.year 
        : null;

    if (height == null || weight == null || age == null) {
      _showError('請先填寫身高、體重和生日');
      return;
    }

    final recommendations = UserGoalsService.calculateRecommendedGoals(
      height: height,
      weight: weight,
      age: age,
      gender: _gender,
      activityLevel: _activityLevel,
      fitnessGoal: _goal,
    );

    // 顯示計算結果對話框
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.calculate, color: Color(0xFF3B82F6)),
            const SizedBox(width: 8),
            const Text('建議目標'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRecommendationRow('基礎代謝率 (BMR)', '${recommendations['bmr']} 大卡'),
            _buildRecommendationRow('每日消耗 (TDEE)', '${recommendations['tdee']} 大卡'),
            const Divider(height: 24),
            _buildRecommendationRow('建議熱量', '${recommendations['targetCalories']} 大卡', highlight: true),
            _buildRecommendationRow('蛋白質', '${recommendations['targetProtein']} g'),
            _buildRecommendationRow('碳水化合物', '${recommendations['targetCarbs']} g'),
            _buildRecommendationRow('脂肪', '${recommendations['targetFat']} g'),
            _buildRecommendationRow('喝水目標', '${recommendations['targetWater']} ml'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _dailyCaloriesController.text = recommendations['targetCalories'].toString();
                _proteinController.text = recommendations['targetProtein'].toString();
                _carbsController.text = recommendations['targetCarbs'].toString();
                _fatController.text = recommendations['targetFat'].toString();
                _waterTargetController.text = recommendations['targetWater'].toString();
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('已套用建議目標！'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
            ),
            child: const Text('套用'),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: highlight ? FontWeight.bold : FontWeight.w600,
              color: highlight ? const Color(0xFF3B82F6) : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveData() async {
    // 驗證必填欄位
    if (_nameController.text.isEmpty) {
      _showError('請輸入姓名');
      return;
    }
    if (_heightController.text.isEmpty) {
      _showError('請輸入身高');
      return;
    }
    if (_weightController.text.isEmpty) {
      _showError('請輸入體重');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('未登入');

      final age = _birthDate != null 
          ? DateTime.now().year - _birthDate!.year 
          : null;

      // 1️⃣ 更新基本用戶資料
      await _firestore.collection('users').doc(user.uid).set({
        'displayName': _nameController.text.trim(),
        'gender': _gender,
        'birthDate': _birthDate != null ? Timestamp.fromDate(_birthDate!) : null,
        'age': age,
        'height': int.tryParse(_heightController.text),
        'weight': double.tryParse(_weightController.text),
        'targetWeight': double.tryParse(_targetWeightController.text),
        'goal': _goal,
        'activityLevel': _activityLevel,
        'phone': _phoneController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 2️⃣ 🔥 使用 UserGoalsService 同步更新目標到所有位置
      await _goalsService.updateUserGoals(
        targetCalories: int.tryParse(_dailyCaloriesController.text),
        targetProtein: double.tryParse(_proteinController.text),
        targetCarbs: double.tryParse(_carbsController.text),
        targetFat: double.tryParse(_fatController.text),
        targetWater: int.tryParse(_waterTargetController.text),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 儲存成功！目標已同步更新'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      _showError('儲存失敗：$e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
        title: const Text('編輯個人資料'),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveData,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    '儲存',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 基本資料
                  _buildSection(
                    title: '基本資料',
                    icon: Icons.person,
                    children: [
                      _buildTextField(
                        controller: _nameController,
                        label: '姓名',
                        hint: '請輸入姓名',
                        icon: Icons.person,
                      ),
                      const SizedBox(height: 16),
                      _buildGenderSelector(),
                      const SizedBox(height: 16),
                      _buildBirthDateSelector(),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _phoneController,
                        label: '手機號碼',
                        hint: '例如：0912345678',
                        icon: Icons.phone,
                        keyboardType: TextInputType.phone,
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // 身體數據
                  _buildSection(
                    title: '身體數據',
                    icon: Icons.monitor_weight,
                    children: [
                      _buildNumberField(
                        controller: _heightController,
                        label: '身高',
                        hint: '請輸入身高',
                        unit: 'cm',
                        icon: Icons.height,
                      ),
                      const SizedBox(height: 16),
                      _buildNumberField(
                        controller: _weightController,
                        label: '目前體重',
                        hint: '請輸入體重',
                        unit: 'kg',
                        icon: Icons.monitor_weight,
                      ),
                      const SizedBox(height: 16),
                      if (_heightController.text.isNotEmpty && 
                          _weightController.text.isNotEmpty)
                        _buildBMIDisplay(),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // 健身目標
                  _buildSection(
                    title: '健身目標',
                    icon: Icons.flag,
                    children: [
                      _buildGoalSelector(),
                      const SizedBox(height: 16),
                      _buildActivityLevelSelector(), // 🔥 新增活動量選擇
                      const SizedBox(height: 16),
                      _buildNumberField(
                        controller: _targetWeightController,
                        label: '目標體重',
                        hint: '請輸入目標體重',
                        unit: 'kg',
                        icon: Icons.flag,
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // 🔥 新增：營養目標區塊
                  _buildSection(
                    title: '營養目標',
                    icon: Icons.restaurant,
                    trailing: TextButton.icon(
                      onPressed: _calculateRecommendedGoals,
                      icon: const Icon(Icons.calculate, size: 18),
                      label: const Text('自動計算'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF3B82F6),
                      ),
                    ),
                    children: [
                      _buildNumberField(
                        controller: _dailyCaloriesController,
                        label: '每日熱量目標',
                        hint: '例如：2000',
                        unit: 'kcal',
                        icon: Icons.local_fire_department,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildCompactNumberField(
                              controller: _proteinController,
                              label: '蛋白質',
                              unit: 'g',
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildCompactNumberField(
                              controller: _carbsController,
                              label: '碳水',
                              unit: 'g',
                              color: Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildCompactNumberField(
                              controller: _fatController,
                              label: '脂肪',
                              unit: 'g',
                              color: Colors.purple,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildNumberField(
                        controller: _waterTargetController,
                        label: '每日喝水目標',
                        hint: '例如：2000',
                        unit: 'ml',
                        icon: Icons.water_drop,
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF3B82F6)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: const Color(0xFF3B82F6), size: 20),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required String unit,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          onChanged: (value) => setState(() {}),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: const Color(0xFF3B82F6), size: 20),
            suffixText: unit,
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  /// 🔥 新增：緊湊型數字輸入框（用於三大營養素）
  Widget _buildCompactNumberField({
    required TextEditingController controller,
    required String label,
    required String unit,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            suffixText: unit,
            filled: true,
            fillColor: color.withOpacity(0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: color.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: color, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '性別',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildGenderButton('male', '男性', Icons.male),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildGenderButton('female', '女性', Icons.female),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGenderButton(String value, String label, IconData icon) {
    final isSelected = _gender == value;
    return InkWell(
      onTap: () => setState(() => _gender = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3B82F6).withOpacity(0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF3B82F6) : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF3B82F6) : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? const Color(0xFF3B82F6) : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBirthDateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '生日',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _selectBirthDate(context),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                const Icon(Icons.cake, color: Color(0xFF3B82F6), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _birthDate != null
                        ? '${_birthDate!.year}/${_birthDate!.month}/${_birthDate!.day}'
                        : '請選擇生日',
                    style: TextStyle(
                      fontSize: 14,
                      color: _birthDate != null ? Colors.black87 : Colors.grey,
                    ),
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 🔥 新增：活動量選擇器
  Widget _buildActivityLevelSelector() {
    final levels = {
      'sedentary': '久坐（幾乎不運動）',
      'light': '輕度（每週運動1-3天）',
      'moderate': '中度（每週運動3-5天）',
      'active': '高度（每週運動6-7天）',
      'very_active': '非常活躍（體力勞動/專業運動員）',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '活動量',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _activityLevel,
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down),
              items: levels.entries.map((entry) {
                return DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value, style: const TextStyle(fontSize: 14)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _activityLevel = value);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGoalSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '健身目標',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        _buildGoalButton('減重', '降低體重，塑造身材'),
        const SizedBox(height: 8),
        _buildGoalButton('增肌', '增加肌肉量，提升力量'),
        const SizedBox(height: 8),
        _buildGoalButton('維持', '保持現狀，健康生活'),
      ],
    );
  }

  Widget _buildGoalButton(String goalValue, String description) {
    final isSelected = _goal == goalValue;
    return InkWell(
      onTap: () => setState(() => _goal = goalValue),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3B82F6).withOpacity(0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF3B82F6) : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              color: isSelected ? const Color(0xFF3B82F6) : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    goalValue,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? const Color(0xFF3B82F6) : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBMIDisplay() {
    final height = double.tryParse(_heightController.text);
    final weight = double.tryParse(_weightController.text);
    
    if (height == null || weight == null || height == 0) {
      return const SizedBox.shrink();
    }
    
    final bmi = weight / ((height / 100) * (height / 100));
    final bmiText = bmi.toStringAsFixed(1);
    
    String category = '';
    Color color = Colors.green;
    
    if (bmi < 18.5) {
      category = '過輕';
      color = Colors.orange;
    } else if (bmi < 24) {
      category = '正常';
      color = Colors.green;
    } else if (bmi < 27) {
      category = '過重';
      color = Colors.orange;
    } else {
      category = '肥胖';
      color = Colors.red;
    }
    
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.analytics, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                const Text(
                  'BMI: ',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  bmiText,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  category,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectBirthDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF3B82F6),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _birthDate = picked);
    }
  }
}