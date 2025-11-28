// lib/pages/profile/trainee_setup_page.dart
// 學生專用的初始資料設定頁面
// 🔥 修正：使用 UserGoalsService 同步更新目標到所有位置

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/user_goals_service.dart'; // 🔥 新增

class TraineeSetupPage extends StatefulWidget {
  const TraineeSetupPage({Key? key}) : super(key: key);

  @override
  State<TraineeSetupPage> createState() => _TraineeSetupPageState();
}

class _TraineeSetupPageState extends State<TraineeSetupPage> {
  final PageController _pageController = PageController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserGoalsService _goalsService = UserGoalsService(); // 🔥 新增
  
  int _currentStep = 0;
  final int _totalSteps = 3;

  // 表單控制器
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _targetWeightController = TextEditingController();
  final TextEditingController _dailyCaloriesController = TextEditingController();
  final TextEditingController _proteinController = TextEditingController();   // 🔥 新增
  final TextEditingController _carbsController = TextEditingController();     // 🔥 新增
  final TextEditingController _fatController = TextEditingController();       // 🔥 新增
  final TextEditingController _waterTargetController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  // 表單數據
  String _gender = 'male';
  DateTime? _birthDate;
  String _goal = '減重';
  String _activityLevel = 'light'; // 🔥 新增
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserEmail();
  }

  @override
  void dispose() {
    _pageController.dispose();
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

  Future<void> _loadUserEmail() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final name = doc.data()?['displayName'];
        if (name != null && name.isNotEmpty) {
          _nameController.text = name;
        }
      }
    }
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      if (_validateCurrentStep()) {
        // 🔥 在第二步完成後自動計算建議目標
        if (_currentStep == 1) {
          _autoCalculateGoals();
        }
        
        setState(() => _currentStep++);
        _pageController.animateToPage(
          _currentStep,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } else {
      _completeSetup();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  /// 🔥 新增：自動計算建議目標
  void _autoCalculateGoals() {
    final height = double.tryParse(_heightController.text);
    final weight = double.tryParse(_weightController.text);
    final age = _birthDate != null 
        ? DateTime.now().year - _birthDate!.year 
        : 25; // 預設 25 歲

    if (height != null && weight != null) {
      final recommendations = UserGoalsService.calculateRecommendedGoals(
        height: height,
        weight: weight,
        age: age,
        gender: _gender,
        activityLevel: _activityLevel,
        fitnessGoal: _goal,
      );

      setState(() {
        _dailyCaloriesController.text = recommendations['targetCalories'].toString();
        _proteinController.text = recommendations['targetProtein'].toString();
        _carbsController.text = recommendations['targetCarbs'].toString();
        _fatController.text = recommendations['targetFat'].toString();
        _waterTargetController.text = recommendations['targetWater'].toString();
      });
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        if (_nameController.text.isEmpty) {
          _showError('請輸入姓名');
          return false;
        }
        if (_birthDate == null) {
          _showError('請選擇生日');
          return false;
        }
        return true;
      case 1:
        if (_heightController.text.isEmpty) {
          _showError('請輸入身高');
          return false;
        }
        if (_weightController.text.isEmpty) {
          _showError('請輸入體重');
          return false;
        }
        return true;
      case 2:
        if (_dailyCaloriesController.text.isEmpty) {
          _showError('請輸入每日熱量目標');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  Future<void> _completeSetup() async {
    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('未登入');

      final age = _birthDate != null 
          ? DateTime.now().year - _birthDate!.year 
          : null;

      // 1️⃣ 儲存基本用戶資料
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
        'profileSetupCompleted': true,
        'profileSetupAt': FieldValue.serverTimestamp(),
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

      // 3️⃣ 🔥 確保今日的目標數據存在
      await _goalsService.ensureTodayGoalsExist();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 設定完成！開始你的健身之旅！'),
            backgroundColor: Colors.green,
          ),
        );
        
        Navigator.of(context).pushReplacementNamed('/studentHome');
      }
    } catch (e) {
      _showError('儲存失敗：$e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF3B82F6).withOpacity(0.8),
              const Color(0xFF2563EB),
              const Color(0xFF1D4ED8),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildProgressBar(),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (index) {
                    setState(() => _currentStep = index);
                  },
                  children: [
                    _buildStep1BasicInfo(),
                    _buildStep2BodyData(),
                    _buildStep3Goals(),
                  ],
                ),
              ),
              _buildBottomButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '學員資料設定',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${_currentStep + 1}/$_totalSteps',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: (_currentStep + 1) / _totalSteps,
              backgroundColor: Colors.white30,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  // 步驟 1：基本資料
  Widget _buildStep1BasicInfo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepTitle('👤', '基本資料', '讓我們認識你'),
          const SizedBox(height: 32),
          
          _buildWhiteCard(
            child: Column(
              children: [
                _buildTextField(
                  controller: _nameController,
                  label: '姓名',
                  hint: '請輸入你的姓名',
                  icon: Icons.person,
                ),
                const SizedBox(height: 20),
                
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '性別',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
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
                ),
                const SizedBox(height: 20),
                
                InkWell(
                  onTap: () => _selectBirthDate(context),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.cake, color: Color(0xFF3B82F6)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '生日',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _birthDate != null
                                    ? '${_birthDate!.year}/${_birthDate!.month}/${_birthDate!.day}'
                                    : '請選擇生日',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: _birthDate != null ? Colors.black : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 16),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _phoneController,
                  label: '手機號碼（選填）',
                  hint: '例如：0912345678',
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 步驟 2：身體數據
  Widget _buildStep2BodyData() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepTitle('📏', '身體數據', '了解你的身體狀況'),
          const SizedBox(height: 32),
          
          _buildWhiteCard(
            child: Column(
              children: [
                _buildNumberField(
                  controller: _heightController,
                  label: '身高',
                  hint: '請輸入身高',
                  unit: 'cm',
                  icon: Icons.height,
                ),
                const SizedBox(height: 20),
                _buildNumberField(
                  controller: _weightController,
                  label: '目前體重',
                  hint: '請輸入體重',
                  unit: 'kg',
                  icon: Icons.monitor_weight,
                ),
                const SizedBox(height: 20),
                
                // 🔥 新增：活動量選擇
                _buildActivityLevelSelector(),
                
                const SizedBox(height: 20),
                
                if (_heightController.text.isNotEmpty && 
                    _weightController.text.isNotEmpty)
                  _buildBMIDisplay(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 步驟 3：健身目標
  Widget _buildStep3Goals() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepTitle('🎯', '健身目標', '設定你的目標'),
          const SizedBox(height: 32),
          
          _buildWhiteCard(
            child: Column(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '你的目標是什麼？',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildGoalButton('減重', '降低體重，塑造身材'),
                    const SizedBox(height: 8),
                    _buildGoalButton('增肌', '增加肌肉量，提升力量'),
                    const SizedBox(height: 8),
                    _buildGoalButton('維持', '保持現狀，健康生活'),
                  ],
                ),
                const SizedBox(height: 20),
                
                _buildNumberField(
                  controller: _targetWeightController,
                  label: '目標體重',
                  hint: '請輸入目標體重',
                  unit: 'kg',
                  icon: Icons.flag,
                ),
                const SizedBox(height: 20),

                // 🔥 新增：顯示計算來源提示
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade600, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '以下目標已根據你的身體數據自動計算，你可以手動調整',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                _buildNumberField(
                  controller: _dailyCaloriesController,
                  label: '每日熱量目標',
                  hint: '例如：2000',
                  unit: 'kcal',
                  icon: Icons.local_fire_department,
                ),
                const SizedBox(height: 16),
                
                // 🔥 新增：三大營養素目標
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
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildCompactNumberField(
                        controller: _carbsController,
                        label: '碳水',
                        unit: 'g',
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 8),
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
          ),
        ],
      ),
    );
  }

  Widget _buildStepTitle(String emoji, String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildWhiteCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
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
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: const Color(0xFF3B82F6)),
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
            ),
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
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          onChanged: (value) => setState(() {}),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: const Color(0xFF3B82F6)),
            suffixText: unit,
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
            ),
          ),
        ),
      ],
    );
  }

  /// 🔥 新增：緊湊型數字輸入框
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
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: color, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderButton(String value, String label, IconData icon) {
    final isSelected = _gender == value;
    return InkWell(
      onTap: () => setState(() => _gender = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3B82F6).withOpacity(0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF3B82F6) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF3B82F6) : Colors.grey,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isSelected ? const Color(0xFF3B82F6) : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🔥 新增：活動量選擇器
  Widget _buildActivityLevelSelector() {
    final levels = {
      'sedentary': '久坐（幾乎不運動）',
      'light': '輕度（每週1-3天）',
      'moderate': '中度（每週3-5天）',
      'active': '高度（每週6-7天）',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '活動量',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...levels.entries.map((entry) {
          final isSelected = _activityLevel == entry.key;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => setState(() => _activityLevel = entry.key),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF3B82F6).withOpacity(0.1) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF3B82F6) : Colors.transparent,
                    width: 2,
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
                    Text(
                      entry.value,
                      style: TextStyle(
                        fontSize: 14,
                        color: isSelected ? const Color(0xFF3B82F6) : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildGoalButton(String goalValue, String description) {
    final isSelected = _goal == goalValue;
    return InkWell(
      onTap: () {
        setState(() => _goal = goalValue);
        // 🔥 切換目標時重新計算
        _autoCalculateGoals();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3B82F6).withOpacity(0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF3B82F6) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              color: isSelected ? const Color(0xFF3B82F6) : Colors.grey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    goalValue,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? const Color(0xFF3B82F6) : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.analytics, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'BMI 指數',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      bmiText,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      category,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
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
      initialDate: DateTime(2000),
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

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Color(0xFF3B82F6)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '上一步',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3B82F6),
                  ),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      _currentStep == _totalSteps - 1 ? '完成設定' : '下一步',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}