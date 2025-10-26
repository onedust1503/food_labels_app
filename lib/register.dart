import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 新增：觸覺回饋功能
// *** 新增：導入 Firebase 相關套件 ***
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // 控制器：用來取得使用者輸入的文字
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  
  // *** 新增：Firebase 實例 ***
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // 控制密碼是否可見的變數
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  
  // 新增載入狀態
  bool _isLoading = false;
  
  // 表單驗證的GlobalKey
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // 身分選擇狀態變數 (新增)
  int selectedRoleIndex = 0; // 預設選擇學員
  final List<String> roleOptions = ['學員', '教練']; // 身分選項
  String get selectedRole => roleOptions[selectedRoleIndex]; // 取得目前選擇的身分

  // ⭐ 新增：教練專業選項
  final List<String> specialtyOptions = ['重量訓練', '有氧運動', '瑜伽', '皮拉提斯'];
  List<String> selectedSpecialties = [];

  @override
  void dispose() {
    // 釋放控制器資源，避免記憶體洩漏
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  // 身分切換處理函數 (新增)
  void _onRoleChanged(int newIndex) {
    setState(() {
      selectedRoleIndex = newIndex; // 更新選擇的身分
      // ⭐ 切換身分時清空專業選擇
      selectedSpecialties.clear();
    });
    _triggerHapticFeedback(); // 觸覺回饋

    final roleName = roleOptions[selectedRoleIndex];
    // 顯示切換身分的提示訊息
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已選擇 $roleName 身分', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating, // 浮動式顯示
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // 身分切換Widget (新增)
  Widget _buildRoleSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: List.generate(roleOptions.length, (index) {
          bool isSelected = selectedRoleIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => _onRoleChanged(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF173C56) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isSelected ? [
                    BoxShadow(
                      color: const Color(0xFF173C56).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ] : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      roleOptions[index] == '教練' ? Icons.fitness_center : Icons.person,
                      color: isSelected ? Colors.white : Colors.grey[600],
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      roleOptions[index],
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[600],
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // 震動回饋 - 提供觸覺反饋 (新增)
  void _triggerHapticFeedback() {
    HapticFeedback.mediumImpact(); // 中等強度震動
  }

  // *** 新增：將 UI 選擇轉換為資料庫角色值 ***
  String _convertSelectedRoleToDbRole() {
    return selectedRole == '教練' ? 'coach' : 'trainee';
  }

  // *** 修復：創建用戶資料到 Firestore ***
  Future<void> _createUserProfile(User user, String role) async {
    try {
      // 確保角色值正確
      if (role != 'coach' && role != 'trainee') {
        throw Exception('無效的角色值: $role');
      }

      // 基本用戶資料
      Map<String, dynamic> userData = {
        'uid': user.uid,
        'email': user.email,
        'role': role,
        'displayName': _nameController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        'profileSetupCompleted': false, // 設為 false，首次登入需要設定
      };

      // ⭐ 重點修復：如果是教練，添加專業欄位
      if (role == 'coach') {
        userData['bio'] = '專業健身教練，提供專業訓練指導';
        userData['experience'] = 0; // 預設經驗年數
        // ✅ 關鍵：初始化為空陣列或用戶選擇的專業
        userData['specialties'] = selectedSpecialties.isNotEmpty 
            ? selectedSpecialties 
            : [];
        userData['certifications'] = [];
      }

      await _firestore.collection('users').doc(user.uid).set(
        userData,
        SetOptions(merge: true)
      );
      
      print('用戶資料創建成功，角色: $role');
      if (role == 'coach') {
        print('教練專業: ${userData['specialties']}');
      }
    } catch (e) {
      print('創建用戶資料失敗: $e');
      throw e; // 重新拋出錯誤，讓上層處理
    }
  }

  // *** 新增：處理 Firebase 認證錯誤 ***
  void _handleFirebaseAuthError(FirebaseAuthException e) {
    String errorMessage;
    
    switch (e.code) {
      case 'weak-password':
        errorMessage = '密碼強度不足，請設置更強的密碼';
        break;
      case 'email-already-in-use':
        errorMessage = '此電子郵件已被註冊，請使用其他郵件或直接登入';
        break;
      case 'invalid-email':
        errorMessage = '電子郵件格式不正確';
        break;
      case 'network-request-failed':
        errorMessage = '網路連接失敗，請檢查您的網路設定';
        break;
      default:
        errorMessage = '註冊失敗：${e.message ?? '未知錯誤'}';
    }
    
    _handleRegisterError(errorMessage);
  }

  // *** 完全重寫：註冊按鈕點擊事件 (使用真正的 Firebase Auth) ***
  void _handleRegister() async {
    // 觸覺回饋
    _triggerHapticFeedback();
    
    // 驗證表單
    if (!_formKey.currentState!.validate()) {
      _showSnackBar('請檢查輸入的資料格式', Colors.red);
      return;
    }

    // 檢查密碼確認
    if (_passwordController.text != _confirmPasswordController.text) {
      _showSnackBar('密碼與確認密碼不一致', Colors.red);
      return;
    }

    // 設置載入狀態
    setState(() {
      _isLoading = true;
    });

    try {
      // 檢查網路連接
      bool hasInternet = await _checkInternetConnection();
      if (!hasInternet) {
        throw Exception('無網路連接，請檢查您的網路設定');
      }

      // *** 修改：使用真正的 Firebase Auth 註冊 ***
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (userCredential.user != null) {
        // *** 修改：設置用戶顯示名稱 ***
        await userCredential.user!.updateDisplayName(_nameController.text.trim());
        
        // *** 修改：創建用戶資料，使用轉換後的角色值 ***
        String userRole = _convertSelectedRoleToDbRole();
        await _createUserProfile(userCredential.user!, userRole);

        print('註冊成功，角色: $userRole');
        
        // 註冊成功處理
        _handleRegisterSuccess();
      }

    } on FirebaseAuthException catch (e) {
      // *** 新增：Firebase 認證失敗處理 ***
      _handleFirebaseAuthError(e);
    } catch (error) {
      // 其他註冊失敗處理
      _handleRegisterError('註冊失敗：$error');
    } finally {
      // 結束載入狀態
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 處理註冊成功
  void _handleRegisterSuccess() {
    _triggerHapticFeedback(); // 成功震動回饋
    
    // 顯示成功訊息
    _showSnackBar('註冊成功！歡迎加入 $selectedRole 行列', Colors.green);
    
    // 清空表單
    _clearForm();
    
    // *** 修改：延遲後讓 AuthWrapper 自動處理導航，而不是返回登入頁面 ***
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        // AuthWrapper 會自動檢測登入狀態並導向正確頁面
        // 不需要手動 Navigator.pop(context);
      }
    });
  }

  // 處理註冊錯誤
  void _handleRegisterError(String errorMessage) {
    _triggerHapticFeedback(); // 錯誤震動回饋
    
    _showSnackBar(errorMessage, Colors.red);
  }

  // 清空表單
  void _clearForm() {
    _nameController.clear();
    _emailController.clear();
    _passwordController.clear();
    _confirmPasswordController.clear();
    // ⭐ 新增：清空專業選擇
    setState(() {
      selectedSpecialties.clear();
    });
  }

  // 檢查網路連接狀態
  Future<bool> _checkInternetConnection() async {
    // 實際專案中，這裡應該使用 connectivity_plus 套件
    // 現在先模擬網路檢查
    await Future.delayed(const Duration(milliseconds: 500));
    return true; // 模擬網路正常
  }

  // 顯示提示訊息 (修改：支援不同顏色)
  void _showSnackBar(String message, [Color? backgroundColor]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: backgroundColor ?? Colors.blue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // 驗證姓名格式
  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '請輸入您的姓名';
    }
    if (value.trim().length < 2) {
      return '姓名至少需要 2 個字元';
    }
    return null;
  }

  // 驗證 Email 格式
  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '請輸入電子郵件';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
      return '請輸入有效的電子郵件格式';
    }
    return null;
  }

  // 驗證密碼格式
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return '請輸入密碼';
    }
    if (value.length < 6) {
      return '密碼長度至少需要 6 個字元';
    }
    return null;
  }

  // 驗證確認密碼
  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return '請再次輸入密碼';
    }
    if (value != _passwordController.text) {
      return '兩次輸入的密碼不一致';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF173C56)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 標題和副標題
                  const Text(
                    '建立帳號',
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF173C56),
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '開始你的健身旅程',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 18,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  
                  // 身分選擇器
                  _buildRoleSelector(),
                  
                  const SizedBox(height: 20),
                  
                  // 姓名輸入框
                  Text(
                    '姓名',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  TextFormField(
                    controller: _nameController,
                    validator: _validateName,
                    decoration: InputDecoration(
                      hintText: '請輸入您的姓名',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      prefixIcon: Icon(Icons.person_outline, color: Colors.grey),
                      contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(
                          color: Colors.grey[300]!,
                          width: 2,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(
                          color: const Color(0xFF173C56),
                          width: 2,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: Colors.red, width: 1.5),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF1F2F4),
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Email 輸入框
                  Text(
                    '電子郵件',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  TextFormField(
                    controller: _emailController,
                    validator: _validateEmail,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: '請輸入您的電子郵件',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      prefixIcon: Icon(Icons.email_outlined, color: Colors.grey),
                      contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(
                          color: Colors.grey[300]!,
                          width: 2,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(
                          color: const Color(0xFF173C56),
                          width: 2,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: Colors.red, width: 1.5),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF1F2F4),
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  
                  // 密碼輸入框
                  Text(
                    '密碼',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  TextFormField(
                    controller: _passwordController,
                    validator: _validatePassword,
                    obscureText: !_isPasswordVisible,
                    decoration: InputDecoration(
                      hintText: '請輸入您的密碼',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      prefixIcon: Icon(Icons.lock_outline, color: Colors.grey),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                      contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(
                          color: Colors.grey[300]!,
                          width: 2,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(
                          color: const Color(0xFF173C56),
                          width: 2,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: Colors.red, width: 1.5),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF1F2F4),
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  
                  // 確認密碼輸入框
                  Text(
                    '確認密碼',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  TextFormField(
                    controller: _confirmPasswordController,
                    validator: _validateConfirmPassword,
                    obscureText: !_isConfirmPasswordVisible,
                    decoration: InputDecoration(
                      hintText: '請再次輸入密碼',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      prefixIcon: Icon(Icons.lock_outline, color: Colors.grey),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                          });
                        },
                      ),
                      contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(
                          color: Colors.grey[300]!,
                          width: 2,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(
                          color: const Color(0xFF173C56),
                          width: 2,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: Colors.red, width: 1.5),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF1F2F4),
                    ),
                  ),
                  
                  // ⭐ 新增：教練專業選擇 (僅教練身分時顯示)
                  if (selectedRole == '教練') ...[
                    const SizedBox(height: 20),
                    const Text(
                      '專業領域 (可多選)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: specialtyOptions.map((specialty) {
                        final isSelected = selectedSpecialties.contains(specialty);
                        return FilterChip(
                          label: Text(specialty),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                selectedSpecialties.add(specialty);
                              } else {
                                selectedSpecialties.remove(specialty);
                              }
                            });
                            _triggerHapticFeedback(); // 震動回饋
                          },
                          selectedColor: Colors.green.withOpacity(0.3),
                          backgroundColor: Colors.grey[200],
                          checkmarkColor: Colors.green,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.green[700] : Colors.grey[700],
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 14,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '提示：選擇專業領域可以讓學員更容易找到您',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 30),
                  
                  // 註冊按鈕
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleRegister,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isLoading 
                            ? Colors.grey[400]
                            : const Color(0xFF173C56),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        elevation: _isLoading ? 0 : 2,
                        shadowColor: const Color(0xFF173C56),
                      ),
                      child: _isLoading
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Text('註冊中...'),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.person_add, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  '註冊',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // 返回登入連結
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        '已有帳號？',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: const Text(
                          '立即登入',
                          style: TextStyle(
                            color: Color(0xFF2C5F7C),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // 分隔線
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.black12)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          '或以下方式註冊',
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.black12)),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // 第三方註冊按鈕
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildSocialButton(
                        onPressed: () => socialRegister('Google'),
                        child: Image.asset(
                          'assets/icons/google_icon.png',
                          width: 24,
                          height: 24,
                          filterQuality: FilterQuality.none,
                        ),
                      ),
                      _buildSocialButton(
                        onPressed: () => socialRegister('Apple'),
                        child: Image.asset(
                          'assets/icons/apple_icon.png',
                          width: 24,
                          height: 24,
                          filterQuality: FilterQuality.none,
                        ),
                      ),
                      _buildSocialButton(
                        onPressed: () => socialRegister('Facebook'),
                        child: Image.asset(
                          'assets/icons/facebook_icon.png',
                          width: 24,
                          height: 24,
                          filterQuality: FilterQuality.none,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 社群帳號註冊功能
  void socialRegister(String platform) {
    _triggerHapticFeedback();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Row(
            children: [
              Icon(
                _getSocialIcon(platform), 
                color: _getSocialColor(platform),
              ),
              const SizedBox(width: 8),
              Text('$platform $selectedRole 註冊'),
            ],
          ),
          content: Text('使用 $platform 帳號註冊 $selectedRole 功能開發中\n\n此功能將在未來版本中推出，敬請期待！'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('確定', style: TextStyle(color: Color(0xFF173C56))),
            ),
          ],
        );
      },
    );
  }

  // 取得社群平台圖標
  IconData _getSocialIcon(String platform) {
    switch (platform) {
      case 'Google': return Icons.g_mobiledata;
      case 'Apple': return Icons.apple;
      case 'Facebook': return Icons.facebook;
      default: return Icons.account_circle;
    }
  }

  // 取得社群平台顏色
  Color _getSocialColor(String platform) {
    switch (platform) {
      case 'Google': return Colors.red;
      case 'Apple': return Colors.black;
      case 'Facebook': return Colors.blue;
      default: return Colors.grey;
    }
  }

  // 建立第三方登入按鈕的輔助方法
  Widget _buildSocialButton({required VoidCallback onPressed, required Widget child}) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Center(child: child),
      ),
    );
  }
}