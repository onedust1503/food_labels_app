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

  // *** 新增：創建用戶資料到 Firestore ***
  Future<void> _createUserProfile(User user, String role) async {
    try {
      // 確保角色值正確
      if (role != 'coach' && role != 'trainee') {
        throw Exception('無效的角色值: $role');
      }

      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'role': role, // 只存 'coach' 或 'trainee'
        'displayName': _nameController.text.trim(), // *** 修改：使用用戶輸入的姓名 ***
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      print('用戶資料創建成功，角色: $role');
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

      // *** 刪除：移除以下模擬邏輯 ***
      // await Future.delayed(const Duration(seconds: 2));
      // if (DateTime.now().millisecond % 5 == 0) {
      //   throw Exception('註冊失敗：此 Email 已被使用');
      // }
      // Map<String, dynamic> registerData = {...};

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
        content: Row(
          children: [
            Icon(
              backgroundColor == Colors.green ? Icons.check_circle : Icons.error,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor ?? Colors.deepOrange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Email 驗證器
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return '請輸入 Email';
    }
    // 簡單的 Email 格式驗證
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return '請輸入有效的 Email 格式';
    }
    return null;
  }

  // 密碼驗證器
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return '請輸入密碼';
    }
    if (value.length < 6) {
      return '密碼至少需要 6 個字符';
    }
    return null;
  }

  // 姓名驗證器
  String? _validateName(String? value) {
    if (value == null || value.isEmpty) {
      return '請輸入姓名';
    }
    if (value.length < 2) {
      return '姓名至少需要 2 個字符';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 背景顏色設定 (修改為與登入頁面一致)
      backgroundColor: const Color(0xFFE8F4FD),
      // 自訂 AppBar (修改為與登入頁面一致的深藍色)
      appBar: AppBar(
        title: const Text('註冊帳號'),
        backgroundColor: const Color(0xFF173C56),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView( // 可滾動，避免鍵盤彈出時溢出
          child: Column(
            children: [
              const SizedBox(height: 20),
              
              // Logo 區域（修改為與登入頁面相同的設計）
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue, Colors.purple],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: ClipOval(
                  child: Image.asset(
                    'assets/anim/Login_Food.gif',
                    width: 110,
                    height: 110,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.none,
                  ),
                ),
              ),
              
              const SizedBox(height: 30),

              // 身分選擇器 (新增)
              _buildRoleSelector(),
              
              // 表單容器 (修改為與登入頁面相同的白色圓角設計)
              Container(
                width: double.infinity,  // 確保容器佔滿寬度
                padding: const EdgeInsets.all(30),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(40),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 姓名輸入框 (修改樣式與登入頁面一致)
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
                          prefixIcon: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            child: Icon(
                              Icons.person_outline,
                              color: Colors.grey,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(
                              color: Colors.grey,
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
                      
                      // Email 輸入框 (修改樣式與登入頁面一致)
                      Text(
                        'Email',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      TextFormField(
                        controller: _emailController,
                        validator: _validateEmail,
                        keyboardType: TextInputType.emailAddress, // 設定鍵盤類型為 Email
                        decoration: InputDecoration(
                          hintText: '請輸入您的Email',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          prefixIcon: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            child: Icon(
                              Icons.email_outlined,
                              color: Colors.grey,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(
                              color: Colors.grey,
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
                      
                      // 密碼輸入框 (修改樣式與登入頁面一致)
                      Text(
                        '密碼',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      TextFormField(
                        controller: _passwordController,
                        validator: _validatePassword,
                        obscureText: !_isPasswordVisible, // 控制是否隱藏密碼
                        decoration: InputDecoration(
                          hintText: '請輸入您的密碼',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          prefixIcon: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            child: Icon(
                              Icons.lock_outline,
                              color: Colors.grey,
                            ),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                              color: const Color.fromARGB(255, 65, 62, 62),
                            ),
                            onPressed: () {
                              _triggerHapticFeedback(); // 觸覺回饋
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(
                              color: Colors.grey,
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
                      
                      // 確認密碼輸入框 (修改樣式與登入頁面一致)
                      Text(
                        '確認密碼',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      TextFormField(
                        controller: _confirmPasswordController,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '請再次輸入密碼';
                          }
                          return null;
                        },
                        obscureText: !_isConfirmPasswordVisible,
                        decoration: InputDecoration(
                          hintText: '請再次輸入密碼',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          prefixIcon: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            child: Icon(
                              Icons.lock_outline,
                              color: Colors.grey,
                            ),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                              color: const Color.fromARGB(255, 65, 62, 62),
                            ),
                            onPressed: () {
                              _triggerHapticFeedback(); // 觸覺回饋
                              setState(() {
                                _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(
                              color: Colors.grey,
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
                      
                      const SizedBox(height: 32),
                      
                      // 註冊按鈕 (修改：添加載入狀態)
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleRegister, // 載入中禁用按鈕
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(54),
                            backgroundColor: _isLoading 
                                ? Colors.grey[400] // 載入中變灰色
                                : const Color(0xFF173C56),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                            elevation: _isLoading ? 0 : 2, // 載入中去除陰影
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
                              Navigator.pop(context); // 返回登入頁面
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
                      
                      // 分隔線 (修改為與登入頁面一致)
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
                      
                      // 第三方註冊按鈕 (修改為與登入頁面相同的設計)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Google 註冊
                          _buildSocialButton(
                            onPressed: () => socialRegister('Google'),
                            child: Image.asset(
                              'assets/icons/google_icon.png',
                              width: 24,
                              height: 24,
                              filterQuality: FilterQuality.none,
                            ),
                          ),

                          // Apple 註冊
                          _buildSocialButton(
                            onPressed: () => socialRegister('Apple'),
                            child: Image.asset(
                              'assets/icons/apple_icon.png',
                              width: 24,
                              height: 24,
                              filterQuality: FilterQuality.none,
                            ),
                          ),

                          // Facebook 註冊
                          _buildSocialButton(
                            onPressed: () => socialRegister('Facebook'),
                            child: Image.asset(
                              'assets/icons/facebook_icon.png', // *** 修正：應該是 facebook_icon.png ***
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
            ],
          ),
        ),
      ),
    );
  }

  // 社群帳號註冊功能 (新增)
  void socialRegister(String platform) {
    _triggerHapticFeedback(); // 觸覺回饋
    
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

  // 取得社群平台圖標 (新增)
  IconData _getSocialIcon(String platform) {
    switch (platform) {
      case 'Google': return Icons.g_mobiledata;
      case 'Apple': return Icons.apple;
      case 'Facebook': return Icons.facebook;
      default: return Icons.account_circle;
    }
  }

  // 取得社群平台顏色 (新增)
  Color _getSocialColor(String platform) {
    switch (platform) {
      case 'Google': return Colors.red;
      case 'Apple': return Colors.black;
      case 'Facebook': return Colors.blue;
      default: return Colors.grey;
    }
  }

  // 建立第三方登入按鈕的輔助方法 (修改為與登入頁面相同)
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